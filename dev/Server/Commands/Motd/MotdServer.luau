--[[
    The motd command's server half, which answers with the message of the
    day as an Info line
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local MOTD: string = require(ServerScriptService.Dev.Config.Admin).motd
local INFO: Kind = "Info"

type Context = Decree.Context
type Kind = Decree.Kind

return function (_: Context): (string, Kind)
	return MOTD, INFO
end
