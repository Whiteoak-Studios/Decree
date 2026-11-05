--[[
    registerCommandObject hands each definition to the access check before
    it stores it, and an error there refuses the command with nothing of it
    stored, its name and aliases left free
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Refuses = require("../../Fixtures/Types/Refuses")
local Server = require("../../Fixtures/Core/Server")

local ECHO: string = "echo"
local KICK: string = "kick"
local KICK_ALIAS: string = "boot"
local REFUSAL: string = "Refused by the access check"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	-- What the registry held when the access check was handed the definition
	local stored: any = false
	local listed: number = -1

	core.access.registered = function (definition: any)
		stored = registry:getCommand(definition.name)
		listed = #registry:getCommands()
	end

	local echo: { [string]: any } = Echo()
	registry:registerCommandObject(echo)

	if stored ~= nil or listed ~= 0 or registry:getCommand(ECHO) ~= echo then
		return false, `the access check was handed echo with {listed} commands stored, echo among them: {stored}`
	end

	core.access.registered = function (_: any): ()
		error(REFUSAL)
	end

	local kick: { [string]: any } = { name = KICK, aliases = { KICK_ALIAS }, args = {} }
	if not Refuses(REFUSAL, registry.registerCommandObject, registry, kick) then
		return false, "an error in the access check did not refuse the command"
	end

	if registry:getCommand(KICK) ~= nil or registry:getCommand(KICK_ALIAS) ~= nil or #registry:getCommands() ~= 1 then
		return false, "the command the access check refused was stored"
	end

	-- Its name and alias are free for a later registration
	core.access.registered = function (_: any) end
	registry:registerCommandObject(kick)

	if registry:getCommand(KICK) ~= kick or registry:getCommand(KICK_ALIAS) ~= kick then
		return false, "the name or alias of the refused command stayed taken"
	end

	return true, nil
end
