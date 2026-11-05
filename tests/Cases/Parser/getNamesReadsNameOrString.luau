--[[
    Util's getNames gives each value's Name in order, from an Instance, an
    EnumItem or a table, a string as itself and tostring for a nameless
    table, and throws on a value that cannot be indexed
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins names in a failure message
local INSTANCE_NAME: string = "Alpha"
local TABLE_NAME: string = "Beta"
local TEXT: string = "gamma"
local UNINDEXABLE: { any } = { 5 }

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	local folder: any = roblox.Instance.new("Folder")
	folder.Name = INSTANCE_NAME

	local keyCode: any = roblox.Enum.KeyCode.F2
	local nameless: { [string]: any } = {}

	local values: { any } = { folder, keyCode, { Name = TABLE_NAME }, TEXT, nameless }
	local expected: { string } = { INSTANCE_NAME, keyCode.Name, TABLE_NAME, TEXT, tostring(nameless) }

	local names: { string } = util.getNames(values)
	if not Listed(names, expected) then
		return false, `getNames gave {table.concat(names, SEPARATOR)}`
	end

	if #util.getNames({}) ~= 0 then
		return false, "getNames gave names for an empty list"
	end

	if pcall(util.getNames, UNINDEXABLE) then
		return false, "getNames read a name off a number"
	end

	return true, nil
end
