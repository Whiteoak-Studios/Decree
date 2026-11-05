--[[
    A fresh wipe command per call, which asks for confirmation before it
    runs and counts every run in the counter it is handed
--]]

--!strict
local NAME: string = "wipe"
local WIPED: string = "Wiped"

export type Counter = { runs: number }

return function (counter: Counter): { [string]: any }
	return {
		name = NAME,
		args = {},
		confirm = true,

		run = function (_: any): string
			counter.runs += 1

			return WIPED
		end,
	}
end
