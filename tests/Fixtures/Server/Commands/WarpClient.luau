--[[
    The teleport command's device half, named after its definition's module
    rather than the command, answering that it ran on the device
--]]

--!strict
local MOVED: string = "Moved on the device"

return function (_: any): string
	return MOVED
end
