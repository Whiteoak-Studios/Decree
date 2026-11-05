--[[
    The commands call answers the player's list over Volt, each entry's
    device flag true only for a command registered with a {Name}Client
    module beside it
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local COMMANDS: string = "tests/Fixtures/Core/Commands"

-- Each command the folder registers, by whether it has a device half
local DEVICE: { [string]: boolean } = {
	clientInfo = true,
	kill = true,
	serverStatus = false,
}

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree({ folders = { COMMANDS } })
	server.decree.registry:registerCommandsIn(server.env.find(COMMANDS))
	server.start()

	local listed: any = server.client.Decree.commands.invoke()
	if not server.settle(listed) then
		return false, "the list never came"
	end

	local resolved: boolean, list: { any } = listed:await()
	if not resolved then
		return false, `the commands call was refused: {list}`
	end

	local unseen: { [string]: boolean } = table.clone(DEVICE)

	for _, entry: any in list do
		if unseen[entry.name] == nil then
			return false, `the list holds {entry.name} where it holds each registered command once`
		elseif entry.device ~= DEVICE[entry.name] then
			return false, `{entry.name}'s device flag is {entry.device}`
		end

		unseen[entry.name] = nil
	end

	local missing: string? = next(unseen)
	if missing then
		return false, `the list leaves out {missing}`
	end

	return true, nil
end
