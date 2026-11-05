--[[
    The serverStatus command's server half, the run the registry gives its
    definition, answering that the server is up
--]]

--!strict
local UP: string = "Up"

return function (_: any): string
	return UP
end
