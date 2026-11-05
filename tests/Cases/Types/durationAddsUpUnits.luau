--[[
    The duration type adds each number and unit up to seconds, m alone being
    minutes and a negative sum kept, refuses a number left without a unit, a
    fraction or a zero sum, and completes the unit being typed
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Duration"
local TYPE: string = "duration"
local LISTABLE: string = "durations"
local REFUSED: { string } = { "", "1", "5x", "0s", "1d6", "1.5h", "abc" }
local REFUSAL: string = "Invalid duration format. Example: 1d6h, 30m, 10s."
local LISTED: string = "30m"
local LISTED_SECONDS: number = 1800
local SEPARATOR: string = "|" -- Joins a list of suggestions into one string to compare

-- Each text the type reads, and its seconds
local READS: { Read } = {
	{ text = "0", seconds = 0 },
	{ text = "10s", seconds = 10 },
	{ text = "30m", seconds = 1800 },
	{ text = "2M", seconds = 120 },
	{ text = "1h", seconds = 3600 },
	{ text = "1d6h", seconds = 108000 },
	{ text = "1d 6h", seconds = 108000 },
	{ text = "2w", seconds = 1209600 },
	{ text = "1mo", seconds = 2629744 },
	{ text = "1y2mo", seconds = 36816414 },
	{ text = "-5s", seconds = -5 },
}

-- Each text whose last unit is being typed, and what it completes to, in sorted order
local COMPLETIONS: { Completion } = {
	{ text = "1h", suggestions = { "1hour" } },
	{ text = "2m", suggestions = { "2minutes", "2months" } },
	{ text = "1m", suggestions = { "1minute", "1month" } },
	{ text = "2M", suggestions = { "2Minutes", "2Months" } },
	{ text = "1d6h", suggestions = { "1d6hours" } },
	{ text = "5x", suggestions = {} },
	{ text = "-5s", suggestions = { "-5seconds" } },
}

-- Each text ending in a number with no unit, and every unit it completes to, in any order and singular after 1
local UNITS: { Completion } = {
	{ text = "1", suggestions = { "1Day", "1Hour", "1Minute", "1Month", "1Second", "1Week", "1Year" } },
	{ text = "0", suggestions = { "0Days", "0Hours", "0Minutes", "0Months", "0Seconds", "0Weeks", "0Years" } },
	{
		text = "1d6",
		suggestions = { "1d6Days", "1d6Hours", "1d6Minutes", "1d6Months", "1d6Seconds", "1d6Weeks", "1d6Years" },
	},
}

type Read = {
	text: string,
	seconds: number,
}

type Completion = {
	text: string,
	suggestions: { string },
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	-- Transform keeps the text first, and every later step takes each value it returned
	for _, read: Read in READS do
		local values: { n: number, [number]: any } = table.pack(definition.transform(read.text))
		local valid: boolean = definition.validate(table.unpack(values, 1, values.n))
		local seconds: number = definition.parse(table.unpack(values, 1, values.n))
		if values[1] ~= read.text or values[2] ~= read.seconds or not valid or seconds ~= read.seconds then
			return false, `duration read {read.text} as {values[2]} seconds`
		end
	end

	for _, text: string in REFUSED do
		local values: { n: number, [number]: any } = table.pack(definition.transform(text))
		local valid: boolean, reason: string? = definition.validate(table.unpack(values, 1, values.n))
		if valid or reason ~= REFUSAL then
			return false, `duration accepted "{text}", or refused it with {reason}`
		end
	end

	for _, completion: Completion in COMPLETIONS do
		local values: { n: number, [number]: any } = table.pack(definition.transform(completion.text))
		local suggestions: { string } = definition.autocomplete(table.unpack(values, 1, values.n))
		if table.concat(suggestions, SEPARATOR) ~= table.concat(completion.suggestions, SEPARATOR) then
			return false, `duration completed {completion.text} as {table.concat(suggestions, ", ")}`
		end
	end

	for _, completion: Completion in UNITS do
		local values: { n: number, [number]: any } = table.pack(definition.transform(completion.text))
		local suggestions: { string } = definition.autocomplete(table.unpack(values, 1, values.n))
		local sorted: { string } = table.clone(suggestions)
		table.sort(sorted)

		if table.concat(sorted, SEPARATOR) ~= table.concat(completion.suggestions, SEPARATOR) then
			return false, `duration completed {completion.text} as {table.concat(suggestions, ", ")}`
		end
	end

	local listedValues: { n: number, [number]: any } = table.pack(listable.transform(LISTED))
	local listed: { number } = listable.parse(table.unpack(listedValues, 1, listedValues.n))
	if listable.listable ~= true or #listed ~= 1 or listed[1] ~= LISTED_SECONDS then
		return false, "durations did not parse to a list of the one duration"
	end

	return true, nil
end
