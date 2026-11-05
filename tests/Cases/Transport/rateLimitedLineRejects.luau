--[[
    A line past the game's rate is refused by Volt before Decree's handler,
    and the caller's Promise rejects with rate limited
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")

local FIRST: string = "echo first"
local SECOND: string = "echo second"
local LIMITED: string = "rate limited"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree.registry:registerCommandObject(Echo())
	server.start({ rate = { perSecond = 1 } })

	-- Both go in the same frame, so the second finds the one-call allowance spent
	local first: any = server.client.Decree.run.invoke(FIRST)
	local second: any = server.client.Decree.run.invoke(SECOND)

	if not server.settle(first) or not server.settle(second) then
		return false, "the two calls never settled"
	end

	local resolved: boolean = first:await()
	local accepted: boolean, reason: string = second:await()
	if not resolved or accepted or reason ~= LIMITED then
		return false, `the first call resolved {resolved} and the second was answered {reason}`
	end

	return true, nil
end
