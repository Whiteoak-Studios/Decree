--[[
    Util's trimString strips whitespace of every kind from both ends of a
    text, keeps what sits between, and makes an empty or blank text empty
--]]

--!strict
local Environment = require("../../Environment")

local UTIL: string = "src/DecreeClient/Shared/Util"

-- Each text and what trimString makes of it
local TRIMS: { Trim } = {
	{ text = "  a b  ", expected = "a b" },
	{ text = "\t\na\r\n", expected = "a" },
	{ text = " a", expected = "a" },
	{ text = "a ", expected = "a" },
	{ text = "ab", expected = "ab" },
	{ text = "   ", expected = "" },
	{ text = "", expected = "" },
}

type Trim = {
	text: string,
	expected: string,
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	for _, trim: Trim in TRIMS do
		local trimmed: string = util.trimString(trim.text)
		if trimmed ~= trim.expected then
			return false, `trimString made "{trimmed}" of "{trim.text}"`
		end
	end

	return true, nil
end
