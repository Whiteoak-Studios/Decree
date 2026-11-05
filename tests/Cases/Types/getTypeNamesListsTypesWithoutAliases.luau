--[[
    getTypeNames lists every registered type once, a type registered since
    included, and leaves out every alias and every name that holds only a
    prefix, each name it lists one getType reads
--]]

--!strict
local Environment = require("../../Environment")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local ADDED: string = "fruit" -- A type the case registers
local ALIAS: string = "stringOrNumber"
local UNION: string = "string # number"
local GHOST: string = "ghost" -- A name given a prefix and never registered as a type
local GHOST_PREFIX: string = "# string"

-- Every built-in type Decree keeps
local BUILT_IN: { string } = {
	"string",
	"strings",
	"number",
	"numbers",
	"integer",
	"integers",
	"positiveInteger",
	"positiveIntegers",
	"nonNegativeInteger",
	"nonNegativeIntegers",
	"byte",
	"bytes",
	"digit",
	"digits",
	"boolean",
	"booleans",
	"json",
	"url",
	"urls",
	"mathOperator",
	"player",
	"players",
	"playerId",
	"playerIds",
	"team",
	"teams",
	"teamPlayers",
	"teamColor",
	"teamColors",
	"brickColor",
	"brickColors",
	"brickColor3",
	"brickColor3s",
	"color3",
	"color3s",
	"hexColor3",
	"hexColor3s",
	"vector3",
	"vector3s",
	"vector2",
	"vector2s",
	"positionVector3",
	"positionVector3s",
	"duration",
	"durations",
	"command",
	"commands",
	"type",
	"types",
	"userInput",
	"userInputs",
}

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)

	registry:registerType(ADDED, { parse = tostring })
	registry:registerTypeAlias(ALIAS, UNION)
	registry:registerTypePrefix(GHOST, GHOST_PREFIX)

	local names: { string } = registry:getTypeNames()
	local listed: { [string]: boolean } = {}

	for _, name: string in names do
		if listed[name] then
			return false, `getTypeNames listed {name} twice`
		end

		if registry:getType(name) == nil then
			return false, `getTypeNames listed {name}, which getType does not read`
		end

		listed[name] = true
	end

	for _, name: string in BUILT_IN do
		if not listed[name] then
			return false, `getTypeNames left out the built-in type {name}`
		end
	end

	if not listed[ADDED] or listed[ALIAS] or listed[GHOST] then
		return false, "getTypeNames left out a type registered since, or listed an alias or a prefix"
	end

	return true, nil
end
