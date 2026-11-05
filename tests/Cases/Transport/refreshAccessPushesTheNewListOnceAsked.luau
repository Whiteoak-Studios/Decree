--[[
    refreshAccess pushes a player's new list over the access event only
    once their console has asked for one, and then each time it changes
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Environment = require("../../Environment")
local Names = require("../../Fixtures/Server/Names")
local Pair = require("../../Fixtures/Dispatcher/Pair")

local ECHO: string = "echo"
local PAIR: string = "pair"
local BOTH: string = "echo pair"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local player: any = server.env.player
	local allowed: { [string]: true } = {}

	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerCommandObject(Pair())
	server.start({
		canAccess = function (_: any, command: any): boolean
			return allowed[command.name] == true
		end,
	})

	local pushed: { { any } } = {}
	server.client.Decree.access.on(function (list: { any })
		table.insert(pushed, list)
	end)

	-- A change before the console asks is kept, not pushed
	allowed[ECHO] = true
	server.decree:refreshAccess(player)

	for _ = 1, Environment.ROUND_TRIP do
		server.env.mock:step()
	end

	if #pushed > 0 then
		return false, "a list was pushed before the console asked for one"
	end

	local listed: any = server.client.Decree.commands.invoke()
	if not server.settle(listed) then
		return false, "the list never came"
	end

	local _, asked: { any } = listed:await()
	if Names(asked) ~= ECHO then
		return false, `the console was answered {Names(asked)}`
	end

	allowed[PAIR] = true
	server.decree:refreshAccess(player)

	local arrived: boolean = server.step(function (): boolean
		return #pushed > 0
	end)

	if not arrived or Names(pushed[1]) ~= BOTH then
		return false, "the changed list was not pushed once the console had asked"
	end

	return true, nil
end
