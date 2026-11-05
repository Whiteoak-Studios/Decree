--[[
    A command's lines go out at most FRAME_BYTES between two of Volt's
    flushes to their recipient: what passes it waits for the next flush,
    and every line still arrives
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Flood = require("../../Fixtures/Server/Flood")

local FRAME_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").FRAME_BYTES
local LINES: number = 6
local SIZE: number = 16000 -- Six of these pass FRAME_BYTES, and four fit it
local LINE: string = "flood"
local STARTED: string = "Started" -- Promise.Status.Started

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree.registry:registerCommandObject(Flood(LINES, SIZE))
	server.start()

	local received: number = 0
	local stepBytes: number = 0 -- The bytes of lines the client heard in the step being counted
	local perStep: { number } = {}

	server.client.Decree.line.on(function (text: string)
		received += 1
		stepBytes += #text
	end)

	local replied: any = server.client.Decree.run.invoke(LINE)

	local done: boolean = server.step(function (): boolean
		table.insert(perStep, stepBytes)
		stepBytes = 0

		return received == LINES and replied:getStatus() ~= STARTED
	end)

	if not done then
		return false, `the client heard {received} of {LINES} lines`
	end

	for step: number, bytes: number in perStep do
		if bytes > FRAME_BYTES then
			return false, `step {step} carried {bytes} bytes of lines, past FRAME_BYTES`
		end
	end

	return true, nil
end
