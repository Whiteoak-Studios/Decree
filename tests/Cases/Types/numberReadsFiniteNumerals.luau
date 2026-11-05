--[[
    The number type reads any finite numeral Luau's tonumber reads, hex and
    exponents included, and refuses inf, -inf, nan and any other text with
    no message of its own; numbers parses to a list of the one number
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Primitives"
local TYPE: string = "number"
local LISTABLE: string = "numbers"
local REFUSED: { string } = { "abc", "1_000", "1,5", "", "inf", "-inf", "nan" }

-- Each text the type reads, and the number it reads it as
local READS: { Read } = {
	{ text = "1.5", value = 1.5 },
	{ text = "-3", value = -3 },
	{ text = "1e3", value = 1000 },
	{ text = "0x10", value = 16 },
	{ text = ".5", value = 0.5 },
}

type Read = {
	text: string,
	value: number,
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	for _, read: Read in READS do
		local value: number? = definition.transform(read.text)
		local valid: boolean = definition.validate(value)
		if value ~= read.value or not valid or definition.parse(value) ~= read.value then
			return false, `number read {read.text} as {value}`
		end
	end

	for _, text: string in REFUSED do
		local refused: number? = definition.transform(text)
		local valid: boolean, reason: string? = definition.validate(refused)
		if valid or reason ~= nil then
			return false, `number accepted "{text}", or refused it with {reason}`
		end
	end

	local parsed: { number } = listable.parse(READS[1].value)
	if listable.listable ~= true or #parsed ~= 1 or parsed[1] ~= READS[1].value then
		return false, "numbers did not parse to a list of the one number"
	end

	return true, nil
end
