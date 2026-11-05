--[[
    Calls a function that should raise an error, and whether it raised one
    holding the expected refusal past the position Luau starts it with
--]]

--!strict
local PLAIN: boolean = true -- Finds the refusal as written, with no pattern characters

return function (expected: string, call: (...any) -> ...any, ...: any): boolean
	local ran: boolean, message: any = pcall(call, ...)

	return not ran and tostring(message):find(expected, 1, PLAIN) ~= nil
end
