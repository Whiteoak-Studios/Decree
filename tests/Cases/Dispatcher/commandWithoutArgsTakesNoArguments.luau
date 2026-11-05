--[[
    A command registered with no args table is accepted and found, and a
    line naming it evaluates with no arguments, as one with an empty args
    table does, and runs as far as the permission hook
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "bare"
local NO_HOOK: string = "No permission hook is registered" -- Reached only once the line evaluates and validates
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local definition: { [string]: any } = { name = NAME }

	core.registry:registerCommandObject(definition)
	if core.registry:getCommand(NAME) ~= definition then
		return false, "the command with no args was not registered"
	end

	local context: any, reason: string? = core.dispatcher:evaluate(NAME, core.env.player)
	if not context or #context.argumentDefinitions ~= 0 or #context.arguments ~= 0 then
		return false, `evaluate gave {reason}, or arguments for a command with no args`
	end

	local reply: string, kind: string = core.run(NAME, core.env.player)
	if reply ~= NO_HOOK or kind ~= REFUSED then
		return false, `evaluateAndRun answered {reply} as {kind}`
	end

	return true, nil
end
