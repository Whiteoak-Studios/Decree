--[[
    The whisper command's server half: sends the text as a line to the
    target's console, which Decree filters for anyone but the caller
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local ADD_LINE: string = "AddLine" -- The one event the server sends, a line in that player's console
local INFO: Kind = "Info"
local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (context: Context, target: Player, text: string): (string, Kind)
	context:sendEvent(target, ADD_LINE, `{context.executor.Name} whispers: {text}`, INFO)

	return `Sent to {target.Name}.`, OK
end
