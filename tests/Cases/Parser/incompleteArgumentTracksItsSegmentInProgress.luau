--[[
    On a client, a line still being typed builds every argument, and each
    holds the segment in progress and the suggestions for it, with an
    operator's expansion marked as autocomplete's own
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Entry = require("../../Fixtures/Core/Entry")
local Environment = require("../../Environment")
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Names = require("../../Fixtures/Parser/Names")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local DISPATCHER: string = "src/DecreeClient/Shared/Dispatcher"
local HIT: string = "hit" -- Takes a player
local KICK: string = "kick" -- Takes players, listable, whose union adds % teamPlayers
local GIVE: string = "give" -- Takes a player, then a number, which has no autocomplete
local SAY: string = "say" -- Takes a string, which has no autocomplete
local PLAYER: string = "Player" -- The Name of the environment's own player
local SECOND: string = "Second"
local THIRD: string = "Third"
local NAMES: { string } = { PLAYER, SECOND, THIRD }
local EVERYONE: string = `{PLAYER},{SECOND},{THIRD}`
local RED: string = "Red"
local RED_BRICK: string = "Bright red"
local EXPANDED: string = `{KICK} *`
local INCOMPLETE: boolean = true -- Evaluates as autocomplete does, allowing arguments not yet typed

-- Each line still being typed, the argument read, its segment in progress, its suggestions as
-- names, and whether an operator filled its segments
local TYPING: { Typing } = {
	{ line = HIT, index = 1, progress = "", suggestions = EVERYONE, filled = false },
	{ line = `{HIT} Se`, index = 1, progress = "Se", suggestions = SECOND, filled = false },
	{ line = `{HIT} Nob`, index = 1, progress = "Nob", suggestions = "", filled = false },
	{ line = `{HIT} .`, index = 1, progress = ".", suggestions = PLAYER, filled = true },
	{ line = `{KICK} {PLAYER},Se`, index = 1, progress = "Se", suggestions = SECOND, filled = false },
	{ line = `{KICK} {PLAYER},`, index = 1, progress = "", suggestions = EVERYONE, filled = false },
	{ line = `{KICK} %Re`, index = 1, progress = "Re", suggestions = RED, filled = false },
	{ line = `{GIVE} {PLAYER}`, index = 2, progress = "", suggestions = "", filled = false },
	{ line = `{SAY} hel`, index = 1, progress = "hel", suggestions = "", filled = false },
}

type Typing = {
	line: string,
	index: number,
	progress: string,
	suggestions: string,
	filled: boolean,
}

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	env.mock:join(SECOND)
	env.mock:join(THIRD)
	env.game:GetService("Teams"):create(RED, roblox.BrickColor.new(RED_BRICK))

	local dispatcher: any = env.require(DISPATCHER)
	env.require(REGISTRY):replaceCommands({
		Entry({ name = HIT, args = { { name = "target", type = "player" } } }),
		Entry({ name = KICK, args = { { name = "targets", type = "players" } } }),
		Entry({
			name = GIVE,
			args = { { name = "target", type = "player" }, { name = "amount", type = "number" } },
		}),
		Entry({ name = SAY, args = { { name = "message", type = "string" } } }),
	})

	for _, typing: Typing in TYPING do
		local argument: any, reason: string? = Evaluate(dispatcher, env.player, typing.line, typing.index, INCOMPLETE)
		if not argument then
			return false, reason
		end

		local offered: { string } = argument:getAutocomplete()
		local suggestions: string = Names(offered)
		local progress: string = argument.textSegmentInProgress

		if progress ~= typing.progress or suggestions ~= typing.suggestions then
			return false, `{typing.line} held {progress} in progress and suggested {suggestions}`
		end

		if argument.rawSegmentsAreAutocomplete ~= typing.filled then
			return false, `{typing.line} marked its segments filled {argument.rawSegmentsAreAutocomplete}`
		end
	end

	-- The expansion's last name is the segment in progress, in whatever order the names tie
	local expanded: any, reason: string? = Evaluate(dispatcher, env.player, EXPANDED, 1, INCOMPLETE)
	if not expanded then
		return false, reason
	end

	local last: string = expanded.textSegmentInProgress
	if not table.find(NAMES, last) or last ~= expanded.rawSegments[#expanded.rawSegments] then
		return false, `{EXPANDED} held {last} in progress`
	end

	if not expanded.rawSegmentsAreAutocomplete then
		return false, `{EXPANDED} did not mark its segments filled`
	end

	return true, nil
end
