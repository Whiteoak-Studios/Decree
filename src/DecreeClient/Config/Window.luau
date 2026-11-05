--[[
    The console window's tunables, and the style a game's partial style
    table falls back to: Cmdr 1.13.1's colors and fonts, a color for each
    reply kind and one for the echo of the typed line
--]]

--!strict
local CODE: Font = Font.fromEnum(Enum.Font.Code)

local STYLE: ResolvedStyle = {
	background = Color3.fromRGB(17, 17, 17),
	text = Color3.fromRGB(255, 255, 255),
	invalid = Color3.fromRGB(255, 73, 73),
	prompt = Color3.fromRGB(255, 223, 93),
	echo = Color3.fromRGB(255, 223, 93),
	info = Color3.fromRGB(255, 255, 255),
	ok = Color3.fromRGB(131, 255, 131),
	refused = Color3.fromRGB(255, 153, 153),
	error = Color3.fromRGB(255, 73, 73),
	suggestions = Color3.fromRGB(59, 59, 59),
	suggestionText = Color3.fromRGB(255, 255, 255),
	typed = Color3.fromRGB(131, 222, 255),
	outputFont = CODE,
	inputFont = CODE,
	titleFont = Font.fromEnum(Enum.Font.SourceSansBold),
	descriptionFont = Font.fromEnum(Enum.Font.SourceSansLight),
	typeFont = Font.fromEnum(Enum.Font.SourceSans),
}

-- Every key is optional, and a key left out keeps the default above
export type Style = {
	background: Color3?, -- The window behind the lines
	text: Color3?, -- The typed line while it is valid
	invalid: Color3?, -- The typed line while it is not, and an invalid argument's description
	prompt: Color3?, -- The Name$ prompt and the context line above it
	echo: Color3?, -- The typed line, printed as it is sent
	info: Color3?, -- A reply of each kind
	ok: Color3?,
	refused: Color3?,
	error: Color3?,
	suggestions: Color3?, -- The suggestions' backgrounds
	suggestionText: Color3?, -- A suggestion, and its title, type and description
	typed: Color3?, -- The typed part of a suggestion
	outputFont: Font?, -- Monospace, for the printed lines and the context line
	inputFont: Font?, -- Monospace, for the prompt, the typed line and the suggestions
	titleFont: Font?, -- The suggested argument's name
	descriptionFont: Font?, -- Its description
	typeFont: Font?, -- Its type
}

export type ResolvedStyle = {
	background: Color3,
	text: Color3,
	invalid: Color3,
	prompt: Color3,
	echo: Color3,
	info: Color3,
	ok: Color3,
	refused: Color3,
	error: Color3,
	suggestions: Color3,
	suggestionText: Color3,
	typed: Color3,
	outputFont: Font,
	inputFont: Font,
	titleFont: Font,
	descriptionFont: Font,
	typeFont: Font,
}

return {
	style = STYLE,

	maxHeight = 300, -- The tallest the window grows, in pixels, before its lines scroll
	maxLines = 500, -- The lines the window keeps when the game's start settings give no number
	tabWidth = 8, -- Columns between the tab stops a printed line's tabs move to
	mashPresses = 5, -- Presses of an activation key that open the window when mash to enable is on
	mashSeconds = 1, -- The most seconds between two of those presses
	activationKeys = { Enum.KeyCode.F2 }, -- The keys that open and close the window until the game sets its own
	placeName = "", -- Shown after the player's name in the prompt, as Name@Place$, once the game sets one
	characterWidth = 7, -- A character's pixels in the input font until the measured width is known
	measureSeconds = 10, -- The most seconds a printed line waits on its font to measure, past which it grows only to the window's height

	textSize = 14, -- The printed lines, the prompt, the typed line and the suggestions
	titleTextSize = 20, -- The suggested argument's name
	descriptionTextSize = 16, -- Its description
	typeTextSize = 15, -- Its type

	windowTransparency = 0.4, -- The window's background
	suggestionsTransparency = 0.5, -- The suggestions' background
	headerTransparency = 0.2, -- The background of the suggested argument's name and description
	selectedTransparency = 0.5, -- The selected suggestion's background, where the others show none
}
