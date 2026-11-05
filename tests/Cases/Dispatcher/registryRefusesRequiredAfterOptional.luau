--[[
    registerCommandObject refuses a command whose required argument follows
    an optional one, naming it, and stores nothing, so every line that
    names it is refused as an unknown command, whatever arguments it has
--]]

--!strict
local Misordered = require("../../Fixtures/Dispatcher/Misordered")
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local MISORDERED: string = "[Decree] Command misordered has required arguments after optional arguments."
local UNKNOWN: string = "misordered is not a valid command name."

-- The name alone, with only its optional argument and with both arguments
local LINES: { string } = { "misordered", "misordered one", "misordered one two" }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local registered: boolean, thrown: any = pcall(registry.registerCommandObject, registry, Misordered())
	if registered or Thrown(thrown) ~= MISORDERED then
		return false, `registering the misordered command gave {thrown}`
	end

	for _, line: string in LINES do
		local context: any, reason: string? = core.dispatcher:evaluate(line, core.env.player)
		if context or reason ~= UNKNOWN then
			return false, `evaluate of {line} gave {reason}`
		end
	end

	return true, nil
end
