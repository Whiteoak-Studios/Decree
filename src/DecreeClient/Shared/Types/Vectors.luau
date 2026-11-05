--[[
    The vector argument types: vector3, vector2 and positionVector3, which
    reads offsets from the executor's character, each with its listable
--]]

--!strict
local Util = require("../Util")

local RELATIVE: string = "~" -- Marks a position's component as read from the character's
local DELIMITERS: { string } = { ",", "%s" } -- A position splits at commas, or else at whitespace
local ORIGIN: number = 0 -- What a ~ past the third component reads from

local Types = require("../Config/Types/Command")

type TypeDefinition = Types.TypeDefinition

--[[
    Refuses a component that is missing or reads as no number, naming where
    it sits
--]]

local function validateComponent(value: number?, index: number): (boolean, string?)
	if value == nil then
		return false, `Invalid or missing number at position {index} in Vector type.`
	end

	return true, nil
end

--[[
    Reads one component of a position: a number as typed, or after a ~ an
    offset from the character's own component, a lone ~ being that component
--]]

local function readComponent(text: string, current: number): number?
	if text:sub(1, 1) ~= RELATIVE then
		return tonumber(text)
	end

	if text == RELATIVE then
		return current
	end

	local offset: number? = tonumber(text:sub(2))

	return offset and current + offset
end

--[[
    Reads a component's text as a number
--]]

local function readNumber(text: string): number?
	return tonumber(text)
end

--[[
    Builds a Vector3 from its components
--]]

local function newVector3(...: any): Vector3
	return Vector3.new(...)
end

--[[
    Builds a Vector2 from its components
--]]

local function newVector2(...: any): Vector2
	return Vector2.new(...)
end

local Definitions: { [string]: TypeDefinition } = {
	vector3 = Util.makeSequenceType({
		transformEach = readNumber,
		validateEach = validateComponent,
		constructor = newVector3,
		length = 3,
	}),

	vector2 = Util.makeSequenceType({
		transformEach = readNumber,
		validateEach = validateComponent,
		constructor = newVector2,
		length = 2,
	}),

	positionVector3 = Util.makeSequenceType({
		-- The character is read through its pivot, from the origin while the executor has none
		transform = function (text: string, executor: Player): { number? }
			local character: Model? = executor.Character
			local pivot: Vector3 = character and character:GetPivot().Position or Vector3.zero
			local axes: { number } = { pivot.X, pivot.Y, pivot.Z }
			local components: { string } = Util.splitPrioritizedDelimiter(text, DELIMITERS) or {}

			return Util.map(components, function (component: string, index: number): number?
				return readComponent(component, axes[index] or ORIGIN)
			end)
		end,

		validateEach = validateComponent,
		constructor = newVector3,
		length = 3,
	}),
}

Definitions.vector3s = Util.makeListableType(Definitions.vector3)
Definitions.vector2s = Util.makeListableType(Definitions.vector2)
Definitions.positionVector3s = Util.makeListableType(Definitions.positionVector3)

return Definitions
