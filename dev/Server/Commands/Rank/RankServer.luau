--[[
    The rank command's server half: sets the target's rank attribute, which
    the gate reads, then has Decree work out their commands again
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local RANK: string = require(ServerScriptService.Dev.Config.Admin).rankAttribute
local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (context: Context, target: Player, rank: number): (string, Kind)
	target:SetAttribute(RANK, rank)
	context.decree:refreshAccess(target)

	return `{target.Name} holds rank {rank} now.`, OK
end
