--[[
    The url type accepts text that starts http:// or https:// in lowercase
    and has more after it, and parses it unchanged, while it refuses any
    other text with its message; urls parses to a list of the one url
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Primitives"
local TYPE: string = "url"
local LISTABLE: string = "urls"
local ACCEPTED: { string } = { "https://example.com", "http://x", "https://example.com/a b?c=1" }
local REFUSED: { string } = { "ftp://example.com", "example.com", "http://", "HTTPS://example.com", "" }
local REFUSAL: string = "URLs must begin with http:// or https://"
local LISTED: string = "https://example.com"

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	if definition.transform ~= nil or definition.autocomplete ~= nil then
		return false, "url transforms or completes its text"
	end

	for _, text: string in ACCEPTED do
		local valid: boolean = definition.validate(text)
		if not valid or definition.parse(text) ~= text then
			return false, `url refused or changed {text}`
		end
	end

	for _, text: string in REFUSED do
		local valid: boolean, reason: string? = definition.validate(text)
		if valid or reason ~= REFUSAL then
			return false, `url accepted "{text}", or refused it with {reason}`
		end
	end

	local parsed: { string } = listable.parse(LISTED)
	if listable.listable ~= true or #parsed ~= 1 or parsed[1] ~= LISTED then
		return false, "urls did not parse to a list of the one url"
	end

	return true, nil
end
