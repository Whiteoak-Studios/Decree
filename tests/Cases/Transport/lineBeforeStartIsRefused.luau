--[[
    Until start runs, every typed line is refused with "Decree has not
    started", the hook and the command registered or not
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")

local LINE: string = "echo early"
local NOT_STARTED: string = "Decree has not started"
local REFUSED: string = "Refused"
local BEFORE_RUN: string = "beforeRun"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerHook(BEFORE_RUN, PassingHook)

	local answered: boolean, text: string, kind: string = server.run(LINE)
	if not answered or text ~= NOT_STARTED or kind ~= REFUSED then
		return false, `a line before start was answered {text} as {kind}`
	end

	return true, nil
end
