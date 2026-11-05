--[[
    Util's makeEnumType builds a type that accepts and parses to a value
    named exactly or in part, completes the values that hold the text, and
    refuses any other text, quoted, beside the enum's name
--]]

--!strict
local Environment = require("../../Environment")
local Refuses = require("../../Fixtures/Types/Refuses")

local UTIL: string = "src/DecreeClient/Shared/Util"
local NAME: string = "Fruit"
local VALUES: { string } = { "apple", "Banana", "applesauce" }
local APPLE: string = "apple"
local BANANA: string = "Banana"
local EXACT: string = "APPLE" -- APPLE in another case
local PART: string = "app" -- Starts APPLE and applesauce, so the shorter one parses
local PART_SUGGESTIONS: { string } = { "apple", "applesauce" }
local INSIDE: string = "nan" -- Inside BANANA only
local UNKNOWN: string = "pear"
local UNKNOWN_REFUSAL: string = `Value "{UNKNOWN}" is not a valid {NAME}.`
local QUOTED: string = `a"b`
local QUOTED_REFUSAL: string = `Value "a\\"b" is not a valid {NAME}.` -- The text quoted, its quote escaped
local SIZE: string = "Size"
local SMALL: string = "small"
local LARGE: string = "large"
local SHARED: string = "l" -- Starts LARGE and sits later in SMALL
local NOT_A_LIST: number = 5
local NOT_A_LIST_REFUSAL: string = "[Decree] makeFuzzyFinder only accepts a table, Enum, or Instance."
local NUMBERS: { number } = { 1, 2 }
local NUMBERS_REFUSAL: string = "[Decree] makeFuzzyFinder only accepts tables of instances or strings."
local SEPARATOR: string = "|" -- Joins a list of suggestions into one string to compare

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)
	local enum: any = util.makeEnumType(NAME, VALUES)

	if enum.transform ~= nil then
		return false, "makeEnumType's type transforms its text"
	end

	local exact: boolean = enum.validate(EXACT)
	local part: boolean = enum.validate(PART)
	if not exact or not part or enum.parse(EXACT) ~= APPLE or enum.parse(PART) ~= APPLE then
		return false, `makeEnumType's type did not read {EXACT} and {PART} as {APPLE}`
	end

	local suggestions: { string } = enum.autocomplete(PART)
	if table.concat(suggestions, SEPARATOR) ~= table.concat(PART_SUGGESTIONS, SEPARATOR) then
		return false, `makeEnumType's type completed {PART} as {table.concat(suggestions, ", ")}`
	end

	if enum.parse(INSIDE) ~= BANANA then
		return false, `makeEnumType's type did not read {INSIDE} as {BANANA}`
	end

	local unknown: boolean, unknownReason: string? = enum.validate(UNKNOWN)
	local none: { string } = enum.autocomplete(UNKNOWN)
	if unknown or unknownReason ~= UNKNOWN_REFUSAL or enum.parse(UNKNOWN) ~= nil or #none ~= 0 then
		return false, `makeEnumType's type accepted {UNKNOWN}, or refused it with {unknownReason}`
	end

	local quoted: boolean, quotedReason: string? = enum.validate(QUOTED)
	if quoted or quotedReason ~= QUOTED_REFUSAL then
		return false, `makeEnumType's type refused {QUOTED} with {quotedReason}`
	end

	-- Values named by a Name key complete to their names and parse to the values themselves
	local small: { Name: string } = { Name = SMALL }
	local large: { Name: string } = { Name = LARGE }
	local sizes: any = util.makeEnumType(SIZE, { small, large })
	local sizeNames: { string } = sizes.autocomplete(SHARED)
	if sizeNames[1] ~= LARGE or sizeNames[2] ~= SMALL or #sizeNames ~= 2 or sizes.parse(SMALL) ~= small then
		return false, `makeEnumType's type of named values completed {SHARED} as {table.concat(sizeNames, ", ")}`
	end

	local empty: any = util.makeEnumType(NAME, {})
	local emptyValid: boolean = empty.validate(APPLE)
	if emptyValid then
		return false, "makeEnumType's type of no values accepted a value"
	end

	if not Refuses(NOT_A_LIST_REFUSAL, util.makeEnumType, NAME, NOT_A_LIST) then
		return false, "makeEnumType took values that are no list"
	end

	if not Refuses(NUMBERS_REFUSAL, util.makeEnumType, NAME, NUMBERS) then
		return false, "makeEnumType took a list of numbers"
	end

	return true, nil
end
