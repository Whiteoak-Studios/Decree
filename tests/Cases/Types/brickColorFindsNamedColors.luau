--[[
    The brick color types find colors by part of their name in any case and
    parse to the first or its Color3, and list each name once, so Lilac,
    Gold, Rust and Deep orange each complete to themselves once
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Colors"
local BRICK_COLOR: string = "brickColor"
local BRICK_COLORS: string = "brickColors"
local BRICK_COLOR3: string = "brickColor3"
local BRICK_COLOR3S: string = "brickColor3s"
local PREFIXES: string = "% teamColor" -- brickColor's prefix, which reads a team's color
local LISTABLE_PREFIXES: string = "% teamColors"
local NAME: string = "Really red"
local TYPED: string = "really RED" -- NAME typed in another case
local NONE: string = "Not a color"
local REFUSAL: string = "No valid brick colors with that name could be found."
local EVERYTHING: string = "" -- A text every name holds
local NAMES: number = 204 -- Every name the types list
local DISTINCT: number = 204
local REPEATED: { string } = { "Lilac", "Gold", "Rust", "Deep orange" }
local REPEATS: number = 1 -- How many times the text of each of those names completes to it
local LILAC: string = "Lilac"
local SEPARATOR: string = "|" -- Joins a list of suggestions into one string to compare

-- Everything the Lilac text completes to: the exact name, then by where lilac starts in each
local LILAC_SUGGESTIONS: { string } = {
	"Lilac",
	"Light lilac",
	"Medium lilac",
	"Reddish lilac",
	"Bright reddish lilac",
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local brickColor: any = types[BRICK_COLOR]
	local brickColor3: any = types[BRICK_COLOR3]
	local brickColors: any = types[BRICK_COLORS]
	local brickColor3s: any = types[BRICK_COLOR3S]
	local expected: any = roblox.BrickColor.new(NAME)

	if brickColor.prefixes ~= PREFIXES or brickColors.prefixes ~= LISTABLE_PREFIXES then
		return false, "brickColor or brickColors lacks its team prefix"
	end

	if brickColor3.prefixes ~= nil or brickColor3s.prefixes ~= nil then
		return false, "brickColor3 or brickColor3s carries a prefix"
	end

	local found: { any } = brickColor.transform(TYPED)
	local valid: boolean = brickColor.validate(found)
	if not valid or found[1].Name ~= NAME or brickColor.parse(found).Name ~= NAME then
		return false, `brickColor did not find {NAME} first for {TYPED}`
	end

	local colorFound: { any } = brickColor3.transform(TYPED)
	if brickColor3.parse(colorFound) ~= expected.Color then
		return false, `brickColor3 did not parse {TYPED} to {NAME}'s Color3`
	end

	for _, definition: any in { brickColor, brickColor3 } do
		local none: { any } = definition.transform(NONE)
		local noneValid: boolean, reason: string? = definition.validate(none)
		if #none ~= 0 or noneValid or reason ~= REFUSAL then
			return false, `a brick color type found {NONE}, or refused it with {reason}`
		end
	end

	local lilacFound: { any } = brickColor.transform(LILAC)
	local lilac: { string } = brickColor.autocomplete(lilacFound)
	if table.concat(lilac, SEPARATOR) ~= table.concat(LILAC_SUGGESTIONS, SEPARATOR) then
		return false, `brickColor completed {LILAC} as {table.concat(lilac, ", ")}`
	end

	for _, name: string in REPEATED do
		local repeatedFound: { any } = brickColor3.transform(name)
		local suggestions: { string } = brickColor3.autocomplete(repeatedFound)
		local count: number = 0

		for _, suggestion: string in suggestions do
			if suggestion == name then
				count += 1
			end
		end

		if count ~= REPEATS then
			return false, `{name} completed to itself {count} times`
		end
	end

	local everythingFound: { any } = brickColor.transform(EVERYTHING)
	local everything: { string } = brickColor.autocomplete(everythingFound)
	local distinct: { [string]: boolean } = {}
	local distinctCount: number = 0

	for _, name: string in everything do
		if not distinct[name] then
			distinct[name] = true
			distinctCount += 1
		end
	end

	if #everything ~= NAMES or distinctCount ~= DISTINCT then
		return false, `the brick color types list {#everything} names, {distinctCount} of them distinct`
	end

	local listed: { any } = brickColors.parse(found)
	local listedColors: { any } = brickColor3s.parse(colorFound)
	if brickColors.listable ~= true or #listed ~= 1 or listed[1].Name ~= NAME then
		return false, "brickColors did not parse to a list of the first color found"
	end

	if brickColor3s.listable ~= true or #listedColors ~= 1 or listedColors[1] ~= expected.Color then
		return false, "brickColor3s did not parse to a list of the first color's Color3"
	end

	return true, nil
end
