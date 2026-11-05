--[[
    A line whose call Volt fails, with no handler on the server or with one
    that throws, answers Volt's reason as an Error, and the next line is
    sent as usual
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")

local LINE: string = "wave"
local NO_HANDLER: string = "The command failed: no handler"
local PROBLEM: string = "The handler broke"
local ERROR: string = "Error"
local OK: string = "Ok"
local PLAIN: boolean = true -- Finds the text as written, with no pattern characters

return function (): (boolean, string | nil)
	local console: Console.Console = Console()

	local unhandled: string?, unhandledKind: string? = console.reply(console.session:send(LINE))
	if unhandled ~= NO_HANDLER or unhandledKind ~= ERROR then
		return false, `a line with no handler answered {unhandled} as {unhandledKind}`
	end

	local calls: number = 0
	console.server.Decree.run.on(function (_: any, text: string): (string, string)
		calls += 1

		if calls == 1 then
			error(PROBLEM)
		end

		return text, OK
	end)

	local thrown: string?, thrownKind: string? = console.reply(console.session:send(LINE))
	if not thrown or not thrown:find(PROBLEM, 1, PLAIN) or thrownKind ~= ERROR then
		return false, `a line whose handler threw answered {thrown} as {thrownKind}`
	end

	local answer: string?, kind: string? = console.reply(console.session:send(LINE))
	if answer ~= LINE or kind ~= OK then
		return false, `a line after the failed calls answered {answer} as {kind}`
	end

	return true, nil
end
