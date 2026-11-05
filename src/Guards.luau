--[[
    The five guard factories a game builds a command's guards from, each
    making a Guard that refuses a line by its executor or one argument
--]]

--!strict
local ROOT_PART: string = "HumanoidRootPart" -- What a character stands on, which hasCharacter looks for
local BLANK: string = "^%s*$"
local NO_CHARACTER: string = "You don't have a character."
local TARGET_NO_CHARACTER: string = "Target player has no character."
local TARGETS_NO_CHARACTER: string = "One or more target players don't have a character."

local Types = require("./DecreeClient/Shared/Config/Types/Command")

type Context = Types.Context
type Guard = Types.Guard

--- @class Guards
--- The guard factories, called with a dot, each making a Guard for a
--- command's guards list. Guards run on the server only, after the
--- beforeRun hooks

local Guards = {}

--[[
    The value the argument at a position holds, or nil when it was not typed
--]]

local function valueOf(context: Context, index: number): any
	local argument = context:getArgument(index)

	return argument and argument:getValue()
end

--[[
    Whether a player's character is in the world, holding its root part
--]]

local function hasRootPart(player: Player): boolean
	local character: Model? = player.Character

	return character ~= nil and character:FindFirstChild(ROOT_PART) ~= nil
end

--- Makes a guard that refuses unless every player it checks has a
--- character with a HumanoidRootPart: the executor, or the player or the
--- list of players an argument holds. Any other value passes.
--- @function hasCharacter
--- @within Guards
--- @param index number? -- The argument holding the players, the executor when left out
--- @return Guard

function Guards.hasCharacter(index: number?): Guard
	return function (context: Context): string?
		local target: any = context.executor
		if index then
			target = valueOf(context, index)
		end

		local first: any = nil
		if typeof(target) == "table" then
			first = (target :: any)[1]
		end

		local single: boolean = typeof(target) == "Instance" and (target :: Instance):IsA("Player")
		local list: boolean = typeof(first) == "Instance" and (first :: Instance):IsA("Player")
		if not single and not list then
			return nil
		end

		local players: { Player } = single and { target } or target

		for _, player: Player in players do
			if hasRootPart(player) then
				continue
			end

			if single then
				return index and TARGET_NO_CHARACTER or NO_CHARACTER
			end

			return #players == 1 and TARGET_NO_CHARACTER or TARGETS_NO_CHARACTER
		end

		return nil
	end
end

--- Makes a guard that refuses a list argument holding more than a number
--- of values.
--- @function maxArrayLength
--- @within Guards
--- @param index number -- The list argument
--- @param maxCount number -- The most values it may hold
--- @return Guard

function Guards.maxArrayLength(index: number, maxCount: number): Guard
	return function (context: Context): string?
		local value: any = valueOf(context, index)
		if typeof(value) == "table" and #value > maxCount then
			return `Argument #{index} exceeds the maximum allowed limit of {maxCount} items.`
		end

		return nil
	end
end

--- Makes a guard that refuses a text argument longer than a number of
--- characters.
--- @function maxStringLength
--- @within Guards
--- @param index number -- The text argument
--- @param maxLength number -- The most bytes it may hold
--- @return Guard

function Guards.maxStringLength(index: number, maxLength: number): Guard
	return function (context: Context): string?
		local value: any = valueOf(context, index)
		if typeof(value) == "string" and #value > maxLength then
			return `Argument #{index} exceeds the maximum character limit of {maxLength}`
		end

		return nil
	end
end

--- Makes a guard that refuses an argument unless it is text holding more
--- than whitespace.
--- @function nonEmptyString
--- @within Guards
--- @param index number -- The text argument
--- @return Guard

function Guards.nonEmptyString(index: number): Guard
	return function (context: Context): string?
		local value: any = valueOf(context, index)
		if typeof(value) ~= "string" or (value :: string):match(BLANK) then
			return `Argument #{index} cannot be empty or blank.`
		end

		return nil
	end
end

--- Makes a guard that refuses an argument whose value is one forbidden
--- value.
--- @function notEquals
--- @within Guards
--- @param index number -- The argument
--- @param forbiddenValue any -- The value it may not hold
--- @return Guard

function Guards.notEquals(index: number, forbiddenValue: any): Guard
	return function (context: Context): string?
		if valueOf(context, index) == forbiddenValue then
			return `Argument #{index} cannot be "{forbiddenValue}".`
		end

		return nil
	end
end

return Guards
