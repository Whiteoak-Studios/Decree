--[[
    A reply waits for the caller's earlier lines only until its deadline,
    so it still arrives inside run's timeout while a line queued ahead of
    it is held in a filter, and that line follows once the filter answers
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local WaitFor = require("../../Fixtures/Core/WaitFor")

local PROMISE: string = "Packages/Promise"
local SECOND: string = "Second"
local TELL: string = "tell"
local LINE: string = "echo still here"
local REPLY: string = "still here"
local HELD: string = "Held by the filter"
local ADD_LINE: string = "AddLine"
local STARTED: string = "Started" -- Promise.Status.Started
local WAIT_SECONDS: number = 12 -- Real seconds the case steps for the reply, past run's 10-second timeout

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local caller: any = server.env.player
	local second: any = server.env.mock:join(SECOND)
	local Promise: any = server.env.require(PROMISE)

	-- The filter answers only once the case opens the gate, holding the caller's queue until then
	local open: (() -> ())? = nil
	local gate: any = Promise.new(function (resolve: () -> ())
		open = resolve
	end)

	server.env.game:GetService("TextService").filter = function (text: string): string
		gate:await()

		return text
	end

	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerCommandObject({
		name = TELL,
		args = {},

		run = function (context: any): string
			context:sendEvent(caller, ADD_LINE, HELD)

			return HELD
		end,
	})

	server.start()

	local heard: string? = nil
	server.client.Decree.line.on(function (text: string)
		heard = text
	end)

	-- Another player's command queues a line for the caller, which waits in the filter
	server.decree.dispatcher:evaluateAndRun(TELL, second)

	local replied: any = server.client.Decree.run.invoke(LINE)
	local settled: boolean = WaitFor(function (): boolean
		server.env.mock:step()

		return replied:getStatus() ~= STARTED
	end, WAIT_SECONDS)

	local resolved: boolean, text: string = replied:await()
	if not settled or not resolved or text ~= REPLY then
		return false, `the line was answered {text} where its reply goes ahead of the held line`
	elseif heard ~= nil then
		return false, "the held line arrived before the reply that went ahead of it"
	end

	local release: () -> () = open :: () -> ()
	release()

	local followed: boolean = server.step(function (): boolean
		return heard == HELD
	end)

	if not followed then
		return false, "the held line never followed the reply"
	end

	return true, nil
end
