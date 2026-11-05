--[[
    evaluateAndRun parses a line inside the catch it runs the command in, so
    an assert in the parse, for an argument of an unregistered type, is
    answered with an Error line
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local UNTYPED_NAME: string = "untyped"
local UNTYPED_LINE: string = "untyped word"
local UNTYPED: string = `[Decree] Argument "value" has an unregistered type absent`
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local ERROR: string = "Error"
local REFUSED: string = "Refused"
local INFO: string = "Info"

-- The unregistered type's argument is never built when it is left out, so the line is refused instead
local UNTYPED_MISSING: string = "Required argument #1 value is missing."

local ECHO_LINE: string = "echo still here"
local ECHOED: string = "still here"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local dispatcher: any = core.dispatcher
	local player: any = core.env.player

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject(Echo())
	core.registry:registerCommandObject({
		name = UNTYPED_NAME,
		args = { { type = "absent", name = "value" } },
	})

	-- Each assert the parse raises, which evaluateAndRun answers in place of throwing
	for line: string, thrown: string in { [UNTYPED_LINE] = UNTYPED } do
		local evaluated: boolean, problem: any = pcall(dispatcher.evaluate, dispatcher, line, player)
		if evaluated or Thrown(problem) ~= thrown then
			return false, `evaluate of {line} gave {problem}`
		end

		local reply: string, kind: string = core.run(line, player)
		if reply ~= ERROR_REPLY or kind ~= ERROR then
			return false, `evaluateAndRun of {line} answered {reply} as {kind}`
		end
	end

	local untypedMissing: string, missingKind: string = core.run(UNTYPED_NAME, player)
	if untypedMissing ~= UNTYPED_MISSING or missingKind ~= REFUSED then
		return false, `the unregistered type's argument left out answered {untypedMissing}`
	end

	local echoed: string, echoedKind: string = core.run(ECHO_LINE, player)
	if echoed ~= ECHOED or echoedKind ~= INFO then
		return false, `the line after the errors answered {echoed} as {echoedKind}`
	end

	return true, nil
end
