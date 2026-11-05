--[[
    A listable argument expands * to every autocomplete name, ** to every
    name but the executor's, ?N to N of them and ? to one, . gives the type's
    default, aliases reach them, and nothing to expand leaves them as typed
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Listed = require("../../Fixtures/Parser/Listed")
local Names = require("../../Fixtures/Parser/Names")
local Server = require("../../Fixtures/Core/Server")

local KICK: string = "kick" -- Takes players, listable
local HIT: string = "hit" -- Takes a player, not listable
local PAINT: string = "paint" -- Takes teams, of which there are none
local PICK: string = "pick" -- Takes PARTIAL, whose autocomplete is partial
local PARTIAL: string = "partialWords"
local PARTIAL_WORDS: { string } = { "one", "two" }
local PLAYER: string = "Player" -- The Name of the environment's own player
local SECOND: string = "Second"
local THIRD: string = "Third"
local NAMES: { string } = { PLAYER, SECOND, THIRD }
local SEPARATOR: string = " | " -- Joins segments in a failure message

-- Each typed line and the names of every player it expands to
local EXPANSIONS: { Expansion } = {
	{ line = `{KICK} *`, names = `{PLAYER},{SECOND},{THIRD}` },
	{ line = `{KICK} all`, names = `{PLAYER},{SECOND},{THIRD}` },
	{ line = `{KICK} **`, names = `{SECOND},{THIRD}` },
	{ line = `{KICK} others`, names = `{SECOND},{THIRD}` },
	{ line = `{KICK} ?9`, names = `{PLAYER},{SECOND},{THIRD}` }, -- More than there are gives them all
	{ line = `{KICK} .`, names = PLAYER },
	{ line = `{KICK} me`, names = PLAYER },
}

local DEFAULTED: string = `{HIT} .` -- The default on a type that is not listable

-- Each typed line and how many distinct players it draws at random
local DRAWS: { Draw } = {
	{ line = `{KICK} ?`, count = 1 },
	{ line = `{KICK} random`, count = 1 },
	{ line = `{KICK} ?2`, count = 2 },
	{ line = `{HIT} ?`, count = 1 },
}

-- Each typed line whose operator stays the one segment as typed
local LITERALS: { string } = {
	`{KICK} ?0`,
	`{HIT} *`,
	`{HIT} **`,
	`{PAINT} *`,
	`{PICK} *`,
	`{PICK} ?`,
	`{PICK} ?2`,
}

type Expansion = {
	line: string,
	names: string,
}

type Draw = {
	line: string,
	count: number,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player
	core.env.mock:join(SECOND)
	core.env.mock:join(THIRD)

	core.registry:registerType(PARTIAL, {
		listable = true,

		autocomplete = function (): ({ string }, { isPartial: boolean })
			return table.clone(PARTIAL_WORDS), { isPartial = true }
		end,

		parse = function (text: string): { string }
			return { text }
		end,
	})

	core.registry:registerCommandObject({ name = KICK, args = { { name = "targets", type = "players" } } })
	core.registry:registerCommandObject({ name = HIT, args = { { name = "target", type = "player" } } })
	core.registry:registerCommandObject({ name = PAINT, args = { { name = "teams", type = "teams" } } })
	core.registry:registerCommandObject({ name = PICK, args = { { name = "words", type = PARTIAL } } })

	for _, expansion: Expansion in EXPANSIONS do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, expansion.line, 1)
		if not argument then
			return false, reason
		end

		local segments: string = Names(argument.rawSegments)
		local values: string = Names(argument:getValue())

		if segments ~= expansion.names or values ~= expansion.names or not argument.rawSegmentsAreAutocomplete then
			return false, `{expansion.line} expanded to {segments}, giving {values}`
		end
	end

	local defaulted: any, defaultReason: string? = Evaluate(core.dispatcher, player, DEFAULTED, 1)
	if not defaulted then
		return false, defaultReason
	end

	local target: any = defaulted:getValue()
	if
		not Listed(defaulted.rawSegments, { PLAYER })
		or target ~= player
		or not defaulted.rawSegmentsAreAutocomplete
	then
		return false, `{DEFAULTED} gave {table.concat(defaulted.rawSegments, SEPARATOR)}, the player {target}`
	end

	for _, draw: Draw in DRAWS do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, draw.line, 1)
		if not argument then
			return false, reason
		end

		local drawn: { [string]: boolean } = {}

		for _, segment: string in argument.rawSegments do
			if not table.find(NAMES, segment) or drawn[segment] then
				return false, `{draw.line} drew {table.concat(argument.rawSegments, SEPARATOR)}`
			end

			drawn[segment] = true
		end

		if #argument.rawSegments ~= draw.count or not argument.rawSegmentsAreAutocomplete then
			return false, `{draw.line} drew {#argument.rawSegments} players`
		end
	end

	for _, line: string in LITERALS do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, line, 1)
		if not argument then
			return false, reason
		end

		if not Listed(argument.rawSegments, { argument.rawValue }) or argument.rawSegmentsAreAutocomplete then
			return false, `{line} expanded to {table.concat(argument.rawSegments, SEPARATOR)}`
		end
	end

	return true, nil
end
