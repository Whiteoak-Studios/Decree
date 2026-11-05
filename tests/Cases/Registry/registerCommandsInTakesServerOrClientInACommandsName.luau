--[[
    registerCommandsIn reads a module as a half only when its name is a
    sibling module's followed by Server or Client, so ServerStatus and
    ClientInfo register as commands, each paired with its own half
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local COMMANDS: string = "tests/Fixtures/Core/Commands"
local STATUS: string = `{COMMANDS}/Status/ServerStatus`
local STATUS_SERVER: string = `{COMMANDS}/Status/ServerStatusServer`
local INFO: string = `{COMMANDS}/ClientInfo`
local INFO_CLIENT: string = `{COMMANDS}/ClientInfoClient`
local STATUS_NAME: string = "serverStatus"
local INFO_NAME: string = "clientInfo"
local REGISTERED: number = 3 -- kill, serverStatus and clientInfo, the folder's three commands

return function (): (boolean, string | nil)
	local core: Server.Core = Server({ folders = { COMMANDS } })
	local env: any = core.env
	local registry: any = core.registry

	registry:registerCommandsIn(env.find(COMMANDS))

	local status: any = registry:getCommand(STATUS_NAME)
	if status == nil or status ~= env.require(STATUS) or status.run ~= env.require(STATUS_SERVER) then
		return false, "ServerStatus did not register as a command with its server half"
	end

	local info: any = registry:getCommand(INFO_NAME)
	if info == nil or info ~= env.require(INFO) or registry:getDeviceHalf(INFO_NAME) ~= env.find(INFO_CLIENT) then
		return false, "ClientInfo did not register as a command with its device half"
	end

	if #registry:getCommands() ~= REGISTERED then
		return false, `the folder registered {#registry:getCommands()} commands, not {REGISTERED}`
	end

	return true, nil
end
