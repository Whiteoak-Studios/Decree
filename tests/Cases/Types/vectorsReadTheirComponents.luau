--[[
    The vector3 and vector2 types read three and two numbers, split at
    commas or else at spaces with empty pieces skipped, and parse them to a
    vector, refusing a missing or extra number with where it sits
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Vectors"

-- Each vector type, its listable, the texts it reads with their vectors, and the texts it refuses
local VECTORS: { Vector } = {
	{
		name = "vector3",
		listable = "vector3s",
		reads = {
			{ text = "1,2,3", value = roblox.Vector3.new(1, 2, 3) },
			{ text = "1 2 3", value = roblox.Vector3.new(1, 2, 3) },
			{ text = "-1.5, 0, 2e1", value = roblox.Vector3.new(-1.5, 0, 20) },
		},
		refused = {
			{ text = "1,2", reason = "Invalid or missing number at position 3 in Vector type." },
			{ text = "1,,3", reason = "Invalid or missing number at position 3 in Vector type." },
			{ text = "1,x,3", reason = "Invalid or missing number at position 2 in Vector type." },
			{ text = "1,2,3,4", reason = "Maximum of 3 values allowed in sequence" },
		},
	},
	{
		name = "vector2",
		listable = "vector2s",
		reads = {
			{ text = "4,5", value = roblox.Vector2.new(4, 5) },
			{ text = "4 5", value = roblox.Vector2.new(4, 5) },
		},
		refused = {
			{ text = "4", reason = "Invalid or missing number at position 2 in Vector type." },
			{ text = "4,5,6", reason = "Maximum of 2 values allowed in sequence" },
		},
	},
}

type Read = {
	text: string,
	value: any,
}

type Refusal = {
	text: string,
	reason: string,
}

type Vector = {
	name: string,
	listable: string,
	reads: { Read },
	refused: { Refusal },
}

return function (): (boolean, string | nil)
	local types: any = Environment.new().require(TYPES)

	for _, vector: Vector in VECTORS do
		local definition: any = types[vector.name]
		local listable: any = types[vector.listable]

		if definition.prefixes ~= nil or listable.prefixes ~= nil then
			return false, `{vector.name} or {vector.listable} carries a prefix`
		end

		for _, read: Read in vector.reads do
			local components: { number } = definition.transform(read.text)
			local valid: boolean = definition.validate(components)
			local listed: { any } = listable.parse(components)
			if not valid or definition.parse(components) ~= read.value then
				return false, `{vector.name} did not read {read.text} as its vector`
			end

			if listable.listable ~= true or #listed ~= 1 or listed[1] ~= read.value then
				return false, `{vector.listable} did not parse {read.text} to a list of the one vector`
			end
		end

		for _, refusal: Refusal in vector.refused do
			local components: { number } = definition.transform(refusal.text)
			local valid: boolean, reason: string? = definition.validate(components)
			if valid or reason ~= refusal.reason then
				return false, `{vector.name} accepted "{refusal.text}", or refused it with {reason}`
			end
		end
	end

	return true, nil
end
