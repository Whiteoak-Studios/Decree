--[[
    The window's suggestions: a row for each way to finish the word being
    typed, below the entry, under the suggested name, type and description
--]]

--!strict
local AutoComplete = {}
AutoComplete.__index = AutoComplete

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Util = require("../../Shared/Util")
local WindowConfig = require("../../Config/Window")

local CHARACTER_WIDTH: number = WindowConfig.characterWidth
local TEXT_SIZE: number = WindowConfig.textSize
local SELECTED: number = WindowConfig.selectedTransparency
local UNSELECTED: number = 1 -- A row that is not selected shows no background
local MIN_WIDTH: number = 200 -- The narrowest the suggestions get, in pixels
local ROW_PADDING: number = 20 -- Pixels a row keeps beside its text
local EDGE: number = 10 -- The rows' left padding, which the suggestions sit left by so a row's text lines up
local BELOW: number = 30 -- Pixels from the entry's top to the suggestions' top
local SCREEN_MARGIN: number = 10 -- Pixels the suggestions keep clear of the screen's bottom
local MEASURE_SAMPLE: string = "MMMMMMMMMM" -- Its width over its length is one character's in a monospace font
local MEASURE_WIDTH: number = 1000 -- Wide enough that the sample never wraps
local PLAIN: boolean = true -- Finds the text as written, with no pattern characters
local SPACE: string = " "
local NONE: string = ""

local Types = require("../../Shared/Config/Types/Command")

type ArgumentContext = Types.ArgumentContext
type Context = Types.Context
type ResolvedStyle = WindowConfig.ResolvedStyle

export type Details = {
	name: string?, -- The suggested command's, subcommand's or argument's name
	type: string?, -- The argument's type
	description: string?,
	invalid: boolean?, -- Whether the description is the argument's refusal
}

export type Item = {
	typed: string, -- What is typed of the suggestion
	suggestion: string,
	details: Details?, -- Shown while the item is selected, in place of the show's own
}

export type Options = {
	at: number?, -- The column the suggestions start under, the word being typed when left out
	isLast: boolean?, -- Whether the word is the last argument's, so a Tab after a space keeps the text
	argumentCount: number?, -- How many arguments are typed
	context: Context?, -- The command whose argument is suggested
	argument: ArgumentContext?, -- That argument
	isPartial: boolean?, -- Whether each suggestion is part of a value, so no space follows one
	lead: string?, -- The text a suggestion follows when it is no argument's, such as the command before a subcommand
	details: Details?,
}

type Fields = {
	items: { Item },
	selected: number,
	lastItem: boolean,
	context: Context?,
	argument: ArgumentContext?,
	argumentCount: number?,
	isPartial: boolean,
	lead: string,
	_gui: ScreenGui,
	_frame: ScrollingFrame,
	_layout: UIListLayout,
	_title: Frame,
	_field: TextLabel,
	_type: TextLabel,
	_description: Frame,
	_label: TextLabel,
	_rowTemplate: TextButton,
	_rows: { TextButton },
	_textBox: TextBox,
	_style: ResolvedStyle,
	_barThickness: number,
	_width: number,
	_characterWidth: number,
}

--- Makes the suggestions over the Autocomplete frame of the console's
--- ScreenGui, and starts measuring the input font's character width.
--- @function new
--- @within AutoComplete
--- @param gui ScreenGui
--- @param style ResolvedStyle
--- @return AutoComplete

