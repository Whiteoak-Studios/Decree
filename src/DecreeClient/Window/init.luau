--[[
    The console window over the ScreenGui CreateGui builds: typing with live
    validation and completion, history, opening and closing, and the lines
    replies print, colored by kind and capped
--]]

--!strict
local Window = {}
Window.__index = Window

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local AutoComplete = require("./Window/Modules/AutoComplete")
local CreateGui = require("./Window/Functions/CreateGui")
local Dispatcher = require("./Shared/Dispatcher")
local Registry = require("./Shared/Registry")
local Util = require("./Shared/Util")
local WindowConfig = require("./Config/Window")

local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui -- Boot-time wait: it may not have replicated yet

local MAX_HEIGHT: number = WindowConfig.maxHeight
local TAB_WIDTH: number = WindowConfig.tabWidth
local MASH_PRESSES: number = WindowConfig.mashPresses
local MASH_SECONDS: number = WindowConfig.mashSeconds
local MEASURE_SECONDS: number = WindowConfig.measureSeconds
local HISTORY: string = "DECREE_COMMAND_HISTORY" -- The teleport setting the typed lines are kept under
local ACTIVATION_ACTION: string = "DecreeActivation"
local REFOCUS_ACTION: string = "DecreeRefocus"
local CLICK_OUTSIDE_ACTION: string = "DecreeClickOutside"
local ACTION_PRIORITY: number = Enum.ContextActionPriority.High.Value
local CREATE_TOUCH_BUTTON: boolean = false -- The window's actions need no touch button of the engine's
local REQUIRED_ARGUMENTS: string = "This command has required arguments."
local OPTIONAL: string = "?" -- Follows an optional argument's name in its details
local INFO: Kind = "Info"
local REFUSED: Kind = "Refused"
local TRAILING_SPACE: string = "%s$"
local LINE_BREAKS: string = "[\r\n]"
local TAB: string = "\t"
local LINE_BREAK: string = "\n"
local CARRIAGE_RETURN: string = "\r"
local SPACE: string = " "
local LIST_SEPARATOR: string = ","
local QUOTED: string = "%q"
local PLAIN: boolean = true -- Finds the text as written, with no pattern characters
local NONE: string = ""

local POINTER_INPUTS: { Enum.UserInputType } = {
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2,
	Enum.UserInputType.Touch,
}

local Types = require("./Shared/Config/Types/Command")
local Wire = require("./Shared/Wire")

type ArgumentContext = Types.ArgumentContext
type ArgumentDefinition = Types.ArgumentDefinition
type CommandDefinition = Types.CommandDefinition
type Context = Types.Context
type Item = AutoComplete.Item
type Kind = Wire.Decree_Kind
type ResolvedStyle = WindowConfig.ResolvedStyle
type SubcommandDefinition = Types.SubcommandDefinition

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Toggled = {
	Connect: (self: Toggled, callback: (visible: boolean) -> ()) -> Connection,
	Fire: (self: Toggled, visible: boolean) -> (),
}

-- What the client object holds for the window, set before or after start
export type Settings = {
	enabled: boolean, -- Whether the activation keys, show and toggle open the window
	activationKeys: { Enum.KeyCode },
	activationUnlocksMouse: boolean,
	hideOnLostFocus: boolean, -- Whether a click or tap outside the window hides it
	mashToEnable: boolean, -- Whether the window waits for a mash of an activation key before it first opens
	placeName: string,
	contextLine: string, -- Shown above the prompt, and hidden while empty
	maxLines: number,
	toggleButtons: { [GuiObject]: RBXScriptConnection }, -- A tap on one is the button's; each holds the watch that drops it once destroyed
}

type Owner = {
	_settings: Settings,
	toggled: Toggled,
}

type Action = (name: string, state: Enum.UserInputState, input: InputObject) -> Enum.ContextActionResult

type ChatConfiguration = ChatWindowConfiguration | ChatInputBarConfiguration | ChannelTabsConfiguration

type HistoryState = {
	position: number, -- The history entry shown, one past the last for the text typed before
	initialText: string,
}

