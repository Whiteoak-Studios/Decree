--[[
    The console holds Decree's clear whenever the server's list holds a
    command, and not while the list is empty
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")
local Entry = require("../../Fixtures/Core/Entry")

local CLEAR: string = "clear"
local WAVE: string = "wave"

return function (): (boolean, string | nil)
	local console: Console.Console = Console()
	local player: any = console.env.player

	console.server.Decree.commands.on(function (_: any): { any }
		return {}
	end)

	console.listen()
	console.step()

	if console.registry:getCommand(CLEAR) then
		return false, `the console held {CLEAR} from an empty list`
	end

	console.server.Decree.access.fire(player, { Entry({ name = WAVE }) })
	console.step()

	if not console.registry:getCommand(CLEAR) then
		return false, `the console did not hold {CLEAR} beside {WAVE}`
	end

	console.server.Decree.access.fire(player, {})
	console.step()

	if console.registry:getCommand(CLEAR) then
		return false, `the console still held {CLEAR} once the list was empty again`
	end

	return true, nil
end
