--[[
    The motd command's definition, whose autoExec line runs echo once the
    console receives it
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local MOTD: string = require(ServerScriptService.Dev.Config.Admin).motd

return {
	name = "motd",
	description = "Shows the message of the day, which also prints when your console starts.",
	group = "Player",
	args = {},
	autoExec = { `echo {MOTD}` },
}
