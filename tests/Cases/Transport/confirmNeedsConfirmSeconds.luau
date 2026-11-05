--[[
    A command or subcommand asking for confirmation needs confirmSeconds:
    start refuses to run without it while one is registered, and once
    start has run without it, registering one is refused
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Wipe = require("../../Fixtures/Server/Wipe")

local RATE: { [string]: number } = { perSecond = 1 }

return function (): (boolean, string | nil)
	local before: Decree.Decree = Decree()
	before.decree.registry:registerCommandObject(Wipe({ runs = 0 }))

	if pcall(before.decree.start, before.decree, { rate = RATE }) then
		return false, "start ran without confirmSeconds while a registered command asks for confirmation"
	end

	local after: Decree.Decree = Decree()
	after.decree:start({ rate = RATE })

	local subcommands: { [string]: any } = {
		name = "shard",
		subcommands = { { name = "close", confirm = true } },
	}

	if pcall(after.decree.registry.registerCommandObject, after.decree.registry, Wipe({ runs = 0 })) then
		return false, "a command asking for confirmation registered after start had no confirmSeconds"
	elseif pcall(after.decree.registry.registerCommandObject, after.decree.registry, subcommands) then
		return false, "a subcommand asking for confirmation registered after start had no confirmSeconds"
	elseif not pcall(after.decree.registry.registerCommandObject, after.decree.registry, Echo()) then
		return false, "a command asking for nothing was refused"
	end

	return true, nil
end
