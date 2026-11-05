--[[
    The duration type reads a text that ends in a stray word as the units
    before it and suggests nothing for that word, while a stray word before
    the last number and unit leaves that unit completing
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Duration"
local TYPE: string = "duration"
local EARLIER: string = "1h foo 2m" -- A stray word before the last number and unit
local EARLIER_SECONDS: number = 3720
local EARLIER_SUGGESTIONS: { string } = { "1h foo 2minutes", "1h foo 2months" }
local SEPARATOR: string = "|" -- Joins a list of suggestions into one string to compare

-- Each text that ends in a stray word, and the seconds it reads as
local STRAYS: { Read } = {
	{ text = "1h foo", seconds = 3600 },
	{ text = "10s !", seconds = 10 },
	{ text = "1d6h then ", seconds = 108000 },
}

type Read = {
	text: string,
	seconds: number,
}

return function (): (boolean, string | nil)
	local definition: any = Environment.new().require(TYPES)[TYPE]

	-- Transform keeps the text first, and every later step takes each value it returned
	for _, stray: Read in STRAYS do
		local values: { n: number, [number]: any } = table.pack(definition.transform(stray.text))
		local valid: boolean = definition.validate(table.unpack(values, 1, values.n))
		if values[2] ~= stray.seconds or not valid then
			return false, `duration read "{stray.text}" as {values[2]} seconds`
		end

		local completed: boolean, suggestions: any = pcall(definition.autocomplete, table.unpack(values, 1, values.n))
		if not completed then
			return false, `duration threw completing "{stray.text}": {suggestions}`
		end

		if #suggestions ~= 0 then
			return false, `duration completed "{stray.text}" as {table.concat(suggestions, ", ")}`
		end
	end

	local values: { n: number, [number]: any } = table.pack(definition.transform(EARLIER))
	local suggestions: { string } = definition.autocomplete(table.unpack(values, 1, values.n))
	if
		values[2] ~= EARLIER_SECONDS
		or table.concat(suggestions, SEPARATOR) ~= table.concat(EARLIER_SUGGESTIONS, SEPARATOR)
	then
		return false, `duration completed "{EARLIER}" as {table.concat(suggestions, ", ")}`
	end

	return true, nil
end
