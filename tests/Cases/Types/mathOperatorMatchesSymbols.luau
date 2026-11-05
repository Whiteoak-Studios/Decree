--[[
    The mathOperator type accepts each of its six symbols and parses each to
    an operator that performs its sum, completes a symbol to the ones that
    hold it, and refuses any other text with its message
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Primitives"
local TYPE: string = "mathOperator"
local LISTABLE: string = "mathOperators" -- A name the file holds no type under
local LEFT: number = 2
local RIGHT: number = 3
local STAR: string = "*"
local STAR_SUGGESTIONS: { string } = { "*", "**" } -- The exact symbol first, then the one that holds it
local UNKNOWN: string = "x"
local REFUSAL: string = `Value "{UNKNOWN}" is not a valid Math Operator.`
local SEPARATOR: string = "|" -- Joins a list of suggestions into one string to compare

-- Each symbol, and what its operator makes of LEFT and RIGHT
local RESULTS: { [string]: number } = {
	["+"] = 5,
	["-"] = -1,
	["*"] = 6,
	["/"] = 2 / 3,
	["**"] = 8,
	["%"] = 2,
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]

	if definition.transform ~= nil or types[LISTABLE] ~= nil then
		return false, "mathOperator transforms its text, or has a listable"
	end

	for symbol: string, result: number in RESULTS do
		local valid: boolean = definition.validate(symbol)
		local operator: any = definition.parse(symbol)
		if not valid or not operator or operator.Name ~= symbol or operator.perform(LEFT, RIGHT) ~= result then
			return false, `mathOperator did not read {symbol} as its operator`
		end
	end

	local suggestions: { string } = definition.autocomplete(STAR)
	if table.concat(suggestions, SEPARATOR) ~= table.concat(STAR_SUGGESTIONS, SEPARATOR) then
		return false, `mathOperator completed {STAR} as {table.concat(suggestions, ", ")}`
	end

	local valid: boolean, reason: string? = definition.validate(UNKNOWN)
	local none: { string } = definition.autocomplete(UNKNOWN)
	if valid or reason ~= REFUSAL or definition.parse(UNKNOWN) ~= nil or #none ~= 0 then
		return false, `mathOperator accepted or completed {UNKNOWN}, or refused it with {reason}`
	end

	return true, nil
end
