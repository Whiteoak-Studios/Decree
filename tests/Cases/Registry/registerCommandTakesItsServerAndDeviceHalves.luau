--[[
    registerCommand registers the definition a module returns, with its
    server half's module as its run and its device half's module kept, and
    refuses a module that returns anything but a table
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local COMMANDS: string = "tests/Fixtures/Core/Commands"
local NOT_TABLES: string = "tests/Fixtures/Core/NotTables"
local KILL: string = `{COMMANDS}/Moderation/Kill/Kill`
local KILL_SERVER: string = `{COMMANDS}/Moderation/Kill/KillServer`
local KILL_CLIENT: string = `{COMMANDS}/Moderation/Kill/KillClient`
local STATUS: string = `{COMMANDS}/Status/ServerStatus` -- Registered here without its halves
local TEXT: string = `{NOT_TABLES}/Text`
local KILL_NAME: string = "kill"
local STATUS_NAME: string = "serverStatus"
local KILLED: string = "Killed on the server"
local INFO: string = "Info"
local TEXT_REFUSAL: string =
	`[Decree] Invalid return value from command script "Text" (CommandDefinition expected, got string)`

return function (): (boolean, string | nil)
	local core: Server.Core = Server({ folders = { COMMANDS, NOT_TABLES } })
	local env: any = core.env
	local registry: any = core.registry

	registry:registerHook("beforeRun", PassingHook)
	registry:registerCommand(env.find(KILL), env.find(KILL_SERVER), env.find(KILL_CLIENT))

	local kill: any = registry:getCommand(KILL_NAME)
	if kill == nil or kill ~= env.require(KILL) or kill.run ~= env.require(KILL_SERVER) then
		return false, "the kill definition did not register with its server half as its run"
	end

	if registry:getDeviceHalf(KILL_NAME) ~= env.find(KILL_CLIENT) then
		return false, "the kill definition did not keep its device half's module"
	end

	local reply: string, kind: string = core.run(KILL_NAME, env.player)
	if reply ~= KILLED or kind ~= INFO then
		return false, `the kill command answered {reply} as {kind}`
	end

	registry:registerCommand(env.find(STATUS))

	local status: any = registry:getCommand(STATUS_NAME)
	if status ~= env.require(STATUS) or status.run ~= nil or registry:getDeviceHalf(STATUS_NAME) ~= nil then
		return false, "a module registered without halves gained a run or a device half"
	end

	local registered: boolean, problem: any = pcall(registry.registerCommand, registry, env.find(TEXT))
	if registered or Thrown(problem) ~= TEXT_REFUSAL then
		return false, `a module that returns text gave {problem}`
	end

	return true, nil
end
