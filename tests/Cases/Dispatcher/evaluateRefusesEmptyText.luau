--[[
    The dispatcher refuses text that is empty, only whitespace or no string
    at all with one message, from evaluate and evaluateAndRun alike
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local EMPTY: string = "Command cannot be empty."
local REFUSED: string = "Refused"

-- Text with no word in it: nothing, spaces, and a tab and a newline among spaces
local BLANK_TEXTS: { string } = { "", "   ", " \t \n " }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()

	for _, text: string in BLANK_TEXTS do
		local context: any, reason: string? = core.dispatcher:evaluate(text, core.env.player)
		if context ~= false or reason ~= EMPTY then
			return false, `evaluate answered {reason} for {#text} blank characters`
		end

		local reply: string, kind: string = core.run(text, core.env.player)
		if reply ~= EMPTY or kind ~= REFUSED then
			return false, `evaluateAndRun answered {reply} as {kind} for {#text} blank characters`
		end
	end

	local missing: any, missingReason: string? = core.dispatcher:evaluate(nil, core.env.player)
	if missing ~= false or missingReason ~= EMPTY then
		return false, `evaluate answered {missingReason} for no text at all`
	end

	return true, nil
end
