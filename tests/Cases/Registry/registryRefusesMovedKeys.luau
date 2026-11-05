--[[
    registerCommandObject refuses a definition holding a clientRun or a
    data key, with a message saying where that code goes, and stores
    neither
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local FLASH: string = "flash"
local STATS: string = "stats"
local CLIENT_RUN_HOME: string = `the command's own \{Name}Client module beside its definition`
local CLIENT_RUN_REFUSAL: string = `[Decree] Command "flash" holds clientRun, which now goes in {CLIENT_RUN_HOME}`
local DATA_HOME: string = "the server half reads what it needs on the server"
local DATA_REFUSAL: string = `[Decree] Command "stats" holds data, which is removed: {DATA_HOME}`

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local clientRun: { [string]: any } = {
		name = FLASH,
		args = {},

		clientRun = function (): string
			return FLASH
		end,
	}

	local data: { [string]: any } = {
		name = STATS,
		args = {},

		data = function (): string
			return STATS
		end,
	}

	local ranOnDevice: boolean, clientRunError: any = pcall(registry.registerCommandObject, registry, clientRun)
	if ranOnDevice or Thrown(clientRunError) ~= CLIENT_RUN_REFUSAL then
		return false, `a definition holding clientRun gave {clientRunError}`
	end

	local gathered: boolean, dataError: any = pcall(registry.registerCommandObject, registry, data)
	if gathered or Thrown(dataError) ~= DATA_REFUSAL then
		return false, `a definition holding data gave {dataError}`
	end

	if registry:getCommand(FLASH) ~= nil or registry:getCommand(STATS) ~= nil or #core.access.definitions ~= 0 then
		return false, "a refused definition was stored or handed to the access check"
	end

	return true, nil
end
