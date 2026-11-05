--[[
    A listable argument's ?N picks N distinct suggestions from a copy of the
    list the type's autocomplete gives, so a list the type keeps stays whole
    and every later ?N picks from all of it again
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Listed = require("../../Fixtures/Parser/Listed")
local Server = require("../../Fixtures/Core/Server")

local TYPE: string = "kept"
local NAME: string = "pick"
local WORDS: { string } = { "one", "two", "three" }
local SEPARATOR: string = ", " -- Joins a list of words in a failure message

-- Each line typed, and how many words it picks
local PICKS: { Pick } = {
	{ line = `{NAME} ?2`, count = 2 },
	{ line = `{NAME} ?3`, count = 3 }, -- Every word again, so none was taken by the pick before
	{ line = `{NAME} ?3`, count = 3 },
}

type Pick = {
	line: string,
	count: number,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local kept: { string } = table.clone(WORDS) -- The one list the type's autocomplete gives every time

	core.registry:registerType(TYPE, {
		listable = true,

		autocomplete = function (): { string }
			return kept
		end,

		parse = function (text: string): { string }
			return { text }
		end,
	})

	core.registry:registerCommandObject({ name = NAME, args = { { name = "words", type = TYPE } } })

	for _, pick: Pick in PICKS do
		local argument: any, reason: string? = Evaluate(core.dispatcher, core.env.player, pick.line, 1)
		if not argument then
			return false, reason
		end

		local picked: { [string]: true } = {}

		for _, segment: string in argument.rawSegments do
			if not table.find(WORDS, segment) or picked[segment] then
				return false, `{pick.line} picked {table.concat(argument.rawSegments, SEPARATOR)}`
			end

			picked[segment] = true
		end

		if #argument.rawSegments ~= pick.count then
			return false, `{pick.line} picked {#argument.rawSegments} words`
		end

		if not Listed(kept, WORDS) then
			return false, `{pick.line} left the type's list as {table.concat(kept, SEPARATOR)}`
		end
	end

	return true, nil
end
