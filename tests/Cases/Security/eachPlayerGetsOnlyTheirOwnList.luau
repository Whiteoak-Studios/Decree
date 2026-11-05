--[[
    Each player's console gets only their own list, as canAccess grants it
    to them, and a refresh of one player's list pushes nothing to another
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Environment = require("../../Environment")
local Names = require("../../Fixtures/Server/Names")
local Pair = require("../../Fixtures/Dispatcher/Pair")

local CLIENT: string = "src/DecreeClient/Network"
local SECOND: string = "Second"
local ECHO: string = "echo"
local PAIR: string = "pair"
local BOTH: string = "echo pair"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local first: any = server.env.player
	local second: any, transport: any = server.env.mock:join(SECOND)
	local secondClient: any = server.env.connect(transport, second).require(CLIENT)

	-- What each player holds, by their name
	local allowed: { [string]: { [string]: true } } = {
		[first.Name] = { [ECHO] = true },
		[SECOND] = { [PAIR] = true },
	}

	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerCommandObject(Pair())
	server.start({
		canAccess = function (player: any, command: any): boolean
			return allowed[player.Name][command.name] == true
		end,
	})

	local firstPushed: number = 0
	server.client.Decree.access.on(function ()
		firstPushed += 1
	end)

	local secondPushed: { any }? = nil
	secondClient.Decree.access.on(function (list: { any })
		secondPushed = list
	end)

	local firstListed: any = server.client.Decree.commands.invoke()
	local secondListed: any = secondClient.Decree.commands.invoke()
	server.settle(firstListed)
	server.settle(secondListed)

	local _, firstList: { any } = firstListed:await()
	local _, secondList: { any } = secondListed:await()
	if Names(firstList) ~= ECHO or Names(secondList) ~= PAIR then
		return false, `the players were answered {Names(firstList)} and {Names(secondList)}`
	end

	allowed[SECOND][ECHO] = true
	server.decree:refreshAccess(second)

	local arrived: boolean = server.step(function (): boolean
		return secondPushed ~= nil
	end)

	for _ = 1, Environment.ROUND_TRIP do
		server.env.mock:step()
	end

	if not arrived or Names(secondPushed :: { any }) ~= BOTH then
		return false, "the second player's changed list was not pushed to them"
	elseif firstPushed ~= 0 then
		return false, "the second player's refresh pushed a list to the first"
	end

	return true, nil
end
