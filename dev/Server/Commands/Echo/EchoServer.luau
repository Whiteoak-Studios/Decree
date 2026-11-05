--[[
    The echo command's server half, which replies Ok with the text it is
    given, the reply a typed line or an autoExec line gets back
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (_: Context, text: string): (string, Kind)
	return text, OK
end
