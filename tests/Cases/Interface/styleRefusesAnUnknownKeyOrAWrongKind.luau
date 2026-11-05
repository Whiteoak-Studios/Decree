--[[
    A style that gives a key the style has no place for, or a key a value of
    another kind than its default's, raises an error naming the key
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local RESOLVE_STYLE: string = "src/DecreeClient/Window/Functions/ResolveStyle"
local MISSPELT: string = "backgrund"
local REFUSED: string = "refused"
local UNKNOWN: string = `The style has no key {MISSPELT}`
local MISTYPED: string = `The style's {REFUSED} is a Font, where it takes a Color3`
local PLAIN: boolean = true -- Finds the text as written, with no pattern characters

return function (): (boolean, string | nil)
	local resolve: any = Environment.new({ side = "client" }).require(RESOLVE_STYLE)

	local defaults: { [string]: any } = {
		background = roblox.Color3.fromRGB(17, 17, 17),
		refused = roblox.Color3.fromRGB(255, 153, 153),
	}

	local unknown: boolean, unknownProblem: any = pcall(resolve, { [MISSPELT] = roblox.Color3.new() }, defaults)
	if unknown or not tostring(unknownProblem):find(UNKNOWN, 1, PLAIN) then
		return false, `a style with the key {MISSPELT} resolved, or raised {unknownProblem}`
	end

	local wrong: { [string]: any } = { [REFUSED] = roblox.Font.fromEnum(roblox.Enum.Font.Code) }
	local mistyped: boolean, mistypedProblem: any = pcall(resolve, wrong, defaults)
	if mistyped or not tostring(mistypedProblem):find(MISTYPED, 1, PLAIN) then
		return false, `a style whose {REFUSED} is a Font resolved, or raised {mistypedProblem}`
	end

	return true, nil
end
