--[[
    A definition whose name repeats a registered one in any case, or whose
    alias repeats another command's name, is refused, and the registered
    command keeps its name and aliases while the refused one gets none
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REPEATED: string = "Echo" -- echo's name in another case
local OLD_ALIAS: string = "say"
local NEW_ALIAS: string = "repeat"
local SHADOWED: string = "ping" -- A command's name that a later command takes as its alias
local SHADOWING: string = "pong"
local REPEATED_REFUSAL: string = `[Decree] Command "{REPEATED}" takes echo, which command "echo" already has`
local SHADOWING_REFUSAL: string =
	`[Decree] Command "{SHADOWING}" takes {SHADOWED}, which command "{SHADOWED}" already has`

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local first: { [string]: any } = Echo()
	local second: { [string]: any } = { name = REPEATED, aliases = { NEW_ALIAS }, args = {} }

	registry:registerCommandObject(first)

	local repeatedRegistered: boolean, repeatedError: any = pcall(registry.registerCommandObject, registry, second)
	if repeatedRegistered or Thrown(repeatedError) ~= REPEATED_REFUSAL then
		return false, `registering a repeated name gave {repeatedError}`
	end

	local commands: { any } = registry:getCommands()
	if #commands ~= 1 or commands[1] ~= first then
		return false, `getCommands listed {#commands} commands after a repeated name`
	end

	local byName: any = registry:getCommand(REPEATED)
	local byNewAlias: any = registry:getCommand(NEW_ALIAS)
	local byOldAlias: any = registry:getCommand(OLD_ALIAS)
	if byName ~= first or byNewAlias ~= nil or byOldAlias ~= first then
		return false, "the refused name took over the first command's name, or the first lost its alias"
	end

	local shadowed: { [string]: any } = { name = SHADOWED, args = {} }
	local shadowing: { [string]: any } = { name = SHADOWING, aliases = { SHADOWED }, args = {} }

	registry:registerCommandObject(shadowed)

	local shadowRegistered: boolean, shadowError: any = pcall(registry.registerCommandObject, registry, shadowing)
	if shadowRegistered or Thrown(shadowError) ~= SHADOWING_REFUSAL then
		return false, `an alias repeating another command's name gave {shadowError}`
	end

	local listed: { any } = registry:getCommands()
	if registry:getCommand(SHADOWED) ~= shadowed or registry:getCommand(SHADOWING) ~= nil or #listed ~= 2 then
		return false, "an alias repeating another command's name took over its lookup"
	end

	return true, nil
end
