--[[
    The only messages a console sends Decree's server are run, carrying the
    typed text and nothing else, and commands, carrying nothing
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")

local NETWORK: string = "src/Network"
local LINE: string = "echo only this"
local RUN: string = "Decree.run"
local COMMANDS: string = "Decree.commands"
local MESSAGES: number = 2 -- The one list request and the one line the case sends

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local network: any = server.env.require(NETWORK)
	local heard: number = 0
	local runValues: { n: number, [number]: any }? = nil
	local commandsValues: { n: number, [number]: any }? = nil

	network.hooks.afterReceive(nil, function (): boolean
		heard += 1

		return true
	end)

	network.hooks.afterReceive(RUN, function (_: any, ...: any): boolean
		runValues = table.pack(...)

		return true
	end)

	network.hooks.afterReceive(COMMANDS, function (_: any, ...: any): boolean
		commandsValues = table.pack(...)

		return true
	end)

	server.decree.registry:registerCommandObject(Echo())
	server.start()

	server.settle(server.client.Decree.commands.invoke())
	server.run(LINE)

	if heard ~= MESSAGES then
		return false, `the server heard {heard} messages, not {MESSAGES}`
	elseif not runValues or runValues.n ~= 1 or runValues[1] ~= LINE then
		return false, "run carried more than the typed text"
	elseif not commandsValues or commandsValues.n ~= 0 then
		return false, "commands carried something"
	end

	return true, nil
end
