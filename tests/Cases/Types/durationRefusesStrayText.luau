--[[
    The duration type refuses a text holding anything besides its numbers,
    units and spaces, such as a stray word or stray punctuation anywhere, and
    suggests nothing for it, while units split by a space still read whole
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Duration"
local TYPE: string = "duration"
local REFUSAL: string = "Invalid duration format. Example: 1d6h, 30m, 10s."
local EARLIER: string = "1h foo 2m" -- A stray word before the last number and unit
local STRAYS: { string } = { "1h foo", "10s !", "1d6h then ", EARLIER }
local SPACED: string = "1h 30m"
local SPACED_SECONDS: number = 5400

return function (): (boolean, string | nil)
	local definition: any = Environment.new().require(TYPES)[TYPE]

	-- Transform keeps the text first, and every later step takes each value it returned
	for _, stray: string in STRAYS do
		local values: { n: number, [number]: any } = table.pack(definition.transform(stray))
		local valid: boolean, reason: string? = definition.validate(table.unpack(values, 1, values.n))
		if valid or reason ~= REFUSAL then
			return false, `duration read "{stray}" as {values[2]} seconds, or refused it with {reason}`
		end

		local suggestions: { string } = definition.autocomplete(table.unpack(values, 1, values.n))
		if #suggestions ~= 0 then
			return false, `duration completed "{stray}" as {table.concat(suggestions, ", ")}`
		end
	end

	local values: { n: number, [number]: any } = table.pack(definition.transform(SPACED))
	local valid: boolean = definition.validate(table.unpack(values, 1, values.n))
	if values[2] ~= SPACED_SECONDS or not valid then
		return false, `duration read "{SPACED}" as {values[2]} seconds`
	end

	return true, nil
end
