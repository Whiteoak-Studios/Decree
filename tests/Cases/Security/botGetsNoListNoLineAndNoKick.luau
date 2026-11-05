--[[
    A bot gets an empty list and has its line refused, canAccess never
    hears of it, so no device half reaches it, and a failure it causes,
    a mismatched handshake included, reaches the game without a kick
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local RawClient = require("../../Fixtures/Server/RawClient")

local CLIENT: string = "src/DecreeClient/Network"
local BOT: string = "Bot"
local MISMATCHED: string = "Mismatched"
local LINE: string = "echo beep"
local BOT_REFUSAL: string = "Decree takes no commands from a bot."
local REFUSED: string = "Refused"
local HANDSHAKE: string = "handshake"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local asked: { [any]: true } = {}
	local failures: { { any } } = {}

	server.decree.registry:registerCommandObject(Echo())
	server.start({
		canAccess = function (player: any): boolean
			asked[player] = true

			return true
		end,

		onFailure = function (player: any, kind: string)
			table.insert(failures, { player, kind })
		end,
	})

	local bot: any = server.env.mock:addBot(BOT)
	local botClient: any = server.env.connect(server.env.mock:connectBot(bot), bot).require(CLIENT)

	local listed: any = botClient.Decree.commands.invoke()
	local replied: any = botClient.Decree.run.invoke(LINE)
	if not server.settle(listed) or not server.settle(replied) then
		return false, "the bot's calls were never answered"
	end

	local _, list: { any } = listed:await()
	local _, text: string, kind: string = replied:await()
	if #list ~= 0 then
		return false, `the bot was given a list of {#list} commands`
	elseif text ~= BOT_REFUSAL or kind ~= REFUSED then
		return false, `the bot's line was answered {text} as {kind}`
	elseif asked[bot] then
		return false, "canAccess was asked about the bot"
	end

	-- A bot has no Kick, so a kick would raise in the handler before the game hears of it
	local mismatched: any = server.env.mock:addBot(MISMATCHED)
	local raw: RawClient.RawClient = RawClient(server.env.mock:connectBot(mismatched))
	raw.handshake(bit32.bnot(raw.hash))

	local heard: boolean = false

	for _, failure: { any } in failures do
		heard = heard or failure[1] == mismatched and failure[2] == HANDSHAKE
	end

	if not heard then
		return false, "the bot's mismatched handshake never reached the game's onFailure"
	end

	return true, nil
end
