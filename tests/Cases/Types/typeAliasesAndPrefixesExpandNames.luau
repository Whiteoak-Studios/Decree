--[[
    registerTypeAlias names a type string once, under a name a type could
    take that no type or alias has, and registerTypePrefix adds a prefixed
    union after a name; getTypeName expands both, getType neither
--]]

--!strict
local Environment = require("../../Environment")
local Refuses = require("../../Fixtures/Types/Refuses")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local ALIAS: string = "stringOrNumber"
local UNION: string = "string # number"
local OTHER_UNION: string = "string # integer"
local ALIAS_REFUSAL: string = `[Decree] Type alias "{ALIAS}" already exists!`
local PREFIXED: string = "players" -- A built-in type whose own prefix already made it an alias
local PREFIXED_REFUSAL: string = `[Decree] Type alias "{PREFIXED}" already exists!`
local SHADOWED: string = "number" -- A built-in type with no prefix, whose name no alias may take
local SHADOW: string = "integer"
local SHADOWED_REFUSAL: string = `[Decree] Type alias "{SHADOWED}" is already the name of a type.`
local UNCHECKED: string = "Not-A-Name" -- A name registerType refuses, which an alias is refused too
local UNCHECKED_UNION: string = "string"
local NAME_RULE: string = "type names must be alphanumeric and start with a lowercase letter or digit."
local UNCHECKED_REFUSAL: string = `[Decree] Invalid type name provided: "{UNCHECKED}", {NAME_RULE}`
local PREFIX_TYPE: string = "integer"
local FIRST_PREFIX: string = "! boolean"
local SECOND_PREFIX: string = "@ string"
local PREFIXED_ONCE: string = "integer ! boolean"
local PREFIXED_TWICE: string = "integer ! boolean @ string"
local ALIAS_PREFIXED: string = "string # number ! boolean"
local TAGGED: string = "tagged" -- A type registered with a prefixes key
local TAGGED_PREFIXES: string = "# integer"
local TAGGED_NAME: string = "tagged # integer"
local GHOST: string = "ghost" -- A name given a prefix and never registered as a type
local GHOST_PREFIX: string = "# string"
local GHOST_NAME: string = "ghost # string"
local PLAIN_TYPE: string = "string" -- A built-in type with no prefix
local UNREGISTERED: string = "unregistered"

-- Each built-in type whose definition carries prefixes, and the name getTypeName expands it to
local BUILT_IN: { [string]: string } = {
	players = "players % teamPlayers",
	playerId = "playerId # positiveInteger",
	playerIds = "playerIds # positiveIntegers",
	brickColor = "brickColor % teamColor",
	brickColors = "brickColors % teamColors",
	color3 = "color3 # hexColor3 ! brickColor3",
	color3s = "color3s # hexColor3s ! brickColor3s",
}

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)

	for name: string, expanded: string in BUILT_IN do
		if registry:getTypeName(name) ~= expanded or registry:getType(name) == nil then
			return false, `getTypeName expanded {name} to {registry:getTypeName(name)}`
		end
	end

	if registry:getTypeName(PLAIN_TYPE) ~= PLAIN_TYPE or registry:getTypeName(UNREGISTERED) ~= UNREGISTERED then
		return false, "getTypeName changed a name that has no alias"
	end

	registry:registerTypeAlias(ALIAS, UNION)
	if registry:getTypeName(ALIAS) ~= UNION or registry:getType(ALIAS) ~= nil then
		return false, `getTypeName expanded {ALIAS} to {registry:getTypeName(ALIAS)}, or getType read the alias`
	end

	local aliasRefused: boolean = Refuses(ALIAS_REFUSAL, registry.registerTypeAlias, registry, ALIAS, OTHER_UNION)
	if not aliasRefused or registry:getTypeName(ALIAS) ~= UNION then
		return false, `registerTypeAlias took {ALIAS} a second time`
	end

	local prefixedRefused: boolean =
		Refuses(PREFIXED_REFUSAL, registry.registerTypeAlias, registry, PREFIXED, OTHER_UNION)
	if not prefixedRefused or registry:getTypeName(PREFIXED) ~= BUILT_IN[PREFIXED] then
		return false, `registerTypeAlias took {PREFIXED}, whose prefix made it an alias`
	end

	local shadowed: any = registry:getType(SHADOWED)
	local shadowRefused: boolean = Refuses(SHADOWED_REFUSAL, registry.registerTypeAlias, registry, SHADOWED, SHADOW)
	if not shadowRefused or registry:getTypeName(SHADOWED) ~= SHADOWED or registry:getType(SHADOWED) ~= shadowed then
		return false, `registerTypeAlias took the name of the type {SHADOWED}`
	end

	local uncheckedRefused: boolean =
		Refuses(UNCHECKED_REFUSAL, registry.registerTypeAlias, registry, UNCHECKED, UNCHECKED_UNION)
	if not uncheckedRefused or registry:getTypeName(UNCHECKED) ~= UNCHECKED then
		return false, `registerTypeAlias took the name {UNCHECKED}`
	end

	registry:registerTypePrefix(PREFIX_TYPE, FIRST_PREFIX)
	local once: string = registry:getTypeName(PREFIX_TYPE)
	registry:registerTypePrefix(PREFIX_TYPE, SECOND_PREFIX)
	if once ~= PREFIXED_ONCE or registry:getTypeName(PREFIX_TYPE) ~= PREFIXED_TWICE then
		return false, `registerTypePrefix gave {once}, then {registry:getTypeName(PREFIX_TYPE)}`
	end

	registry:registerTypePrefix(ALIAS, FIRST_PREFIX)
	if registry:getTypeName(ALIAS) ~= ALIAS_PREFIXED then
		return false, `registerTypePrefix on an alias gave {registry:getTypeName(ALIAS)}`
	end

	registry:registerType(TAGGED, { parse = tostring, prefixes = TAGGED_PREFIXES })
	if registry:getTypeName(TAGGED) ~= TAGGED_NAME then
		return false, `a type registered with prefixes expanded to {registry:getTypeName(TAGGED)}`
	end

	registry:registerTypePrefix(GHOST, GHOST_PREFIX)
	if registry:getTypeName(GHOST) ~= GHOST_NAME or registry:getType(GHOST) ~= nil then
		return false, `a prefix on a name with no type expanded to {registry:getTypeName(GHOST)}`
	end

	return true, nil
end
