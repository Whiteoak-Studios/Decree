--[[
    A confirm sent after confirmSeconds have passed is refused as expired,
    and the waiting command never runs
--]]

--!strict
local task = require("@lune/task")

local Decree = require("../../Fixtures/Server/Decree")
local Wipe = require("../../Fixtures/Server/Wipe")

local LINE: string = "wipe"
local CONFIRM: string = "confirm"
local SECONDS: number = 0.2 -- A short window, which the case waits past
local LATE_SECONDS: number = 0.4 -- How long the case waits before it confirms
local EXPIRED: string = "The command waiting for confirm has expired."
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local counter: Wipe.Counter = { runs = 0 }

	server.decree.registry:registerCommandObject(Wipe(counter))
	server.start({ confirmSeconds = SECONDS })

	local asked: boolean = server.run(LINE)
	if not asked then
		return false, `{LINE} was never answered`
	end

	task.wait(LATE_SECONDS)

	local confirmed: boolean, text: string, kind: string = server.run(CONFIRM)
	if not confirmed or text ~= EXPIRED or kind ~= REFUSED then
		return false, `a late {CONFIRM} was answered {text} as {kind}`
	elseif counter.runs ~= 0 then
		return false, `{LINE} ran after its confirm expired`
	end

	return true, nil
end
