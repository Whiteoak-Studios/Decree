--[[
    Util's parseEscapeSequences turns \t, \n, \xHH and \uHHHH into their
    characters and leaves an unknown or short escape, and a doubled
    backslash, exactly as written
--]]

--!strict
local Environment = require("../../Environment")

local UTIL: string = "src/DecreeClient/Shared/Util"

-- Each text, written as a Luau string, and what parseEscapeSequences makes of it
local PARSES: { Parse } = {
	{ text = "a\\tb", expected = "a\tb" },
	{ text = "a\\nb", expected = "a\nb" },
	{ text = "\\x41", expected = "A" },
	{ text = "\\u00e9", expected = "é" },
	{ text = "\\x41\\u0042c", expected = "ABc" },
	{ text = "\\q", expected = "\\q" },
	{ text = "\\u12", expected = "\\u12" },
	{ text = "\\xZZ", expected = "\\xZZ" },
	{ text = "\\\\n", expected = "\\\\n" },
	{ text = "plain", expected = "plain" },
	{ text = "", expected = "" },
}

type Parse = {
	text: string,
	expected: string,
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, parse: Parse in PARSES do
		local parsed: string = util.parseEscapeSequences(parse.text)
		if parsed ~= parse.expected then
			return false, `parseEscapeSequences made {parsed} of {parse.text}`
		end
	end

	return true, nil
end
