--[[
    confirm takes no arguments: one with a word after it is refused and
    leaves the line waiting, which a plain confirm then runs
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Wipe = require("../../Fixtures/Server/Wipe")

local LINE: string = "wipe"
local WORDY: string = "confirm now"
local CONFIRM: string = "confirm"
local SECONDS: number = 5 -- Room to send both confirms in
local EXTRA_WORDS: string = "confirm takes no arguments."
local REFUSED: string = "Refused"
local WIPED: string = "Wiped"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local counter: Wipe.Counter = { runs = 0 }

	server.decree.registry:registerCommandObject(Wipe(counter))
	server.start({ confirmSeconds = SECONDS })
	server.run(LINE)

	local refused: boolean, refusal: string, kind: string = server.run(WORDY)
	if not refused or refusal ~= EXTRA_WORDS or kind ~= REFUSED or counter.runs ~= 0 then
		return false, `{WORDY} was answered {refusal} as {kind}, and {LINE} ran {counter.runs} times`
	end

	local confirmed: boolean, text: string = server.run(CONFIRM)
	if not confirmed or text ~= WIPED or counter.runs ~= 1 then
		return false, `{CONFIRM} after a refused one was answered {text}`
	end

	return true, nil
end
