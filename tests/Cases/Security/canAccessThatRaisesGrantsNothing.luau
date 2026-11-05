--[[
    A canAccess that raises an error for a command answers false for it,
    so the list leaves that command out and keeps the ones it granted
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Names = require("../../Fixtures/Server/Names")
local Pair = require("../../Fixtures/Dispatcher/Pair")

local ECHO: string = "echo"
local PAIR: string = "pair"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()

	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerCommandObject(Pair())
	server.start({
		canAccess = function (_: any, command: any): boolean
			if command.name == PAIR then
				error("the rank lookup failed")
			end

			return true
		end,
	})

	local listed: any = server.client.Decree.commands.invoke()
	if not server.settle(listed) then
		return false, "the list never came"
	end

	local resolved: boolean, list: any = listed:await()
	if not resolved or Names(list) ~= ECHO then
		return false, `the list was {resolved and Names(list) or list}`
	end

	return true, nil
end