function AutoComplete.new(gui: ScreenGui, style: ResolvedStyle): Self
	local frame = gui:FindFirstChild("Autocomplete") :: ScrollingFrame
	local title = frame:FindFirstChild("Title") :: Frame
	local field = title:FindFirstChild("Field") :: TextLabel
	local description = frame:FindFirstChild("Description") :: Frame
	local rowTemplate = frame:FindFirstChild("Row") :: TextButton
	local entry = (gui:FindFirstChild("Frame") :: ScrollingFrame):FindFirstChild("Entry") :: Frame

	rowTemplate.Parent = nil

	local fields: Fields = {
		items = {},
		selected = 1,
		lastItem = false,
		context = nil,
		argument = nil,
		argumentCount = nil,
		isPartial = false,
		lead = NONE,
		_gui = gui,
		_frame = frame,
		_layout = frame:FindFirstChild("UIListLayout") :: UIListLayout,
		_title = title,
		_field = field,
		_type = field:FindFirstChild("Type") :: TextLabel,
		_description = description,
		_label = description:FindFirstChild("Label") :: TextLabel,
		_rowTemplate = rowTemplate,
		_rows = {},
		_textBox = entry:FindFirstChild("TextBox") :: TextBox,
		_style = style,
		_barThickness = frame.ScrollBarThickness,
		_width = MIN_WIDTH,
		_characterWidth = CHARACTER_WIDTH,
	}

	local self: Self = setmetatable(fields, AutoComplete)

	-- Goes with the ScreenGui, which holds the layout
	self._layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function ()
		self:_updateSize()
	end)

	self:_measure()

	return self
end

--[[
    Measures one character of the input font, on a thread of its own since
    the font may still be loading, and keeps the default width until then
--]]

function AutoComplete._measure(self: Self)
	local params: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
	params.Text = MEASURE_SAMPLE
	params.Font = self._style.inputFont
	params.Size = TEXT_SIZE
	params.Width = MEASURE_WIDTH

	Promise.new(function (resolve: (bounds: Vector2) -> ())
		resolve(TextService:GetTextBoundsAsync(params))
	end)
		:andThen(function (bounds: Vector2)
			self._characterWidth = bounds.X / #MEASURE_SAMPLE
		end)
		:catch(function (problem: any)
			warn(
				`[Decree] The console could not measure its input font, so suggestions take {CHARACTER_WIDTH} px a character: {problem}`
			)
		end)
end

--- Shows a row for each item below the entry, the first selected, under
--- the selected item's details or the show's own.
--- @method show
--- @within AutoComplete
--- @param items { Item }
--- @param options Options?

function AutoComplete.show(self: Self, items: { Item }, options: Options?)
	local given: Options = options or {}

	for _, row: TextButton in self._rows do
		row:Destroy()
	end

	table.clear(self._rows)

	self.items = items
	self.selected = 1
	self.lastItem = given.isLast == true
	self.context = given.context
	self.argument = given.argument
	self.argumentCount = given.argumentCount
	self.isPartial = given.isPartial == true
	self.lead = given.lead or NONE

	local width: number = MIN_WIDTH
	self._frame.ScrollBarThickness = 0

	for index: number, item: Item in items do
		local row: TextButton = self._rowTemplate:Clone()
		local typed = row:FindFirstChild("Typed") :: TextLabel
		local suggest = row:FindFirstChild("Suggest") :: TextLabel
		local suggestion: string = item.suggestion

		-- The typed text lines up over where it sits in the suggestion, or over its start when it is not in it
		local first: number?, last: number? = suggestion:lower():find(item.typed:lower(), 1, PLAIN)
		local start: number = first or 1
		local stop: number = last or #suggestion

		typed.Text = `{SPACE:rep(start - 1)}{item.typed}`
		suggest.Text = `{suggestion:sub(1, start - 1)}{SPACE:rep(#item.typed)}{suggestion:sub(stop + 1)}`
		row.Name = `{item.typed}{suggestion}`
		row.BackgroundTransparency = index == self.selected and SELECTED or UNSELECTED
		row.LayoutOrder = index
		row.Parent = self._frame

		width = math.max(width, typed.TextBounds.X + ROW_PADDING, suggest.TextBounds.X + ROW_PADDING)
		table.insert(self._rows, row)
	end

	local text: string = self._textBox.Text
	local words: { string } = Util.splitString(text)

	-- The word being typed starts where the words before it end, and a trailing space starts the next one
	if text:sub(-1) ~= SPACE then
		table.remove(words)
	end

	local column: number = given.at or #table.concat(words, SPACE) + 1
	self:updatePosition(column * self._characterWidth)

	self._width = width
	self._frame.Size = UDim2.fromOffset(width, self._layout.AbsoluteContentSize.Y)
	self._frame.Visible = true

	local selected: Item? = items[1]
	local details: Details? = selected and selected.details
	self:_updateInfo(details or given.details or {})
