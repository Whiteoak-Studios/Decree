--[[
    An argument shows its type's displayName, or else the name the type it
    picked registered under, so playerIds reads as its own name while
    playerId keeps its Full Player Name
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Server = require("../../Fixtures/Core/Server")

local COMMAND: string = "find" -- Each row's command is this name and the row's position
local PLAYER: string = "Player" -- The Name of the environment's own player
local FRUIT: string = "fruit"
local PRODUCE: string = "produce" -- A second name for FRUIT's definition
local VEGGIE: string = "veggie"
local VEGETABLE: string = "Vegetable" -- VEGGIE's displayName

-- Each argument type, the value typed for it, and the name its argument shows
local SHOWN: { Shown } = {
	{ type = "playerIds", value = PLAYER, name = "playerIds" },
	{ type = "playerId", value = PLAYER, name = "Full Player Name" },
	{ type = "playerId", value = "#5", name = "positiveInteger" }, -- The type its prefix picks
	{ type = "string", value = "hello", name = "string" },
	{ type = FRUIT, value = "apple", name = FRUIT },
	{ type = PRODUCE, value = "apple", name = PRODUCE },
	{ type = VEGGIE, value = "kale", name = VEGETABLE },
}

type Shown = {
	type: string,
	value: string,
	name: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()

	local function parse(text: string): string
		return text
	end

	local fruit: { [string]: any } = { parse = parse }
	core.registry:registerType(FRUIT, fruit)
	core.registry:registerType(PRODUCE, fruit)
	core.registry:registerType(VEGGIE, { parse = parse, displayName = VEGETABLE })

	for index: number, shown: Shown in SHOWN do
		local name: string = `{COMMAND}{index}`
		core.registry:registerCommandObject({ name = name, args = { { name = "value", type = shown.type } } })

		local argument: any, reason: string? = Evaluate(core.dispatcher, core.env.player, `{name} {shown.value}`, 1)
		if not argument then
			return false, reason
		end

		if argument.displayName ~= shown.name then
			return false, `a {shown.type} argument typed {shown.value} shows {argument.displayName}`
		end
	end

	return true, nil
end
