--[[
    The slow command's server half, a Promise that resolves with its reply
    once the seconds asked for, capped by the config, have passed
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Decree = require(ServerScriptService.ServerPackages.Decree)

local SLOW_SECONDS: number = require(ServerScriptService.Dev.Config.Admin).slowSeconds
local OK: Kind = "Ok"

type Context = Decree.Context
type Kind = Decree.Kind

return function (_: Context, seconds: number): any
	local waited: number = math.clamp(seconds, 0, SLOW_SECONDS)

	return Promise.delay(waited):andThen(function (): (string, Kind)
		return `Replied after {waited} seconds.`, OK
	end)
end
