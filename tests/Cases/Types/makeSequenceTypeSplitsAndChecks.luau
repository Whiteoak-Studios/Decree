--[[
    Util's makeSequenceType splits text at commas or else at whitespace,
    checks each element up to its length and refuses any past it, and builds
    the value from the elements through parse or else constructor
--]]

--!strict
local Environment = require("../../Environment")
local Refuses = require("../../Fixtures/Types/Refuses")

local UTIL: string = "src/DecreeClient/Shared/Util"
local REFUSAL: string = "[Decree] makeSequenceType: Must provide one of: constructor, parse"
local SEPARATOR: string = "|" -- Joins a list of elements into one string to compare
local MANY: { string } = { "a", "b", "c", "d" } -- More elements than any length, which a sequence with none takes
local PAIR: { string } = { "a", "b" }
local JOINED: string = "a|b" -- PAIR through the case's constructor
local LENGTH: number = 2
local NUMBERS: string = "1,2"
local NUMBERS_SUM: number = 3
local TOO_MANY: { number } = { 1, 2, 3 }
local TOO_MANY_REFUSAL: string = `Maximum of {LENGTH} values allowed in sequence`
local SHORT: { number } = { 1 }
local MISSING_REFUSAL: string = "missing 2" -- What the case's validateEach says of the second element
local PREFIXES: string = "# integer"
local WHOLE: string = "a,b" -- Kept as one element by a sequence with its own transform

-- Each text a sequence splits, and its elements
local SPLITS: { Split } = {
	{ text = "a,b c", elements = { "a", "b c" } }, -- A comma anywhere wins over the spaces
	{ text = "a b", elements = { "a", "b" } },
	{ text = "a,,b", elements = { "a", "b" } },
	{ text = "", elements = {} },
}

type Split = {
	text: string,
	elements: { string },
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	local function join(...: string): string
		return table.concat({ ... }, SEPARATOR)
	end

	if not Refuses(REFUSAL, util.makeSequenceType, {}) then
		return false, "makeSequenceType took a sequence with neither parse nor constructor"
	end

	local joined: any = util.makeSequenceType({ constructor = join })
	if joined.prefixes ~= nil then
		return false, "makeSequenceType gave a prefix to a sequence with none"
	end

	for _, split: Split in SPLITS do
		local elements: { string } = joined.transform(split.text)
		if
			#elements ~= #split.elements
			or table.concat(elements, SEPARATOR) ~= table.concat(split.elements, SEPARATOR)
		then
			return false, `makeSequenceType split "{split.text}" as {table.concat(elements, ", ")}`
		end
	end

	local many: boolean = joined.validate(MANY)
	if not many or joined.parse(PAIR) ~= JOINED then
		return false,
			"makeSequenceType's sequence with no length refused elements, or did not build through constructor"
	end

	local bounded: any = util.makeSequenceType({
		length = LENGTH,
		prefixes = PREFIXES,
		transformEach = tonumber,

		validateEach = function (value: number?, index: number): (boolean, string?)
			if value == nil then
				return false, `missing {index}`
			end

			return true, nil
		end,

		parse = function (elements: { number }): number
			return elements[1] + elements[2]
		end,
	})

	local numbers: { number } = bounded.transform(NUMBERS)
	local valid: boolean = bounded.validate(numbers)
	if not valid or bounded.parse(numbers) ~= NUMBERS_SUM or bounded.prefixes ~= PREFIXES then
		return false, `makeSequenceType's bounded sequence did not read {NUMBERS} through its own parse`
	end

	local tooMany: boolean, tooManyReason: string? = bounded.validate(TOO_MANY)
	local short: boolean, shortReason: string? = bounded.validate(SHORT)
	if tooMany or tooManyReason ~= TOO_MANY_REFUSAL or short or shortReason ~= MISSING_REFUSAL then
		return false, `makeSequenceType's bounded sequence refused with {tooManyReason} and {shortReason}`
	end

	-- A validateEach that refuses with no reason leaves the sequence's refusal without one
	local silent: any = util.makeSequenceType({
		constructor = join,

		validateEach = function (): boolean
			return false
		end,
	})

	local silentValid: boolean, silentReason: string? = silent.validate(PAIR)
	if silentValid or silentReason ~= nil then
		return false, `makeSequenceType's sequence refused with {silentReason} where validateEach gave none`
	end

	local own: any = util.makeSequenceType({
		constructor = join,

		transform = function (text: string): { string }
			return { text }
		end,
	})

	local whole: { string } = own.transform(WHOLE)
	if #whole ~= 1 or whole[1] ~= WHOLE then
		return false, "makeSequenceType replaced a sequence's own transform"
	end

	return true, nil
end
