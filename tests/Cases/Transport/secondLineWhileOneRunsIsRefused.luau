--[[
    A player has one line on the server at a time: a second line while a
    command still waits on its Promise is refused at once, and the first
    still answers once its Promise settles
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")

local PROMISE: string = "Packages/Promise"
local SLOW: string = "slow"
local QUICK: string = "echo quick"
local SETTLED: string = "Settled at last"
local BUSY: string = "Wait for your last command to finish."
local REFUSED: string = "Refused"
local STARTED: string = "Started" -- Promise.Status.Started

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local Promise: any = server.env.require(PROMISE)
	local finish: ((text: string) -> ())? = nil

	server.decree.registry:registerCommandObject(Echo())
	server.decree.registry:registerCommandObject({
		name = SLOW,
		args = {},

		run = function (_: any): any
			return Promise.new(function (resolve: (text: string) -> ())
				finish = resolve
			end)
		end,
	})

	server.start()

	-- Both go in the same frame, the second reaching the server while the first waits
	local slow: any = server.client.Decree.run.invoke(SLOW)
	local quick: any = server.client.Decree.run.invoke(QUICK)

	if not server.settle(quick) then
		return false, "the second line was never answered"
	end

	local _, refusal: string, kind: string = quick:await()
	if refusal ~= BUSY or kind ~= REFUSED then
		return false, `the second line was answered {refusal} as {kind}`
	elseif slow:getStatus() ~= STARTED or not finish then
		return false, "the first line was answered before its Promise settled"
	end

	finish(SETTLED)

	if not server.settle(slow) then
		return false, "the first line was never answered"
	end

	local _, text: string = slow:await()
	if text ~= SETTLED then
		return false, `the first line was answered {text}`
	end

	return true, nil
end
