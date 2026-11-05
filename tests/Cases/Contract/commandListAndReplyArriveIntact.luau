--[[
    Decree's generated server and client modules carry the contract over
    Volt's mock: a command list with a subcommand and a device half arrives
    intact, and a typed line's reply resolves with its text and kind
--]]

--!strict
local Environment = require("../../Environment")

local SERVER: string = "src/Network"
local CLIENT: string = "src/DecreeClient/Network"
local LINE: string = "camera zoom 20"
local REPLY: string = "The camera is 20 studs out"
local RESOLVED: string = "Resolved" -- Promise.Status.Resolved

local Wire = require("../../../src/DecreeClient/Shared/Wire")

type Commands = Wire.Decree_Commands
type Kind = Wire.Decree_Kind

--[[
    Whether two values hold the same data: equal leaves, and tables with
    the same keys holding the same values, checked both ways round
--]]

local function same(expected: any, actual: any): boolean
	if type(expected) ~= "table" or type(actual) ~= "table" then
		return expected == actual
	end

	for key: any, value: any in expected do
		if not same(value, actual[key]) then
			return false
		end
	end

	for key: any in actual do
		if expected[key] == nil then
			return false
		end
	end

	return true
end

return function (): (boolean, string | nil)
	local env: Environment.Environment = Environment.new()
	local server: any = env.require(SERVER)
	local client: any = env.require(CLIENT)

	local kind: Kind = "Ok"
	local list: Commands = {
		{
			name = "camera",
			aliases = { "cam" },
			description = "Changes how the camera follows you",
			group = "Debug",
			tags = { "view" },
			args = {},
			autoExec = { LINE },
			subcommands = {
				{
					name = "zoom",
					description = "Sets the camera's distance from your character",
					args = {
						{
							name = "distance",
							type = "number",
							description = "Studs from the character",
							optional = false,
						},
					},
				},
			},
			device = true,
		},
	}

	server.Decree.commands.on(function (_: any): Commands
		return list
	end)

	local heard: string? = nil
	server.Decree.run.on(function (_: any, text: string): (string, Kind)
		heard = text

		return REPLY, kind
	end)

	local listed: any = client.Decree.commands.invoke()
	local replied: any = client.Decree.run.invoke(LINE)
	for _ = 1, Environment.ROUND_TRIP do
		env.mock:step()
	end

	if listed:getStatus() ~= RESOLVED or replied:getStatus() ~= RESOLVED then
		return false, `commands was {listed:getStatus()} and run was {replied:getStatus()} after the round trip`
	end

	local _: boolean, received: Commands = listed:await()
	if not same(list, received) then
		return false, "the command list arrived changed"
	end

	local _: boolean, text: string, receivedKind: Kind = replied:await()
	if heard ~= LINE or text ~= REPLY or receivedKind ~= kind then
		return false, `the server heard {heard} and the client got {text} as {receivedKind}`
	end

	return true, nil
end
