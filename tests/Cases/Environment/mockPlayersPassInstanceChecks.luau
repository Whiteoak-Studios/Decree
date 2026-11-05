--[[
    A mock player passes the Instance checks Cmdr keeps, through Cmdr's own
    HasCharacter guard, and carries a PlayerGui a server parents into and a
    Kick that keeps its message, while a bot stays undressed
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local HAS_CHARACTER: string = "Cmdr/CmdrClient/Shared/BuiltInGuards/HasCharacter"
local NO_CHARACTER: string = "You don't have a character." -- HasCharacter's refusal for an executor with none
local ROOT_PART: string = "HumanoidRootPart" -- The part HasCharacter looks for in a character
local COMMANDS: string = "DecreeCommands" -- The ScreenGui a granted command's device half is cloned into
local SECOND: string = "Second"
local BOT: string = "Bot"
local MESSAGE: string = "Removed by a test"

return function (): (boolean, string | nil)
	local env: any = Environment.new()
	local player: any = env.player
	local hasCharacter: any = env.require(HAS_CHARACTER)()

	if player.DisplayName ~= player.Name or type(player.UserId) ~= "number" then
		return false, `the player is {player.DisplayName} with UserId {player.UserId}`
	end

	if not player:IsA("Player") or not player:IsA("Instance") or player:IsA("Part") then
		return false, "the player's IsA answers wrongly"
	end

	-- The guard reads typeof and IsA, so it refuses only an executor it sees as a Player
	local refusal: any = hasCharacter({ Executor = player })
	if refusal ~= NO_CHARACTER then
		return false, `HasCharacter answered {refusal} for a player with no character`
	end

	local character: any = roblox.Instance.new("Model")
	local rootPart: any = roblox.Instance.new("Part")
	rootPart.Name = ROOT_PART
	rootPart.Parent = character
	player.Character = character

	if hasCharacter({ Executor = player }) ~= nil then
		return false, "HasCharacter refused a player with a character"
	end

	local gui: any = roblox.Instance.new("ScreenGui")
	gui.Name = COMMANDS
	gui.Parent = player:WaitForChild("PlayerGui")

	if player.PlayerGui:FindFirstChild(COMMANDS) ~= gui or not player.PlayerGui:IsA("PlayerGui") then
		return false, "the PlayerGui did not keep what the case parented into it"
	end

	if pcall(player.WaitForChild, player, COMMANDS) then
		return false, "WaitForChild answered for a child the player does not have"
	end

	local bot: any = env.mock:addBot(BOT)
	if bot.UserId ~= nil or bot.Kick ~= nil or bot.IsA ~= nil or hasCharacter({ Executor = bot }) ~= nil then
		return false, "the bot was dressed as a player"
	end

	local second: any = env.mock:join(SECOND)
	second:Kick(MESSAGE)

	local stayed: boolean = table.find(env.mock.players, second) ~= nil
	if second.kicked ~= MESSAGE or stayed then
		return false, `Kick kept {second.kicked}, and the player stayed: {stayed}`
	end

	return true, nil
end
