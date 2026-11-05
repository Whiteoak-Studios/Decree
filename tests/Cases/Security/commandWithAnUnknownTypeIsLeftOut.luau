--[[
    A command naming an argument type no client has, in its own arguments
    or a subcommand's, is left out of every list while the rest stay
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Names = require("../../Fixtures/Server/Names")

local ECHO: string = "echo"
local UNKNOWN: string = "fruit" -- A type nothing registered

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()

	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerCommandObject({
		name = "eat",
		args = { { name = "food", type = UNKNOWN } },
	})
	server.decree.registry:registerCommandObject({
		name = "garden",
		subcommands = { { name = "plant", args = { { name = "seed", type = UNKNOWN } } } },
	})

	server.start()

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
