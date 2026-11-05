--[[
    A run, guard or beforeRun hook that throws is answered with the error
    text as an Error line, the afterRun hooks never reached, and the
    dispatcher keeps running the lines that follow
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local FAILING: string = "fail"
local GUARDED: string = "guarded"
local ECHO_LINE: string = "echo still here"
local ECHOED: string = "still here"
local FAILURE: string = "Thrown by the case"
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local ERROR: string = "Error"
local INFO: string = "Info"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player
	local afterRuns: number = 0

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerHook("afterRun", function (): string?
		afterRuns += 1

		return nil
	end)

	core.registry:registerCommandObject(Echo())
	core.registry:registerCommandObject({
		name = FAILING,
		args = {},

		run = function (): ()
			error(FAILURE)
		end,
	})

	core.registry:registerCommandObject({
		name = GUARDED,
		args = {},

		guards = {
			function (): string?
				error(FAILURE)
			end,
		},

		run = function (): string
			return ECHOED
		end,
	})

	local failed: string, failedKind: string = core.run(FAILING, player)
	if failed ~= ERROR_REPLY or failedKind ~= ERROR or afterRuns ~= 0 then
		return false, `a run that threw answered {failed} as {failedKind}, reaching afterRun {afterRuns} times`
	end

	local echoed: string, echoedKind: string = core.run(ECHO_LINE, player)
	if echoed ~= ECHOED or echoedKind ~= INFO or afterRuns ~= 1 then
		return false, `the line after the throw answered {echoed}`
	end

	local guarded: string, guardedKind: string = core.run(GUARDED, player)
	if guarded ~= ERROR_REPLY or guardedKind ~= ERROR or afterRuns ~= 1 then
		return false, `a guard that threw answered {guarded}`
	end

	core.registry:registerHook("beforeRun", function (): string?
		error(FAILURE)
	end)

	local hooked: string, hookedKind: string = core.run(ECHO_LINE, player)
	if hooked ~= ERROR_REPLY or hookedKind ~= ERROR or afterRuns ~= 1 then
		return false, `a beforeRun hook that threw answered {hooked}`
	end

	return true, nil
end