-- Anything that names the arguments it takes first: a command or a subcommand
type Named = {
	args: { ArgumentDefinition }?,
}

type Fields = {
	gui: ScreenGui,
	_owner: Owner,
	_style: ResolvedStyle,
	_kinds: { [any]: Color3 },
	_frame: ScrollingFrame,
	_layout: UIListLayout,
	_padding: UIPadding,
	_textBox: TextBox,
	_prompt: TextLabel,
	_context: TextLabel,
	_lineTemplate: TextBox,
	_backdrop: Frame,
	_mouseUnlocker: TextButton,
	_autoComplete: AutoComplete.AutoComplete,
	_lines: { TextBox },
	_menuOpened: RBXScriptConnection,
	_visibleInput: RBXScriptConnection?,
	_chatStates: { [ChatConfiguration]: boolean },
	_valid: boolean,
	_errorText: string?,
	_history: HistoryState?,
	_presses: number,
	_lastPress: number,
	_onActivation: Action,
	_onRefocus: Action,
	_onClickOutside: Action,
}

--[[
    An action that runs its callback when its input is released, which
    keeps the key's own character out of a TextBox focused in response
--]]

local function onKeyReleased(callback: () -> ()): Action
	local pressed: boolean = false

	return function (_: string, state: Enum.UserInputState): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			pressed = true
		elseif state == Enum.UserInputState.End and pressed then
			pressed = false
			callback()
		else
			pressed = false
		end

		return Enum.ContextActionResult.Pass
	end
end

--- Builds the window in the resolved style for the client object that
--- holds its settings, parented to the PlayerGui and hidden. Everything it
--- connects goes when its ScreenGui is destroyed.
--- @function new
--- @within Window
--- @param owner Owner
--- @param style ResolvedStyle
--- @return Window

function Window.new(owner: Owner, style: ResolvedStyle): Self
	local gui: ScreenGui = CreateGui(style)
	local frame = gui:FindFirstChild("Frame") :: ScrollingFrame
	local entry = frame:FindFirstChild("Entry") :: Frame
	local lineTemplate = frame:FindFirstChild("Line") :: TextBox

	lineTemplate.Parent = nil
	gui.Parent = PlayerGui

	local self: Self

	local fields: Fields = {
		gui = gui,
		_owner = owner,
		_style = style,
		_kinds = { Info = style.info, Ok = style.ok, Refused = style.refused, Error = style.error },
		_frame = frame,
		_layout = frame:FindFirstChild("UIListLayout") :: UIListLayout,
		_padding = frame:FindFirstChild("UIPadding") :: UIPadding,
		_textBox = entry:FindFirstChild("TextBox") :: TextBox,
		_prompt = entry:FindFirstChild("Prompt") :: TextLabel,
		_context = frame:FindFirstChild("Context") :: TextLabel,
		_lineTemplate = lineTemplate,
		_backdrop = gui:FindFirstChild("Backdrop") :: Frame,
		_mouseUnlocker = gui:FindFirstChild("MouseUnlocker") :: TextButton,
		_autoComplete = AutoComplete.new(gui, style),
		_lines = {},
		_visibleInput = nil,
		_chatStates = {},
		_valid = true,
		_errorText = nil,
		_history = nil,
		_presses = 0,
		_lastPress = 0,

		_menuOpened = GuiService.MenuOpened:Connect(function ()
			self:hide()
		end),

		_onActivation = onKeyReleased(function ()
			self:_handleActivationKey()
		end),

		_onRefocus = onKeyReleased(function ()
			self._textBox:CaptureFocus()
		end),

		_onClickOutside = function (_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
			if state == Enum.UserInputState.Begin then
				self:_handlePointerInput(input)
			end

			return Enum.ContextActionResult.Pass
		end,
	}

	self = setmetatable(fields, Window)

	-- Each of these is on one of the ScreenGui's own instances, and goes with it
	self._textBox.FocusLost:Connect(function (submit: boolean, cause: InputObject?)
		self:_loseFocus(submit, cause)
	end)

	self._textBox:GetPropertyChangedSignal("Text"):Connect(function ()
		self:_onTextChanged()
	end)

	self._backdrop.InputBegan:Connect(function (input: InputObject)
		self:_handlePointerInput(input)
	end)

	self._layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function ()
		self:updateWindowHeight()
	end)

	gui.Destroying:Connect(function ()
		self:_destroy()
	end)

	self:bindActivationKeys()
	self:updatePrompt()
	self:updateContextLine()
	self:updateWindowHeight()

	return self
