--[[
    With no beforeRun hook registered, a started Decree refuses every typed
    line with "No permission hook is registered", and the command never runs
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")

local LINE: string = "echo unguarded"
local NO_HOOK: string = "No permission hook is registered"
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local echo: { [string]: any } = Echo()
	local ran: boolean = false

	echo.run = function (): string
		ran = true

		return LINE
	end

	server.decree.registry:registerCommandObject(echo)
	server.decree:start({
		rate = { perSecond = 1 },

		canAccess = function (): boolean
			return true
		end,
	})

	local answered: boolean, text: string, kind: string = server.run(LINE)
	if not answered or text ~= NO_HOOK or kind ~= REFUSED then
		return false, `a line with no hook registered was answered {text} as {kind}`
	elseif ran then
		return false, "the command ran with no hook registered"
	end

	return true, nil
end
