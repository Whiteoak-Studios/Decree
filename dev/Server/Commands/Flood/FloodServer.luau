--[[
    The flood command's server half: replies a capped count of numbered
    lines, each holding the config's filler, then answers how many went
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local FLOOD_LINES: number = require(ServerScriptService.Dev.Config.Admin).floodLines
local FLOOD_BYTES: number = require(ServerScriptService.Dev.Config.Admin).floodBytes
local FILL: string = "x"
local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (context: Context, count: number): (string, Kind)
	local lines: number = math.clamp(count, 1, FLOOD_LINES)
	local filler: string = FILL:rep(FLOOD_BYTES)

	for index = 1, lines do
		context:reply(`Line {index} of {lines}: {filler}`)
	end

	return `Flooded {lines} lines.`, OK
end
