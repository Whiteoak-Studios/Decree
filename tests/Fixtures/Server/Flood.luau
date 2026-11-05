--[[
    A fresh flood command per call: its run replies a number of lines of a
    size, all in one go, then answers that it is done
--]]

--!strict
local NAME: string = "flood"
local FILL: string = "x" -- One byte, so a line's size is its length
local DONE: string = "Flooded"

return function (count: number, size: number): { [string]: any }
	return {
		name = NAME,
		args = {},

		run = function (context: any): string
			for _ = 1, count do
				context:reply(FILL:rep(size))
			end

			return DONE
		end,
	}
end
