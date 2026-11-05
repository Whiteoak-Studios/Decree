--[[
    A fresh server core per call on a fresh environment: the registry bound
    to an Access stand-in and the dispatcher to a ServerPort stand-in, and a
    run that gives a line's reply and kind once its Promise settles
--]]

--!strict
local Access = require("./Access")
local Environment = require("../../Environment")
local ServerPort = require("./ServerPort")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local DISPATCHER: string = "src/DecreeClient/Shared/Dispatcher"

export type Core = {
	env: any,
	registry: any,
	dispatcher: any,
	access: Access.Access,
	port: ServerPort.ServerPort,
	run: (text: any, executor: any) -> (string, string), -- A line's reply and kind, run as the executor
}

return function (options: Environment.Options?): Core -- The environment's options, such as the folders a case mounts
	local env: any = Environment.new(options)
	local registry: any = env.require(REGISTRY)
	local dispatcher: any = env.require(DISPATCHER)
	local access: Access.Access = Access()
	local port: ServerPort.ServerPort = ServerPort()

	registry:bind(access)
	dispatcher:bindServer(port)

	return {
		env = env,
		registry = registry,
		dispatcher = dispatcher,
		access = access,
		port = port,

		run = function (text: any, executor: any): (string, string)
			local _, reply: string, kind: string = dispatcher:evaluateAndRun(text, executor):await()

			return reply, kind
		end,
	}
end
