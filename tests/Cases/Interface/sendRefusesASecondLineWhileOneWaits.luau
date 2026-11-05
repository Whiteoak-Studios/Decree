--[[
    The console keeps one line waiting on the server: a second line sent
    before the first is answered is refused at once and never sent, and a
    line sent after the answer goes as usual
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")
local Listed = require("../../Fixtures/Parser/Listed")

local FIRST: string = "wave"
local SECOND: string = "kick"
local THIRD: string = "fly"
local REFUSAL: string = "Wait for your last command to finish."
local REFUSED: string = "Refused"
local OK: string = "Ok"
local RESOLVED: string = "Resolved" -- Promise.Status.Resolved
local SEPARATOR: string = ", " -- Joins the lines heard in a failure message

-- The lines the server hears, in order
local HEARD: { string } = { FIRST, THIRD }

return function (): (boolean, string | nil)
	local console: Console.Console = Console()
	local heard: { string } = {}

	console.server.Decree.run.on(function (_: any, text: string): (string, string)
		table.insert(heard, text)

		return text, OK
	end)

	local first: any = console.session:send(FIRST)
	local second: any = console.session:send(SECOND)

	-- Answered before any step, since it never waits on the server
	if second:getStatus() ~= RESOLVED then
		return false, "a second line waited instead of being refused at once"
	end

	local _: boolean, refusal: string, refusalKind: string = second:await()
	if refusal ~= REFUSAL or refusalKind ~= REFUSED then
		return false, `a second line answered {refusal} as {refusalKind}`
	end

	local answer: string?, kind: string? = console.reply(first)
	if answer ~= FIRST or kind ~= OK then
		return false, `the first line answered {answer} as {kind}`
	end

	local third: string?, thirdKind: string? = console.reply(console.session:send(THIRD))
	if third ~= THIRD or thirdKind ~= OK then
		return false, `a line sent after the answer answered {third} as {thirdKind}`
	end

	if not Listed(heard, HEARD) then
		return false, `the server heard {table.concat(heard, SEPARATOR)}`
	end

	return true, nil
end
