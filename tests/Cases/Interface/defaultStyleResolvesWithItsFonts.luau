--[[
    The window config's own style resolves whole with no game style, its
    fonts Font values, fills a partial style's other keys from itself, each
    result frozen, and refuses a Color3 where it takes a Font
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local RESOLVE_STYLE: string = "src/DecreeClient/Window/Functions/ResolveStyle"
local WINDOW_CONFIG: string = "src/DecreeClient/Config/Window"
local COLOR: string = "Color3"
local FONT: string = "Font"
local FONT_KEY: string = "outputFont"
local MISTYPED: string = `The style's {FONT_KEY} is a {COLOR}, where it takes a {FONT}`
local PLAIN: boolean = true -- Finds the text as written, with no pattern characters

-- Each key the style takes, by the kind of value it holds
local KINDS: { [string]: string } = {
	background = COLOR,
	text = COLOR,
	invalid = COLOR,
	prompt = COLOR,
	echo = COLOR,
	info = COLOR,
	ok = COLOR,
	refused = COLOR,
	error = COLOR,
	suggestions = COLOR,
	suggestionText = COLOR,
	typed = COLOR,
	outputFont = FONT,
	inputFont = FONT,
	titleFont = FONT,
	descriptionFont = FONT,
	typeFont = FONT,
}

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local resolve: any = env.require(RESOLVE_STYLE)
	local defaults: { [string]: any } = env.require(WINDOW_CONFIG).style

	local whole: { [string]: any } = resolve(nil, defaults)

	for key: string, kind: string in KINDS do
		if typeof(whole[key]) ~= kind or whole[key] ~= defaults[key] then
			return false, `the default style's {key} resolved to {whole[key]}, where its default {kind} was expected`
		end
	end

	for key: string in whole do
		if not KINDS[key] then
			return false, `the default style resolved {key}, a key the style has no place for`
		end
	end

	if not table.isfrozen(whole) then
		return false, "the default style can still change once resolved"
	end

	local given: { [string]: any } = {
		prompt = roblox.Color3.fromRGB(0, 160, 255),
		titleFont = roblox.Font.fromEnum(roblox.Enum.Font.GothamBold),
	}

	local partial: { [string]: any } = resolve(given, defaults)

	for key: string in KINDS do
		local expected: any = given[key] or defaults[key]
		if partial[key] ~= expected then
			return false, `the partial style's {key} resolved to {partial[key]}, where {expected} was expected`
		end
	end

	if not table.isfrozen(partial) then
		return false, "the partial style can still change once resolved"
	end

	local mistyped: boolean, problem: any = pcall(resolve, { [FONT_KEY] = roblox.Color3.new() }, defaults)
	if mistyped or not tostring(problem):find(MISTYPED, 1, PLAIN) then
		return false, `a style whose {FONT_KEY} is a {COLOR} resolved, or raised {problem}`
	end

	return true, nil
end
