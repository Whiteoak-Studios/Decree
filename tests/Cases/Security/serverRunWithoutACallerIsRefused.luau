--[[
    Server code that runs a line through the server object's dispatcher
    with no player is refused, and the command never runs as nobody
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")

local LINE: string = "echo from the server"
local NO_CALLER: string = "A command run from the server needs the player who runs it."
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
	server.start()

	local _, text: string, kind: string = server.decree.dispatcher:evaluateAndRun(LINE):await()
	if text ~= NO_CALLER or kind ~= REFUSED then
		return false, `a line with no caller was answered {text} as {kind}`
	elseif ran then
		return false, "the command ran with no caller"
	end

	return true, nil
end
