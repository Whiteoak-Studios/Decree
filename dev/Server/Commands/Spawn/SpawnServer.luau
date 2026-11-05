--[[
    The spawn command's server half, a Promise that loads the caller's
    character and answers once it is in the world
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Decree = require(ServerScriptService.ServerPackages.Decree)

local SPAWNED: string = "Your character is loaded."
local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (context: Context): any
	local player: Player = context.executor

	-- LoadCharacterAsync yields, and Decree answers Error if this is still pending once its window passes
	return Promise.try(function (): (string, Kind)
		player:LoadCharacterAsync()

		return SPAWNED, OK
	end)
end
