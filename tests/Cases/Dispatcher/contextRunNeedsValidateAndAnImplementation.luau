--[[
    A context's getData gives nothing, its run refuses to start before its
    validate, and a command with no server half answers "No implementation."
    as Info, whether or not it holds a device half
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local COMMANDS: string = "tests/Fixtures/Core/Commands"
local INFO_COMMAND: string = `{COMMANDS}/ClientInfo` -- Holds a device half and no server half
local INFO_CLIENT: string = `{COMMANDS}/ClientInfoClient`
local BARE: string = "bare"
local INFO_NAME: string = "clientInfo"
local UNIMPLEMENTED: { string } = { BARE, INFO_NAME }
local UNVALIDATED: string = "[Decree] Must validate a command before running."
local NO_IMPLEMENTATION: string = "No implementation."
local INFO: string = "Info"

return function (): (boolean, string | nil)
	local core: Server.Core = Server({ folders = { COMMANDS } })
	local player: any = core.env.player
	local registry: any = core.registry

	registry:registerHook("beforeRun", PassingHook)
	registry:registerCommandObject({ name = BARE, args = {} })
	registry:registerCommand(core.env.find(INFO_COMMAND), nil, core.env.find(INFO_CLIENT))

	local context: any = core.dispatcher:evaluate(BARE, player)
	if context:getData() ~= nil then
		return false, "getData gave something"
	end

	local ran: boolean, problem: any = pcall(context.run, context)
	if ran or Thrown(problem) ~= UNVALIDATED then
		return false, `run before validate gave {problem}`
	end

	for _, name: string in UNIMPLEMENTED do
		local reply: string, kind: string = core.run(name, player)
		if reply ~= NO_IMPLEMENTATION or kind ~= INFO then
			return false, `{name}, with no server half, answered {reply} as {kind}`
		end
	end

	return true, nil
end
