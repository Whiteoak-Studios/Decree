--[[
    The console prints each line the server sends in that line's kind, and
    prints an Error line when its ask for the player's commands fails
--]]

--!strict
local Console = require("../../Fixtures/Interface/Console")

local LINE: string = "The shard is wiped"
local OK: string = "Ok"
local FAILED: string = "Decree could not load your commands: no handler"
local ERROR: string = "Error"

return function (): (boolean, string | nil)
	local console: Console.Console = Console()

	-- No commands handler is bound, so the ask fails
	console.listen()
	console.step()

	local failed: Console.Line? = console.lines[1]
	if not failed or failed.text ~= FAILED or failed.kind ~= ERROR then
		return false, `a failed ask printed {failed and failed.text} as {failed and failed.kind}`
	end

	console.server.Decree.line.fire(console.env.player, LINE, OK)
	console.step()

	local printed: Console.Line? = console.lines[2]
	if not printed or printed.text ~= LINE or printed.kind ~= OK or #console.lines ~= 2 then
		return false, `the server's line printed {printed and printed.text} as {printed and printed.kind}`
	end

	return true, nil
end
