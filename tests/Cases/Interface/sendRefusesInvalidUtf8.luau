--[[
    The console refuses to send a line that is not valid UTF-8, answering at
    once, and sends one whose characters take several bytes
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")

local BROKEN: string = "kick \xff" -- A byte no UTF-8 sequence starts with
local ACCENTED: string = "kick Zoë"
local REFUSAL: string = "A command must be valid UTF-8 text."
local REFUSED: string = "Refused"
local OK: string = "Ok"

return function (): (boolean, string | nil)
	local console: Console.Console = Console()
	local heard: { string } = {} -- Each line the server was sent

	console.server.Decree.run.on(function (_: any, text: string): (string, string)
		table.insert(heard, text)

		return text, OK
	end)

	local broken: string?, brokenKind: string? = console.reply(console.session:send(BROKEN))
	if broken ~= REFUSAL or brokenKind ~= REFUSED or #heard ~= 0 then
		return false, `invalid UTF-8 answered {broken} as {brokenKind}, and the server heard {#heard} lines`
	end

	local accented: string?, accentedKind: string? = console.reply(console.session:send(ACCENTED))
	if accented ~= ACCENTED or accentedKind ~= OK or heard[1] ~= ACCENTED then
		return false, `a line of several-byte characters answered {accented} as {accentedKind}`
	end

	return true, nil
end
