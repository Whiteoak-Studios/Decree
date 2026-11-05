--[[
    The hang command's server half, a Promise that never settles, which
    Decree's own pending deadline answers with an Error line
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Decree = require(ServerScriptService.ServerPackages.Decree)

type Context = Decree.Context

return function (_: Context): any
	-- Decree's pending window is its deadline, whose timeout cancels it and answers Error
	return Promise.new(function () end)
end