end

--[[
    Drops what the window holds outside its ScreenGui: its service
    connection, its bound actions and the chat it hid
--]]

function Window._destroy(self: Self)
	self._menuOpened:Disconnect()
	self:_setInputBound(false)
	self:_setChatEnabled(true)

	ContextActionService:UnbindAction(ACTIVATION_ACTION)
end

--[[
    A text with each tab replaced by the spaces to the next tab stop, the
    columns counted from the start of its line
--]]

local function emulateTabstops(text: string, tabWidth: number): string
	local column: number = 0
	local result: { string } = {}

	for index = 1, #text do
		local character: string = text:sub(index, index)

		if character == TAB then
			local spaces: number = tabWidth - column % tabWidth
			table.insert(result, SPACE:rep(spaces))
			column += spaces
			continue
		end

		table.insert(result, character)

		if character == LINE_BREAK then
			column = 0
		elseif character ~= CARRIAGE_RETURN then
			column += 1
		end
	end

	return table.concat(result)
end

--[[
    The height of a line's text wrapped at a width, in the line's own font
    and size, measured on a thread of its own since the font may still be
    loading
--]]

function Window._measureLineHeight(line: TextBox, width: number): any
	local params: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
	params.Text = line.Text
	params.Font = line.FontFace
	params.Size = line.TextSize
	params.Width = width

	local late: string = `its font was not measured within {MEASURE_SECONDS} seconds`

	return Promise.new(function (resolve: (height: number) -> ())
		resolve(TextService:GetTextBoundsAsync(params).Y)
	end):timeout(MEASURE_SECONDS, late)
end

--[[
    Fits a line's height to its text, never under the template's, each time
    its width changes; a height measured for a width the line has since left
    is dropped for the newer one, and a line that fails to measure grows
    only to the window's height
--]]

local function fitter(line: TextBox): () -> ()
	local least: number = line.Size.Y.Offset
	local measured: number? = nil -- The width the line was last measured at

	return function ()
		local width: number = line.AbsoluteSize.X
		if width == measured then
			return
		end

		measured = width

		Window._measureLineHeight(line, width)
			:andThen(function (height: number)
				if line.AbsoluteSize.X == width then
					local across: UDim = line.Size.X
					line.Size = UDim2.new(across.Scale, across.Offset, 0, math.max(height, least))
				end
			end)
			:catch(function (problem: any)
				line.AutomaticSize = Enum.AutomaticSize.Y
				warn(`[Decree] A printed line shows only as tall as the console, since {problem}`)
			end)
	end
end

--[[
    Prints a line in a color, dropping the oldest lines past the cap; an
    empty text prints nothing
--]]

function Window._addLine(self: Self, text: string, color: Color3)
	if text == NONE then
		return
	end

	local line: TextBox = self._lineTemplate:Clone()
	line.Text = emulateTabstops(text, TAB_WIDTH)
	line.TextColor3 = color
	line.Parent = self._frame

	-- Fits the line again as the window's width changes, and goes with the line
	local fit: () -> () = fitter(line)
	line:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	table.insert(self._lines, line)

	while #self._lines > self._owner._settings.maxLines do
		local oldest: TextBox = table.remove(self._lines, 1) :: TextBox
		oldest:Destroy()
	end
end

--- Prints a line in its reply kind's color, where no kind, a Color3 or an
--- options table is Info; an empty text prints nothing.
--- @method addLine
--- @within Window
--- @param text any -- Printed through tostring
--- @param kind any -- "Info", "Ok", "Refused" or "Error"

function Window.addLine(self: Self, text: any, kind: any)
	self:_addLine(tostring(text), self._kinds[kind] or self._kinds[INFO])
end

--- Removes every printed line.
--- @method clear
--- @within Window

