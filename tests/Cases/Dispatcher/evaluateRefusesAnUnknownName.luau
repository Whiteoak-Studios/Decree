--[[
    A line whose first word names no command or alias is refused with that
    word as it was typed, while a word that only starts or contains a
    command's name matches nothing
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Server = require("../../Fixtures/Core/Server")

local NOT_A_COMMAND: string = "is not a valid command name."
local REFUSED: string = "Refused"
local ARGUMENT: string = "hello" -- Typed after each word, which the refusal leaves out

-- Words that name nothing beside the registered echo and its alias say, the typed case among them
local UNKNOWN_WORDS: { string } = { "nope", "NoPe", "ech", "echoes", "sa" }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	core.registry:registerCommandObject(Echo())

	for _, word: string in UNKNOWN_WORDS do
		local line: string = `{word} {ARGUMENT}`
		local expected: string = `{word} {NOT_A_COMMAND}`

		local context: any, reason: string? = core.dispatcher:evaluate(line, core.env.player)
		if context ~= false or reason ~= expected then
			return false, `evaluate answered {reason} for {line}`
		end

		local reply: string, kind: string = core.run(line, core.env.player)
		if reply ~= expected or kind ~= REFUSED then
			return false, `evaluateAndRun answered {reply} as {kind} for {line}`
		end
	end

	return true, nil
end
