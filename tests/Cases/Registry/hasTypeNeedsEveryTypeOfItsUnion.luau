--[[
    hasType is true only when every type of the union a name expands to is
    registered, through its prefixes or its alias, so one unregistered
    member, an alias of an alias or an empty name is false
--]]

--!strict
local Environment = require("../../Environment")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local REGISTERED: { string } = { "string", "players", "color3", "playerId" } -- Built in, three of them prefixed
local UNREGISTERED: string = "unregistered"
local EMPTY: string = ""
local WHOLE_ALIAS: string = "stringOrNumber"
local WHOLE_UNION: string = "string # number"
local GHOST: string = "ghost" -- A type no one has registered yet
local LAST_GHOST_ALIAS: string = "stringOrGhost"
local LAST_GHOST_UNION: string = "string # ghost"
local FIRST_GHOST_ALIAS: string = "ghostOrString"
local FIRST_GHOST_UNION: string = "ghost # string"
local NESTED_ALIAS: string = "nested" -- An alias naming another alias, which no argument can parse
local GHOST_PREFIX: string = "# string"
local HOLDING_GHOST: { string } = { LAST_GHOST_ALIAS, FIRST_GHOST_ALIAS, GHOST } -- Each name whose union holds GHOST

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)

	for _, name: string in REGISTERED do
		if not registry:hasType(name) then
			return false, `hasType did not find the built-in {name}, which expands to {registry:getTypeName(name)}`
		end
	end

	if registry:hasType(UNREGISTERED) or registry:hasType(EMPTY) then
		return false, "hasType found an unregistered name or an empty one"
	end

	registry:registerTypeAlias(WHOLE_ALIAS, WHOLE_UNION)
	registry:registerTypeAlias(LAST_GHOST_ALIAS, LAST_GHOST_UNION)
	registry:registerTypeAlias(FIRST_GHOST_ALIAS, FIRST_GHOST_UNION)
	registry:registerTypeAlias(NESTED_ALIAS, WHOLE_ALIAS)
	registry:registerTypePrefix(GHOST, GHOST_PREFIX)

	if not registry:hasType(WHOLE_ALIAS) then
		return false, `hasType did not find {WHOLE_ALIAS}, whose types are all registered`
	end

	for _, name: string in HOLDING_GHOST do
		if registry:hasType(name) then
			return false, `hasType found {name}, which expands to {registry:getTypeName(name)}`
		end
	end

	if registry:hasType(NESTED_ALIAS) then
		return false, `hasType found {NESTED_ALIAS}, an alias of an alias`
	end

	-- Registering the missing member completes every union that holds it
	registry:registerType(GHOST, { parse = tostring })

	for _, name: string in HOLDING_GHOST do
		if not registry:hasType(name) then
			return false, `hasType did not find {name} once {GHOST} registered`
		end
	end

	if registry:hasType(NESTED_ALIAS) then
		return false, `hasType found {NESTED_ALIAS}, an alias of an alias`
	end

	return true, nil
end
