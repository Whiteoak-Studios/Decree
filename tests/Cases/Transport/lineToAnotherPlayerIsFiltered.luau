--[[
    A line a command prints for a player other than its caller is filtered
    through TextService for that recipient, from the caller, while the
    caller's own line goes as it is
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local CLIENT: string = "src/DecreeClient/Network"
local SECOND: string = "Second"
local LINE: string = "tell"
local WRITTEN: string = "Meet at the docks"
local FILTERED: string = "Meet at the #####"
local ADD_LINE: string = "AddLine"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local caller: any = server.env.player
	local second: any, transport: any = server.env.mock:join(SECOND)
	local secondClient: any = server.env.connect(transport, second).require(CLIENT)

	local filtered: { { any } } = {}
	server.env.game:GetService("TextService").filter = function (text: string, from: number, to: number): string
		table.insert(filtered, { text, from, to })

		return FILTERED
	end

	server.decree.registry:registerCommandObject({
		name = LINE,
		args = {},

		run = function (context: any): string
			context:sendEvent(second, ADD_LINE, WRITTEN)
			context:reply(WRITTEN)

			return WRITTEN
		end,
	})

	server.start()

	local heard: string? = nil
	local own: string? = nil

	secondClient.Decree.line.on(function (text: string)
		heard = text
	end)

	server.client.Decree.line.on(function (text: string)
		own = text
	end)

	server.run(LINE)

	local arrived: boolean = server.step(function (): boolean
		return heard ~= nil
	end)

	if not arrived or heard ~= FILTERED then
		return false, `the other player read {heard}, not the filtered line`
	elseif own ~= WRITTEN then
		return false, `the caller read {own}, where their own line goes unfiltered`
	elseif #filtered ~= 1 or filtered[1][2] ~= caller.UserId or filtered[1][3] ~= second.UserId then
		return false, `TextService filtered {#filtered} lines, or not from the caller for the recipient`
	end

	return true, nil
end
