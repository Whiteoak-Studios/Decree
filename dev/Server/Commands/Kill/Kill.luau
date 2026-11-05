--[[
    The kill command's definition, whose guard refuses a caller with no
    character before the server half runs
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

return {
	name = "kill",
	description = "Removes your character, so spawn gives you a new one.",
	group = "Player",
	args = {},
	guards = { Decree.guards.hasCharacter() },
}
