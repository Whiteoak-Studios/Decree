--[[
    A line's reply waits until every line its command printed for the
    caller has gone out, so the console has them all when the reply comes,
    those paced into a later flush included
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Flood = require("../../Fixtures/Server/Flood")

local LINES: number = 6
local SIZE: number = 16000 -- Enough that the lines take two flushes
local LINE: string = "flood"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree.registry:registerCommandObject(Flood(LINES, SIZE))
	server.start()

	local received: number = 0
	server.client.Decree.line.on(function ()
		received += 1
	end)

	local atReply: number? = nil
	local replied: any = server.client.Decree.run.invoke(LINE):andThen(function ()
		atReply = received
	end)

	if not server.settle(replied) then
		return false, "the reply never came"
	elseif atReply ~= LINES then
		return false, `the reply came when the console had {atReply} of {LINES} lines`
	end

	return true, nil
end
