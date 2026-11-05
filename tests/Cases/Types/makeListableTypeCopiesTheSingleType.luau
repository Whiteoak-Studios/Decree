--[[
    Util's makeListableType copies a type's finding, checking, completing,
    default and operator words but not its display name or prefixes, and
    parses to a list of every value the type parses to
--]]

--!strict
local Environment = require("../../Environment")

local UTIL: string = "src/DecreeClient/Shared/Util"
local COPIED: { string } =
	{ "transform", "validate", "validateOnce", "autocomplete", "default", "argumentOperatorAliases" }
local LEFT_OUT: { string } = { "displayName", "prefixes" }
local DISPLAY_NAME: string = "Base"
local PREFIXES: string = "# string"
local OVERRIDE_PREFIXES: string = "# strings"
local LEFT: number = 3
local RIGHT: number = 1
local SUM: number = 4
local DIFFERENCE: number = 2

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	-- Each copied key holds a table of its own, so a copy shows by identity
	local base: { [string]: any } = {
		displayName = DISPLAY_NAME,
		prefixes = PREFIXES,

		parse = function (left: number, right: number): (number, number)
			return left + right, left - right
		end,
	}

	for _, key: string in COPIED do
		base[key] = { key }
	end

	local listable: any = util.makeListableType(base)
	if listable.listable ~= true or base.listable ~= nil then
		return false, "makeListableType's type is not listable, or the single type became listable"
	end

	for _, key: string in COPIED do
		if listable[key] ~= base[key] then
			return false, `makeListableType did not copy {key}`
		end
	end

	for _, key: string in LEFT_OUT do
		if listable[key] ~= nil then
			return false, `makeListableType copied {key}`
		end
	end

	local parsed: { number } = listable.parse(LEFT, RIGHT)
	if #parsed ~= 2 or parsed[1] ~= SUM or parsed[2] ~= DIFFERENCE then
		return false, "makeListableType's type did not parse to a list of every value the type parses to"
	end

	local overridden: any = util.makeListableType(base, { prefixes = OVERRIDE_PREFIXES, listable = false })
	if
		overridden.prefixes ~= OVERRIDE_PREFIXES
		or overridden.listable ~= false
		or overridden.transform ~= base.transform
	then
		return false, "makeListableType's override did not replace or add its keys over the copy"
	end

	return true, nil
end
