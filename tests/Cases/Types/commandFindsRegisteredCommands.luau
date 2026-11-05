--[[
    The command type finds registered command names by part of the name in
    any case, leaving aliases out, finding commands registered since, and
    on the server only the executor's own, and refuses text that finds none
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local TYPE: string = "command"
local LISTABLE: string = "commands"
local KICK: string = "kick"
local KILL: string = "kill"
local GREET: string = "greet"
local ALIAS: string = "boot" -- KICK's alias, which the type never finds
local LATER: string = "later" -- Registered once the type has already found the others
local SHARED: string = "k" -- Starts both KICK and KILL
local SHOUTED: string = "KILL"
local INSIDE: string = "ee" -- Inside GREET only
local REFUSAL: string = "No command with that name could be found."
local SEPARATOR: string = "|" -- Joins a list of names into one string to compare

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry
	local definition: any = registry:getType(TYPE)
	local listable: any = registry:getType(LISTABLE)

	registry:registerCommandObject({ name = KICK, aliases = { ALIAS } })
	registry:registerCommandObject({ name = KILL })
	registry:registerCommandObject({ name = GREET })

	-- Both names start with the text and are as long, so their order is the finder's to choose
	local shared: { string } = definition.transform(SHARED)
	local sorted: { string } = table.clone(shared)
	table.sort(sorted)

	if table.concat(sorted, SEPARATOR) ~= `{KICK}{SEPARATOR}{KILL}` then
		return false, `command found {table.concat(shared, ", ")} for {SHARED}`
	end

	local suggestions: { string } = definition.autocomplete(shared)
	local valid: boolean = definition.validate(shared)
	if not valid or table.concat(suggestions, SEPARATOR) ~= table.concat(shared, SEPARATOR) then
		return false, "command did not complete to the names it found"
	end

	local shouted: { string } = definition.transform(SHOUTED)
	local inside: { string } = definition.transform(INSIDE)
	if #shouted ~= 1 or definition.parse(shouted) ~= KILL or #inside ~= 1 or inside[1] ~= GREET then
		return false, `command did not find {KILL} for {SHOUTED}, or {GREET} for {INSIDE}`
	end

	local alias: { string } = definition.transform(ALIAS)
	local found: boolean, reason: string? = definition.validate(alias)
	if #alias ~= 0 or found or reason ~= REFUSAL then
		return false, `command found the alias {ALIAS}, or refused it with {reason}`
	end

	registry:registerCommandObject({ name = LATER })

	local later: { string } = definition.transform(LATER)
	if #later ~= 1 or later[1] ~= LATER then
		return false, "command did not find a command registered since it last searched"
	end

	local listed: { string } = listable.parse(later)
	if listable.listable ~= true or #listed ~= 1 or listed[1] ~= LATER then
		return false, "commands did not parse to a list of the first name found"
	end

	-- The executor's own list leaves out every command the access check withholds from them
	core.access.withheld[GREET] = true

	local held: { string } = definition.transform(INSIDE, core.env.player)
	local own: { string } = definition.transform(SHARED, core.env.player)
	if #held ~= 0 or #own ~= 2 then
		return false, `command found {#held} withheld commands, and {#own} held ones, for the executor`
	end

	return true, nil
end
