--[[
    A line past LINE_BYTES raises at the client's invoke, so nothing of it
    is sent and the server hears no message at all
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Environment = require("../../Environment")

local LINE_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").LINE_BYTES
local NETWORK: string = "src/Network"
local FILL: string = "a"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.start()

	if pcall(server.client.Decree.run.invoke, FILL:rep(LINE_BYTES + 1)) then
		return false, "invoke took a line past LINE_BYTES"
	end

	for _ = 1, Environment.ROUND_TRIP do
		server.env.mock:step()
	end

	local heard: number = server.env.require(NETWORK).stats(server.env.player).messagesIn
	if heard ~= 0 then
		return false, `the server heard {heard} messages from a client whose only line raised`
	end

	return true, nil
end
