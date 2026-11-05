--[[
    The string type keeps any text as it was typed, the empty text included,
    and refuses only a missing value, with no message of its own; strings
    parses to a list of the one text
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Primitives"
local TYPE: string = "string"
local LISTABLE: string = "strings"
local TEXTS: { string } = { "two words", "", "#1" }
local LISTED: string = "two words"

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	if definition.transform ~= nil or definition.autocomplete ~= nil then
		return false, "string transforms or completes its text"
	end

	for _, text: string in TEXTS do
		local valid: boolean = definition.validate(text)
		if not valid or definition.parse(text) ~= text then
			return false, `string refused or changed "{text}"`
		end
	end

	local missing: boolean, reason: string? = definition.validate(nil)
	if missing or reason ~= nil then
		return false, `string accepted a missing value, or refused it with {reason}`
	end

	local parsed: { string } = listable.parse(LISTED)
	if listable.listable ~= true or #parsed ~= 1 or parsed[1] ~= LISTED then
		return false, "strings did not parse to a list of the one text"
	end

	return true, nil
end
