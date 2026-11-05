--[[
    The first word after a command's name picks its subcommand in any case,
    whose arguments then start at index 1, and a line that names none, or
    names one the command lacks, is refused naming the command
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "wipe"
local SHARD: number = 3
local KEY: string = "mode"
local VALUE: string = "fast and loose" -- Folds into the last argument of set
local MISSING: string = "wipe takes a subcommand: now, hold, set."
local UNKNOWN: string = "later is not a subcommand of wipe."
local NO_SHARD: string = "Required argument #1 shard is missing."
local RUN_SHARD: number = 7
local RUN_LINE: string = `{NAME} Now {RUN_SHARD}`
local RAN: string = `now {RUN_SHARD}` -- What run answers: the subcommand's name and its value
local INFO: string = "Info"

local NOW: { [string]: any } = {
	name = "now",
	description = "Wipes the shard now",
	args = { { name = "shard", type = "integer" } },
}
local HOLD: { [string]: any } = { name = "hold", description = "Holds the wipe" }
local SET: { [string]: any } = {
	name = "set",
	args = { { name = "key", type = "string" }, { name = "value", type = "string" } },
}

-- Each line refused, and the reason it gets
local REFUSED: { [string]: string } = {
	[NAME] = MISSING,
	[`{NAME} later`] = UNKNOWN,
	[`{NAME} now`] = NO_SHARD,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local dispatcher: any = core.dispatcher
	local player: any = core.env.player

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject({
		name = NAME,
		subcommands = { NOW, HOLD, SET },

		run = function (context: any, value: any): string
			return `{context.subcommand.name} {value}`
		end,
	})

	local now: any, nowReason: string? = dispatcher:evaluate(`{NAME} NOW {SHARD}`, player)
	if not now or now.subcommand ~= NOW or now.argumentDefinitions ~= NOW.args then
		return false, `wipe NOW did not pick the now subcommand: {nowReason}`
	end

	local shard: any = now:getArgument(1)
	if #now.rawArguments ~= 1 or not shard or shard.name ~= NOW.args[1].name or shard:getValue() ~= SHARD then
		return false, "now's first argument is not the word after the subcommand"
	end

	local set: any, setReason: string? = dispatcher:evaluate(`{NAME} Set {KEY} {VALUE}`, player)
	local key: any = set and set:getArgument(1)
	local value: any = set and set:getArgument(2)
	if
		not set
		or set.subcommand ~= SET
		or not key
		or key:getValue() ~= KEY
		or not value
		or value:getValue() ~= VALUE
	then
		return false, `wipe Set did not read its two arguments, the extra words in the last: {setReason}`
	end

	local hold: any, holdReason: string? = dispatcher:evaluate(`{NAME} hold`, player)
	if not hold or hold.subcommand ~= HOLD or #hold.argumentDefinitions ~= 0 or #hold.arguments ~= 0 then
		return false, `wipe hold did not pick a subcommand with no arguments: {holdReason}`
	end

	for line: string, expected: string in REFUSED do
		local context: any, reason: string? = dispatcher:evaluate(line, player)
		if context or reason ~= expected then
			return false, `{line} was refused with {reason}`
		end
	end

	local reply: string, kind: string = core.run(RUN_LINE, player)
	if reply ~= RAN or kind ~= INFO then
		return false, `{RUN_LINE} answered {reply} as {kind}`
	end

	return true, nil
end
