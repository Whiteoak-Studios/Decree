--[[
    A fresh Decree server per call on a fresh environment, with the joined
    player's generated client module over the same mock, and the steps that
    move the mock until what a case waits on has happened
--]]

--!strict
local Environment = require("../../Environment")
local PassingHook = require("../Dispatcher/PassingHook")
local WaitFor = require("../Core/WaitFor")

local DECREE: string = "src"
local CLIENT: string = "src/DecreeClient/Network"
local BEFORE_RUN: string = "beforeRun"
local STARTED: string = "Started" -- Promise.Status.Started
local STEP_SECONDS: number = 5 -- Real seconds a case steps the mock for before it gives up on what it waits for
local PER_SECOND: number = 30 -- The rate start is given, room for every call a case makes in a frame

export type Decree = {
	env: any,
	decree: any, -- The server object src/init returns
	client: any, -- The joined player's generated client module
	step: (condition: () -> boolean) -> boolean, -- Steps the mock a frame at a time until the condition holds
	settle: (promise: any) -> boolean, -- Steps the mock until a Promise is no longer pending
	run: (line: string) -> (boolean, any, any), -- Sends a line and gives how its call settled: resolved, text, kind
	start: (settings: { [string]: any }?) -> (), -- A passing beforeRun hook, then start granting every command
}

--[[
    Grants every command to every player
--]]

local function grantAll(): boolean
	return true
end

return function (options: Environment.Options?): Decree -- The environment's options, such as the folders a case mounts
	local env: any = Environment.new(options)
	local decree: any = env.require(DECREE)
	local client: any = env.require(CLIENT)

	local function step(condition: () -> boolean): boolean
		return WaitFor(function (): boolean
			env.mock:step()

			return condition()
		end, STEP_SECONDS)
	end

	local function settle(promise: any): boolean
		return step(function (): boolean
			return promise:getStatus() ~= STARTED
		end)
	end

	return {
		env = env,
		decree = decree,
		client = client,
		step = step,
		settle = settle,

		run = function (line: string): (boolean, any, any)
			local replied: any = client.Decree.run.invoke(line)
			if not settle(replied) then
				return false, `{line} was never answered`, nil
			end

			return replied:await()
		end,

		start = function (settings: { [string]: any }?)
			local merged: { [string]: any } = { rate = { perSecond = PER_SECOND }, canAccess = grantAll }

			for key: string, value: any in settings or {} do
				merged[key] = value
			end

			decree.registry:registerHook(BEFORE_RUN, PassingHook)
			decree:start(merged)
		end,
	}
end
