--[[
    start raises an error when it is called a second time, even with the
    same good settings
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local SETTINGS: { [string]: any } = { rate = { perSecond = 1 } }

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree:start(SETTINGS)

	if pcall(server.decree.start, server.decree, SETTINGS) then
		return false, "start ran a second time"
	end

	return true, nil
end
