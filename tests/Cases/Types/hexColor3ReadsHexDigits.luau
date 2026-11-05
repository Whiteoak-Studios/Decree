--[[
    The hexColor3 type reads three hex pairs, a # before them optional and a
    single digit read doubled, as the red, green and blue of a Color3, and
    refuses any other text with its message
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Colors"
local TYPE: string = "hexColor3"
local LISTABLE: string = "hexColor3s"
local REFUSED: { string } = { "#gg0000", "#ff80001", "#ff", "" }
local REFUSAL: string = "Invalid hex color"

-- Each text the type reads, and the red, green and blue it reads
local READS: { Read } = {
	{ text = "#ff8000", red = 255, green = 128, blue = 0 },
	{ text = "FF8000", red = 255, green = 128, blue = 0 },
	{ text = "f80", red = 255, green = 136, blue = 0 },
	{ text = "#ff800", red = 255, green = 128, blue = 0 }, -- Five digits read as ff, 80 and a doubled 0
}

type Read = {
	text: string,
	red: number,
	green: number,
	blue: number,
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	if definition.prefixes ~= nil or listable.prefixes ~= nil then
		return false, "hexColor3 or hexColor3s carries a prefix"
	end

	for _, read: Read in READS do
		local values: { n: number, [number]: any } = table.pack(definition.transform(read.text))
		local valid: boolean = definition.validate(table.unpack(values, 1, values.n))
		local color: any = definition.parse(table.unpack(values, 1, values.n))
		local listed: { any } = listable.parse(table.unpack(values, 1, values.n))
		local expected: any = roblox.Color3.fromRGB(read.red, read.green, read.blue)

		if values[1] ~= read.red or values[2] ~= read.green or values[3] ~= read.blue then
			return false, `hexColor3 read {read.text} as {values[1]}, {values[2]} and {values[3]}`
		end

		if not valid or color ~= expected or listable.listable ~= true or #listed ~= 1 or listed[1] ~= expected then
			return false, `hexColor3 or hexColor3s did not parse {read.text} to its color`
		end
	end

	for _, text: string in REFUSED do
		local values: { n: number, [number]: any } = table.pack(definition.transform(text))
		local valid: boolean, reason: string? = definition.validate(table.unpack(values, 1, values.n))
		if valid or reason ~= REFUSAL then
			return false, `hexColor3 accepted "{text}", or refused it with {reason}`
		end
	end

	return true, nil
end
