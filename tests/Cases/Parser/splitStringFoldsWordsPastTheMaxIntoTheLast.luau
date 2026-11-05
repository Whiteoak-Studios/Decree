--[[
    Util's splitString with a max keeps at most that many segments and adds
    every later word to the last one in order, and refuses a max below 1,
    naming it, whatever the line holds
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")
local Refuses = require("../../Fixtures/Types/Refuses")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins segments in a failure message
local NO_MAX: number = 0
local ONE_WORD: string = "a"
local TWO_WORDS: string = "a b"
local NO_MAX_REFUSAL: string = `[Decree] splitString's max must be 1 or more, not {NO_MAX}`

-- Each typed line, its max and the segments splitString makes of it
local SPLITS: { Split } = {
	{ line = "a b", max = 2, expected = { "a", "b" } },
	{ line = "a b c", max = 2, expected = { "a", "b c" } },
	{ line = "a b c d e", max = 2, expected = { "a", "b c d e" } },
	{ line = `a "b c" d e`, max = 1, expected = { "a b c d e" } },
}

type Split = {
	line: string,
	max: number,
	expected: { string },
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, split: Split in SPLITS do
		local segments: { string } = util.splitString(split.line, split.max)
		if not Listed(segments, split.expected) then
			return false, `splitString split {split.line} at {split.max} into {table.concat(segments, SEPARATOR)}`
		end
	end

	-- A max below 1 is refused before the line is read
	for _, line: string in { ONE_WORD, TWO_WORDS } do
		if not Refuses(NO_MAX_REFUSAL, util.splitString, line, NO_MAX) then
			return false, `splitString split {line} at {NO_MAX} without refusing the max`
		end
	end

	return true, nil
end
