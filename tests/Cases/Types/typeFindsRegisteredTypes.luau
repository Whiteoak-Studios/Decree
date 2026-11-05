--[[
    The type type finds registered type names by part of the name, the
    exact name first, then by where the text starts and by length, leaving
    aliases out, and refuses text that names none with its message
--]]

--!strict
local Environment = require("../../Environment")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local TYPE: string = "type"
local LISTABLE: string = "types"
local EXACT: string = "vector3"
local SHARED: string = "vector"
local ALIAS: string = "zone" -- An alias, which the type never finds
local ALIASED: string = "string"
local ADDED: string = "fruit" -- A type the case registers
local NONE: string = "zzz"
local REFUSAL: string = "No type with that name could be found."
local SEPARATOR: string = "|" -- Joins a list of names into one string to compare

-- What SHARED finds, in order, where each group's names may come in any order among themselves
local SHARED_GROUPS: { { string } } = {
	{ "vector2", "vector3" },
	{ "vector2s", "vector3s" },
	{ "positionVector3" },
	{ "positionVector3s" },
}

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)
	local definition: any = registry:getType(TYPE)
	local listable: any = registry:getType(LISTABLE)

	local exact: { string } = definition.transform(EXACT)
	local valid: boolean = definition.validate(exact)
	if not valid or exact[1] ~= EXACT or definition.parse(exact) ~= EXACT then
		return false, `type did not find {EXACT} first for its own name`
	end

	local shared: { string } = definition.transform(SHARED)
	local suggestions: { string } = definition.autocomplete(shared)
	local position: number = 0

	for _, group: { string } in SHARED_GROUPS do
		local slice: { string } = table.move(shared, position + 1, position + #group, 1, {})
		table.sort(slice)

		if table.concat(slice, SEPARATOR) ~= table.concat(group, SEPARATOR) then
			return false, `type found {table.concat(shared, ", ")} for {SHARED}`
		end

		position += #group
	end

	if #shared ~= position or table.concat(suggestions, SEPARATOR) ~= table.concat(shared, SEPARATOR) then
		return false, `type found or completed more than the vector types for {SHARED}`
	end

	registry:registerTypeAlias(ALIAS, ALIASED)
	registry:registerType(ADDED, { parse = tostring })

	local alias: { string } = definition.transform(ALIAS)
	local added: { string } = definition.transform(ADDED)
	if #alias ~= 0 or #added ~= 1 or added[1] ~= ADDED then
		return false, `type found the alias {ALIAS}, or not the type registered since`
	end

	local none: { string } = definition.transform(NONE)
	local found: boolean, reason: string? = definition.validate(none)
	if #none ~= 0 or found or reason ~= REFUSAL then
		return false, `type found {NONE}, or refused it with {reason}`
	end

	local listed: { string } = listable.parse(exact)
	if listable.listable ~= true or #listed ~= 1 or listed[1] ~= EXACT then
		return false, "types did not parse to a list of the first name found"
	end

	return true, nil
end
