--[[
    The positionVector3 type reads three numbers, a ~ standing for that axis
    of the executor's character's pivot and ~N for an offset from it, or
    from the origin while the executor has no character
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Vectors"
local TYPE: string = "positionVector3"
local LISTABLE: string = "positionVector3s"
local PIVOT: any = roblox.Vector3.new(10, 20, 30) -- Where the case's character stands

-- Each text the type reads, with no character and then with one at PIVOT
local READS: { Read } = {
	{ text = "~,~5,~-2", alone = roblox.Vector3.new(0, 5, -2), beside = roblox.Vector3.new(10, 25, 28) },
	{ text = "1,~,3", alone = roblox.Vector3.new(1, 0, 3), beside = roblox.Vector3.new(1, 20, 3) },
	{ text = "~ ~ ~", alone = roblox.Vector3.zero, beside = PIVOT },
	{ text = "4,5,6", alone = roblox.Vector3.new(4, 5, 6), beside = roblox.Vector3.new(4, 5, 6) },
}

-- Each text the type refuses, and its refusal
local REFUSED: { Refusal } = {
	{ text = "~a,0,0", reason = "Invalid or missing number at position 1 in Vector type." },
	{ text = "1,2", reason = "Invalid or missing number at position 3 in Vector type." },
	{ text = "~,~,~,~", reason = "Maximum of 3 values allowed in sequence" },
}

type Read = {
	text: string,
	alone: any,
	beside: any,
}

type Refusal = {
	text: string,
	reason: string,
}

return function (): (boolean, string | nil)
	local env: any = Environment.new()
	local types: any = env.require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	for _, read: Read in READS do
		local components: { number } = definition.transform(read.text, env.player)
		local valid: boolean = definition.validate(components)
		if not valid or definition.parse(components) ~= read.alone then
			return false, `positionVector3 did not read {read.text} from the origin`
		end
	end

	-- The type reads a character only through GetPivot, which Lune's Model lacks, so a table stands in for one
	env.player.Character = {
		GetPivot = function (_: any): any
			return roblox.CFrame.new(PIVOT)
		end,
	}

	for _, read: Read in READS do
		local components: { number } = definition.transform(read.text, env.player)
		local valid: boolean = definition.validate(components)
		local listed: { any } = listable.parse(components)
		if not valid or definition.parse(components) ~= read.beside then
			return false, `positionVector3 did not read {read.text} from the character`
		end

		if listable.listable ~= true or #listed ~= 1 or listed[1] ~= read.beside then
			return false, `positionVector3s did not parse {read.text} to a list of the one vector`
		end
	end

	for _, refusal: Refusal in REFUSED do
		local components: { number } = definition.transform(refusal.text, env.player)
		local valid: boolean, reason: string? = definition.validate(components)
		if valid or reason ~= refusal.reason then
			return false, `positionVector3 accepted "{refusal.text}", or refused it with {reason}`
		end
	end

	return true, nil
end
