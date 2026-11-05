--[[
    The shout command's device half, the run a holder's console runs from
    its own copy, answering that it ran on the device
--]]

--!strict
local SHOWN: string = "Shown on the device"

return function (_: any): string
	return SHOWN
end
