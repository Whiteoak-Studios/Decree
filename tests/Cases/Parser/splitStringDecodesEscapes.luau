--[[
    Util's splitString reads an escaped quote as a literal quote that groups
    nothing, turns \t, \n, \x and \u escapes into their characters, and lets
    an escaped backslash shield the letter after it
--]]

--!strict
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local SEPARATOR: string = " | " -- Joins segments in a failure message

-- Each typed line, written as a Luau string, and the segments splitString makes of it
local SPLITS: { Split } = {
	{ line = `say \\"hi\\"`, expected = { "say", `"hi"` } },
	{ line = `say \\"two words\\"`, expected = { "say", `"two`, `words"` } },
	{ line = `say "a \\"b\\" c"`, expected = { "say", `a "b" c` } },
	{ line = `say \\'it\\'`, expected = { "say", "'it'" } },
	{ line = "say a\\tb", expected = { "say", "a\tb" } },
	{ line = "say a\\nb", expected = { "say", "a\nb" } },
	{ line = "say \\x41\\u0042", expected = { "say", "AB" } },
	{ line = "say a\\\\tb", expected = { "say", "a\\tb" } },
	{ line = "say \\q", expected = { "say", "\\q" } }, -- An escape it does not know stays as typed
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
