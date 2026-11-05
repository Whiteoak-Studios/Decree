--[[
    The userInput type finds KeyCode and UserInputType items by part of
    their name in any case, the exact name first, and refuses text that
    names none with no message of its own
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local TYPE: string = "userInput"
local LISTABLE: string = "userInputs"
local KEY: string = "leftshift" -- The LeftShift key typed in another case
local INPUT: string = "MouseButton1"
local LETTER: string = "f" -- Names the F key exactly, and starts every other F key's name
local LETTER_NAME: string = "F"
local NONE: string = "zzzz"

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)
	local definition: any = registry:getType(TYPE)
	local listable: any = registry:getType(LISTABLE)

	local key: { any } = definition.transform(KEY)
	local input: { any } = definition.transform(INPUT)
	if #key ~= 1 or key[1] ~= roblox.Enum.KeyCode.LeftShift or input[1] ~= roblox.Enum.UserInputType.MouseButton1 then
		return false, `userInput did not find the LeftShift key for {KEY}, or the {INPUT} input type`
	end

	local letter: { any } = definition.transform(LETTER)
	local valid: boolean = definition.validate(letter)
	local suggestions: { string } = definition.autocomplete(letter)
	if
		not valid
		or #letter < 2
		or suggestions[1] ~= LETTER_NAME
		or definition.parse(letter) ~= roblox.Enum.KeyCode.F
	then
		return false, `userInput did not find the F key first among the names that start {LETTER}`
	end

	local none: { any } = definition.transform(NONE)
	local found: boolean, reason: string? = definition.validate(none)
	if #none ~= 0 or found or reason ~= nil then
		return false, `userInput found {NONE}, or refused it with {reason}`
	end

	local listed: { any } = listable.parse(letter)
	if listable.listable ~= true or #listed ~= 1 or listed[1] ~= roblox.Enum.KeyCode.F then
		return false, "userInputs did not parse to a list of the first item found"
	end

	return true, nil
end
