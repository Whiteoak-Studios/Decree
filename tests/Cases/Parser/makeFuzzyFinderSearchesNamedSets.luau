--[[
    Util's makeFuzzyFinder searches an Instance's children, a list of
    Instances, named tables or an Enum's items by Name and gives the values
    themselves, finds nothing in an empty set and refuses any other set
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")

local UTIL: string = "src/DecreeClient/Shared/Util"
local RED: string = "Red"
local BLUE: string = "Blue"
local REDWOOD: string = "Redwood"
local INSIDE_BLUE: string = "lu" -- Inside BLUE's name, at neither end
local KEY: string = "F2" -- An item's Name in Enum.KeyCode
local NOT_A_SET: string = "[Decree] makeFuzzyFinder only accepts a table, Enum, or Instance."
local UNNAMED: string = "[Decree] makeFuzzyFinder only accepts tables of instances or strings."

-- Each set makeFuzzyFinder refuses, and its refusal
local REFUSED: { Refused } = {
	{ set = 5, reason = NOT_A_SET },
	{ set = RED, reason = NOT_A_SET },
	{ set = { 1, 2 }, reason = UNNAMED },
	{ set = { { Id = 1 } }, reason = UNNAMED },
}

type Refused = {
	set: any,
	reason: string,
}

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	local container: any = roblox.Instance.new("Folder")
	local children: { [string]: any } = {}

	for _, name: string in { RED, BLUE, REDWOOD } do
		local child: any = roblox.Instance.new("Folder")
		child.Name = name
		child.Parent = container
		children[name] = child
	end

	local inContainer: { any } = util.makeFuzzyFinder(container)(RED:lower())
	if not Listed(inContainer, { children[RED], children[REDWOOD] }) then
		return false, `the container's children matched {#inContainer} Instances`
	end

	local listed: any = util.makeFuzzyFinder({ children[BLUE], children[RED] })(BLUE, true)
	if listed ~= children[BLUE] then
		return false, `a list of Instances matched {listed} first`
	end

	local blue: { Name: string } = { Name = BLUE }
	local named: { any } = util.makeFuzzyFinder({ { Name = RED }, blue })(INSIDE_BLUE)
	if not Listed(named, { blue }) then
		return false, `named tables matched {#named} tables`
	end

	local item: any = util.makeFuzzyFinder(roblox.Enum.KeyCode)(KEY, true)
	if item ~= roblox.Enum.KeyCode[KEY] then
		return false, `Enum.KeyCode matched {item}`
	end

	local empty: any = util.makeFuzzyFinder({})
	if #empty(RED) ~= 0 or empty(RED, true) ~= nil then
		return false, "an empty set matched something"
	end

	-- The error ends with the refusal, after the chunk and line the loader names
	for _, refused: Refused in REFUSED do
		local made: boolean, reason: any = pcall(util.makeFuzzyFinder, refused.set)
		if made or tostring(reason):sub(-#refused.reason) ~= refused.reason then
			return false, `makeFuzzyFinder answered {reason} for a set it refuses`
		end
	end

	return true, nil
end
