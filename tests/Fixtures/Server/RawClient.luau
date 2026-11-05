--[[
    A raw client of Decree's scope on one mock transport, whose packets are
    written by hand from Volt's framing and the schema's hash, past the
    generated writer that would refuse them, keeping what the server sends
--]]

--!strict
local fs = require("@lune/fs")

local NETWORK: string = "src/Network.luau" -- The generated server module, whose schema table holds the hash
local HASH: string = "hash = (0x%x+)"
local HANDSHAKE_ID: number = 0 -- The id that opens a client's first packet
local RUN_ID: number = 1 -- Decree.run's call id toward the server
local SLOT: number = 1 -- The call slot the raw client's one call takes
local HANDSHAKE_BYTES: number = 5 -- The id, then the hash as a u32
local CALL_BYTES: number = 5 -- The id, the slot as a u16, then the text's length less one as a u16

-- The schema's hash, as the server checks a handshake against it
local HASH_DIGITS: string = fs.readFile(NETWORK):match(HASH) :: string
local SCHEMA_HASH: number = tonumber(HASH_DIGITS) :: number

export type RawClient = {
	hash: number, -- The schema's hash
	received: { buffer }, -- Every packet the server sent this client, in order
	handshake: (hash: number) -> (), -- Sends a handshake with any hash, alone in its packet
	run: (text: string) -> (), -- Sends the right handshake and one run call carrying any text, in one packet
}

--[[
    A client's first packet: the handshake with a hash, then a run call in
    slot 1 when there is text
--]]

local function packet(hash: number, text: string?): buffer
	local out: buffer = buffer.create(HANDSHAKE_BYTES + (text and CALL_BYTES + #text or 0))
	buffer.writeu8(out, 0, HANDSHAKE_ID)
	buffer.writeu32(out, 1, hash)

	if text then
		buffer.writeu8(out, HANDSHAKE_BYTES, RUN_ID)
		buffer.writeu16(out, HANDSHAKE_BYTES + 1, SLOT)
		buffer.writeu16(out, HANDSHAKE_BYTES + 3, #text - 1)
		buffer.writestring(out, HANDSHAKE_BYTES + CALL_BYTES, text)
	end

	return out
end

return function (transport: any): RawClient -- A client transport from the mock's join or connectBot
	local received: { buffer } = {}

	transport.receive(function (_: any, sent: buffer)
		table.insert(received, sent)
	end)

	return {
		hash = SCHEMA_HASH,
		received = received,

		handshake = function (hash: number)
			transport.reliable(nil, packet(hash, nil))
		end,

		run = function (text: string)
			transport.reliable(nil, packet(SCHEMA_HASH, text))
		end,
	}
end
