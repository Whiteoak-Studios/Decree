--[[
    On a client a device half whose Promise is still pending after
    PENDING_SECONDS is answered with an Error line once those seconds are
    up, and not before, and its line never goes to the server
--]]

--!strict
local Client = require("../../Fixtures/Core/Client")
local Entry = require("../../Fixtures/Core/Entry")
local WaitFor = require("../../Fixtures/Core/WaitFor")

local CONSTANTS: string = "src/DecreeClient/Shared/Constants"
local NAME: string = "hang"
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local ERROR: string = "Error"
local STARTED: string = "Started" -- Promise.Status.Started
local MARGIN: number = 3 -- Seconds past PENDING_SECONDS the case waits before it calls the line unanswered

return function (): (boolean, string | nil)
	local core: Client.Core = Client()
	local pending: number = core.env.require(CONSTANTS).PENDING_SECONDS

	core.registry:replaceCommands({ Entry({ name = NAME }) })
	core.port.halves[NAME] = function (): any
		return core.Promise.new(function () end)
	end

	local started: number = os.clock()
	local line: any = core.dispatcher:evaluateAndRun(NAME)

	local answered: boolean = WaitFor(function (): boolean
		return line:getStatus() ~= STARTED
	end, pending + MARGIN)

	local elapsed: number = os.clock() - started
	if not answered then
		return false, `the line was still unanswered after {elapsed} s`
	end

	local _, reply: string, kind: string = line:await()
	if reply ~= ERROR_REPLY or kind ~= ERROR then
		return false, `the pending device half answered {reply} as {kind}`
	end

	if elapsed < pending or #core.port.sent ~= 0 then
		return false, `the pending device half was answered after {elapsed} s, or its line was sent`
	end

	return true, nil
end
