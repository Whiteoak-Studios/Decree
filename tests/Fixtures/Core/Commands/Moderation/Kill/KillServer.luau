--[[
    The kill command's server half, the run the registry gives its
    definition, answering that it ran on the server
--]]

--!strict
local KILLED: string = "Killed on the server"

return function (_: any): string
	return KILLED
end
