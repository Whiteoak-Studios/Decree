--[[
    A listed command's system and tags reach the console's registry with
    its aliases and its arguments' type names, so a game's help can show
    them
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")
local Entry = require("../../Fixtures/Core/Entry")
local Listed = require("../../Fixtures/Parser/Listed")

local NAME: string = "wipe"
local SYSTEM: string = "Shards"
local TAGS: { string } = { "Studio only", "Mike only, even in Studio" }
local ALIASES: { string } = { "reset" }
local TYPE: string = "integer"

return function (): (boolean, string | nil)
	local console: Console.Console = Console()

	console.server.Decree.commands.on(function (_: any): { any }
		return {
			Entry({
				name = NAME,
				system = SYSTEM,
				tags = TAGS,
				aliases = ALIASES,
				args = { { name = "shard", type = TYPE } },
			}),
		}
	end)

	console.listen()
	console.step()

	local definition: any = console.registry:getCommand(NAME)
	if not definition then
		return false, `the console does not hold {NAME}`
	end

	if definition.system ~= SYSTEM or not Listed(definition.tags, TAGS) then
		return false, `{NAME} reached the registry with the system {definition.system} and other tags`
	end

	if not Listed(definition.aliases, ALIASES) or definition.args[1].type ~= TYPE then
		return false, `{NAME} reached the registry without its aliases or its argument's type name`
	end

	return true, nil
end
