--[[
    A server half that returns a Promise is answered with the text and kind
    it resolves to, at once or after a wait, Info when it gives no kind, and
    with an Error line when it rejects
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local PROMISE: string = "Packages/Promise"
local NAME: string = "later"
local DONE: string = "Done"
local WAITED: string = "Waited"
local PLAIN: string = "Plain"
local PROBLEM: string = "Rejected by the case"
local DELAY: number = 0.1 -- Seconds the waiting half takes to resolve
local EXECUTED: string = "Command executed."
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local OK: string = "Ok"
local REFUSED: string = "Refused"
local INFO: string = "Info"
local ERROR: string = "Error"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local Promise: any = core.env.require(PROMISE)

	-- What the server half returns, which each step sets
	local answer: () -> any = function (): any
		return Promise.resolve(DONE, OK)
	end

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): any
			return answer()
		end,
	})

	local function run(): (string, string)
		return core.run(NAME, core.env.player)
	end

	local done: string, doneKind: string = run()
	if done ~= DONE or doneKind ~= OK then
		return false, `a resolved Promise answered {done} as {doneKind}`
	end

	answer = function (): any
		return Promise.delay(DELAY):andThen(function (): (string, string)
			return WAITED, REFUSED
		end)
	end

	local waited: string, waitedKind: string = run()
	if waited ~= WAITED or waitedKind ~= REFUSED then
		return false, `a Promise that resolved after a wait answered {waited} as {waitedKind}`
	end

	answer = function (): any
		return Promise.resolve(PLAIN)
	end

	local plain: string, plainKind: string = run()
	answer = function (): any
		return Promise.resolve()
	end

	local empty: string, emptyKind: string = run()
	if plain ~= PLAIN or plainKind ~= INFO or empty ~= EXECUTED or emptyKind ~= INFO then
		return false, `a Promise with no kind answered {plain} as {plainKind}, and one with nothing {empty}`
	end

	answer = function (): any
		return Promise.reject(PROBLEM)
	end

	local rejected: string, rejectedKind: string = run()
	if rejected ~= ERROR_REPLY or rejectedKind ~= ERROR then
		return false, `a rejected Promise answered {rejected} as {rejectedKind}`
	end

	return true, nil
end
