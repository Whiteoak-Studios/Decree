--[[
    Util's mashExcessArguments joins every argument past the max onto the
    last one with single spaces, into a new list, and at a max of 0 leaves
    nothing at index 1 and the joined words at index 0
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins arguments in a failure message
local NO_MAX: number = 0
local UNMAXED: { string } = { "a", "b" } -- Mashed at NO_MAX
local AT_NO_MAX: string = " a b" -- What index 0 holds for UNMAXED at NO_MAX, a space before each word

-- Each list of arguments, its max and the list mashExcessArguments makes of it
local MASHES: { Mash } = {
	{ arguments = { "a", "b", "c", "d" }, max = 2, expected = { "a", "b c d" } },
	{ arguments = { "a", "b", "c" }, max = 1, expected = { "a b c" } },
	{ arguments = { "a b", "c" }, max = 1, expected = { "a b c" } },
	{ arguments = { "a", "b" }, max = 2, expected = { "a", "b" } },
	{ arguments = { "a" }, max = 3, expected = { "a" } },
	{ arguments = {}, max = 2, expected = {} },
}

type Mash = {
	arguments: { string },
	max: number,
	expected: { string },
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, mash: Mash in MASHES do
		local count: number = #mash.arguments
		local mashed: { string } = util.mashExcessArguments(mash.arguments, mash.max)

		if not Listed(mashed, mash.expected) then
			return false, `mashExcessArguments at {mash.max} made {table.concat(mashed, SEPARATOR)}`
		end

		if mashed == mash.arguments or #mash.arguments ~= count then
			return false, "mashExcessArguments changed the list it was given instead of making one"
		end
	end

	local unmaxed: { [number]: string } = util.mashExcessArguments(UNMAXED, NO_MAX)
	if unmaxed[1] ~= nil or unmaxed[NO_MAX] ~= AT_NO_MAX then
		return false, `mashExcessArguments at {NO_MAX} put {unmaxed[1]} at 1 and {unmaxed[NO_MAX]} at 0`
	end

	return true, nil
end
