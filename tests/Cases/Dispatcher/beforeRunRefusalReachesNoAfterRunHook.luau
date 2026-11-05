--[[
    A line a beforeRun hook refuses is answered with that refusal as Refused
    and reaches no afterRun hook, though a server half that raises reaches one
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "fail"
local FAILURE: string = "Thrown by the case"
local REFUSAL: string = "You may not run this."
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local heard: number = 0

	core.registry:registerHook("beforeRun", function (): string
		return REFUSAL
	end)

	core.registry:registerHook("afterRun", function (): string?
		heard += 1

		return nil
	end)

	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): ()
			error(FAILURE)
		end,
	})

	local reply: string, kind: string = core.run(NAME, core.env.player)
	if reply ~= REFUSAL or kind ~= REFUSED or heard ~= 0 then
		return false, `the refused line answered {reply} as {kind}, reaching the afterRun hook {heard} times`
	end

	return true, nil
end
