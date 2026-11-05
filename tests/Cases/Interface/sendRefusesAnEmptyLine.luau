--[[
    The console refuses to send a line of no bytes, answering at once, so
    nothing reaches the server
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")

local EMPTY: string = ""
local REFUSAL: string = "Command cannot be empty."
local REFUSED: string = "Refused"
local OK: string = "Ok"

return function (): (boolean, string | nil)
	local console: Console.Console = Console()
	local heard: number = 0

	console.server.Decree.run.on(function (_: any, text: string): (string, string)
		heard += 1

		return text, OK
	end)

	local answer: string?, kind: string? = console.reply(console.session:send(EMPTY))
	if answer ~= REFUSAL or kind ~= REFUSED or heard ~= 0 then
		return false, `an empty line answered {answer} as {kind}, and the server heard {heard} lines`
	end

	return true, nil
end
