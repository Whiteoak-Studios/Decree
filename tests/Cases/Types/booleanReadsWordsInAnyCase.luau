--[[
    The boolean type lowers the text and reads each of its true and false
    words in any case, and refuses any other word with its message, parsing
    it to nil; booleans parses to a list of the one value
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Primitives"
local TYPE: string = "boolean"
local LISTABLE: string = "booleans"
local REFUSED: { string } = { "maybe", "", "2", "truthy" }
local REFUSAL: string = "Please use true/yes/on or false/no/off."
local LISTED: string = "OFF"

-- Each word the type reads, by the value it parses it to
local WORDS: { [boolean]: { string } } = {
	[true] = { "true", "t", "yes", "y", "on", "enable", "enabled", "1", "+" },
	[false] = { "false", "f", "no", "n", "off", "disable", "disabled", "0", "-" },
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	for value: boolean, words: { string } in WORDS do
		for _, word: string in words do
			for _, typed: string in { word, word:upper() } do
				local lowered: string = definition.transform(typed)
				local valid: boolean = definition.validate(lowered)
				if lowered ~= word or not valid or definition.parse(lowered) ~= value then
					return false, `boolean did not read {typed} as {value}`
				end
			end
		end
	end

	for _, text: string in REFUSED do
		local refused: string = definition.transform(text)
		local valid: boolean, reason: string? = definition.validate(refused)
		if valid or reason ~= REFUSAL or definition.parse(refused) ~= nil then
			return false, `boolean accepted "{text}", or refused it with {reason}`
		end
	end

	local listed: string = listable.transform(LISTED)
	local parsed: { boolean } = listable.parse(listed)
	if listable.listable ~= true or #parsed ~= 1 or parsed[1] ~= false then
		return false, `booleans did not parse {LISTED} to a list of false`
	end

	return true, nil
end
