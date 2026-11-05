--[[
    The fail command's server half, which raises, so the dispatcher answers
    with its Error line and the server warns with this error
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

type Context = Decree.Context

return function (_: Context)
	error("[Dev] fail raised, as it always does")
end
