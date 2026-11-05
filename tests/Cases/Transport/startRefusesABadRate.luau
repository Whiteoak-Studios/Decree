--[[
    start raises an error when the game gives no rate, or a perSecond or a
    burst that is not a number above 0, and none of those calls starts
    Decree, so a start with a good rate still runs after them
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

-- Each settings table start refuses, by what is wrong with it
local REFUSED: { [string]: { [string]: any } } = {
	["no settings"] = {},
	["no perSecond"] = { rate = {} },
	["a perSecond of 0"] = { rate = { perSecond = 0 } },
	["a perSecond of 0 beside a good burst"] = { rate = { perSecond = 0, burst = 4 } },
	["a negative perSecond"] = { rate = { perSecond = -1 } },
	["a perSecond that is text"] = { rate = { perSecond = "fast" } },
	["a burst of 0"] = { rate = { perSecond = 1, burst = 0 } },
}

local GOOD: { [string]: any } = { rate = { perSecond = 1 } }

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()

	for wrong: string, settings: { [string]: any } in REFUSED do
		if pcall(server.decree.start, server.decree, settings) then
			return false, `start ran with {wrong}`
		end
	end

	local started: boolean, problem: any = pcall(server.decree.start, server.decree, GOOD)
	if not started then
		return false, `start with a good rate failed after the refused ones: {problem}`
	end

	return true, nil
end
