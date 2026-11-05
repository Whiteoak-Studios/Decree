--[[
    A server half whose Promise is still pending after PENDING_SECONDS is
    answered with an Error line once those seconds are up, and not before,
    waiting out the real seconds
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")
local WaitFor = require("../../Fixtures/Core/WaitFor")

local PROMISE: string = "Packages/Promise"
local CONSTANTS: string = "src/DecreeClient/Shared/Constants"
local NAME: string = "hang"
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local ERROR: string = "Error"
local STARTED: string = "Started" -- Promise.Status.Started
local MARGIN: number = 3 -- Seconds past PENDING_SECONDS the case waits before it calls the line unanswered

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local Promise: any = core.env.require(PROMISE)
	local pending: number = core.env.require(CONSTANTS).PENDING_SECONDS

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): any
			return Promise.new(function () end)
		end,
	})

	local started: number = os.clock()
	local line: any = core.dispatcher:evaluateAndRun(NAME, core.env.player)

	local answered: boolean = WaitFor(function (): boolean
		return line:getStatus() ~= STARTED
	end, pending + MARGIN)

	local elapsed: number = os.clock() - started
	if not answered then
		return false, `the line was still unanswered after {elapsed} s`
	end

	local _, reply: string, kind: string = line:await()
	if reply ~= ERROR_REPLY or kind ~= ERROR then
		return false, `the pending server half answered {reply} as {kind}`
	end

	if elapsed < pending then
		return false, `the pending server half was answered after {elapsed} s, before {pending} s were up`
	end

	return true, nil
end
