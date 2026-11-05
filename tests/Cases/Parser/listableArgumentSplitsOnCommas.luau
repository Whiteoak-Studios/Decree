--[[
    A listable argument splits its raw value at each comma into segments,
    drops empty ones but keeps a trailing one, and gives each value once,
    while a non-listable argument keeps its commas and a bad segment fails
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Listed = require("../../Fixtures/Parser/Listed")
local Names = require("../../Fixtures/Parser/Names")
local Server = require("../../Fixtures/Core/Server")

local TAG: string = "tag"
local KICK: string = "kick"
local SAY: string = "say"
local PLAYER: string = "Player" -- The Name of the environment's own player
local SECOND: string = "Second"
local NOBODY: string = "Nobody" -- A name no joined player has
local SEPARATOR: string = " | " -- Joins segments in a failure message
local COMMAS: string = "a,b" -- Typed to the non-listable SAY
local BAD_LINE: string = `{KICK} {PLAYER},{NOBODY}`
local NOT_FOUND: string = "No player with that name could be found."

-- Each typed line, its argument's segments, the names its value holds and the segment last typed
local LISTS: { List } = {
	{ line = `{TAG} a,b,c`, segments = { "a", "b", "c" }, value = "a,b,c", progress = "c" },
	{ line = `{TAG} a,,b`, segments = { "a", "b" }, value = "a,b", progress = "b" },
	{ line = `{TAG} a,b,`, segments = { "a", "b", "" }, value = ",a,b", progress = "" },
	{ line = `{TAG} a,a,b`, segments = { "a", "a", "b" }, value = "a,b", progress = "b" },
	{ line = `{TAG} a, b`, segments = { "a", " b" }, value = " b,a", progress = " b" }, -- The space after a comma stays
	{ line = `{TAG} ,`, segments = { "", "" }, value = "", progress = "" },
	{
		line = `{KICK} {PLAYER},{SECOND}`,
		segments = { PLAYER, SECOND },
		value = `{PLAYER},{SECOND}`,
		progress = SECOND,
	},
}

type List = {
	line: string,
	segments: { string },
	value: string,
	progress: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player
	core.env.mock:join(SECOND)

	core.registry:registerCommandObject({ name = TAG, args = { { name = "words", type = "strings" } } })
	core.registry:registerCommandObject({ name = KICK, args = { { name = "targets", type = "players" } } })
	core.registry:registerCommandObject({ name = SAY, args = { { name = "message", type = "string" } } })

	for _, list: List in LISTS do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, list.line, 1)
		if not argument then
			return false, reason
		end

		if not Listed(argument.rawSegments, list.segments) or argument.textSegmentInProgress ~= list.progress then
			local segments: string = table.concat(argument.rawSegments, SEPARATOR)
			return false, `{list.line} gave the segments {segments}, {argument.textSegmentInProgress} in progress`
		end

		local value: string = Names(argument:getValue())
		if value ~= list.value then
			return false, `{list.line} gave the value {value}`
		end
	end

	local single: any, reason: string? = Evaluate(core.dispatcher, player, `{SAY} {COMMAS}`, 1)
	if not single then
		return false, reason
	end

	if not Listed(single.rawSegments, { COMMAS }) or single:getValue() ~= COMMAS then
		return false, `the non-listable argument split {COMMAS} into {#single.rawSegments} segments`
	end

	local bad: any, badReason: string? = Evaluate(core.dispatcher, player, BAD_LINE, 1)
	if not bad then
		return false, badReason
	end

	local valid: boolean, invalid: string? = bad:validate()
	if valid or invalid ~= NOT_FOUND then
		return false, `{BAD_LINE} validated {valid}: {invalid}`
	end

	return true, nil
end
