--[[
    Decree's own confirm joins a player's list, last, with no group and no
    arguments, only while the list holds a command that asks for
    confirmation
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Names = require("../../Fixtures/Server/Names")
local Wipe = require("../../Fixtures/Server/Wipe")

local ECHO: string = "echo"
local WIPE: string = "wipe"
local WITH_CONFIRM: string = "echo wipe confirm"
local SECONDS: number = 5 -- Any window, since nothing is confirmed

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local allowed: { [string]: true } = { [ECHO] = true }

	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerCommandObject(Wipe({ runs = 0 }))
	server.start({
		confirmSeconds = SECONDS,

		canAccess = function (_: any, command: any): boolean
			return allowed[command.name] == true
		end,
	})

	local pushed: { any }? = nil
	server.client.Decree.access.on(function (list: { any })
		pushed = list
	end)

	local listed: any = server.client.Decree.commands.invoke()
	server.settle(listed)

	local _, plain: { any } = listed:await()
	if Names(plain) ~= ECHO then
		return false, `a list with no command asking for confirmation held {Names(plain)}`
	end

	allowed[WIPE] = true
	server.decree:refreshAccess(server.env.player)

	local arrived: boolean = server.step(function (): boolean
		return pushed ~= nil
	end)

	local list: { any } = pushed or {}
	if not arrived or Names(list) ~= WITH_CONFIRM then
		return false, `the list holding wipe was {Names(list)}`
	end

	local confirm: any = list[#list]
	if confirm.group ~= nil or #confirm.args ~= 0 or confirm.description == "" or confirm.device then
		return false, "Decree's confirm entry holds a group, arguments, a device half or no description"
	end

	return true, nil
end
