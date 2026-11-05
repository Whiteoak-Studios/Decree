--[[
    An afterRun hook that returns anything but nil for a server half that
    raises or rejects replaces the Error reply with that value as Info text
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local PROMISE: string = "Packages/Promise"
local RAISING: string = "fail"
local REJECTING: string = "later"
local FAILURE: string = "Thrown by the case"
local PROBLEM: string = "Rejected by the case"
local REPLACED: string = "Logged and replaced"
local INFO: string = "Info"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local Promise: any = core.env.require(PROMISE)

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerHook("afterRun", function (): string
		return REPLACED
	end)

	core.registry:registerCommandObject({
		name = RAISING,
		args = {},

		run = function (): ()
			error(FAILURE)
		end,
	})

	core.registry:registerCommandObject({
		name = REJECTING,
		args = {},

		run = function (): any
			return Promise.reject(PROBLEM)
		end,
	})

	local raised: string, raisedKind: string = core.run(RAISING, core.env.player)
	if raised ~= REPLACED or raisedKind ~= INFO then
		return false, `a replacing hook answered the raising half {raised} as {raisedKind}`
	end

	local rejected: string, rejectedKind: string = core.run(REJECTING, core.env.player)
	if rejected ~= REPLACED or rejectedKind ~= INFO then
		return false, `a replacing hook answered the rejecting half {rejected} as {rejectedKind}`
	end

	return true, nil
end
