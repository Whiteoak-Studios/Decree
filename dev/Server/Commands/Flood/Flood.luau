--[[
    The flood command's definition, a burst of long lines past what one
    frame carries, so Decree's pacing shows
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local FLOOD_LINES: number = require(ServerScriptService.Dev.Config.Admin).floodLines

return {
	name = "flood",
	description = "Replies with a number of long lines in one go.",
	group = "Admin",
	system = "Transport",
	tags = { "Admin only" },
	args = {
		{ name = "count", type = "integer", description = `How many lines, at most {FLOOD_LINES}` },
	},
}
