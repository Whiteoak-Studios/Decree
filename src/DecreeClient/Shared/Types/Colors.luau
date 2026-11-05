--[[
    The color argument types: brickColor and brickColor3, which find brick
    colors by name, and color3 and hexColor3, which read a Color3's red,
    green and blue, each with its listable
--]]

--!strict
local Util = require("../Util")

local CHANNELS: number = 3 -- A Color3's red, green and blue
local CHANNEL_MAX: number = 255
local HEX: number = 16
local HEX_COLOR: string = "^#?(%x%x?)(%x%x?)(%x%x?)$" -- Three channels of one or two hex digits, after an optional #
local NO_BRICK_COLOR: string = "No valid brick colors with that name could be found."

-- Every brick color's name, each once
local BRICK_COLOR_NAMES: { string } = {
	"White",
	"Grey",
	"Light yellow",
	"Brick yellow",
	"Light green (Mint)",
	"Light reddish violet",
	"Pastel Blue",
	"Light orange brown",
	"Nougat",
	"Bright red",
	"Med. reddish violet",
	"Bright blue",
	"Bright yellow",
	"Earth orange",
	"Black",
	"Dark grey",
	"Dark green",
	"Medium green",
	"Lig. Yellowich orange",
	"Bright green",
	"Dark orange",
	"Light bluish violet",
	"Transparent",
	"Tr. Red",
	"Tr. Lg blue",
	"Tr. Blue",
	"Tr. Yellow",
	"Light blue",
	"Tr. Flu. Reddish orange",
	"Tr. Green",
	"Tr. Flu. Green",
	"Phosph. White",
	"Light red",
	"Medium red",
	"Medium blue",
	"Light grey",
	"Bright violet",
	"Br. yellowish orange",
	"Bright orange",
	"Bright bluish green",
	"Earth yellow",
	"Bright bluish violet",
	"Tr. Brown",
	"Medium bluish violet",
	"Tr. Medi. reddish violet",
	"Med. yellowish green",
	"Med. bluish green",
	"Light bluish green",
	"Br. yellowish green",
	"Lig. yellowish green",
	"Med. yellowish orange",
	"Br. reddish orange",
	"Bright reddish violet",
	"Light orange",
	"Tr. Bright bluish violet",
	"Gold",
	"Dark nougat",
	"Silver",
	"Neon orange",
	"Neon green",
	"Sand blue",
	"Sand violet",
	"Medium orange",
	"Sand yellow",
	"Earth blue",
	"Earth green",
	"Tr. Flu. Blue",
	"Sand blue metallic",
	"Sand violet metallic",
	"Sand yellow metallic",
	"Dark grey metallic",
	"Black metallic",
	"Light grey metallic",
	"Sand green",
	"Sand red",
	"Dark red",
	"Tr. Flu. Yellow",
	"Tr. Flu. Red",
	"Gun metallic",
	"Red flip/flop",
	"Yellow flip/flop",
	"Silver flip/flop",
	"Curry",
	"Fire Yellow",
	"Flame yellowish orange",
	"Reddish brown",
	"Flame reddish orange",
	"Medium stone grey",
	"Royal blue",
	"Dark Royal blue",
	"Bright reddish lilac",
	"Dark stone grey",
	"Lemon metalic",
	"Light stone grey",
	"Dark Curry",
	"Faded green",
	"Turquoise",
	"Light Royal blue",
	"Medium Royal blue",
	"Rust",
	"Brown",
	"Reddish lilac",
	"Lilac",
	"Light lilac",
	"Bright purple",
	"Light purple",
	"Light pink",
	"Light brick yellow",
	"Warm yellowish orange",
	"Cool yellow",
	"Dove blue",
	"Medium lilac",
	"Slime green",
	"Smoky grey",
	"Dark blue",
	"Parsley green",
	"Steel blue",
	"Storm blue",
	"Lapis",
	"Dark indigo",
	"Sea green",
	"Shamrock",
	"Fossil",
	"Mulberry",
	"Forest green",
	"Cadet blue",
	"Electric blue",
	"Eggplant",
	"Moss",
	"Artichoke",
	"Sage green",
	"Ghost grey",
	"Plum",
	"Olivine",
	"Laurel green",
	"Quill grey",
	"Crimson",
	"Mint",
	"Baby blue",
	"Carnation pink",
	"Persimmon",
	"Maroon",
	"Daisy orange",
	"Pearl",
	"Fog",
	"Salmon",
	"Terra Cotta",
	"Cocoa",
	"Wheat",
	"Buttermilk",
	"Mauve",
	"Sunrise",
	"Tawny",
	"Cashmere",
	"Khaki",
	"Lily white",
	"Seashell",
	"Burgundy",
	"Cork",
	"Burlap",
	"Beige",
	"Oyster",
	"Pine Cone",
	"Fawn brown",
	"Hurricane grey",
	"Cloudy grey",
	"Linen",
	"Copper",
	"Dirt brown",
	"Bronze",
	"Flint",
	"Dark taupe",
	"Burnt Sienna",
	"Institutional white",
	"Mid gray",
	"Really black",
	"Really red",
	"Deep orange",
	"Alder",
	"Dusty Rose",
	"Olive",
	"New Yeller",
	"Really blue",
	"Navy blue",
	"Deep blue",
	"Cyan",
	"CGA brown",
	"Magenta",
	"Pink",
	"Teal",
	"Toothpaste",
	"Lime green",
	"Camo",
	"Grime",
	"Lavender",
	"Pastel light blue",
	"Pastel orange",
	"Pastel violet",
	"Pastel blue-green",
	"Pastel green",
	"Pastel yellow",
	"Pastel brown",
	"Royal purple",
	"Hot pink",
}