function Window.clear(self: Self)
	for _, line: TextBox in self._lines do
		line:Destroy()
	end

	table.clear(self._lines)
end

--- Sizes the window to its lines, up to its maximum height, and scrolls to
--- the newest.
--- @method updateWindowHeight
--- @within Window

function Window.updateWindowHeight(self: Self)
	local padding: UIPadding = self._padding
	local height: number = self._layout.AbsoluteContentSize.Y + padding.PaddingTop.Offset + padding.PaddingBottom.Offset
	local width: UDim = self._frame.Size.X

	self._frame.Size = UDim2.new(width.Scale, width.Offset, 0, math.clamp(height, 0, MAX_HEIGHT))
	self._frame.CanvasPosition = Vector2.new(0, height)
	self._autoComplete:updatePosition()
end

--- Shows the player's name and the place name in the prompt, as Name$ or
--- Name@Place$.
--- @method updatePrompt
--- @within Window

function Window.updatePrompt(self: Self)
	local placeName: string = self._owner._settings.placeName

	self._prompt.Text = placeName == NONE and `{Player.Name}$` or `{Player.Name}@{placeName}$`
end

--- Shows the context line above the prompt, or hides it while it is empty.
--- @method updateContextLine
--- @within Window

function Window.updateContextLine(self: Self)
	local text: string = self._owner._settings.contextLine

	self._context.Text = text
	self._context.Visible = text ~= NONE
end

--- Frees the mouse while the window shows, when the game turned that on.
--- @method updateMouseUnlock
--- @within Window

function Window.updateMouseUnlock(self: Self)
	self._mouseUnlocker.Visible = self:isVisible() and self._owner._settings.activationUnlocksMouse
end

--[[
    Turns TextChatService's chat window, input bar and channel tabs off,
    keeping each one's state, or puts back the states it kept
--]]

function Window._setChatEnabled(self: Self, enabled: boolean)
	if enabled then
		for configuration: ChatConfiguration, wasEnabled: boolean in self._chatStates do
			configuration.Enabled = wasEnabled
		end

		table.clear(self._chatStates)

		return
	end

	local configurations: { ChatConfiguration } = {
		TextChatService.ChatWindowConfiguration,
		TextChatService.ChatInputBarConfiguration,
		TextChatService.ChannelTabsConfiguration,
	}

	for _, configuration: ChatConfiguration in configurations do
		self._chatStates[configuration] = configuration.Enabled
		configuration.Enabled = false
	end
end

--- Shows or hides the window. Showing it focuses the entry and hides the
--- chat, hiding it puts the chat back, and either fires toggled.
--- @method setVisible
--- @within Window
--- @param visible boolean

function Window.setVisible(self: Self, visible: boolean)
	if self._frame.Visible == visible then
		return
	end

	self._frame.Visible = visible
	self:_setChatEnabled(not visible)
	self:_setInputBound(visible)
	self:updateMouseUnlock()

	if visible then
		self._textBox:CaptureFocus()
		self:_setEntryText(NONE)
	else
		self._autoComplete:hide()
		self._textBox:ReleaseFocus()
	end

	self._owner.toggled:Fire(visible)
end

--- Whether the window shows.
--- @method isVisible
--- @within Window
--- @return boolean

function Window.isVisible(self: Self): boolean
	return self._frame.Visible
end

--- Shows the window.
--- @method show
--- @within Window

function Window.show(self: Self)
	self:setVisible(true)
end

--- Hides the window.
--- @method hide
--- @within Window

function Window.hide(self: Self)
	self:setVisible(false)
end

--- The lines typed in the console, oldest first, kept across teleports
--- within the game.
--- @method getHistory
--- @within Window
--- @return { string }

function Window.getHistory(_: Self): { string }
	return TeleportService:GetTeleportSetting(HISTORY) or {}
end

--[[
    Adds a typed line to the history, unless it is empty or the line just
    before it
--]]

