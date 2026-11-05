--[[
    When refreshAccess takes a command away from a player, the clone of its
    device half in their DecreeCommands ScreenGui is destroyed
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local COMMANDS: string = "tests/Fixtures/Core/Commands"
local KILL_CLIENT: string = "killClient" -- The kill command's clone, named for the command
local COMMANDS_GUI: string = "DecreeCommands"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree({ folders = { COMMANDS } })
	local player: any = server.env.player
	local granted: boolean = true

	server.decree.registry:registerCommandsIn(server.env.find(COMMANDS))
	server.start({
		canAccess = function (): boolean
			return granted
		end,
	})

	local gui: any = player.PlayerGui:FindFirstChild(COMMANDS_GUI)
	local clone: any = gui and gui:FindFirstChild(KILL_CLIENT)
	if not clone then
		return false, "the granted command's device half was never cloned"
	end

	granted = false
	server.decree:refreshAccess(player)

	if clone.Parent ~= nil or gui:FindFirstChild(KILL_CLIENT) then
		return false, "the revoked command's device half is still in the player's ScreenGui"
	end

	return true, nil
end