local Types = require("../Config/Types/Command")

type TypeDefinition = Types.TypeDefinition

local findBrickColorNames: (text: string, returnFirst: boolean?, matchStart: boolean?) -> any =
	Util.makeFuzzyFinder(BRICK_COLOR_NAMES)

--[[
    Every brick color whose name holds the text, ranked as makeFuzzyFinder
    ranks the names
--]]

local function findBrickColors(text: string): { BrickColor }
	return Util.map(findBrickColorNames(text), function (name: string): BrickColor
		return (BrickColor.new :: any)(name) -- The engine's types take only literal names, and a listed name is a string
	end)
end

--[[
    Refuses a text that found no brick color
--]]

local function validateBrickColors(brickColors: { BrickColor }): (boolean, string?)
	return #brickColors > 0, NO_BRICK_COLOR
end

--[[
    Refuses a Color3 channel that is missing, out of range or fractional,
    naming where it sits
--]]

local function validateChannel(value: number?, index: number): (boolean, string?)
	if value == nil then
		return false, `Invalid or missing number at position {index} in Color3 type.`
	elseif value < 0 or value > CHANNEL_MAX then
		return false, `Number out of acceptable range 0-{CHANNEL_MAX} at position {index} in Color3 type.`
	elseif value % 1 ~= 0 then
		return false, `Number is not an integer at position {index} in Color3 type.`
	end

	return true, nil
end

--[[
    Reads one channel's hex digits, a single digit standing for itself
    twice, as f stands for ff
--]]

local function readHex(digits: string?): number?
	if not digits then
		return nil
	end

	local pair: string = #digits == 1 and digits:rep(2) or digits

	return tonumber(pair, HEX)
end

--[[
    Reads a channel's text as a number
--]]

local function readNumber(text: string): number?
	return tonumber(text)
end

local Definitions: { [string]: TypeDefinition } = {
	brickColor = {
		prefixes = "% teamColor",
		transform = findBrickColors,
		validate = validateBrickColors,
		autocomplete = Util.getNames,

		parse = function (brickColors: { BrickColor }): BrickColor
			return brickColors[1]
		end,
	},

	brickColor3 = {
		transform = findBrickColors,
		validate = validateBrickColors,
		autocomplete = Util.getNames,

		parse = function (brickColors: { BrickColor }): Color3
			return brickColors[1].Color
		end,
	},

	color3 = Util.makeSequenceType({
		prefixes = "# hexColor3 ! brickColor3",
		transformEach = readNumber,
		validateEach = validateChannel,

		constructor = function (...: any): Color3
			return Color3.fromRGB(...)
		end,

		length = CHANNELS,
	}),

	hexColor3 = {
		-- The red, green and blue, which validate and parse each take
		transform = function (text: string): (number?, number?, number?)
			local red: string?, green: string?, blue: string? = text:match(HEX_COLOR)

			return readHex(red), readHex(green), readHex(blue)
		end,

		validate = function (red: number?, green: number?, blue: number?): (boolean, string?)
			return red ~= nil and green ~= nil and blue ~= nil, "Invalid hex color"
		end,

		parse = function (red: number, green: number, blue: number): Color3
			return Color3.fromRGB(red, green, blue)
		end,
	},
}

Definitions.brickColors = Util.makeListableType(Definitions.brickColor, { prefixes = "% teamColors" })
Definitions.brickColor3s = Util.makeListableType(Definitions.brickColor3)
Definitions.color3s = Util.makeListableType(Definitions.color3, { prefixes = "# hexColor3s ! brickColor3s" })
Definitions.hexColor3s = Util.makeListableType(Definitions.hexColor3)

return Definitions
