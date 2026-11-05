--[[
    The json type accepts text that decodes as JSON, a bare number included,
    and parses it to the decoded value, while it refuses broken or empty
    text with the decoder's error; there is no listable json
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Primitives"
local TYPE: string = "json"
local LISTABLE: string = "jsons" -- A name the file holds no type under
local OBJECT: string = `\{"name": "Decree", "tags": [1, 2]}`
local NAME: string = "Decree" -- OBJECT's name field
local TAGS: number = 2 -- How many tags OBJECT holds
local NUMBER: string = "5"
local DECODED: number = 5
local REFUSED: { string } = { "[1,", "", "hello", "{" }

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]

	if definition.transform ~= nil or definition.autocomplete ~= nil or types[LISTABLE] ~= nil then
		return false, "json transforms or completes its text, or has a listable"
	end

	local objectValid: boolean = definition.validate(OBJECT)
	local object: any = definition.parse(OBJECT)
	if not objectValid or object.name ~= NAME or #object.tags ~= TAGS then
		return false, "json did not decode the object"
	end

	local numberValid: boolean = definition.validate(NUMBER)
	if not numberValid or definition.parse(NUMBER) ~= DECODED then
		return false, `json did not read {NUMBER} as a number`
	end

	-- The reason is whatever error the decoder raised, which the engine and the harness word differently
	for _, text: string in REFUSED do
		local valid: boolean, reason: any = definition.validate(text)
		if valid or reason == nil then
			return false, `json accepted "{text}", or refused it with {reason}`
		end
	end

	return true, nil
end
