--[[
    A command whose confirm key is true answers with the question and runs
    nothing, and a confirm within confirmSeconds runs it once, past the
    beforeRun hooks again and without asking again
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Wipe = require("../../Fixtures/Server/Wipe")

local LINE: string = "wipe"
local CONFIRM: string = "confirm"
local SECONDS: number = 5 -- Room to send confirm in
local QUESTION: string = `Send confirm within {SECONDS} seconds to run: {LINE}`
local WIPED: string = "Wiped"
local INFO: string = "Info"
local BEFORE_RUN: string = "beforeRun"
local HOOKED: number = 2 -- The waiting line passes the hook, and passes it again when confirm reruns it

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local counter: Wipe.Counter = { runs = 0 }
	local hooked: number = 0

	server.decree.registry:registerCommandObject(Wipe(counter))
	server.decree.registry:registerHook(BEFORE_RUN, function (_: any): string?
		hooked += 1

		return nil
	end)

	server.start({ confirmSeconds = SECONDS })

	local asked: boolean, question: string, kind: string = server.run(LINE)
	if not asked or question ~= QUESTION or kind ~= INFO then
		return false, `{LINE} was answered {question} as {kind}`
	elseif counter.runs ~= 0 then
		return false, `{LINE} ran before confirm`
	end

	local confirmed: boolean, text: string = server.run(CONFIRM)
	if not confirmed or text ~= WIPED or counter.runs ~= 1 then
		return false, `{CONFIRM} was answered {text}, and {LINE} ran {counter.runs} times`
	elseif hooked ~= HOOKED then
		return false, `the beforeRun hook saw {hooked} lines, not {HOOKED}`
	end

	return true, nil
end
