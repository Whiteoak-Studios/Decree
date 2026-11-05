--[[
    A fresh argument type per call whose validate refuses two set words and
    whose validateOnce refuses two others, one word of each pair refused
    with a message and the other with none
--]]

--!strict
local BAD: string = "bad"
local QUIET: string = "quiet"
local LATE: string = "late"
local HUSHED: string = "hushed"
local BAD_MESSAGE: string = "Bad value."
local LATE_MESSAGE: string = "Late value."

return function (): { [string]: any }
	return {
		validate = function (text: string): (boolean, string | nil)
			if text == BAD then
				return false, BAD_MESSAGE
			end

			return text ~= QUIET, nil
		end,

		validateOnce = function (text: string): (boolean, string | nil)
			if text == LATE then
				return false, LATE_MESSAGE
			end

			return text ~= HUSHED, nil
		end,

		parse = function (text: string): string
			return text
		end,
	}
end
