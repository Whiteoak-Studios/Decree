--[[
    On a client replaceCommands turns each entry of the server's list into
    a command holding no code or default, then drops each command the next
    list leaves out with its aliases, and on the server it refuses to run
--]]

--!strict
local Client = require("../../Fixtures/Core/Client")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Entry = require("../../Fixtures/Core/Entry")
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local ECHO: string = "echo"
local SAY: string = "SAY" -- echo's alias, in another case
local KICK_NAME: string = "kick"
local KICK_ALIAS: string = "boot"
local WIPE_NAME: string = "wipe"
local SYSTEM: string = "Moderation"
local TAGS: { string } = { "admin" }
local REASON: string = "No reason given" -- The default the server keeps
local SERVER_REFUSAL: string = "[Decree] replaceCommands runs on the client, which takes the server's list."
local NAMES: { string } = { ECHO, KICK_NAME, WIPE_NAME }
local LEFT: { string } = { "say", ECHO } -- getCommandNames(true) once kick and wipe have left
local SEPARATOR: string = ", " -- Joins a list of names in a failure message
local SHARD: { [string]: any } = { name = "shard", type = "integer" }
local NOW: { [string]: any } = { name = "now", description = "Wipes the shard now", args = { SHARD } }

local KICK: { [string]: any } = {
	name = KICK_NAME,
	aliases = { KICK_ALIAS },
	system = SYSTEM,
	tags = TAGS,
	args = {
		{ name = "target", type = "player", description = "Who leaves" },
		{ name = "reason", type = "string", default = REASON },
	},
}

local WIPE: { [string]: any } = { name = WIPE_NAME, subcommands = { NOW } }

-- What echo's one argument holds on the client
local TEXT_ARGUMENT: { [string]: any } = {
	name = "text",
	type = "string",
	description = "What is answered",
	optional = false,
}

--[[
    Whether a table holds exactly the expected keys and values
--]]

local function holds(actual: { [string]: any }, expected: { [string]: any }): boolean
	for key: string, value: any in expected do
		if actual[key] ~= value then
			return false
		end
	end

	for key: string in actual do
		if expected[key] == nil then
			return false
		end
	end

	return true
end

return function (): (boolean, string | nil)
	local core: Client.Core = Client()
	local registry: any = core.registry
	local echoDefinition: { [string]: any } = Echo()

	registry:replaceCommands({ Entry(echoDefinition), Entry(KICK), Entry(WIPE) })

	local listed: { string } = {}

	for _, definition: any in registry:getCommands() do
		table.insert(listed, definition.name)
	end

	if not Listed(listed, NAMES) then
		return false, `the client holds {table.concat(listed, SEPARATOR)}`
	end

	local echo: any = registry:getCommand(SAY)
	if
		echo == nil
		or echo.name ~= ECHO
		or not Listed(echo.aliases, echoDefinition.aliases)
		or echo.description ~= echoDefinition.description
		or echo.group ~= echoDefinition.group
		or echo.run ~= nil
		or #echo.args ~= 1
		or not holds(echo.args[1], TEXT_ARGUMENT)
	then
		return false, "echo did not arrive with its name, aliases, description, group and argument, and no run"
	end

	local kick: any = registry:getCommand(KICK_NAME)
	local reason: any = kick and kick.args[2]
	if not kick or kick.system ~= SYSTEM or not Listed(kick.tags, TAGS) or not reason then
		return false, "kick did not arrive with its system, tags and arguments"
	end

	if reason.optional ~= true or reason.default ~= nil then
		return false, "an argument with a default arrived without optional, or with the default the server keeps"
	end

	local wipe: any = registry:getCommand(WIPE_NAME)
	local now: any = wipe and wipe.subcommands[1]
	if not now or now.name ~= NOW.name or now.description ~= NOW.description then
		return false, "wipe did not arrive with its subcommand"
	end

	if #now.args ~= 1 or now.args[1].name ~= SHARD.name or now.args[1].type ~= SHARD.type then
		return false, "wipe's subcommand did not arrive with its argument"
	end

	registry:replaceCommands({ Entry(echoDefinition) })

	if registry:getCommand(KICK_NAME) ~= nil or registry:getCommand(KICK_ALIAS) ~= nil then
		return false, "kick or its alias stayed once the list left kick out"
	end

	local names: { string } = registry:getCommandNames(true)
	if registry:getCommand(WIPE_NAME) ~= nil or #registry:getCommands() ~= 1 or not Listed(names, LEFT) then
		return false, `the client held {table.concat(names, SEPARATOR)} once kick and wipe left`
	end

	local server: any = Environment.new().require(REGISTRY)

	local replaced: boolean, problem: any = pcall(server.replaceCommands, server, { Entry(echoDefinition) })
	if replaced or Thrown(problem) ~= SERVER_REFUSAL or server:getCommand(ECHO) ~= nil then
		return false, `replaceCommands on the server gave {problem}`
	end

	return true, nil
end
