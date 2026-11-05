--[[
    A prefixed type union picks an argument's type by the prefix its raw
    value starts with and strips that prefix off, while a type with no
    prefixes keeps the character, and an unknown team fails validation
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Names = require("../../Fixtures/Parser/Names")
local Server = require("../../Fixtures/Core/Server")

local KICK: string = "kick" -- Takes players, whose union adds % teamPlayers
local PAINT: string = "paint" -- Takes a color3, whose union adds # hexColor3 and ! brickColor3
local SAY: string = "say" -- Takes a string, which has no prefixes
local PLAYER: string = "Player" -- The Name of the environment's own player
local SECOND: string = "Second"
local RED: string = "Red"
local RED_BRICK: string = "Bright red"
local BLACK: string = "Black"
local HEX_RED: string = "ff0000"
local PURE_RED: any = roblox.Color3.fromRGB(255, 0, 0) -- The color HEX_RED names
local TEAM_LINE: string = `{KICK} %{RED}`
local HEX_LINE: string = `{PAINT} #{HEX_RED}`
local BRICK_LINE: string = `{PAINT} !{BLACK}`
local NO_TEAM: string = `{KICK} %Nobody`
local TEAM_NOT_FOUND: string = "No team with that name could be found."

-- Each typed line, the prefix its argument took, the raw value left after it and the type it picked
local UNIONS: { Union } = {
	{ line = TEAM_LINE, prefix = "%", rawValue = RED, typeName = "teamPlayers" },
	{ line = `{KICK} %`, prefix = "%", rawValue = "", typeName = "teamPlayers" },
	{ line = `{KICK} {PLAYER}`, prefix = "", rawValue = PLAYER, typeName = "players" },
	{ line = HEX_LINE, prefix = "#", rawValue = HEX_RED, typeName = "hexColor3" },
	{ line = BRICK_LINE, prefix = "!", rawValue = BLACK, typeName = "brickColor3" },
	{ line = `{PAINT} 255,0,0`, prefix = "", rawValue = "255,0,0", typeName = "color3" },
	{ line = `{SAY} %{RED}`, prefix = "", rawValue = `%{RED}`, typeName = "string" },
	{ line = `{SAY} #1`, prefix = "", rawValue = "#1", typeName = "string" },
}

type Union = {
	line: string,
	prefix: string,
	rawValue: string,
	typeName: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player
	local second: any = core.env.mock:join(SECOND)
	second.Team = core.env.game:GetService("Teams"):create(RED, roblox.BrickColor.new(RED_BRICK))

	core.registry:registerCommandObject({ name = KICK, args = { { name = "targets", type = "players" } } })
	core.registry:registerCommandObject({ name = PAINT, args = { { name = "color", type = "color3" } } })
	core.registry:registerCommandObject({ name = SAY, args = { { name = "message", type = "string" } } })

	for _, union: Union in UNIONS do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, union.line, 1)
		if not argument then
			return false, reason
		end

		local picked: boolean = argument.type == core.registry:getType(union.typeName)
		if argument.prefix ~= union.prefix or argument.rawValue ~= union.rawValue or not picked then
			return false, `{union.line} took the prefix {argument.prefix} and the type {argument.displayName}`
		end
	end

	-- Each line evaluated in the loop above, so each gives its argument
	local team: any = Evaluate(core.dispatcher, player, TEAM_LINE, 1)
	local members: string = Names(team:getValue())
	if members ~= SECOND then
		return false, `{TEAM_LINE} gave the players {members}`
	end

	local hex: any = Evaluate(core.dispatcher, player, HEX_LINE, 1)
	local color: any = hex:getValue()
	if color ~= PURE_RED then
		return false, `{HEX_LINE} gave the color {color}`
	end

	local brick: any = Evaluate(core.dispatcher, player, BRICK_LINE, 1)
	local brickColor: any = brick:getValue()
	if brickColor ~= roblox.BrickColor.new(BLACK).Color then
		return false, `{BRICK_LINE} gave the color {brickColor}`
	end

	local unknown: any, unknownReason: string? = Evaluate(core.dispatcher, player, NO_TEAM, 1)
	if not unknown then
		return false, unknownReason
	end

	local valid: boolean, invalid: string? = unknown:validate()
	if unknown.prefix ~= "%" or valid or invalid ~= TEAM_NOT_FOUND then
		return false, `{NO_TEAM} validated {valid}: {invalid}`
	end

	return true, nil
end
