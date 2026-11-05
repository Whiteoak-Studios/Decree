--[[
    registerCommandsIn finds a command in a folder inside a folder, pairs
    it with the server half and device half beside it, takes neither half
    as a command, and leaves all three modules where they were
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local COMMANDS: string = "tests/Fixtures/Core/Commands"
local KILL: string = `{COMMANDS}/Moderation/Kill/Kill` -- Two folders below the folder registered
local KILL_SERVER: string = `{COMMANDS}/Moderation/Kill/KillServer`
local KILL_CLIENT: string = `{COMMANDS}/Moderation/Kill/KillClient`
local NAME: string = "kill"
local ALIAS: string = "slay"
local MODULES: { string } = { KILL, KILL_SERVER, KILL_CLIENT }

return function (): (boolean, string | nil)
	local core: Server.Core = Server({ folders = { COMMANDS } })
	local env: any = core.env
	local registry: any = core.registry

	-- Where each module sat before registration
	local parents: { [string]: any } = {}

	for _, path: string in MODULES do
		parents[path] = env.find(path).Parent
	end

	-- A half taken as a command throws here, since a half's module returns a function
	registry:registerCommandsIn(env.find(COMMANDS))

	local kill: any = registry:getCommand(NAME)
	if kill == nil or kill ~= env.require(KILL) or registry:getCommand(ALIAS) ~= kill then
		return false, "the kill command two folders down did not register by its name and alias"
	end

	if kill.run ~= env.require(KILL_SERVER) or registry:getDeviceHalf(NAME) ~= env.find(KILL_CLIENT) then
		return false, "the kill command was not paired with the halves beside it"
	end

	for path: string, parent: any in parents do
		if env.find(path).Parent ~= parent then
			return false, `{path} moved when it registered`
		end
	end

	return true, nil
end
