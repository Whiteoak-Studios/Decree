--[[
    Cmdr 1.13.1 on the client side evaluates a line whose argument is still
    being typed, as its autocomplete does, and offers the matching player,
    while it refuses a finished line without it and any other executor
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "greet"
local SECOND: string = "Second"
local TYPED: string = "Se" -- The start of SECOND's name, as a player is still typing it
local SUGGESTED: string = SECOND -- The one name autocomplete offers for TYPED
local MISSING: string = "Required argument #1 target is missing."

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local second: any = env.mock:join(SECOND)
	local cmdr: any = env.cmdr()

	cmdr.Registry:RegisterCommandObject({
		Name = NAME,
		Args = { { Type = "player", Name = "target" } },
	})

	local context: any, reason: string? = cmdr.Dispatcher:Evaluate(`{NAME} {TYPED}`, env.player, true)
	if not context then
		return false, `the incomplete line was refused: {reason}`
	end

	local suggestions: { string } = context:GetArgument(1):GetAutocomplete()
	if #suggestions ~= 1 or suggestions[1] ~= SUGGESTED then
		return false, `autocomplete offered {table.concat(suggestions, ", ")}`
	end

	local finished: any, refusal: string? = cmdr.Dispatcher:Evaluate(NAME, env.player)
	if finished or refusal ~= MISSING then
		return false, `the finished line without its argument gave {refusal}`
	end

	if pcall(cmdr.Dispatcher.Evaluate, cmdr.Dispatcher, `{NAME} {TYPED}`, second, true) then
		return false, "the client evaluated a line for a player who is not its LocalPlayer"
	end

	return true, nil
end
