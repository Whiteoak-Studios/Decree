--[[
    The slow command's definition, a server half that waits on a Promise
    before it replies
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local SLOW_SECONDS: number = require(ServerScriptService.Dev.Config.Admin).slowSeconds

return {
	name = "slow",
	description = "Replies once a number of seconds have passed.",
	group = "Admin",
	system = "Timing",
	tags = { "Admin only" },
	args = {
		{ name = "seconds", type = "number", description = `How long to wait, at most {SLOW_SECONDS}` },
	},
}
