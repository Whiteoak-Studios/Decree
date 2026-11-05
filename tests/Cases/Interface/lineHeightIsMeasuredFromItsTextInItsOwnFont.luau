--[[
    A printed line no longer grows itself, which stops at the window's
    height, and its height is measured from its own text, font and size at
    the width it is given, taller as its text grows
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local WINDOW: string = "src/DecreeClient/Window"
local CREATE_GUI: string = "src/DecreeClient/Window/Functions/CreateGui"
local RESOLVE_STYLE: string = "src/DecreeClient/Window/Functions/ResolveStyle"
local WINDOW_CONFIG: string = "src/DecreeClient/Config/Window"
local RESOLVED: string = "Resolved" -- Promise.Status.Resolved
local WIDTH: number = 300 -- The width each line is measured at
local CHARACTER_WIDTH: number = 7 -- What the stand-in measure gives each character
local ROW_HEIGHT: number = 14 -- And each row the text wraps to
local SHORT: string = "Wiped"
local LONG: string = string.rep("The shard is wiped ", 200) -- Many rows at the width

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local measured: { any } = {}

	-- A stand-in for the engine's measure, which Lune lacks: fixed-width characters wrapped at the width
	env.game:GetService("TextService").GetTextBoundsAsync = function (_: any, params: any): any
		table.insert(measured, params)

		local rows: number = math.ceil(#params.Text * CHARACTER_WIDTH / params.Width)

		return roblox.Vector2.new(params.Width, rows * ROW_HEIGHT)
	end

	local outputFont: any = roblox.Font.fromEnum(roblox.Enum.Font.Arial)
	local style: any = env.require(RESOLVE_STYLE)({ outputFont = outputFont }, env.require(WINDOW_CONFIG).style)
	local template: any = env.require(CREATE_GUI)(style):FindFirstChild("Frame"):FindFirstChild("Line")

	if template.AutomaticSize ~= roblox.Enum.AutomaticSize.None then
		return false, `the line template grows itself on {template.AutomaticSize}, which stops at the window's height`
	end

	local Window: any = env.require(WINDOW)

	local function measure(text: string): number?
		local line: any = template:Clone()
		line.Text = text

		local promise: any = Window._measureLineHeight(line, WIDTH)
		if promise:getStatus() ~= RESOLVED then
			return nil
		end

		local _: boolean, height: number = promise:await()

		return height
	end

	local short: number? = measure(SHORT)
	local long: number? = measure(LONG)

	if not short or not long or long <= short then
		return false, `a short line measured {short} and a long one {long}, where the long one is taller`
	end

	for index: number, text: string in { SHORT, LONG } do
		local params: any = measured[index]

		if
			not params
			or params.Text ~= text
			or params.Font ~= outputFont
			or params.Size ~= template.TextSize
			or params.Width ~= WIDTH
		then
			return false, `a line was not measured from its own text, font and size at {WIDTH} px`
		end
	end

	return true, nil
end
