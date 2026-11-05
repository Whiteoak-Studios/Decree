--[[
    Util's splitPrioritizedDelimiter splits on the first delimiter whose
    characters the text holds, or on the last one when none is found, and
    gives nil for no delimiters at all
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins pieces in a failure message
local COMMA_OR_SPACE: { string } = { ",", "%s" } -- The order a sequence type splits its text in
local ANY_FIRST: { string } = { ".", "," } -- A first delimiter that as a pattern would find any character

-- Each text, its delimiters and the pieces splitPrioritizedDelimiter makes of it
local SPLITS: { Split } = {
	{ text = "1,2,3", delimiters = COMMA_OR_SPACE, expected = { "1", "2", "3" } },
	{ text = "1 2 3", delimiters = COMMA_OR_SPACE, expected = { "1", "2", "3" } },
	{ text = "1, 2 3", delimiters = COMMA_OR_SPACE, expected = { "1", " 2 3" } },
	{ text = "123", delimiters = COMMA_OR_SPACE, expected = { "123" } },
	{ text = "", delimiters = COMMA_OR_SPACE, expected = {} },
	{ text = "a,b", delimiters = ANY_FIRST, expected = { "a", "b" } }, -- The text holds no dot, so the comma splits it
}

type Split = {
	text: string,
	delimiters: { string },
	expected: { string },
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, split: Split in SPLITS do
		local pieces: { string } = util.splitPrioritizedDelimiter(split.text, split.delimiters)
		if not Listed(pieces, split.expected) then
			return false, `splitPrioritizedDelimiter split {split.text} into {table.concat(pieces, SEPARATOR)}`
		end
	end

	local none: { string }? = util.splitPrioritizedDelimiter(SPLITS[1].text, {})
	if none ~= nil then
		return false, "splitPrioritizedDelimiter split a text with no delimiters"
	end

	return true, nil
end
