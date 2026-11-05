--[[
    The kill command's server half, which removes the caller's character so
    that spawn can give them a new one
--]]

--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local KILLED: string = "Your character is gone. Type spawn for a new one."
local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (context: Context): (string, Kind)
	-- The hasCharacter guard has already refused a caller with no character
	local character = context.executor.Character :: Model
	character:Destroy()

	return KILLED, OK
end
