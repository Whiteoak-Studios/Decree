--[[
    The longline command's server half: a reply of exactly the config's
    character count, filler then a marker, every character one byte
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local CHARACTERS: number = require(ServerScriptService.Dev.Config.Admin).longLineCharacters
local FILL: string = "x"
local MARKER: string = "[longline ends here]"
local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (_: Context): (string, Kind)
	return `{FILL:rep(CHARACTERS - #MARKER)}{MARKER}`, OK
end
