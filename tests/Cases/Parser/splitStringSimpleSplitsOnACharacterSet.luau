--[[
    Util's splitStringSimple splits at whitespace by default, or at any one
    character of the separator it is given, drops every empty piece and
    throws on a separator that breaks its pattern
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins pieces in a failure message
local BROKEN: string = "%" -- Leaves the character class splitStringSimple builds unclosed

-- Each text, its separator and the pieces splitStringSimple makes of it
local SPLITS: { Split } = {
	{ text = "a b  c", separator = nil, expected = { "a", "b", "c" } },
	{ text = "a\tb\nc", separator = nil, expected = { "a", "b", "c" } },
	{ text = "a,b,,c", separator = ",", expected = { "a", "b", "c" } },
	{ text = ",a,", separator = ",", expected = { "a" } },
	{ text = "a b", separator = ",", expected = { "a b" } },
	{ text = "a-b_c", separator = "-_", expected = { "a", "b", "c" } }, -- Each character of it separates
	{ text = "a.b", separator = ".", expected = { "a", "b" } },
	{ text = ",,,", separator = ",", expected = {} },
	{ text = "", separator = nil, expected = {} },
}

type Split = {
	text: string,
	separator: string?,
	expected: { string },
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, split: Split in SPLITS do
		local pieces: { string } = util.splitStringSimple(split.text, split.separator)
		if not Listed(pieces, split.expected) then
			local joined: string = table.concat(pieces, SEPARATOR)
			return false, `splitStringSimple split {split.text} at {split.separator} into {joined}`
		end
	end

	if pcall(util.splitStringSimple, SPLITS[1].text, BROKEN) then
		return false, `splitStringSimple split at {BROKEN} without throwing`
	end

	return true, nil
end
