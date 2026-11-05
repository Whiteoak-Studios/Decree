--[[
    Util's makeFuzzyFinder over names matches ignoring case, ranks an exact
    match first, then by where the text starts in the name, then shortest,
    takes the text literally, and with matchStart keeps only prefixes
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins matches in a failure message
local FRUITS: { string } = { "pineapple", "Apple pie", "banana", "apple" }
local LENGTHS: { string } = { "bb", "a", "ccc" }
local SYMBOLS: { string } = { "100%", "50" }

-- Each set, the text searched for, whether only a name's start counts, and the matches in order
local SEARCHES: { Search } = {
	{ set = FRUITS, text = "apple", matchStart = false, expected = { "apple", "Apple pie", "pineapple" } },
	{ set = FRUITS, text = "APPLE", matchStart = false, expected = { "apple", "Apple pie", "pineapple" } },
	{ set = FRUITS, text = "p", matchStart = false, expected = { "pineapple", "apple", "Apple pie" } },
	{ set = FRUITS, text = "an", matchStart = false, expected = { "banana" } },
	{ set = FRUITS, text = "zzz", matchStart = false, expected = {} },
	{ set = FRUITS, text = "ap", matchStart = true, expected = { "apple", "Apple pie" } },
	{ set = FRUITS, text = "apple", matchStart = true, expected = { "apple", "Apple pie" } },
	{ set = FRUITS, text = "pie", matchStart = true, expected = {} },
	{ set = LENGTHS, text = "", matchStart = false, expected = { "a", "bb", "ccc" } },
	{ set = SYMBOLS, text = "%", matchStart = false, expected = { "100%" } },
}

-- Each set, the text searched for, whether only a name's start counts, and the one match returnFirst gives
local FIRSTS: { First } = {
	{ set = FRUITS, text = "APPLE", matchStart = false, expected = "apple" },
	{ set = FRUITS, text = "pine", matchStart = false, expected = "pineapple" },
	{ set = FRUITS, text = "ap", matchStart = true, expected = "apple" },
	{ set = FRUITS, text = "zzz", matchStart = false, expected = nil },
}

type Search = {
	set: { string },
	text: string,
	matchStart: boolean,
	expected: { string },
}

type First = {
	set: { string },
	text: string,
	matchStart: boolean,
	expected: string?,
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, search: Search in SEARCHES do
		local find: any = util.makeFuzzyFinder(search.set)
		local matches: { string } = find(search.text, false, search.matchStart)

		if not Listed(matches, search.expected) then
			return false, `{search.text} matched {table.concat(matches, SEPARATOR)}`
		end
	end

	for _, first: First in FIRSTS do
		local find: any = util.makeFuzzyFinder(first.set)
		local match: string? = find(first.text, true, first.matchStart)

		if match ~= first.expected then
			return false, `{first.text} matched {match} first`
		end
	end

	return true, nil
end
