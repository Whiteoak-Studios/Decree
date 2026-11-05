--[[
    A listable argument whose type has no autocomplete keeps *, ** and ?N,
    which have no suggestions to expand to, as the one segment typed, as it
    keeps ?, . and ?0
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Listed = require("../../Fixtures/Parser/Listed")
local Server = require("../../Fixtures/Core/Server")

local TAG: string = "tag" -- Takes strings, a listable type with no autocomplete
local SEPARATOR: string = " | " -- Joins segments in a failure message

local UNEXPANDED: { string } = { `{TAG} *`, `{TAG} **`, `{TAG} ?2` }
local LITERALS: { string } = { `{TAG} ?`, `{TAG} .`, `{TAG} ?0` }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player

	core.registry:registerCommandObject({ name = TAG, args = { { name = "words", type = "strings" } } })

	for _, lines: { string } in { UNEXPANDED, LITERALS } do
		for _, line: string in lines do
			local argument: any, reason: string? = Evaluate(core.dispatcher, player, line, 1)
			if not argument then
				return false, reason
			end

			if not Listed(argument.rawSegments, { argument.rawValue }) or argument.rawSegmentsAreAutocomplete then
				return false, `{line} expanded to {table.concat(argument.rawSegments, SEPARATOR)}`
			end
		end
	end

	return true, nil
end
