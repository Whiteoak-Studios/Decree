--[[
    The duration argument types: duration, which adds a text's numbers and
    units up to seconds and completes the unit being typed, and durations
--]]

--!strict
local Util = require("../Util")

local NONE: string = ""
local EVERY_UNIT: string = "" -- A text every unit's name starts with
local COMPONENT: string = "-?%d+%a+" -- A number and its unit, such as 6h
local COMPONENT_PARTS: string = "(-?%d+)(%a+)"
local NUMBER: string = "-?%d+"
local ENDING_UNIT: string = "^.*-?%d+(%a+)%s?$" -- The unit typed last, after its number
local MINUTES_ALONE: string = "m" -- An m alone is minutes, though Months starts with it too
local FROM_START: boolean = true -- Finds only the unit names a text starts
local REFUSAL: string = "Invalid duration format. Example: 1d6h, 30m, 10s."

-- Each unit's length in seconds, by its name
local UNIT_SECONDS: { [string]: number } = {
	Years = 31556926,
	Months = 2629744,
	Weeks = 604800,
	Days = 86400,
	Hours = 3600,
	Minutes = 60,
	Seconds = 1,
}

local Types = require("../Config/Types/Command")

type TypeDefinition = Types.TypeDefinition

local UnitNames: { string } = {}

for name: string in UNIT_SECONDS do
	table.insert(UnitNames, name)
end

local findUnits: (text: string, returnFirst: boolean?, matchStart: boolean?) -> any = Util.makeFuzzyFinder(UnitNames)

--[[
    Adds a text's numbers and units up to seconds, giving the seconds, the
    last number typed and whether that number still lacks its unit. The
    seconds are nil for a text it refuses, a zero or negative sum among
    them, and 0 for a bare 0
--]]

local function readSeconds(text: string): (number?, number?, boolean?)
	if text == NONE then
		return nil, nil, nil
	end

	if tonumber(text) == 0 then
		return 0, 0, true
	end

	local missingUnit: string? = (text:gsub(COMPONENT, NONE)):match(NUMBER)
	if missingUnit then
		return nil, tonumber(missingUnit), true
	end

	local seconds: number = 0
	local lastNumber: number? = nil

	for component: string in text:gmatch(COMPONENT) do
		local rawNumber: string?, rawUnit: string? = component:match(COMPONENT_PARTS)
		if rawNumber == nil or rawUnit == nil then
			continue
		end

		local amount: number = tonumber(rawNumber) :: number -- The pattern holds only digits
		local units: { string } = findUnits(rawUnit, nil, FROM_START)
		lastNumber = amount

		if #units == 0 then
			return nil, lastNumber, nil
		end

		local unitSeconds: number = rawUnit:lower() == MINUTES_ALONE and UNIT_SECONDS.Minutes or UNIT_SECONDS[units[1]]
		seconds += unitSeconds * amount
	end

	if seconds <= 0 then
		return nil, nil, nil
	end

	return seconds, lastNumber, nil
end

--[[
    Completes each unit's name onto the typed text from the name's start'th
    letter, a count of one dropping the name's plural s
--]]

local function completeUnits(units: { string }, rawText: string, lastNumber: number?, start: number): { string }
	return Util.map(units, function (unit: string): string
		local ending: string = lastNumber == 1 and unit:sub(start, #unit - 1) or unit:sub(start)

		return `{rawText}{ending}`
	end)
end

local Definitions: { [string]: TypeDefinition } = {
	duration = {
		-- The text, then what readSeconds gives, which every later step takes
		transform = function (text: string): (string, number?, number?, boolean?)
			return text, readSeconds(text)
		end,

		validate = function (_: string, seconds: number?): (boolean, string?)
			return seconds ~= nil, REFUSAL
		end,

		autocomplete = function (
			rawText: string,
			seconds: number?,
			lastNumber: number?,
			missingUnit: boolean?
		): { string }
			if missingUnit then
				return completeUnits(findUnits(EVERY_UNIT, nil, FROM_START), rawText, lastNumber, 1)
			end

			if seconds == nil then
				return {}
			end

			-- A stray last word, as in 1h foo, leaves no unit being typed
			local endingUnit: string? = rawText:match(ENDING_UNIT)
			if not endingUnit then
				return {}
			end

			local units: { string } = findUnits(endingUnit, nil, FROM_START)
			local completions: { string } = completeUnits(units, rawText, lastNumber, #endingUnit + 1)
			table.sort(completions)

			return completions
		end,

		parse = function (_: string, seconds: number): number
			return seconds
		end,
	},
}

Definitions.durations = Util.makeListableType(Definitions.duration)

return Definitions
