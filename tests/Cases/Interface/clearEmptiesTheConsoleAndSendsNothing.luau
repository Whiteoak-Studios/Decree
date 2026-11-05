--[[
    Decree's clear empties the console on the device, answering text that
    prints nothing, so the line never goes to the server
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")
local Entry = require("../../Fixtures/Core/Entry")

local CLEAR: string = "clear"
local WAVE: string = "wave"
local NOTHING: string = "" -- Clear's answer, which the window prints as no line
local INFO: string = "Info"

return function (): (boolean, string | nil)
	local console: Console.Console = Console()
	local heard: { string } = {} -- Each line the server was sent

	console.server.Decree.commands.on(function (_: any): { any }
		return { Entry({ name = WAVE }) }
	end)

	console.server.Decree.run.on(function (_: any, text: string): (string, string)
		table.insert(heard, text)

		return text, INFO
	end)

	console.listen()
	console.step()

	local answer: string?, kind: string? = console.reply(console.dispatcher:evaluateAndRun(CLEAR))
	if answer ~= NOTHING or kind ~= INFO then
		return false, `{CLEAR} answered {answer} as {kind}`
	end

	if console.clears ~= 1 or #heard ~= 0 then
		return false, `{CLEAR} emptied the console {console.clears} times and sent {#heard} lines`
	end

	return true, nil
end
