--[[
    A fresh client core per call on a fresh client environment: the
    dispatcher bound to a ClientPort stand-in, and a run that gives a line's
    reply and kind once its Promise settles
--]]

--!strict
local ClientPort = require("./ClientPort")
local Environment = require("../../Environment")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local DISPATCHER: string = "src/DecreeClient/Shared/Dispatcher"
local PROMISE: string = "Packages/Promise"

export type Core = {
	env: any,
	registry: any,
	dispatcher: any,
	port: ClientPort.ClientPort,
	Promise: any, -- The environment's own Promise, which a case's device halves answer with
	run: (text: any) -> (string, string), -- A line's reply and kind, run as the LocalPlayer
}

return function (): Core
	local env: any = Environment.new({ side = "client" })
	local registry: any = env.require(REGISTRY)
	local dispatcher: any = env.require(DISPATCHER)
	local Promise: any = env.require(PROMISE)
	local port: ClientPort.ClientPort = ClientPort(Promise)

	dispatcher:bindClient(port)

	return {
		env = env,
		registry = registry,
		dispatcher = dispatcher,
		port = port,
		Promise = Promise,

		run = function (text: any): (string, string)
			local _, reply: string, kind: string = dispatcher:evaluateAndRun(text):await()

			return reply, kind
		end,
	}
end
