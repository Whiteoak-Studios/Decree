--[[
    The kill command's device half, the run a holder's console runs from its
    own copy, answering that it ran on the device
--]]

--!strict
local KILLED: string = "Killed on the device"

return function (_: any): string
	return KILLED
end
