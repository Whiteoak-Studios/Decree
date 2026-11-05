--[[
    getDeviceHalf gives the device half's module a command registered with,
    found by its name or an alias in any case, nil for a command with none
    or no command, and refuses to run on a client
--]]

--!strict
local Environment = require("../../Environment")
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local COMMANDS: string = "tests/Fixtures/Core/Commands"
local KILL: string = `{COMMANDS}/Moderation/Kill/Kill`
local KILL_CLIENT: string = `{COMMANDS}/Moderation/Kill/KillClient`
local WORDS: { string } = { "kill", "KILL", "slay", "Slay" } -- kill's name and alias, in two cases each
local BARE: string = "bare" -- Registered with no device half
local NOBODY: string = "nobody"
local CLIENT_REFUSAL: string = "[Decree] Device halves stay on the server, which clones them out."

return function (): (boolean, string | nil)
	local core: Server.Core = Server({ folders = { COMMANDS } })
	local registry: any = core.registry
	local half: any = core.env.find(KILL_CLIENT)

	registry:registerCommand(core.env.find(KILL), nil, half)
	registry:registerCommandObject({ name = BARE, args = {} })

	for _, word: string in WORDS do
		if registry:getDeviceHalf(word) ~= half then
			return false, `getDeviceHalf did not find kill's device half by {word}`
		end
	end

	if registry:getDeviceHalf(BARE) ~= nil or registry:getDeviceHalf(NOBODY) ~= nil then
		return false, "getDeviceHalf found a half for a command with none, or for no command"
	end

	local client: any = Environment.new({ side = "client" }).require(REGISTRY)

	local found: boolean, problem: any = pcall(client.getDeviceHalf, client, BARE)
	if found or Thrown(problem) ~= CLIENT_REFUSAL then
		return false, `getDeviceHalf on a client gave {problem}`
	end

	return true, nil
end
