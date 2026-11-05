--[[
    Players lists the mock's players and never a bot, fires its join and
    leave signals as they come and go, finds one by Name, answers the web
    lookup from what a case gives it, and has a LocalPlayer only on a client
--]]

--!strict
local Environment = require("../../Environment")

local SECOND: string = "Second"
local BOT: string = "Bot"
local LISTED: number = 2 -- The environment's own player and SECOND, with the bot left out
local OFFLINE: string = "Offline" -- A name no player in the server has, which the case gives the web lookup
local OFFLINE_ID: number = 156
local UNKNOWN: string = "Nobody" -- A name the web lookup does not know

return function (): (boolean, string | nil)
	local env: any = Environment.new()
	local players: any = env.game:GetService("Players")

	if players.LocalPlayer ~= nil then
		return false, "the server side has a LocalPlayer"
	end

	local joined: { any } = {}
	local left: { any } = {}

	players.PlayerAdded:Connect(function (player: any)
		table.insert(joined, player)
	end)

	players.PlayerRemoving:Connect(function (player: any)
		table.insert(left, player)
	end)

	local second: any = env.mock:join(SECOND)
	env.mock:addBot(BOT)

	local listed: { any } = players:GetPlayers()
	if #listed ~= LISTED or listed[1] ~= env.player or listed[2] ~= second then
		return false, `GetPlayers listed {#listed} players`
	end

	if #joined ~= 1 or joined[1] ~= second then
		return false, `PlayerAdded fired {#joined} times`
	end

	if players:FindFirstChild(SECOND) ~= second or players[SECOND] ~= second or players[BOT] ~= nil then
		return false, "Players found the wrong player by Name"
	end

	env.mock:leave(second)

	local remaining: number = #players:GetPlayers()
	if #left ~= 1 or left[1] ~= second or remaining ~= LISTED - 1 then
		return false, `PlayerRemoving fired {#left} times, leaving {remaining} players`
	end

	players.userIds[OFFLINE] = OFFLINE_ID
	if players:GetUserIdFromNameAsync(OFFLINE) ~= OFFLINE_ID then
		return false, "GetUserIdFromNameAsync missed a name the case gave it"
	end

	if pcall(players.GetUserIdFromNameAsync, players, UNKNOWN) then
		return false, "GetUserIdFromNameAsync answered for a name it was never given"
	end

	local client: any = Environment.new({ side = "client" })
	if client.game:GetService("Players").LocalPlayer ~= client.player then
		return false, "the client side's LocalPlayer is not its player"
	end

	return true, nil
end
