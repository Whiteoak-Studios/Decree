--[[
    A line that leaves out a required argument is refused with the first
    missing argument's position and name, from evaluate and evaluateAndRun
    alike, and evaluates once every one is given
--]]

--!strict
local Pair = require("../../Fixtures/Dispatcher/Pair")
local Server = require("../../Fixtures/Core/Server")

local NO_ARGUMENTS: string = "pair"
local FIRST_ONLY: string = "pair one"
local BOTH: string = "pair one two"
local FIRST_MISSING: string = "Required argument #1 first is missing."
local REST_MISSING: string = "Required argument #2 rest is missing."
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	core.registry:registerCommandObject(Pair())

	local none: any, noneReason: string? = core.dispatcher:evaluate(NO_ARGUMENTS, core.env.player)
	if none ~= false or noneReason ~= FIRST_MISSING then
		return false, `a line with no arguments gave {noneReason}`
	end

	local first: any, firstReason: string? = core.dispatcher:evaluate(FIRST_ONLY, core.env.player)
	if first ~= false or firstReason ~= REST_MISSING then
		return false, `a line with only its first argument gave {firstReason}`
	end

	local reply: string, kind: string = core.run(FIRST_ONLY, core.env.player)
	if reply ~= REST_MISSING or kind ~= REFUSED then
		return false, `evaluateAndRun answered {reply} as {kind} for a line with only its first argument`
	end

	local both: any, bothReason: string? = core.dispatcher:evaluate(BOTH, core.env.player)
	if not both then
		return false, `a line with both arguments was refused: {bothReason}`
	end

	return true, nil
end
