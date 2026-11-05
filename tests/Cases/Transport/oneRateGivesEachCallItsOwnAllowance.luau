--[[
    The game's one rate applies to run and to commands, each with its own
    allowance: in one frame, run takes its burst and is refused past it,
    while commands still takes a burst of its own past the schema's
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")

local BURST: number = 2 -- Past the schema's own burst of 1 for commands
local LINE: string = "echo again"
local STARTED: string = "Started" -- Promise.Status.Started
local RESOLVED: string = "Resolved" -- Promise.Status.Resolved
local REJECTED: string = "Rejected" -- Promise.Status.Rejected

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree.registry:registerCommandObject(Echo())
	server.start({ rate = { perSecond = 1, burst = BURST } })

	-- Every call goes in the same frame, so each finds only its burst
	local runs: { any } = {}
	local lists: { any } = {}

	for _ = 1, BURST + 1 do
		local run: any = server.client.Decree.run.invoke(LINE)
		table.insert(runs, run)
	end

	for _ = 1, BURST do
		local list: any = server.client.Decree.commands.invoke()
		table.insert(lists, list)
	end

	local settled: boolean = server.step(function (): boolean
		return runs[#runs]:getStatus() ~= STARTED and lists[#lists]:getStatus() ~= STARTED
	end)

	if not settled then
		return false, "the calls never settled"
	end

	for index: number, run: any in runs do
		local expected: string = index <= BURST and RESOLVED or REJECTED
		if run:getStatus() ~= expected then
			return false, `run call {index} was {run:getStatus()}, not {expected}`
		end
	end

	for index: number, list: any in lists do
		if list:getStatus() ~= RESOLVED then
			return false, `commands call {index} was {list:getStatus()} beside run's spent allowance`
		end
	end

	return true, nil
end
