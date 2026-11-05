--[[
    A second client and a bot client connected to one server over the mock
    each call it through a client module of their own, the server hears
    each as its own caller, and each client's LocalPlayer is its own
--]]

--!strict
local Environment = require("../../Environment")

local SCHEMA: string = "tests/Schemas/Smoke.volt"
local OUTPUT: string = ".volt/Smoke" -- Where the schema's options write its modules
local SERVER: string = `{OUTPUT}/Server`
local CLIENT: string = `{OUTPUT}/Client`
local SECOND: string = "Second"
local BOT: string = "Bot"
local RESOLVED: string = "Resolved" -- Promise.Status.Resolved

return function (): (boolean, string | nil)
	local compiled: boolean, reason: string? = Environment.compile(SCHEMA, OUTPUT)
	if not compiled then
		return false, reason
	end

	local env: any = Environment.new({ files = { `{SERVER}.luau`, `{CLIENT}.luau` } })
	local server: any = env.require(SERVER)

	-- Each caller by the text it sent, which is its own name
	local callers: { [string]: any } = {}

	server.Smoke.echo.on(function (player: any, text: string): string
		callers[text] = player

		return text:reverse()
	end)

	local secondPlayer: any, secondTransport: any = env.mock:join(SECOND)
	local second: any = env.connect(secondTransport, secondPlayer)

	local bot: any = env.mock:addBot(BOT)
	local botTransport: any = env.mock:connectBot(bot)
	local botClient: any = env.connect(botTransport, bot)

	local secondModule: any = second.require(CLIENT)
	local botModule: any = botClient.require(CLIENT)
	if secondModule == botModule then
		return false, "two connected clients share one client module"
	end

	local fromSecond: any = secondModule.Smoke.echo.invoke(SECOND)
	local fromBot: any = botModule.Smoke.echo.invoke(BOT)

	for _ = 1, Environment.ROUND_TRIP do
		env.mock:step()
	end

	if fromSecond:getStatus() ~= RESOLVED or fromBot:getStatus() ~= RESOLVED then
		return false, `the calls were {fromSecond:getStatus()} and {fromBot:getStatus()} after the steps`
	end

	local _: boolean, secondReply: string = fromSecond:await()
	local _: boolean, botReply: string = fromBot:await()
	if secondReply ~= SECOND:reverse() or botReply ~= BOT:reverse() then
		return false, `the second client got {secondReply} and the bot got {botReply}`
	end

	if callers[SECOND] ~= secondPlayer or callers[BOT] ~= bot then
		return false, "the server heard a caller as someone else"
	end

	local secondLocal: any = second.game:GetService("Players").LocalPlayer
	local botLocal: any = botClient.game:GetService("Players").LocalPlayer
	if secondLocal ~= secondPlayer or botLocal ~= bot or env.game:GetService("Players").LocalPlayer ~= nil then
		return false, "a client's LocalPlayer is not its own, or the server side has one"
	end

	return true, nil
end
