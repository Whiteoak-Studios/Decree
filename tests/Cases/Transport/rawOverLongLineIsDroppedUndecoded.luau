--[[
    A raw client's run carrying more than LINE_BYTES is a decode failure,
    which reaches the game's onFailure, before Decree's handler or any hook
    runs, so no reply ever comes back
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Environment = require("../../Environment")
local RawClient = require("../../Fixtures/Server/RawClient")

local LINE_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").LINE_BYTES
local RAW: string = "Raw"
local PREFIX: string = "echo "
local FILL: string = "a"
local DECODE: string = "decode"
local RUN: string = "Decree.run: "
local BEFORE_RUN: string = "beforeRun"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local failures: { { any } } = {}
	local hooked: number = 0

	server.decree.registry:registerHook(BEFORE_RUN, function (_: any): string?
		hooked += 1

		return nil
	end)

	server.start({
		onFailure = function (player: any, kind: string, detail: string)
			table.insert(failures, { player, kind, detail })
		end,
	})

	local player: any, transport: any = server.env.mock:join(RAW)
	local raw: RawClient.RawClient = RawClient(transport)
	raw.run(`{PREFIX}{FILL:rep(LINE_BYTES + 1 - #PREFIX)}`)

	for _ = 1, Environment.ROUND_TRIP do
		server.env.mock:step()
	end

	local failure: { any }? = failures[1]
	if not failure or failure[1] ~= player or failure[2] ~= DECODE or failure[3]:sub(1, #RUN) ~= RUN then
		return false, "the over-long run reached the game as no decode failure named for Decree.run"
	elseif hooked ~= 0 then
		return false, "the over-long run reached the beforeRun hook"
	elseif #raw.received ~= 0 then
		return false, `the raw client was sent {#raw.received} packets for a run that never decoded`
	end

	return true, nil
end
