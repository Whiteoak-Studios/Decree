--[[
    The wipe command's server half, which answers with the subcommand that
    ran and the shard it was given, so a confirmed line shows it ran whole
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind
type SubcommandDefinition = Decree.SubcommandDefinition

return function (context: Context, shard: number?): (string, Kind)
	local name: string = (context.subcommand :: SubcommandDefinition).name

	if shard then
		return `wipe {name} ran for shard {shard}.`, OK
	end

	return `wipe {name} ran.`, OK
end
