--[[
    The console holds the commands of the list the server answers at start
    and then of each list the server pushes, the commands a pushed list
    leaves out going with their aliases
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")
local Entry = require("../../Fixtures/Core/Entry")
local Listed = require("../../Fixtures/Parser/Listed")

local KICK: string = "kick"
local KICK_ALIAS: string = "boot"
local WAVE: string = "wave"
local FLY: string = "fly"
local CLEAR: string = "clear"
local SEPARATOR: string = ", " -- Joins the names held in a failure message

-- What the registry names after each list, clear following the server's own
local AT_START: { string } = { KICK, WAVE, CLEAR }
local AFTER_PUSH: { string } = { WAVE, FLY, CLEAR }

return function (): (boolean, string | nil)
	local console: Console.Console = Console()
	local registry: any = console.registry

	console.server.Decree.commands.on(function (_: any): { any }
		return { Entry({ name = KICK, aliases = { KICK_ALIAS } }), Entry({ name = WAVE }) }
	end)

	console.listen()
	console.step()

	local held: { string } = registry:getCommandNames()
	if not Listed(held, AT_START) or not registry:getCommand(KICK_ALIAS) then
		return false, `the console held {table.concat(held, SEPARATOR)} from the list answered at start`
	end

	console.server.Decree.access.fire(console.env.player, { Entry({ name = WAVE }), Entry({ name = FLY }) })
	console.step()

	held = registry:getCommandNames()
	if not Listed(held, AFTER_PUSH) then
		return false, `the console held {table.concat(held, SEPARATOR)} from the pushed list`
	end

	if registry:getCommand(KICK) or registry:getCommand(KICK_ALIAS) then
		return false, "a command the pushed list left out, or its alias, still found it"
	end

	return true, nil
end
