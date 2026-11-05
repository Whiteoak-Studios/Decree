--[[
    Builds the console's Decree ScreenGui in the resolved style: the window
    with its lines, context line and entry, the suggestions, and the layers
    that hear a click outside and free the mouse
--]]

--!strict
local WindowConfig = require("../../Config/Window")

local TEXT_SIZE: number = WindowConfig.textSize
local TITLE_TEXT_SIZE: number = WindowConfig.titleTextSize
local DESCRIPTION_TEXT_SIZE: number = WindowConfig.descriptionTextSize
local TYPE_TEXT_SIZE: number = WindowConfig.typeTextSize
local WINDOW_TRANSPARENCY: number = WindowConfig.windowTransparency
local SUGGESTIONS_TRANSPARENCY: number = WindowConfig.suggestionsTransparency
local HEADER_TRANSPARENCY: number = WindowConfig.headerTransparency
local SELECTED_TRANSPARENCY: number = WindowConfig.selectedTransparency

type ResolvedStyle = WindowConfig.ResolvedStyle

--[[
    An instance of a class with its properties set and its children, each
    named by its key, parented to it
--]]

local function create(className: string, properties: { [string]: any }, children: { [string]: Instance }?): Instance
	local instance: any = Instance.new(className :: any)

	for property: string, value: any in properties do
		instance[property] = value
	end

	for name: string, child: Instance in children or {} do
		child.Name = name
		child.Parent = instance
	end

	return instance
end

return function (style: ResolvedStyle): ScreenGui
	return create("ScreenGui", {
		Name = "Decree",
		DisplayOrder = 1000,
		ResetOnSpawn = false,
		AutoLocalize = false,
	}, {
		Frame = create("ScrollingFrame", {
			BackgroundColor3 = style.background,
			BackgroundTransparency = WINDOW_TRANSPARENCY,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			Position = UDim2.new(0.025, 0, 0, 25),
			ScrollBarThickness = 6,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Selectable = true,
			Size = UDim2.fromScale(0.95, 0),
			Visible = false,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ZIndex = 1,
		}, {
			UIListLayout = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),

			UIPadding = create("UIPadding", {
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 10),
			}),

			-- The window clones a line from this, and takes it out of the window before the first
			Line = create("TextBox", {
				BackgroundTransparency = 1,
				ClearTextOnFocus = false,
				FontFace = style.outputFont,
				RichText = false,
				Selectable = false,
				Size = UDim2.new(1, 0, 0, 20),
				Text = "",
				TextColor3 = style.info,
				TextEditable = false,
				TextSize = TEXT_SIZE,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
			}),

			Context = create("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = style.outputFont,
				LayoutOrder = 999999998,
				Size = UDim2.new(1, 0, 0, 20),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = "",
				TextColor3 = style.prompt,
				TextSize = TEXT_SIZE,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Visible = false,
				ZIndex = 2,
			}),

			Entry = create("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 999999999,
				Size = UDim2.new(1, 0, 0, 20),
				ZIndex = 2,
			}, {
				UIListLayout = create("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 7),
				}),

				Prompt = create("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = style.inputFont,
					Size = UDim2.fromOffset(0, 20),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = "",
					TextColor3 = style.prompt,
					TextSize = TEXT_SIZE,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
				}),

				TextBox = create("TextBox", {
					BackgroundTransparency = 1,
					ClearTextOnFocus = false,
					FontFace = style.inputFont,
					LayoutOrder = 999999999,
					Position = UDim2.fromOffset(140, 0),
					Selectable = true,
					Size = UDim2.new(1, 0, 0, 20),
					Text = "",
					TextColor3 = style.text,
					TextSize = TEXT_SIZE,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
				}),
			}),
		}),

		Autocomplete = create("ScrollingFrame", {
			BackgroundColor3 = style.suggestions,
			BackgroundTransparency = SUGGESTIONS_TRANSPARENCY,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromOffset(167, 75),
			ScrollBarThickness = 6,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Selectable = false,
			Size = UDim2.fromOffset(200, 200),
			Visible = false,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ZIndex = 4,
		}, {
			UIListLayout = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),

			Title = create("Frame", {
				BackgroundColor3 = style.suggestions,
				BackgroundTransparency = HEADER_TRANSPARENCY,
				BorderSizePixel = 0,
				LayoutOrder = -2,
				Size = UDim2.new(1, 0, 0, 40),
				ZIndex = 5,
			}, {
				UIPadding = create("UIPadding", { PaddingLeft = UDim.new(0, 10) }),

				Field = create("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = style.titleFont,
					Size = UDim2.fromScale(0, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					Text = "",
					TextColor3 = style.suggestionText,
					TextSize = TITLE_TEXT_SIZE,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 6,
				}, {
					Type = create("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = style.typeFont,
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0, 1),
						Text = "",
						TextColor3 = style.suggestionText,
						TextSize = TYPE_TEXT_SIZE,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 7,
					}),
				}),
			}),

			Description = create("Frame", {
				BackgroundColor3 = style.suggestions,
				BackgroundTransparency = HEADER_TRANSPARENCY,
				BorderSizePixel = 0,
				LayoutOrder = -1,
				Size = UDim2.new(1, 0, 0, 40),
				AutomaticSize = Enum.AutomaticSize.Y,
				ZIndex = 5,
			}, {
				UIPadding = create("UIPadding", {
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),

				Label = create("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = style.descriptionFont,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = "",
					TextColor3 = style.suggestionText,
					TextSize = DESCRIPTION_TEXT_SIZE,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 6,
				}),
			}),

			-- The suggestions clone a row from this, and take it out before the first
			Row = create("TextButton", {
				BackgroundColor3 = style.suggestions,
				BackgroundTransparency = SELECTED_TRANSPARENCY,
				BorderSizePixel = 0,
				FontFace = style.inputFont,
				Selectable = false,
				Size = UDim2.new(1, 0, 0, 30),
				Text = "",
				TextColor3 = style.suggestionText,
				TextSize = TEXT_SIZE,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 5,
			}, {
				UIPadding = create("UIPadding", { PaddingLeft = UDim.new(0, 10) }),

				Typed = create("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = style.inputFont,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					TextColor3 = style.typed,
					TextSize = TEXT_SIZE,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 6,
				}),

				Suggest = create("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = style.inputFont,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					TextColor3 = style.suggestionText,
					TextSize = TEXT_SIZE,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 6,
				}),
			}),
		}),

		-- It sinks no input, so the window hears a click over other UI, which ContextActionService never sees
		Backdrop = create("Frame", {
			Active = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 0,
		}),

		-- Modal frees the mouse while this shows, which the window does only when the game asks it to
		MouseUnlocker = create("TextButton", {
			Active = false,
			BackgroundTransparency = 1,
			Modal = true,
			Selectable = false,
			Size = UDim2.fromOffset(0, 0),
			Text = "",
			Visible = false,
			ZIndex = 0,
		}),
	}) :: ScreenGui
end
