--[[
    A confirm, in any case, with no line waiting for it is refused, and it
    reaches Confirm though no registered command is named confirm
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local CONFIRM: string = "Confirm"
local NOTHING_WAITING: string = "Nothing is waiting for confirm."
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.start()

	local answered: boolean, text: string, kind: string = server.run(CONFIRM)
	if not answered or text ~= NOTHING_WAITING or kind ~= REFUSED then
		return false, `{CONFIRM} with nothing waiting was answered {text} as {kind}`
	end

	return true, nil
end
