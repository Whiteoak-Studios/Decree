--[[
    The dispatcher finds a command by its name or an alias typed in any case,
    and the context keeps the definition's name beside the word as typed,
    which runs the command as its name does
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "echo"
local TEXT: string = "hi" -- Typed after each word, and what echo answers
local INFO: string = "Info"

-- The name and the alias say, each in lowercase, uppercase and mixed case
local WORDS: { string } = { "echo", "ECHO", "eChO", "say", "SAY", "sAy" }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local definition: { [string]: any } = Echo()

	core.registry:registerCommandObject(definition)
	core.registry:registerHook("beforeRun", PassingHook)

	for _, word: string in WORDS do
		local line: string = `{word} {TEXT}`

		local context: any, reason: string? = core.dispatcher:evaluate(line, core.env.player)
		if not context then
			return false, `evaluate refused {line}: {reason}`
		end

		if context.object ~= definition or context.name ~= NAME or context.alias ~= word then
			return false, `{line} evaluated to {context.name}, typed as {context.alias}`
		end

		local reply: string, kind: string = core.run(line, core.env.player)
		if reply ~= TEXT or kind ~= INFO then
			return false, `{line} answered {reply} as {kind}`
		end
	end

	return true, nil
end
