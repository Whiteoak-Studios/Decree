--[[
    Cmdr 1.13.1's own files load through the environment, their const lines
    rewritten and their string requires resolved, and Util splits a typed
    line with its quoted words kept as one argument
--]]

--!strict
local Environment = require("../../Environment")

local DISPATCHER: string = "Cmdr/CmdrClient/Shared/Dispatcher"
local UTIL: string = "Cmdr/CmdrClient/Shared/Util"
local LINE: string = `kick "two words" three`
local EXPECTED: { string } = { "kick", "two words", "three" }
local SEPARATOR: string = "|" -- Joins a list of arguments into one string to compare

return function (): (boolean, string | nil)
	local env: any = Environment.new()

	-- Dispatcher reaches Command, Argument and Util through ./ requires
	local dispatcher: any = env.require(DISPATCHER)
	if type(dispatcher) ~= "function" then
		return false, `Dispatcher returned a {type(dispatcher)}, not its constructor`
	end

	local segments: { string } = env.require(UTIL).SplitString(LINE)
	if table.concat(segments, SEPARATOR) ~= table.concat(EXPECTED, SEPARATOR) then
		return false, `SplitString gave {table.concat(segments, SEPARATOR)}`
	end

	return true, nil
end
