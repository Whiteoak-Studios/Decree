--[[
    The playerId type looks a full name up among joined players and then on
    the web, reads the name inside a display form's (@name), keeps each id
    it finds for the rest of the server and refuses a name nobody holds
--]]

--!strict
local Environment = require("../../Environment")
local PlayerOperators = require("../../Fixtures/Types/PlayerOperators")

local TYPES: string = "src/DecreeClient/Shared/Types/Players"
local TYPE: string = "playerId"
local LISTABLE: string = "playerIds"
local DISPLAY_NAME: string = "Full Player Name"
local PREFIXES: string = "# positiveInteger" -- A user id typed after #
local LISTABLE_PREFIXES: string = "# positiveIntegers"
local SECOND: string = "Second"
local TYPED: string = "Sec" -- The start of SECOND's name, as a player is still typing it
local OFFLINE: string = "Offline" -- A name no joined player holds, which the web lookup answers
local OFFLINE_ID: number = 4242
local DISPLAYED: string = `Someone (@{OFFLINE})` -- OFFLINE as a display form writes it
local LATE: string = "Late" -- A name the web lookup learns only after a lookup for it failed
local LATE_ID: number = 5151
local NOBODY: string = "Nobody"
local REFUSAL: string = "No player with that name could be found."

return function (): (boolean, string | nil)
	local env: any = Environment.new()
	local second: any = env.mock:join(SECOND)
	local userIds: { [string]: number } = env.game:GetService("Players").userIds
	local types: any = env.require(TYPES)
	local definition: any = types[TYPE]
	local listable: any = types[LISTABLE]

	if definition.displayName ~= DISPLAY_NAME or definition.prefixes ~= PREFIXES or definition.validate ~= nil then
		return false, "playerId lacks its display name or prefix, or validates as it is typed"
	end

	-- Transform keeps the text beside the players it names, which only autocomplete reads
	local typed: { n: number, [number]: any } = table.pack(definition.transform(TYPED))
	local suggestions: { string } = definition.autocomplete(table.unpack(typed, 1, typed.n))
	local partial: boolean, partialReason: string? = definition.validateOnce(table.unpack(typed, 1, typed.n))
	if typed[1] ~= TYPED or #suggestions ~= 1 or suggestions[1] ~= SECOND then
		return false, `playerId completed {TYPED} as {table.concat(suggestions, ", ")}`
	end

	if partial or partialReason ~= REFUSAL then
		return false, `playerId accepted the part name {TYPED}, or refused it with {partialReason}`
	end

	local joined: boolean = definition.validateOnce(SECOND)
	if not joined or definition.parse(SECOND) ~= second.UserId then
		return false, "playerId did not find a joined player's id"
	end

	userIds[OFFLINE] = OFFLINE_ID
	local offline: boolean = definition.validateOnce(OFFLINE)
	if not offline or definition.parse(DISPLAYED) ~= OFFLINE_ID then
		return false, "playerId did not look up a name no joined player holds, or its display form"
	end

	-- A found id stays, so the lookup never runs for that name again
	userIds[OFFLINE] = nil
	local cached: boolean = definition.validateOnce(OFFLINE)
	if not cached or definition.parse(OFFLINE) ~= OFFLINE_ID then
		return false, "playerId looked a name up again after finding its id"
	end

	-- A failed lookup is kept nowhere, so a later one for the same name runs again
	local before: boolean, beforeReason: string? = definition.validateOnce(LATE)
	userIds[LATE] = LATE_ID
	local after: boolean = definition.validateOnce(LATE)
	if before or beforeReason ~= REFUSAL or not after then
		return false, "playerId kept a failed lookup"
	end

	local nobody: boolean, reason: string? = definition.validateOnce(NOBODY)
	if nobody or reason ~= REFUSAL or definition.parse(NOBODY) ~= nil then
		return false, `playerId found {NOBODY}, or refused it with {reason}`
	end

	local operators: boolean, operatorReason: string? = PlayerOperators(definition.argumentOperatorAliases)
	if not operators or definition.default(env.player) ~= env.player.Name then
		return false, `playerId's default is not the executor's name, or: {operatorReason}`
	end

	local listed: { number } = listable.parse(SECOND)
	local listedValid: boolean = listable.validateOnce(SECOND)
	if listable.listable ~= true or listable.prefixes ~= LISTABLE_PREFIXES or not listedValid then
		return false, "playerIds is not listable, lacks its prefix, or refused a joined player"
	end

	local listedOperators: boolean, listedReason: string? = PlayerOperators(listable.argumentOperatorAliases)
	if #listed ~= 1 or listed[1] ~= second.UserId or not listedOperators then
		return false, `playerIds did not parse to a list of the one id, or: {listedReason}`
	end

	return true, nil
end
