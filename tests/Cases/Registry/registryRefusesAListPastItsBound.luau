--[[
    registerCommandObject refuses a list one entry past a bound of the
    wire's, in a command and in a subcommand, naming the list and where it
    is, and stores none of them
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local LIST_ENTRIES: number = require("../../../src/DecreeClient/Shared/Constants").LIST_ENTRIES
local ARGUMENTS: number = require("../../../src/DecreeClient/Shared/Constants").ARGUMENTS
local NAME: string = "audit"
local ARGUMENT: { [string]: any } = { name = "target", type = "player" }
local SUBCOMMAND: { [string]: any } = { name = "now" }

type Refused = {
	definition: { [string]: any },
	refusal: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local entries: number = LIST_ENTRIES + 1
	local arguments: number = ARGUMENTS + 1

	-- Each definition with one list past its bound, and the refusal naming it
	local refusals: { Refused } = {
		{
			definition = { name = NAME, aliases = table.create(entries, "check") },
			refusal = `[Decree] Command "audit" holds {entries} aliases, past {LIST_ENTRIES}`,
		},
		{
			definition = { name = NAME, tags = table.create(entries, "admin") },
			refusal = `[Decree] Command "audit" holds {entries} tags, past {LIST_ENTRIES}`,
		},
		{
			definition = { name = NAME, autoExec = table.create(entries, "audit") },
			refusal = `[Decree] Command "audit" holds {entries} autoExec, past {LIST_ENTRIES}`,
		},
		{
			definition = { name = NAME, args = table.create(arguments, ARGUMENT) },
			refusal = `[Decree] Command "audit" holds {arguments} args, past {ARGUMENTS}`,
		},
		{
			definition = { name = NAME, subcommands = table.create(entries, SUBCOMMAND) },
			refusal = `[Decree] Command "audit" holds {entries} subcommands, past {LIST_ENTRIES}`,
		},
		{
			definition = { name = NAME, subcommands = { { name = "now", args = table.create(arguments, ARGUMENT) } } },
			refusal = `[Decree] Command "audit now" holds {arguments} args, past {ARGUMENTS}`,
		},
	}

	for index: number, refused: Refused in refusals do
		local registered: boolean, problem: any = pcall(registry.registerCommandObject, registry, refused.definition)
		if registered or Thrown(problem) ~= refused.refusal then
			return false, `a list past its bound #{index} gave {problem}`
		end
	end

	if registry:getCommand(NAME) ~= nil or #core.access.definitions ~= 0 then
		return false, "a refused definition was stored or handed to the access check"
	end

	return true, nil
end
