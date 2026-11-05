--[[
    Each whole-number type accepts the values inside its bounds and refuses
    a fraction, a value past them, an infinity or text that reads as no
    number with its own message
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Primitives"

-- Each whole-number type, its listable, the texts it accepts and refuses, and its refusal
local BOUNDS: { Bound } = {
	{
		name = "integer",
		listable = "integers",
		accepts = { "-7", "0", "12" },
		refuses = { "1.5", "nan", "abc", "inf", "-inf" },
		reason = "Only whole numbers are valid.",
	},
	{
		name = "positiveInteger",
		listable = "positiveIntegers",
		accepts = { "1", "12" },
		refuses = { "0", "-1", "1.5", "abc", "inf" },
		reason = "Only positive whole numbers are valid.",
	},
	{
		name = "nonNegativeInteger",
		listable = "nonNegativeIntegers",
		accepts = { "0", "12" },
		refuses = { "-1", "0.5", "-inf", "abc", "inf" },
		reason = "Only non-negative whole numbers are valid.",
	},
	{
		name = "byte",
		listable = "bytes",
		accepts = { "0", "255" },
		refuses = { "256", "-1", "1.5", "inf", "abc" },
		reason = "Only bytes are valid.",
	},
	{
		name = "digit",
		listable = "digits",
		accepts = { "0", "9" },
		refuses = { "10", "-1", "0.5", "inf", "abc" },
		reason = "Only digits are valid.",
	},
}

type Bound = {
	name: string,
	listable: string,
	accepts: { string },
	refuses: { string },
	reason: string,
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)

	for _, bound: Bound in BOUNDS do
		local definition: any = types[bound.name]
		local listable: any = types[bound.listable]

		for _, text: string in bound.accepts do
			local value: number? = definition.transform(text)
			local valid: boolean = definition.validate(value)
			if not valid or definition.parse(value) ~= value then
				return false, `{bound.name} refused {text}`
			end

			local parsed: { number } = listable.parse(value)
			if listable.listable ~= true or #parsed ~= 1 or parsed[1] ~= value then
				return false, `{bound.listable} did not parse {text} to a list of the one number`
			end
		end

		for _, text: string in bound.refuses do
			local refused: number? = definition.transform(text)
			local valid: boolean, reason: string? = definition.validate(refused)
			if valid or reason ~= bound.reason then
				return false, `{bound.name} accepted {text}, or refused it with {reason}`
			end
		end
	end

	return true, nil
end
