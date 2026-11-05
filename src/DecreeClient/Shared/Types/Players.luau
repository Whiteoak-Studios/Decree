--[[
    The player and team argument types: player and playerId, which find
    joined players, and team, teamPlayers and teamColor, which find teams,
    each with its listable but teamPlayers, which is listable itself
--]]

--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Util = require("../Util")

local IS_SERVER: boolean = RunService:IsServer()
local DISPLAY_FORM: string = "%(@([^%)]+)%)" -- The name inside a display form, as in Someone (@name)
local NO_PLAYER: string = "No player with that name could be found."
local NO_TEAM: string = "No team with that name could be found."

-- The operator each word a player argument takes stands for
local OPERATOR_ALIASES: { [string]: string } = {
	me = ".",
	all = "*",
	others = "**",
	random = "?",
}

local Types = require("../Config/Types/Command")

type TypeDefinition = Types.TypeDefinition

-- Whiteoak TODO: Ids stay cached for the server's life with no cap; add a least-recently-used cap if lookups pile up
local UserIds: { [string]: number } = {} -- Each user id found, by the name it was found for

--[[
    Every joined player whose name holds the text, ranked as makeFuzzyFinder
    ranks them
--]]

local function findPlayers(text: string): { Player }
	return Util.makeFuzzyFinder(Players:GetPlayers())(text)
end

--[[
    The executor's name, the text a player argument stands for when it is
    left out
--]]

local function executorName(executor: Player): string
	return executor.Name
end

--[[
    The user id of a full name, or of the name inside a display form: one
    found before, a joined player's, or on the server the web's, which
    yields while it looks. A failed lookup is kept nowhere, so it runs again
--]]

local function getUserId(text: string): number?
	local name: string = text:match(DISPLAY_FORM) or text
	local known: number? = UserIds[name]
	if known then
		return known
	end

	local player = Players:FindFirstChild(name) :: Player?
	if player then
		UserIds[name] = player.UserId
		return player.UserId
	end

	if not IS_SERVER then
		return nil
	end

	local found: boolean, userId: any = pcall(Players.GetUserIdFromNameAsync, Players, name)
	if not found then
		return nil
	end

	UserIds[name] = userId
	return userId
end

--[[
    Every team whose name holds the text, ranked as makeFuzzyFinder ranks
    them
--]]

local function findTeams(text: string): { Team }
	return Util.makeFuzzyFinder(Teams:GetTeams())(text)
end

--[[
    Refuses a text that found no team
--]]

local function validateTeams(teams: { Team }): (boolean, string?)
	return #teams > 0, NO_TEAM
end

local Definitions: { [string]: TypeDefinition } = {
	player = {
		transform = findPlayers,

		validate = function (players: { Player }): (boolean, string?)
			return #players > 0, NO_PLAYER
		end,

		autocomplete = Util.getNames,

		parse = function (players: { Player }): Player?
			return players[1]
		end,

		default = executorName,
		argumentOperatorAliases = OPERATOR_ALIASES,
	},

	playerId = {
		displayName = "Full Player Name",
		prefixes = "# positiveInteger",

		-- The text, then the players it names, which only autocomplete reads
		transform = function (text: string): (string, { Player })
			return text, findPlayers(text)
		end,

		-- The web lookup runs on the server alone, so a client leaves this check to the server
		validateOnce = function (text: string): (boolean, string?)
			if not IS_SERVER then
				return true, nil
			end

			return getUserId(text) ~= nil, NO_PLAYER
		end,

		autocomplete = function (_: string, players: { Player }): { string }
			return Util.getNames(players)
		end,

		parse = getUserId,
		default = executorName,
		argumentOperatorAliases = OPERATOR_ALIASES,
	},

	team = {
		transform = findTeams,
		validate = validateTeams,
		autocomplete = Util.getNames,

		parse = function (teams: { Team }): Team?
			return teams[1]
		end,
	},

	teamPlayers = {
		listable = true,
		transform = findTeams,
		validate = validateTeams,
		autocomplete = Util.getNames,

		parse = function (teams: { Team }): { Player }
			return teams[1]:GetPlayers()
		end,
	},

	teamColor = {
		transform = findTeams,
		validate = validateTeams,
		autocomplete = Util.getNames,

		parse = function (teams: { Team }): BrickColor
			return teams[1].TeamColor
		end,
	},
}

Definitions.players = Util.makeListableType(Definitions.player, { prefixes = "% teamPlayers" })
Definitions.playerIds = Util.makeListableType(Definitions.playerId, { prefixes = "# positiveIntegers" })
Definitions.teams = Util.makeListableType(Definitions.team)
Definitions.teamColors = Util.makeListableType(Definitions.teamColor)

return Definitions
