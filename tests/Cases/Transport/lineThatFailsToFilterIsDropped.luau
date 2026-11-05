--[[
    A line for another player that fails to filter is dropped, and the
    lines after it still reach that player
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local CLIENT: string = "src/DecreeClient/Network"
local SECOND: string = "Second"
local LINE: string = "tell"
local UNFILTERABLE: string = "This one fails"
local AFTER: string = "This one goes"
local ADD_LINE: string = "AddLine"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local second: any, transport: any = server.env.mock:join(SECOND)
	local secondClient: any = server.env.connect(transport, second).require(CLIENT)

	server.env.game:GetService("TextService").filter = function (text: string): string
		if text == UNFILTERABLE then
			error("TextService:FilterStringAsync() failed")
		end

		return text
	end

	server.decree.registry:registerCommandObject({
		name = LINE,
		args = {},

		run = function (context: any): string
			context:sendEvent(second, ADD_LINE, UNFILTERABLE)
			context:sendEvent(second, ADD_LINE, AFTER)

			return AFTER
		end,
	})

	server.start()

	local heard: { string } = {}
	secondClient.Decree.line.on(function (text: string)
		table.insert(heard, text)
	end)

	server.run(LINE)

	local arrived: boolean = server.step(function (): boolean
		return #heard > 0
	end)

	if not arrived or #heard ~= 1 or heard[1] ~= AFTER then
		return false, `the other player read {#heard} lines, the first {heard[1]}`
	end

	return true, nil
end
