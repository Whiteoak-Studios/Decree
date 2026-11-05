--[[
    The registry holds each registered definition once, in registration
    order, finds it by its name or an alias in any case, and lists the names
    as registered, with each command's aliases before it when asked
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Server = require("../../Fixtures/Core/Server")

local SHOUT: string = "Shout" -- Registered in mixed case, as is each of its aliases
local SHOUT_ALIASES: { string } = { "YELL", "Holler" }
local UNKNOWN: string = "whisper"
local SEPARATOR: string = ", " -- Joins the names in a failure's reason

-- Each word by the command getCommand finds for it, in either case
local FOUND: { [string]: string } = {
	echo = "echo",
	ECHO = "echo",
	say = "echo",
	SaY = "echo",
	shout = SHOUT,
	SHOUT = SHOUT,
	yell = SHOUT,
	holler = SHOUT,
	HOLLER = SHOUT,
}

local NAMES: { string } = { "echo", SHOUT }
local NAMES_WITH_ALIASES: { string } = { "say", "echo", "YELL", "Holler", SHOUT }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	if #registry:getCommands() ~= 0 then
		return false, `the registry started with {#registry:getCommands()} commands`
	end

	local echo: { [string]: any } = Echo()
	local shout: { [string]: any } = { name = SHOUT, aliases = SHOUT_ALIASES, args = {} }
	local byName: { [string]: { [string]: any } } = { echo = echo, [SHOUT] = shout }

	registry:registerCommandObject(echo)
	registry:registerCommandObject(shout)

	for word: string, name: string in FOUND do
		if registry:getCommand(word) ~= byName[name] then
			return false, `getCommand did not find {name} by {word}`
		end
	end

	if registry:getCommand(UNKNOWN) ~= nil then
		return false, "getCommand found a command by a word that names none"
	end

	local commands: { any } = registry:getCommands()
	if #commands ~= 2 or commands[1] ~= echo or commands[2] ~= shout then
		return false, `getCommands listed {#commands} commands, not each definition once in order`
	end

	local names: string = table.concat(registry:getCommandNames(), SEPARATOR)
	local withAliases: string = table.concat(registry:getCommandNames(true), SEPARATOR)
	if names ~= table.concat(NAMES, SEPARATOR) or withAliases ~= table.concat(NAMES_WITH_ALIASES, SEPARATOR) then
		return false, `getCommandNames listed {names}, and with aliases {withAliases}`
	end

	return true, nil
end
