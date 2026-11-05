--[[
    A backslash before an operator keeps it as text, unescaped once into
    both the value and the segment, and every escaped operator in an
    argument loses its backslash, not only the first of each kind
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Listed = require("../../Fixtures/Parser/Listed")
local Names = require("../../Fixtures/Parser/Names")
local Server = require("../../Fixtures/Core/Server")

local HIT: string = "hit" -- Takes a player, not listable, whose type has a default
local KICK: string = "kick" -- Takes players, listable
local SAY: string = "say" -- Takes a string, not listable
local TAG: string = "tag" -- Takes strings, listable
local BACKSLASH: string = "\\"
local SEPARATOR: string = " | " -- Joins segments in a failure message

-- Each typed line, the raw value its argument holds, its segments and its value as names
local ESCAPES: { Escape } = {
	{ line = `{HIT} {BACKSLASH}.`, rawValue = `{BACKSLASH}.`, segments = { "." }, value = "" },
	{ line = `{KICK} {BACKSLASH}*`, rawValue = `{BACKSLASH}*`, segments = { "*" }, value = "" },
	{ line = `{KICK} {BACKSLASH}?`, rawValue = `{BACKSLASH}?`, segments = { "?" }, value = "" },
	{ line = `{KICK} {BACKSLASH}.`, rawValue = `{BACKSLASH}.`, segments = { "." }, value = "" },
	{ line = `{SAY} {BACKSLASH}*`, rawValue = `{BACKSLASH}*`, segments = { "*" }, value = "*" },
	{ line = `{SAY} {BACKSLASH}.`, rawValue = `{BACKSLASH}.`, segments = { "." }, value = "." },
	{
		-- A typed double backslash is one in the raw value, which stays before the operator it escapes
		line = `{SAY} {BACKSLASH}{BACKSLASH}{BACKSLASH}*`,
		rawValue = `{BACKSLASH}{BACKSLASH}*`,
		segments = { `{BACKSLASH}*` },
		value = `{BACKSLASH}*`,
	},
	{
		line = `{SAY} {BACKSLASH}*{BACKSLASH}*`,
		rawValue = `{BACKSLASH}*{BACKSLASH}*`,
		segments = { "**" },
		value = "**",
	},
	{
		line = `{TAG} {BACKSLASH}*,{BACKSLASH}*`,
		rawValue = `{BACKSLASH}*,{BACKSLASH}*`,
		segments = { "*", "*" },
		value = "*",
	},
}

type Escape = {
	line: string,
	rawValue: string,
	segments: { string },
	value: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player

	core.registry:registerCommandObject({ name = HIT, args = { { name = "target", type = "player" } } })
	core.registry:registerCommandObject({ name = KICK, args = { { name = "targets", type = "players" } } })
	core.registry:registerCommandObject({ name = SAY, args = { { name = "message", type = "string" } } })
	core.registry:registerCommandObject({ name = TAG, args = { { name = "words", type = "strings" } } })

	for _, escape: Escape in ESCAPES do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, escape.line, 1)
		if not argument then
			return false, reason
		end

		local segments: string = table.concat(argument.rawSegments, SEPARATOR)
		if argument.rawValue ~= escape.rawValue or not Listed(argument.rawSegments, escape.segments) then
			return false, `{escape.line} held {argument.rawValue} in the segments {segments}`
		end

		-- A value that is a player or a list of them is read by its names, and nil by none
		local value: any = argument:getValue()
		local values: { any } = {}

		if type(value) == "table" then
			values = value
		elseif value ~= nil then
			values = { value }
		end

		local names: string = Names(values)
		if names ~= escape.value or argument.rawSegmentsAreAutocomplete then
			return false, `{escape.line} gave the value {names}, expanded {argument.rawSegmentsAreAutocomplete}`
		end
	end

	return true, nil
end
