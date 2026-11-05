--[[
    A Volt failure reaches the game's onFailure, and a client whose schema
    does not match is still kicked with Volt's message, by Volt's own
    handling, which Decree keeps for a handshake failure
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local RawClient = require("../../Fixtures/Server/RawClient")

local MISMATCHED: string = "Mismatched"
local HANDSHAKE: string = "handshake"
local MISMATCH: string = "schema mismatch"
local PLAIN: boolean = true -- Finds the text as written

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local failures: { { any } } = {}

	server.start({
		onFailure = function (player: any, kind: string, detail: string)
			table.insert(failures, { player, kind, detail })
		end,
	})

	local player: any, transport: any = server.env.mock:join(MISMATCHED)
	local raw: RawClient.RawClient = RawClient(transport)
	raw.handshake(bit32.bnot(raw.hash))

	server.env.mock:step()

	local failure: { any }? = failures[1]
	if not failure or failure[1] ~= player or failure[2] ~= HANDSHAKE then
		return false, "the mismatched handshake never reached the game's onFailure"
	elseif not player.kicked or not player.kicked:find(MISMATCH, 1, PLAIN) then
		return false, `the mismatched client was kicked with {player.kicked}`
	end

	return true, nil
end
