--[[
    Util's splitString splits a line at runs of spaces, keeps a run of words
    in matching quotes as one segment and keeps a quote left open in the text
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins segments in a failure message

-- Each typed line and the segments splitString makes of it
local SPLITS: { Split } = {
	{ line = `kick "two words" three`, expected = { "kick", "two words", "three" } },
	{ line = "say 'single quoted'", expected = { "say", "single quoted" } },
	{ line = `say "one"`, expected = { "say", "one" } },
	{ line = `say "it's here"`, expected = { "say", "it's here" } }, -- A quote of the other kind stays inside
	{ line = `say "a   b"   c`, expected = { "say", "a b", "c" } }, -- Spaces inside quotes collapse to one too
	{ line = "  kick  me  ", expected = { "kick", "me" } },
	{ line = `say "a" "b"`, expected = { "say", "a", "b" } },
	{ line = `say ""`, expected = { "say", "" } },
	{ line = `say "`, expected = { "say", "" } }, -- A lone quote both opens and closes
	{ line = `say mid"dle`, expected = { "say", `mid"dle` } },
	{ line = `say "a b"c`, expected = { "say", `"a b"c` } }, -- A quote that closes mid-word closes nothing
	{ line = `say "open words`, expected = { "say", `"open words` } },
	{ line = "say a\tb", expected = { "say", "a\tb" } }, -- Only a space separates
	{ line = "", expected = {} },
	{ line = "   ", expected = {} },
}

type Split = {
	line: string,
	expected: { string },
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, split: Split in SPLITS do
		local segments: { string } = util.splitString(split.line)
		if not Listed(segments, split.expected) then
			return false, `splitString split {split.line} into {table.concat(segments, SEPARATOR)}`
		end
	end

	return true, nil
end
