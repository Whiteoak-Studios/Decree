--[[
    getCommandNames lists every command's name in registration order, each
    after its aliases when asked, and with an executor on the server only
    the commands the access check says that player holds
--]]

--!strict
local Entry = require("../../Fixtures/Core/Entry")
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")
local Server = require("../../Fixtures/Core/Server")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local KICK: { [string]: any } = { name = "kick", aliases = { "boot", "punt" }, args = {} }
local GREET: { [string]: any } = { name = "greet", args = {} }
local BAN: { [string]: any } = { name = "ban", aliases = { "exile" }, args = {} }
local DEFINITIONS: { { [string]: any } } = { KICK, GREET, BAN }
local WITHHELD: string = "greet"
local NAMES: { string } = { "kick", "greet", "ban" }
local WITH_ALIASES: { string } = { "boot", "punt", "kick", "greet", "exile", "ban" }
local HELD: { string } = { "kick", "ban" }
local HELD_WITH_ALIASES: { string } = { "boot", "punt", "kick", "exile", "ban" }
local SEPARATOR: string = ", " -- Joins a list of names in a failure message

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry
	local player: any = core.env.player
	local asked: { any } = {} -- Each player the access check was asked about

	for _, definition: { [string]: any } in DEFINITIONS do
		registry:registerCommandObject(definition)
	end

	core.access.withheld[WITHHELD] = true

	local holds = core.access.holds
	core.access.holds = function (holder: any, definition: any): boolean
		table.insert(asked, holder)

		return holds(holder, definition)
	end

	local names: { string } = registry:getCommandNames()
	local withAliases: { string } = registry:getCommandNames(true)
	if not Listed(names, NAMES) or not Listed(withAliases, WITH_ALIASES) or #asked ~= 0 then
		return false, `with no executor getCommandNames gave {table.concat(withAliases, SEPARATOR)}`
	end

	local held: { string } = registry:getCommandNames(false, player)
	local heldWithAliases: { string } = registry:getCommandNames(true, player)
	if not Listed(held, HELD) or not Listed(heldWithAliases, HELD_WITH_ALIASES) then
		return false, `for the executor getCommandNames gave {table.concat(heldWithAliases, SEPARATOR)}`
	end

	for _, holder: any in asked do
		if holder ~= player then
			return false, "the access check was asked about someone other than the executor"
		end
	end

	-- A client's list is the player's own already, so it keeps every name
	local client: any = Environment.new({ side = "client" }).require(REGISTRY)
	client:replaceCommands({ Entry(KICK), Entry(GREET), Entry(BAN) })

	local clientNames: { string } = client:getCommandNames(true, player)
	if not Listed(clientNames, WITH_ALIASES) then
		return false, `on a client getCommandNames gave {table.concat(clientNames, SEPARATOR)}`
	end

	return true, nil
end
