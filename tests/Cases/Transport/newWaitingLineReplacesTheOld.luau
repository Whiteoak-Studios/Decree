--[[
    A player has one waiting line: a second line that asks replaces the
    first, so confirm runs only the second, and nothing waits after it
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local NAME: string = "wipe"
local FIRST: string = "north"
local SECOND: string = "south"
local SECONDS: number = 5 -- Room to send confirm in
local CONFIRM: string = "confirm"
local NOTHING_WAITING: string = "Nothing is waiting for confirm."

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local ran: { string } = {}

	server.decree.registry:registerCommandObject({
		name = NAME,
		args = { { name = "shard", type = "string" } },
		confirm = true,

		run = function (_: any, shard: string): string
			table.insert(ran, shard)

			return shard
		end,
	})

	server.start({ confirmSeconds = SECONDS })
	server.run(`{NAME} {FIRST}`)
	server.run(`{NAME} {SECOND}`)

	local _, confirmed: string = server.run(CONFIRM)
	if confirmed ~= SECOND or #ran ~= 1 or ran[1] ~= SECOND then
		return false, `{CONFIRM} ran {#ran} lines, the first {ran[1]}, where only the second waits`
	end

	local _, again: string = server.run(CONFIRM)
	if again ~= NOTHING_WAITING then
		return false, `a second {CONFIRM} was answered {again}`
	end

	return true, nil
end
