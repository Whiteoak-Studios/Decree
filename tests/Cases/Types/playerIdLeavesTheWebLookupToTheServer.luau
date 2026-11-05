--[[
    On a client the playerId type never looks a name up on the web: its
    final check passes any name for the server to make, and it parses only
    a joined player's name to an id
--]]

--!strict
local Environment = require("../../Environment")

local TYPES: string = "src/DecreeClient/Shared/Types/Players"
local TYPE: string = "playerId"
local OFFLINE: string = "Offline" -- A name no joined player holds, which only the web lookup knows
local OFFLINE_ID: number = 4242
local NOBODY: string = "Nobody"

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local userIds: { [string]: number } = env.game:GetService("Players").userIds
	local definition: any = env.require(TYPES)[TYPE]

	userIds[OFFLINE] = OFFLINE_ID

	for _, name: string in { OFFLINE, NOBODY } do
		local valid: boolean, reason: string? = definition.validateOnce(name)
		if not valid or reason ~= nil then
			return false, `playerId refused {name} on the client with {reason}`
		end
	end

	if definition.parse(OFFLINE) ~= nil then
		return false, "playerId looked a name up on the web from the client"
	end

	if definition.parse(env.player.Name) ~= env.player.UserId then
		return false, "playerId did not parse a joined player's name to their id on the client"
	end

	return true, nil
end
