--[[
    The player type finds joined players by part of their name in any case,
    the exact name first and then by where the text starts in each, refuses
    text that names nobody, and parses to the first; players is its listable
--]]

--!strict
local Environment = require("../../Environment")
local PlayerOperators = require("../../Fixtures/Types/PlayerOperators")

local TYPES: string = "src/DecreeClient/Shared/Types/Players"
local TYPE: string = "player"
local LISTABLE: string = "players"
local SECOND: string = "Second"
local EXACT: string = "second" -- SECOND's name typed in another case
local SHARED: string = "e" -- In both names, sooner in SECOND's than in the environment's own player's
local NOBODY: string = "Nobody"
local REFUSAL: string = "No player with that name could be found."
local PREFIXES: string = "% teamPlayers" -- The listable's prefix, which reads a team's players

return function (): (boolean, string | nil)
	local env: any = Environment.new()
	local second: any = env.mock:join(SECOND)
	local types: any = env.require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	local exact: { any } = definition.transform(EXACT)
	if #exact ~= 1 or exact[1] ~= second then
		return false, `player found {#exact} players for {EXACT}`
	end

	local shared: { any } = definition.transform(SHARED)
	local valid: boolean = definition.validate(shared)
	local names: { string } = definition.autocomplete(shared)
	if not valid or #names ~= 2 or names[1] ~= SECOND or names[2] ~= env.player.Name then
		return false, `player completed {SHARED} as {table.concat(names, ", ")}`
	end

	if definition.parse(shared) ~= second or definition.default(env.player) ~= env.player.Name then
		return false, "player did not parse to the first player found, or its default is not the executor's name"
	end

	local nobody: { any } = definition.transform(NOBODY)
	local found: boolean, reason: string? = definition.validate(nobody)
	if #nobody ~= 0 or found or reason ~= REFUSAL then
		return false, `player found {NOBODY}, or refused it with {reason}`
	end

	local operators: boolean, operatorReason: string? = PlayerOperators(definition.argumentOperatorAliases)
	if not operators then
		return false, `player: {operatorReason}`
	end

	-- The listable finds and defaults as player does, and parses each typed name to a list of the first found
	local listed: { any } = listable.parse(shared)
	if listable.listable ~= true or listable.prefixes ~= PREFIXES or #listed ~= 1 or listed[1] ~= second then
		return false, "players did not parse to a list of the first player found, or lacks its team prefix"
	end

	local listedOperators: boolean, listedReason: string? = PlayerOperators(listable.argumentOperatorAliases)
	local listedExact: { any } = listable.transform(EXACT)
	if not listedOperators or listedExact[1] ~= second or listable.default(env.player) ~= env.player.Name then
		return false, `players does not find, default or take operator words as player does: {listedReason}`
	end

	return true, nil
end
