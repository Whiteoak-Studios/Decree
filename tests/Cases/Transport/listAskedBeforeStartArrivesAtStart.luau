--[[
    A commands call before start is answered with an empty list and the
    player is remembered, so start pushes them their list
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Names = require("../../Fixtures/Server/Names")

local ECHO: string = "echo"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree.registry:registerCommandObject(Echo())

	local pushed: { any }? = nil
	server.client.Decree.access.on(function (list: { any })
		pushed = list
	end)

	local listed: any = server.client.Decree.commands.invoke()
	if not server.settle(listed) then
		return false, "the list never came"
	end

	local resolved: boolean, early: { any } = listed:await()
	if not resolved or #early ~= 0 then
		return false, `the commands call before start was answered {resolved and Names(early) or early}`
	end

	server.start()

	local arrived: boolean = server.step(function (): boolean
		return pushed ~= nil
	end)

	if not arrived or Names(pushed :: { any }) ~= ECHO then
		return false, "start pushed no list to the player who asked before it"
	end

	return true, nil
end