function Window._pushHistory(self: Self, text: string)
	local history: { string } = self:getHistory()
	if Util.trimString(text) == NONE or text == history[#history] then
		return
	end

	table.insert(history, text)
	TeleportService:SetTeleportSetting(HISTORY, history)
end

--[[
    The typed line without the tabs a Tab press leaves in it
--]]

function Window._getEntryText(self: Self): string
	return (self._textBox.Text:gsub(TAB, NONE))
end

--[[
    Sets the typed line, with the cursor after it while the window shows
--]]

function Window._setEntryText(self: Self, text: string)
	self._textBox.Text = text

	if self:isVisible() then
		self._textBox.CursorPosition = #text + 1
		self:updateWindowHeight()
	end
end

--[[
    Marks the typed line valid or invalid, in its color and in whether
    Enter runs it or prints the reason
--]]

function Window._setIsValidInput(self: Self, valid: boolean, errorText: string?)
	self._textBox.TextColor3 = valid and self._style.text or self._style.invalid
	self._valid = valid
	self._errorText = errorText
end

--[[
    Shows the typed line in the valid color while it stays invalid
--]]

function Window._hideInvalidState(self: Self)
	self._textBox.TextColor3 = self._style.text
end

--[[
    Moves through the history, back from the text typed before the first
    move and forward to it again
--]]

function Window._traverseHistory(self: Self, delta: number)
	local history: { string } = self:getHistory()
	local state: HistoryState = self._history or { position = #history + 1, initialText = self:_getEntryText() }
	self._history = state

	state.position = math.clamp(state.position + delta, 1, #history + 1)
	self:_setEntryText(state.position == #history + 1 and state.initialText or history[state.position])
end

--[[
    Moves the suggestions' selection while they show and no history is
    being moved through, or else moves through the history
--]]

function Window._selectVertical(self: Self, delta: number)
	if self._autoComplete:isVisible() and not self._history then
		self._autoComplete:select(delta)
	else
		self:_traverseHistory(delta)
	end
end

--[[
    Runs a typed line: keeps it in the history, prints it in the echo color
    and prints its reply once it comes
--]]

function Window._processEntry(self: Self, text: string)
	local trimmed: string = Util.trimString(text)
	if trimmed == NONE then
		return
	end

	self:_pushHistory(trimmed)
	self:_addLine(`{self._prompt.Text} {trimmed}`, self._style.echo)

	Dispatcher:evaluateAndRun(trimmed):andThen(function (reply: string, kind: Kind)
		self:addLine(reply, kind)
	end)
end

--[[
    Hides the window on Escape, and on Enter runs the typed line, or
    prints why it can't run, and takes focus back
--]]

function Window._loseFocus(self: Self, submit: boolean, cause: InputObject?)
	local text: string = self._textBox.Text
	self._history = nil

	if cause and cause.KeyCode == Enum.KeyCode.Escape then
		self:hide()
		return
	end

	if not submit then
		return
	end

	-- Focus comes back once the engine has finished taking it away
	task.defer(function ()
		if self:isVisible() then
			self._textBox:CaptureFocus()
		end
	end)

	if self._valid then
		self:_setEntryText(NONE)
		self:_processEntry(text)
	else
		self:_addLine(self._errorText or NONE, self._kinds[REFUSED])
	end
end

--[[
    Opens or closes the window on an activation key, or with mash to
    enable on, opens it at the last of enough quick presses
--]]

function Window._handleActivationKey(self: Self)
	local settings: Settings = self._owner._settings
	if not settings.enabled then
		return
	end

	if not settings.mashToEnable then
		self:setVisible(not self:isVisible())
		return
	end

	local now: number = os.clock()
	if now - self._lastPress < MASH_SECONDS then
		self._presses += 1
	else
		self._presses = 1
	end

	self._lastPress = now

	if self._presses >= MASH_PRESSES then
		self._presses = 0
		settings.mashToEnable = false
		self:setVisible(true)
	end
end

--[[
    The typed line with the last argument's segment in progress replaced,
    the arguments after it left out, and quotes around an empty argument
    or one holding a space
--]]

local function buildCompletion(context: Context, last: ArgumentContext?, replace: string): string
	local parts: { string } = { context.alias }

	if context.subcommand then
		table.insert(parts, context.subcommand.name)
	end

	for _, argument: ArgumentContext in context.arguments do
		local segments: { string } = argument.rawSegments

		if argument == last then
			segments = table.clone(segments)
			segments[#segments] = replace
		end

		local argumentText: string = `{argument.prefix}{table.concat(segments, LIST_SEPARATOR)}`
		local quoted: boolean = argumentText == NONE or argumentText:find(SPACE, 1, PLAIN) ~= nil
		table.insert(parts, quoted and QUOTED:format(argumentText) or argumentText)

		if argument == last then
			break
		end
	end

	return table.concat(parts, SPACE)
end

--[[
    Completes the typed line with the selected suggestion on Tab, and a
    space after it unless the suggestion is part of a value or the last
--]]

function Window._handleTabCompletion(self: Self)
	local autoComplete: AutoComplete.AutoComplete = self._autoComplete
	local item: Item? = autoComplete:getSelectedItem()
	local text: string = self:_getEntryText()

	if not item or (autoComplete.lastItem and text:match(TRAILING_SPACE) ~= nil) then
		self:_setEntryText(text)
		return
	end

	local context: Context? = autoComplete.context
	if not context then
		self:_setEntryText(`{autoComplete.lead}{item.suggestion}{SPACE}`)
		return
	end

	local completed: string = buildCompletion(context, autoComplete.argument, item.suggestion)
	local spaced: boolean = autoComplete.argumentCount ~= #context.argumentDefinitions and not autoComplete.isPartial

	self:_setEntryText(spaced and `{completed}{SPACE}` or completed)
end

--[[
    Whether a screen position is outside a GuiObject's bounds
--]]

local function isOutside(position: Vector3, object: GuiObject): boolean
	local topLeft: Vector2 = object.AbsolutePosition
	local bottomRight: Vector2 = topLeft + object.AbsoluteSize

	return position.X < topLeft.X or position.X > bottomRight.X or position.Y < topLeft.Y or position.Y > bottomRight.Y
end

--[[
    Hides the window on a click or tap outside it, when hide on lost focus
    is on, unless it lands on a registered toggle button
--]]

function Window._handlePointerInput(self: Self, input: InputObject)
	local settings: Settings = self._owner._settings
	if not settings.hideOnLostFocus or not table.find(POINTER_INPUTS, input.UserInputType) then
		return
	end

	local position: Vector3 = input.Position
	if not isOutside(position, self._frame) then
		return
	end

	for button: GuiObject in settings.toggleButtons do
		if button.Visible and not isOutside(position, button) then
			return
		end
	end

	self:hide()
end

--[[
    Handles the keys the window hears while it shows: an activation key the
    game took, Ctrl+Backspace, Up and Down, and any other key's typing
--]]

function Window._handleVisibleInput(self: Self, input: InputObject, gameProcessed: boolean)
	local keyCode: Enum.KeyCode = input.KeyCode

	if table.find(self._owner._settings.activationKeys, keyCode) then
		if gameProcessed then
			self:hide()
		end
	elseif keyCode == Enum.KeyCode.Backspace and input:IsModifierKeyDown(Enum.ModifierKey.Ctrl) then
		self:_setEntryText(NONE)
	elseif keyCode == Enum.KeyCode.Down then
		self:_selectVertical(1)
	elseif keyCode == Enum.KeyCode.Up then
		self:_selectVertical(-1)
	elseif input.UserInputType == Enum.UserInputType.Keyboard and keyCode ~= Enum.KeyCode.Tab then
		self._history = nil
	end
end

--- Binds the activation keys the client object holds, in place of any it
--- bound before.
--- @method bindActivationKeys
--- @within Window

function Window.bindActivationKeys(self: Self)
	ContextActionService:UnbindAction(ACTIVATION_ACTION)

	local keys: { Enum.KeyCode } = self._owner._settings.activationKeys
	if #keys == 0 then
		return
	end

	ContextActionService:BindActionAtPriority(
		ACTIVATION_ACTION,
		self._onActivation,
		CREATE_TOUCH_BUTTON,
		ACTION_PRIORITY,
		table.unpack(keys)
	)
end

--[[
    Binds the input the window takes only while it shows, Tab to refocus
    and clicks outside, or unbinds it
--]]

function Window._setInputBound(self: Self, bound: boolean)
	self._backdrop.Visible = bound

	local visibleInput: RBXScriptConnection? = self._visibleInput
	if visibleInput then
		visibleInput:Disconnect()
		self._visibleInput = nil
	end

	if not bound then
		ContextActionService:UnbindAction(REFOCUS_ACTION)
		ContextActionService:UnbindAction(CLICK_OUTSIDE_ACTION)

		return
	end

	ContextActionService:BindActionAtPriority(
		REFOCUS_ACTION,
		self._onRefocus,
		CREATE_TOUCH_BUTTON,
		ACTION_PRIORITY,
		Enum.KeyCode.Tab
	)

	ContextActionService:BindActionAtPriority(
		CLICK_OUTSIDE_ACTION,
		self._onClickOutside,
		CREATE_TOUCH_BUTTON,
		ACTION_PRIORITY,
		table.unpack(POINTER_INPUTS)
	)

	self._visibleInput = UserInputService.InputBegan:Connect(function (input: InputObject, gameProcessed: boolean)
		self:_handleVisibleInput(input, gameProcessed)
	end)
end

--[[
    Marks a typed command or subcommand name valid, or invalid with the
    reason, or invalid while its first argument is required; a name that is
    there, or not yet typed, keeps the valid color while it is invalid
--]]

function Window._validateName(self: Self, found: Named?, pending: boolean, context: Context | false, reason: string?)
	local first: ArgumentDefinition? = found and found.args and found.args[1]

	if not context then
		self:_setIsValidInput(false, reason)
	elseif first and not first.optional and first.default == nil then
		self:_setIsValidInput(false, REQUIRED_ARGUMENTS)
	else
		self:_setIsValidInput(true, nil)
	end

	if pending and not self._valid then
		self:_hideInvalidState()
	end
end

--[[
    Suggests the command names and aliases the typed word starts, the
    command it names first
--]]

function Window._suggestCommands(self: Self, typed: string, context: Context | false, reason: string?)
	local exact: CommandDefinition? = Registry:getCommand(typed)
	self:_validateName(exact, exact ~= nil, context, reason)

	local items: { Item } = {}
	if exact then
		table.insert(items, {
			typed = exact.name,
			suggestion = exact.name,
			details = { name = exact.name, description = exact.description },
		})
	end

	local lowered: string = typed:lower()

	for _, name: string in Registry:getCommandNames(true) do
		if name:lower():sub(1, #lowered) ~= lowered or (exact and exact.name == name) then
			continue
		end

		local definition: CommandDefinition = Registry:getCommand(name) :: CommandDefinition
		table.insert(items, {
			typed = typed,
			suggestion = name,
			details = { name = definition.name, description = definition.description },
		})
	end

	self._autoComplete:show(items)
end

--[[
    Suggests the subcommands a command's next word starts, the one it names
    first, completing after the command's own word
--]]

function Window._suggestSubcommands(
	self: Self,
	commandText: string,
	subcommands: { SubcommandDefinition },
	typed: string,
	text: string,
	context: Context | false,
	reason: string?
)
	local lowered: string = typed:lower()
	local exact: SubcommandDefinition? = nil
	local items: { Item } = {}

	for _, subcommand: SubcommandDefinition in subcommands do
		local name: string = subcommand.name
		if name:lower():sub(1, #lowered) ~= lowered then
			continue
		end

		local item: Item = {
			typed = typed,
			suggestion = name,
			details = { name = name, description = subcommand.description },
		}

		if name:lower() == lowered then
			exact = subcommand
			table.insert(items, 1, item)
		else
			table.insert(items, item)
		end
	end

	self:_validateName(exact, exact ~= nil or typed == NONE, context, reason)
	self._autoComplete:show(items, { at = #text - #typed, lead = `{commandText}{SPACE}` })
end

--[[
    Validates the typed arguments and suggests values for the last one,
    with its name, type and description, or its refusal
--]]

function Window._suggestArguments(
	self: Self,
	context: Context,
	arguments: { string },
	text: string,
	hasTrailingSpace: boolean,
	atEnd: boolean
)
	local valid: boolean, problems: string = context:validate()
	self:_setIsValidInput(valid, `Validation errors: {problems}`)

	local argument: ArgumentContext? = context:getArgument(#arguments)
	if not argument then
		return
	end

	local typed: string = argument.textSegmentInProgress
	local items: { Item } = {}
	local isPartial: boolean = false

	if argument.rawSegmentsAreAutocomplete then
		for _, segment: string in argument.rawSegments do
			table.insert(items, { typed = segment, suggestion = segment })
		end
	else
		local suggestions: { string }, options: { isPartial: boolean? }? = argument:getAutocomplete()
		isPartial = options ~= nil and options.isPartial == true

		for _, suggestion: string in suggestions do
			table.insert(items, { typed = typed, suggestion = suggestion })
		end
	end

	local argumentValid: boolean, refusal: string? = true, nil
	if typed ~= NONE then
		argumentValid, refusal = argument:validate()
	end

	if not atEnd and argumentValid then
		self:_hideInvalidState()
	end

	local description: string? = argument.object.description
	if not argumentValid then
		description = refusal
	end

	local trailing: number = hasTrailingSpace and 1 or 0

	self._autoComplete:show(items, {
		at = atEnd and #text - #typed - trailing or nil,
		isLast = #context.arguments == #context.argumentDefinitions and typed ~= NONE,
		argumentCount = #arguments,
		context = context,
		argument = argument,
		isPartial = isPartial,

		details = {
			name = `{argument.name}{argument.required and NONE or OPTIONAL}`,
			type = argument.displayName,
			description = description,
			invalid = not argumentValid,
		},
	})
end

--[[
    Validates the typed line as it changes and suggests the next word: the
    command, its subcommand or its last argument's value
--]]

function Window._updateSuggestions(self: Self, text: string)
	local context: Context | false, reason: string? = Dispatcher:evaluate(text, Player, true)
	local words: { string } = Util.splitString(text)
	local commandText: string? = table.remove(words, 1)
	local hasTrailingSpace: boolean = text:match(TRAILING_SPACE) ~= nil

	local definition: CommandDefinition? = commandText and Registry:getCommand(commandText)
	local subcommands: { SubcommandDefinition }? = definition and definition.subcommands
	local typingSubcommand: boolean = (#words == 0 and hasTrailingSpace) or (#words == 1 and not hasTrailingSpace)

	if commandText and subcommands and #subcommands > 0 and typingSubcommand then
		self:_suggestSubcommands(commandText, subcommands, words[1] or NONE, text, context, reason)
		return
	end

	-- A subcommand's own arguments follow its word
	if context and context.subcommand then
		table.remove(words, 1)
	end

	local arguments: { string } = words
	local atEnd: boolean = false

	if context then
		arguments = Util.mashExcessArguments(arguments, #context.argumentDefinitions)
		atEnd = #arguments == #context.argumentDefinitions
	end

	local entryComplete: boolean = commandText ~= nil and #arguments > 0
	if hasTrailingSpace and not atEnd then
		entryComplete = true
		table.insert(arguments, NONE)
	end

	if context and entryComplete then
		self:_suggestArguments(context, arguments, text, hasTrailingSpace, atEnd)
	elseif commandText and #arguments == 0 then
		self:_suggestCommands(commandText, context, reason)
	else
		self:_setIsValidInput(false, reason)
		self._autoComplete:hide()
	end
end

--[[
    Follows the typed line: a Tab completes it, a line break is taken out,
    and any other change validates it and updates the suggestions
--]]

function Window._onTextChanged(self: Self)
	local text: string = self._textBox.Text
	self._frame.CanvasPosition = Vector2.new(0, self._frame.AbsoluteCanvasSize.Y)

	if text:find(TAB, 1, PLAIN) then
		self:_handleTabCompletion()
	elseif text:find(LINE_BREAKS) then
		self:_setEntryText((text:gsub(LINE_BREAKS, NONE)))
	else
		self:_updateSuggestions(text)
	end
end

export type Window = Self
type Self = typeof(setmetatable({} :: Fields, Window))

return Window
