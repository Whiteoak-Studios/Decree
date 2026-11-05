--[[
    The console refuses to send a line of more than LINE_BYTES bytes,
    answering at once, and sends one of exactly LINE_BYTES
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")

local CONSTANTS: string = "src/DecreeClient/Shared/Constants"
local CHARACTER: string = "a"
local REFUSED: string = "Refused"
local OK: string = "Ok"
local ANSWER: string = "Heard"

return function (): (boolean, string | nil)
	local console: Console.Console = Console()
	local lineBytes: number = console.env.require(CONSTANTS).LINE_BYTES
	local heard: { string } = {} -- Each line the server was sent

	console.server.Decree.run.on(function (_: any, text: string): (string, string)
		table.insert(heard, text)

		return ANSWER, OK
	end)

	local longest: string = CHARACTER:rep(lineBytes)
	local refusal: string = `A command is at most {lineBytes} bytes, and this one is {lineBytes + 1}.`

	local over: string?, overKind: string? = console.reply(console.session:send(CHARACTER:rep(lineBytes + 1)))
	if over ~= refusal or overKind ~= REFUSED or #heard ~= 0 then
		return false, `a line over the bound answered {over} as {overKind}, and the server heard {#heard} lines`
	end

	local within: string?, withinKind: string? = console.reply(console.session:send(longest))
	if within ~= ANSWER or withinKind ~= OK or heard[1] ~= longest then
		return false, `a line of exactly {lineBytes} bytes answered {within} as {withinKind}`
	end

	return true, nil
end
