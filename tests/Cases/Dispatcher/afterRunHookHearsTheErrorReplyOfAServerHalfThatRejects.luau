--[[
    An afterRun hook hears a server half whose Promise rejects, once, with
    the Error reply as the context's response, and the line answers that reply
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local PROMISE: string = "Packages/Promise"
local NAME: string = "later"
local PROBLEM: string = "Rejected by the case"
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local ERROR: string = "Error"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local Promise: any = core.env.require(PROMISE)
	local heard: number = 0
	local response: any = nil -- What the afterRun hook read as the context's response

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerHook("afterRun", function (context: any): string?
		heard += 1
		response = context.response

		return nil
	end)

	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): any
			return Promise.reject(PROBLEM)
		end,
	})

	local reply: string, kind: string = core.run(NAME, core.env.player)
	if heard ~= 1 or response ~= ERROR_REPLY then
		return false, `the afterRun hook heard the rejecting half {heard} times, reading {response}`
	end

	if reply ~= ERROR_REPLY or kind ~= ERROR then
		return false, `the rejecting half answered {reply} as {kind}`
	end

	return true, nil
end
