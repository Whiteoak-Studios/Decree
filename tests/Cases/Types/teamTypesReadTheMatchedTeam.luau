--[[
    The team types find teams by part of their name in any case, refuse
    text that names none, and parse to the first team found, its players or
    its color; teams and teamColors parse to a list of the one
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Players"
local TEAM: string = "team"
local TEAMS: string = "teams"
local TEAM_PLAYERS: string = "teamPlayers"
local TEAM_COLOR: string = "teamColor"
local TEAM_COLORS: string = "teamColors"
local RED: string = "Red"
local BLUE: string = "Blue"
local RED_BRICK: string = "Bright red"
local BLUE_BRICK: string = "Bright blue"
local SECOND: string = "Second" -- Joins RED, while the environment's own player joins no team
local EXACT: string = "blue" -- BLUE's name typed in another case
local SHARED: string = "e" -- In both names, sooner in RED's than in BLUE's
local NONE: string = "Green"
local REFUSAL: string = "No team with that name could be found."

return function (): (boolean, string | nil)
	local env: any = Environment.new()
	local second: any = env.mock:join(SECOND)
	local teams: any = env.game:GetService("Teams")
	local types: any = env.require(TYPES)
	local team: any = types[TEAM]

	local early: { any } = team.transform(RED)
	if #early ~= 0 then
		return false, "team found a team before any existed"
	end

	local red: any = teams:create(RED, roblox.BrickColor.new(RED_BRICK))
	local blue: any = teams:create(BLUE, roblox.BrickColor.new(BLUE_BRICK))
	second.Team = red

	local exact: { any } = team.transform(EXACT)
	if #exact ~= 1 or exact[1] ~= blue then
		return false, `team found {#exact} teams for {EXACT}`
	end

	local shared: { any } = team.transform(SHARED)
	local valid: boolean = team.validate(shared)
	local names: { string } = team.autocomplete(shared)
	if not valid or #names ~= 2 or names[1] ~= RED or names[2] ~= BLUE or team.parse(shared) ~= red then
		return false, `team completed {SHARED} as {table.concat(names, ", ")}`
	end

	local none: { any } = team.transform(NONE)
	local found: boolean, reason: string? = team.validate(none)
	if #none ~= 0 or found or reason ~= REFUSAL then
		return false, `team found {NONE}, or refused it with {reason}`
	end

	-- Every other team type finds, refuses and completes as team does
	for _, name: string in { TEAMS, TEAM_PLAYERS, TEAM_COLOR, TEAM_COLORS } do
		local definition: any = types[name]
		local typeFound: { any } = definition.transform(SHARED)
		local typeNames: { string } = definition.autocomplete(typeFound)
		local typeValid: boolean, typeReason: string? = definition.validate(none)
		if typeFound[1] ~= red or typeNames[1] ~= RED or typeValid or typeReason ~= REFUSAL then
			return false, `{name} does not find, complete or refuse as team does`
		end
	end

	local listedTeams: { any } = types[TEAMS].parse(exact)
	if types[TEAMS].listable ~= true or #listedTeams ~= 1 or listedTeams[1] ~= blue then
		return false, "teams did not parse to a list of the one team"
	end

	-- teamPlayers is listable of its own, and parses the first team found to its players
	local teamPlayers: any = types[TEAM_PLAYERS]
	local members: { any } = teamPlayers.parse(shared)
	local nobody: { any } = teamPlayers.parse(exact)
	if teamPlayers.listable ~= true or #members ~= 1 or members[1] ~= second or #nobody ~= 0 then
		return false, "teamPlayers did not parse to the first team's players"
	end

	if types[TEAM_COLOR].parse(shared) ~= red.TeamColor then
		return false, "teamColor did not parse to the first team's color"
	end

	local colors: { any } = types[TEAM_COLORS].parse(exact)
	if types[TEAM_COLORS].listable ~= true or #colors ~= 1 or colors[1] ~= blue.TeamColor then
		return false, "teamColors did not parse to a list of the one team's color"
	end

	return true, nil
end
