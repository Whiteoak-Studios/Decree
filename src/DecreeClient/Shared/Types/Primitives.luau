--[[
    The plain argument types: string, the six number types, boolean and url,
    each with its listable, and json and mathOperator, which have none
--]]

--!strict
local HttpService = game:GetService("HttpService")

local Util = require("../Util")

local BYTE_MAX: number = 255
local DIGIT_MAX: number = 9
local URL: string = "^https?://.+$" -- An http or https scheme in lowercase, with something after it

-- The words a boolean reads, each in any case
local TRUE_WORDS: { string } = { "true", "t", "yes", "y", "on", "enable", "enabled", "1", "+" }
local FALSE_WORDS: { string } = { "false", "f", "no", "n", "off", "disable", "disabled", "0", "-" }
local TRUTHY: { [string]: true } = Util.makeDictionary(TRUE_WORDS)
local FALSY: { [string]: true } = Util.makeDictionary(FALSE_WORDS)

-- Each operator mathOperator parses to, found by its symbol
local MATH_OPERATORS: { MathOperator } = {
	{
		Name = "+",
		perform = function (a: number, b: number): number
			return a + b
		end,
	},
	{
		Name = "-",
		perform = function (a: number, b: number): number
			return a - b
		end,
	},
	{
		Name = "*",
		perform = function (a: number, b: number): number
			return a * b
		end,
	},
	{
		Name = "/",
		perform = function (a: number, b: number): number
			return a / b
		end,
	},
	{
		Name = "**",
		perform = function (a: number, b: number): number
			return a ^ b
		end,
	},
	{
		Name = "%",
		perform = function (a: number, b: number): number
			return a % b
		end,
	},
}

local Types = require("../Config/Types/Command")

type TypeDefinition = Types.TypeDefinition

-- Name keeps its capital, since makeFuzzyFinder reads every named value's Name
type MathOperator = {
	Name: string,
	perform: (a: number, b: number) -> number,
}

--[[
    Whether a number is neither infinite nor nan
--]]

local function isFinite(value: number): boolean
	return value == value and math.abs(value) ~= math.huge
end

--[[
    Whether a number is finite and has no fraction
--]]

local function isWhole(value: number): boolean
	return isFinite(value) and value == math.floor(value)
end

--[[
    Makes a number type, which reads its text as tonumber does and refuses
    a missing number, or one the check turns down, with the reason
--]]

local function numeric(check: (value: number) -> boolean, reason: string?): TypeDefinition
	return {
		transform = function (text: string): number?
			return tonumber(text)
		end,

		validate = function (value: number?): (boolean, string?)
			return value ~= nil and check(value), reason
		end,

		parse = function (value: number): number
			return value
		end,
	}
end

local Definitions: { [string]: TypeDefinition } = {
	string = {
		validate = function (value: any): (boolean, string?)
			return value ~= nil, nil
		end,

		parse = function (value: any): string
			return tostring(value)
		end,
	},

	number = numeric(isFinite, nil),
	integer = numeric(isWhole, "Only whole numbers are valid."),

	positiveInteger = numeric(function (value: number): boolean
		return isWhole(value) and value > 0
	end, "Only positive whole numbers are valid."),

	nonNegativeInteger = numeric(function (value: number): boolean
		return isWhole(value) and value >= 0
	end, "Only non-negative whole numbers are valid."),

	byte = numeric(function (value: number): boolean
		return isWhole(value) and value >= 0 and value <= BYTE_MAX
	end, "Only bytes are valid."),

	digit = numeric(function (value: number): boolean
		return isWhole(value) and value >= 0 and value <= DIGIT_MAX
	end, "Only digits are valid."),

	boolean = {
		transform = function (text: string): string
			return text:lower()
		end,

		validate = function (value: string): (boolean, string?)
			return TRUTHY[value] ~= nil or FALSY[value] ~= nil, "Please use true/yes/on or false/no/off."
		end,

		parse = function (value: string): boolean?
			if TRUTHY[value] then
				return true
			elseif FALSY[value] then
				return false
			end

			return nil
		end,
	},

	json = {
		validate = function (text: string): (boolean, string?)
			local decoded: boolean, problem: any = pcall(HttpService.JSONDecode, HttpService, text)
			if not decoded then
				return false, problem
			end

			return true, nil
		end,

		parse = function (text: string): any
			return HttpService:JSONDecode(text)
		end,
	},

	url = {
		validate = function (text: string): (boolean, string?)
			if text:match(URL) then
				return true, nil
			end

			return false, "URLs must begin with http:// or https://"
		end,

		parse = function (text: string): string
			return text
		end,
	},

	mathOperator = Util.makeEnumType("Math Operator", MATH_OPERATORS),
}

Definitions.strings = Util.makeListableType(Definitions.string)
Definitions.numbers = Util.makeListableType(Definitions.number)
Definitions.integers = Util.makeListableType(Definitions.integer)
Definitions.positiveIntegers = Util.makeListableType(Definitions.positiveInteger)
Definitions.nonNegativeIntegers = Util.makeListableType(Definitions.nonNegativeInteger)
Definitions.bytes = Util.makeListableType(Definitions.byte)
Definitions.digits = Util.makeListableType(Definitions.digit)
Definitions.booleans = Util.makeListableType(Definitions.boolean)
Definitions.urls = Util.makeListableType(Definitions.url)

return Definitions
