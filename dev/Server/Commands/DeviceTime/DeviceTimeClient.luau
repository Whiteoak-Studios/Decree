--[[
    The devicetime command's device half, cloned to each player who holds
    it, which answers with the device's own clock and sends nothing
--]]

--!strict
local FORMAT: string = "LTS" -- Hours, minutes and seconds
local LOCALE: string = "en-us"
local OK: string = "Ok"

-- A clone in the player's PlayerGui reaches no server module, so the context goes untyped
return function (_: any): (string, string)
	return `Your device's clock reads {DateTime.now():FormatLocalTime(FORMAT, LOCALE)}.`, OK
end
