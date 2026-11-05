--[[
    A granted command's device half is cloned into the player's
    DecreeCommands ScreenGui, ResetOnSpawn off, named for the command
    whatever its module is called, and a withheld command's half is not
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local COMMANDS: string = "tests/Fixtures/Server/Commands"
local WARP_CLIENT: string = `{COMMANDS}/WarpClient` -- The teleport command's half, named after its module, Warp
local SHOUT_CLIENT: string = `{COMMANDS}/ShoutClient`
local TELEPORT: string = "teleport"
local CLONE_NAME: string = "teleportClient" -- The command's name and Client, which the console finds it by
local WITHHELD_NAME: string = "shoutClient"
local COMMANDS_GUI: string = "DecreeCommands"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree({ folders = { COMMANDS } })
	local original: any = server.env.find(WARP_CLIENT)
	local withheld: any = server.env.find(SHOUT_CLIENT)
	local parent: any = original.Parent

	server.decree.registry:registerCommandsIn(server.env.find(COMMANDS))
	server.start({
		canAccess = function (_: any, command: any): boolean
			return command.name == TELEPORT
		end,
	})

	local gui: any = server.env.player.PlayerGui:FindFirstChild(COMMANDS_GUI)
	if not gui or not gui:IsA("ScreenGui") or gui.ResetOnSpawn then
		return false, "the player has no DecreeCommands ScreenGui with ResetOnSpawn off"
	end

	local clone: any = gui:FindFirstChild(CLONE_NAME)
	if not clone or clone == original or clone.Source ~= original.Source then
		return false, `the granted command's device half was not cloned into the ScreenGui as {CLONE_NAME}`
	elseif gui:FindFirstChild(original.Name) then
		return false, "the clone kept its module's name instead of the command's"
	elseif gui:FindFirstChild(WITHHELD_NAME) or gui:FindFirstChild(withheld.Name) then
		return false, "the half of a command the player does not hold was cloned to them"
	elseif original.Parent ~= parent then
		return false, "the device half itself moved instead of being cloned"
	end

	return true, nil
end
