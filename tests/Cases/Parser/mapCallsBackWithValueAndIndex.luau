--[[
    Util's map calls back once with each value of a list and its index, in
    order, into a new list, and stops at the first hole
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins values in a failure message
local LETTERS: { string } = { "a", "b", "c" }
local NUMBERED: { string } = { "a1", "b2", "c3" } -- Each of LETTERS with its index after it
local HOLED: { string? } = { "a", nil, "c" }
local BEFORE_HOLE: { string } = { "a1" } -- What map makes of HOLED

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)
	local calls: number = 0

	local function numbered(value: string, index: number): string
		calls += 1

		return `{value}{index}`
	end

	local mapped: { string } = util.map(LETTERS, numbered)
	if not Listed(mapped, NUMBERED) or mapped == LETTERS or calls ~= #LETTERS then
		return false, `map made {table.concat(mapped, SEPARATOR)} in {calls} calls`
	end

	calls = 0
	local holed: { string } = util.map(HOLED, numbered)
	if not Listed(holed, BEFORE_HOLE) or calls ~= #BEFORE_HOLE then
		return false, `map made {table.concat(holed, SEPARATOR)} of a list with a hole, in {calls} calls`
	end

	calls = 0
	local empty: { string } = util.map({}, numbered)
	if #empty ~= 0 or calls ~= 0 then
		return false, `map made {#empty} values of an empty list, in {calls} calls`
	end

	return true, nil
end
