--[[
    The color3 type reads three whole numbers from 0 to 255, split at commas
    or else at spaces, and parses them to a Color3, refusing a missing,
    extra, fractional or out-of-range number with where it sits
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Colors"
local TYPE: string = "color3"
local LISTABLE: string = "color3s"
local PREFIXES: string = "# hexColor3 ! brickColor3" -- Hex digits after #, a brick color's name after !
local LISTABLE_PREFIXES: string = "# hexColor3s ! brickColor3s"
local TEXTS: { string } = { "255,0,128", "255 0 128", "255, 0, 128" }
local RED: number = 255
local GREEN: number = 0
local BLUE: number = 128

-- Each text the type refuses, and its refusal
local REFUSED: { Refusal } = {
	{ text = "255,0", reason = "Invalid or missing number at position 3 in Color3 type." },
	{ text = "1,a,3", reason = "Invalid or missing number at position 2 in Color3 type." },
	{ text = "", reason = "Invalid or missing number at position 1 in Color3 type." },
	{ text = "256,0,0", reason = "Number out of acceptable range 0-255 at position 1 in Color3 type." },
	{ text = "0,-1,0", reason = "Number out of acceptable range 0-255 at position 2 in Color3 type." },
	{ text = "0,0,1.5", reason = "Number is not an integer at position 3 in Color3 type." },
	{ text = "1,2,3,4", reason = "Maximum of 3 values allowed in sequence" },
}

type Refusal = {
	text: string,
	reason: string,
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]
	local expected: any = roblox.Color3.fromRGB(RED, GREEN, BLUE)

	if definition.prefixes ~= PREFIXES or listable.prefixes ~= LISTABLE_PREFIXES then
		return false, "color3 or color3s lacks its hex and brick color prefixes"
	end

	for _, text: string in TEXTS do
		local components: { number } = definition.transform(text)
		local valid: boolean = definition.validate(components)
		if not valid or #components ~= 3 or definition.parse(components) ~= expected then
			return false, `color3 did not read {text} as the color`
		end
	end

	for _, refusal: Refusal in REFUSED do
		local components: { number } = definition.transform(refusal.text)
		local valid: boolean, reason: string? = definition.validate(components)
		if valid or reason ~= refusal.reason then
			return false, `color3 accepted "{refusal.text}", or refused it with {reason}`
		end
	end

	local listedComponents: { number } = listable.transform(TEXTS[1])
	local listed: { any } = listable.parse(listedComponents)
	if listable.listable ~= true or #listed ~= 1 or listed[1] ~= expected then
		return false, "color3s did not parse to a list of the one color"
	end

	return true, nil
end
