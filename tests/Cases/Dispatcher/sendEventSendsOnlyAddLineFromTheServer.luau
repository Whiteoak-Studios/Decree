--[[
    The server's sendEvent sends AddLine alone, to the port with no caller,
    and refuses every other event and broadcastEvent, while a client's
    sends any event to the LocalPlayer's port and refuses a broadcast
--]]

--!strict
local Client = require("../../Fixtures/Core/Client")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Entry = require("../../Fixtures/Core/Entry")
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local ADD_LINE: string = "AddLine"
local OTHER: string = "Flash"
local BROADCAST: string = "Announce"
local LINE: string = "echo hello"
local TEXT: string = "Printed"
local NUMBER: number = 5
local NUMBER_TEXT: string = "5"
local OK: string = "Ok"
local INFO: string = "Info"
local SECOND: string = "Second"
local NOT_A_PLAYER: { [string]: any } = { Name = "Nobody" }
local OTHER_REFUSAL: string =
	`[Decree] The server sends only AddLine, since every other event and its remote are removed: {OTHER}`
local BROADCAST_REFUSAL: string =
	`[Decree] broadcastEvent is removed, since Decree sends no event to every client: {BROADCAST}`
local NOT_A_PLAYER_REFUSAL: string = "[Decree] Argument #1 must be a Player"
local CLIENT_BROADCAST_REFUSAL: string = "[Decree] Can't broadcast event messages from the client."
local NOT_LOCAL_REFUSAL: string = "[Decree] Event messages can only be sent to the local player on the client."

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local dispatcher: any = core.dispatcher
	local player: any = core.env.player
	local lines: { any } = core.port.lines

	dispatcher:sendEvent(player, ADD_LINE, TEXT, OK)
	dispatcher:sendEvent(player, ADD_LINE, NUMBER)

	local first: any, second: any = lines[1], lines[2]
	if #lines ~= 2 or first.recipient ~= player or first.text ~= TEXT or first.kind ~= OK or first.caller ~= nil then
		return false, "AddLine did not reach the port as given, with no caller"
	end

	if second.text ~= NUMBER_TEXT or second.kind ~= INFO or second.caller ~= nil then
		return false, `AddLine with a number and no kind reached the port as {second.text}, {second.kind}`
	end

	local other: boolean, otherError: any = pcall(dispatcher.sendEvent, dispatcher, player, OTHER, TEXT)
	if other or Thrown(otherError) ~= OTHER_REFUSAL then
		return false, `sendEvent with another event gave {otherError}`
	end

	local stranger: boolean, strangerError: any = pcall(dispatcher.sendEvent, dispatcher, NOT_A_PLAYER, ADD_LINE, TEXT)
	if stranger or Thrown(strangerError) ~= NOT_A_PLAYER_REFUSAL then
		return false, `sendEvent to a table that is no Player gave {strangerError}`
	end

	local broadcast: boolean, broadcastError: any = pcall(dispatcher.broadcastEvent, dispatcher, BROADCAST)
	if broadcast or Thrown(broadcastError) ~= BROADCAST_REFUSAL then
		return false, `broadcastEvent gave {broadcastError}`
	end

	-- A command's own broadcastEvent raises the same error
	core.registry:registerCommandObject(Echo())

	local context: any = dispatcher:evaluate(LINE, player)
	local fromContext: boolean, contextError: any = pcall(context.broadcastEvent, context, BROADCAST)
	if fromContext or Thrown(contextError) ~= BROADCAST_REFUSAL or #lines ~= 2 then
		return false, `a context's broadcastEvent gave {contextError}, or a refused event reached the port`
	end

	local client: Client.Core = Client()
	local localPlayer: any = client.env.player
	local events: { any } = client.port.events

	client.dispatcher:sendEvent(localPlayer, OTHER, TEXT, NUMBER)
	client.dispatcher:sendEvent(localPlayer, ADD_LINE, TEXT)

	local flash: any, added: any = events[1], events[2]
	if #events ~= 2 or flash.name ~= OTHER or flash.values.n ~= 2 or flash.values[2] ~= NUMBER then
		return false, `the client's event reached its port as {flash and flash.name}`
	end

	if added.name ~= ADD_LINE or added.values[1] ~= TEXT then
		return false, "the client's AddLine did not reach its port as a local event"
	end

	local secondPlayer: any = client.env.mock:join(SECOND)
	local away: boolean, awayError: any = pcall(client.dispatcher.sendEvent, client.dispatcher, secondPlayer, OTHER)
	if away or Thrown(awayError) ~= NOT_LOCAL_REFUSAL then
		return false, `a client's sendEvent to another player gave {awayError}`
	end

	client.registry:replaceCommands({ Entry(Echo()) })

	local clientContext: any = client.dispatcher:evaluate(LINE, localPlayer)
	local clientBroadcast: boolean, clientError: any = pcall(clientContext.broadcastEvent, clientContext, BROADCAST)
	if clientBroadcast or Thrown(clientError) ~= CLIENT_BROADCAST_REFUSAL then
		return false, `a client's broadcastEvent gave {clientError}`
	end

	return true, nil
end
