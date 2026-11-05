--[[
    The dev place's server: starts Decree the way Frontier Zero will, behind
    a rank gate that reads each player's rank, found when they join
--]]

--!strict
--!nolint DeprecatedApi
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Decree = require(ServerScriptService.ServerPackages.Decree)

local AdminConfig = require(ServerScriptService.Dev.Config.Admin)

local RATE: { perSecond: number, burst: number? } = AdminConfig.rate
local CONFIRM_SECONDS: number = AdminConfig.confirmSeconds
local GROUP_ID: number = AdminConfig.groupId
local RANK_SECONDS: number = AdminConfig.rankSeconds
local RANK: string = AdminConfig.rankAttribute
local GROUP_RANKS: { [string]: number } = AdminConfig.groupRanks
local TEST_RANKS: { [string]: number } = AdminConfig.testRanks
local AUDIT_CHARACTERS: number = AdminConfig.auditCharacters
local GUEST: number = 0 -- The rank Roblox gives a player outside the group
local BEFORE_RUN: HookName = "beforeRun"
local AFTER_RUN: HookName = "afterRun"
local RANK_MISSING: string = "Your rank is still loading, so try again in a moment."
local NO_PLAYER: string = "no player"

type CommandDefinition = Decree.CommandDefinition
type Context = Decree.Context
type HookName = Decree.HookName

-- Each player's rank lookup, cancelled when they leave
local Lookups: { [Player]: any } = {}

--[[
    Whether a rank holds a command group: at or above the lowest rank the
    config gives that group, and never for a group the config does not name
--]]

local function holds(rank: number?, group: string?): boolean
	if rank == nil or group == nil then
		return false
	end

	local needed: number? = GROUP_RANKS[group]

	return needed ~= nil and rank >= needed
end

--[[
    A Promise of a player's rank: the Whiteoak group's for a real account,
    and the config's for one of Studio's test players
--]]

local function lookUp(player: Player): any
	if player.UserId < 0 then
		return Promise.resolve(TEST_RANKS[player.Name] or GUEST)
	end

	return Promise.try(function (): number
		-- Deprecated, and the file's nolint is for this call alone: its replacement answers an untyped role list
		return player:GetRankInGroupAsync(GROUP_ID)
	end)
end

--[[
    Finds a player's rank within RANK_SECONDS and sets it as their
    attribute, which the gate reads and their client shows, then works out
    their commands again; a lookup that fails or runs out leaves a guest
--]]

local function resolve(player: Player)
	Lookups[player] = lookUp(player)
		:timeout(RANK_SECONDS)
		:catch(function (problem: any): number
			warn(`[Dev] {player.Name}'s rank lookup failed, so they hold rank {GUEST}: {problem}`)

			return GUEST
		end)
		:andThen(function (rank: number)
			player:SetAttribute(RANK, rank)
			Decree:refreshAccess(player)
		end)
end

Decree.registry:registerHook(BEFORE_RUN, function (context: Context): string?
	local rank = context.executor:GetAttribute(RANK) :: number?

	if rank == nil then
		return RANK_MISSING
	elseif not holds(rank, context.group) then
		return `{context.name} needs a higher rank than yours.`
	end

	return nil
end)

Decree.registry:registerHook(AFTER_RUN, function (context: Context): string?
	local reply: string = tostring(context.response):sub(1, AUDIT_CHARACTERS)

	print(`[Dev] {context.executor.Name} ran "{context.rawText}" and got "{reply}"`)

	-- Any text returned here would replace the reply
	return nil
end)

Decree.registry:registerCommandsIn(ServerScriptService.Dev.Commands)

Decree:start({
	rate = RATE,
	confirmSeconds = CONFIRM_SECONDS,

	canAccess = function (player: Player, command: CommandDefinition): boolean
		return holds(player:GetAttribute(RANK) :: number?, command.group)
	end,

	onFailure = function (player: (Player | { Name: string })?, kind: string, detail: string)
		local name: string = player and player.Name or NO_PLAYER

		warn(`[Dev] Volt reported a {kind} failure for {name}: {detail}`)
	end,
})

-- Both live as long as the server
Players.PlayerAdded:Connect(resolve)
Players.PlayerRemoving:Connect(function (player: Player)
	local lookup: any = Lookups[player]
	Lookups[player] = nil

	if lookup then
		lookup:cancel()
	end
end)

for _, player: Player in Players:GetPlayers() do
	resolve(player)
end
