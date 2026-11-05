--[[
    TextService, TeleportService, Teams and HttpService answer what Decree
    calls them for, from what a case sets
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local SECOND: string = "Second"
local TEXT: string = "hello there"
local HIDDEN: string = "#####" -- What the case's filter makes of a text for anyone but its sender
local SETTING: string = "history"
local TEAM: string = "Red"
local TEAM_COLOR: string = "Bright red"
local JSON: string = `[1, "two"]`
local BROKEN_JSON: string = "[1,"

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local second: any, transport: any = env.mock:join(SECOND)

	-- TextService filters a text for each receiver through what the case sets, and leaves it as it is by default
	local textService: any = env.game:GetService("TextService")
	local result: any = textService:FilterStringAsync(TEXT, env.player.UserId)
	if result:GetNonChatStringForUserAsync(second.UserId) ~= TEXT then
		return false, "the default filter changed a text"
	end

	textService.filter = function (text: string, fromUserId: number, toUserId: number): string
		if fromUserId == toUserId then
			return text
		end

		return HIDDEN
	end

	local forSecond: string = result:GetNonChatStringForUserAsync(second.UserId)
	local forSender: string = result:GetNonChatStringForUserAsync(env.player.UserId)
	if forSecond ~= HIDDEN or forSender ~= TEXT then
		return false, `the case's filter gave {forSecond} and {forSender}`
	end

	-- TeleportService keeps a setting by value, as the engine does
	local teleportService: any = env.game:GetService("TeleportService")
	if teleportService:GetTeleportSetting(SETTING) ~= nil then
		return false, "a setting nobody set has a value"
	end

	local history: { string } = { TEXT }
	teleportService:SetTeleportSetting(SETTING, history)
	table.insert(history, TEXT)

	local stored: { string } = teleportService:GetTeleportSetting(SETTING)
	table.insert(stored, TEXT)

	local reread: { string } = teleportService:GetTeleportSetting(SETTING)
	if #reread ~= 1 or reread[1] ~= TEXT then
		return false, `the setting holds {#reread} entries after the case changed its copies`
	end

	-- Teams lists a team in every environment over this mock, and the team its players
	local teams: any = env.game:GetService("Teams")
	local red: any = teams:create(TEAM, roblox.BrickColor.new(TEAM_COLOR))
	second.Team = red

	local members: { any } = red:GetPlayers()
	if teams:GetTeams()[1] ~= red or #members ~= 1 or members[1] ~= second or not red:IsA("Team") then
		return false, "Teams did not list the team the case made with its player"
	end

	local connected: any = env.connect(transport, second)
	if connected.game:GetService("Teams"):GetTeams()[1] ~= red then
		return false, "another environment over the mock does not list the team"
	end

	-- HttpService decodes JSON and errors on text that is not
	local httpService: any = env.game:GetService("HttpService")
	local decoded: { any } = httpService:JSONDecode(JSON)
	if decoded[1] ~= 1 or decoded[2] ~= "two" or pcall(httpService.JSONDecode, httpService, BROKEN_JSON) then
		return false, "JSONDecode answered wrongly"
	end

	return true, nil
end