end

--- The selected item while the suggestions show.
--- @method getSelectedItem
--- @within AutoComplete
--- @return Item?

function AutoComplete.getSelectedItem(self: Self): Item?
	if not self._frame.Visible then
		return nil
	end

	return self.items[self.selected]
end

--- Hides the suggestions.
--- @method hide
--- @within AutoComplete

function AutoComplete.hide(self: Self)
	self._frame.Visible = false
end

--- Whether the suggestions show.
--- @method isVisible
--- @within AutoComplete
--- @return boolean

function AutoComplete.isVisible(self: Self): boolean
	return self._frame.Visible
end

--- Moves the selection by a number of rows, wrapping at either end, and
--- scrolls the selected row into view.
--- @method select
--- @within AutoComplete
--- @param delta number

function AutoComplete.select(self: Self, delta: number)
	if not self._frame.Visible then
		return
	end

	self.selected += delta

	if self.selected > #self.items then
		self.selected = 1
	elseif self.selected < 1 then
		self.selected = #self.items
	end

	for index: number, row: TextButton in self._rows do
		row.BackgroundTransparency = index == self.selected and SELECTED or UNSELECTED
	end

	local header: number = self._title.AbsoluteSize.Y + self._description.AbsoluteSize.Y
	local bottom: number = header + self.selected * self._rowTemplate.Size.Y.Offset
	self._frame.CanvasPosition = Vector2.new(0, math.max(0, bottom - self._frame.AbsoluteSize.Y))

	local item: Item? = self.items[self.selected]
	if item and item.details then
		self:_updateInfo(item.details)
	end
end

--- Places the suggestions below the entry, a number of pixels along it
--- when given one.
--- @method updatePosition
--- @within AutoComplete
--- @param offset number?

function AutoComplete.updatePosition(self: Self, offset: number?)
	local entry: Vector2 = self._textBox.AbsolutePosition
	local x: number = offset and entry.X - EDGE + offset or entry.X

	self._frame.Position = UDim2.fromOffset(x, entry.Y + BELOW)
end

--[[
    Sizes the suggestions to their rows and to the name and type above
    them, never past the bottom of the screen
--]]

function AutoComplete._updateSize(self: Self)
	local width: number = math.max(self._field.TextBounds.X + self._type.TextBounds.X, self._width)
	local available: number = self._gui.AbsoluteSize.Y - self._frame.AbsolutePosition.Y - SCREEN_MARGIN

	self._frame.Size = UDim2.fromOffset(width, math.min(self._layout.AbsoluteContentSize.Y, available))
end

--[[
    Shows a label's text, or hides the object that holds it when there is
    no text
--]]

local function showText(object: GuiObject, label: TextLabel, text: string?)
	object.Visible = text ~= nil
	label.Text = text or NONE
end

--[[
    Shows the details of the selected item, the description in the refusal
    color when it is the argument's refusal
--]]

function AutoComplete._updateInfo(self: Self, details: Details)
	local typeName: string? = details.type and `: {details.type:sub(1, 1):upper()}{details.type:sub(2)}`

	showText(self._title, self._field, details.name)
	showText(self._type, self._type, typeName)
	showText(self._description, self._label, details.description)

	self._label.TextColor3 = details.invalid and self._style.invalid or self._style.suggestionText
	self._frame.ScrollBarThickness = self._barThickness

	-- The labels' new text is laid out by the next resumption, which sizes the suggestions to it
	task.defer(self._updateSize, self)
end

export type AutoComplete = Self
type Self = typeof(setmetatable({} :: Fields, AutoComplete))

return AutoComplete
