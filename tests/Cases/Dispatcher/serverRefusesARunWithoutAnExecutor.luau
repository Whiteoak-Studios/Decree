--[[
    On the server a line evaluates with no executor, its context's executor
    nil, but evaluateAndRun refuses to run it with no executor before any
    beforeRun hook sees it
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Server = require("../../Fixtures/Core/Server")

local LINE: string = "echo from nobody"
local NO_CALLER: string = "A command run from the server needs the player who runs it."
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()

	-- Each hook call's executor, kept in a table so a nil one still shows
	local heard: { { executor: any } } = {}

	core.registry:registerCommandObject(Echo())
	core.registry:registerHook("beforeRun", function (context: any): string?
		table.insert(heard, { executor = context.executor })

		return nil
	end)

	local context: any, reason: string? = core.dispatcher:evaluate(LINE, nil)
	if not context or context.executor ~= nil then
		return false, `evaluate with no executor gave {reason}, its executor {context and context.executor}`
	end

	local reply: string, kind: string = core.run(LINE, nil)
	if reply ~= NO_CALLER or kind ~= REFUSED or #heard ~= 0 then
		return false, `evaluateAndRun with no executor answered {reply} as {kind}, the hook called {#heard} times`
	end

	return true, nil
end
