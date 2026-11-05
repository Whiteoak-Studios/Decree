--[[
    The dispatcher binds its server port once and only on the server, and
    its client port once and only on a client, and a line's context carries
    the decree of the port bound first
--]]

--!strict
local Access = require("../../Fixtures/Core/Access")
local ClientPort = require("../../Fixtures/Core/ClientPort")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Entry = require("../../Fixtures/Core/Entry")
local Environment = require("../../Environment")
local ServerPort = require("../../Fixtures/Core/ServerPort")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local DISPATCHER: string = "src/DecreeClient/Shared/Dispatcher"
local PROMISE: string = "Packages/Promise"
local LINE: string = "echo hello"
local SERVER_ONCE: string = "[Decree] The server dispatcher is bound once."
local CLIENT_ONCE: string = "[Decree] The client dispatcher is bound once."
local SERVER_ONLY: string = "[Decree] bindServer runs on the server."
local CLIENT_ONLY: string = "[Decree] bindClient runs on the client."

return function (): (boolean, string | nil)
	local serverEnv: any = Environment.new()
	local server: any = serverEnv.require(DISPATCHER)
	local Promise: any = serverEnv.require(PROMISE)
	local serverPort: ServerPort.ServerPort = ServerPort()

	server:bindServer(serverPort)

	local serverAgain: boolean, serverAgainError: any = pcall(server.bindServer, server, ServerPort())
	if serverAgain or Thrown(serverAgainError) ~= SERVER_ONCE then
		return false, `a second bindServer gave {serverAgainError}`
	end

	local clientOnServer: boolean, clientOnServerError: any = pcall(server.bindClient, server, ClientPort(Promise))
	if clientOnServer or Thrown(clientOnServerError) ~= CLIENT_ONLY then
		return false, `bindClient on the server gave {clientOnServerError}`
	end

	local registry: any = serverEnv.require(REGISTRY)
	registry:bind(Access())
	registry:registerCommandObject(Echo())

	local serverContext: any = server:evaluate(LINE, serverEnv.player)
	if not serverContext or serverContext.decree ~= serverPort.decree then
		return false, "a server line's context does not carry the first port's decree"
	end

	local clientEnv: any = Environment.new({ side = "client" })
	local client: any = clientEnv.require(DISPATCHER)
	local clientPort: ClientPort.ClientPort = ClientPort(clientEnv.require(PROMISE))

	client:bindClient(clientPort)

	local clientAgain: boolean, clientAgainError: any = pcall(client.bindClient, client, ClientPort(Promise))
	if clientAgain or Thrown(clientAgainError) ~= CLIENT_ONCE then
		return false, `a second bindClient gave {clientAgainError}`
	end

	local serverOnClient: boolean, serverOnClientError: any = pcall(client.bindServer, client, ServerPort())
	if serverOnClient or Thrown(serverOnClientError) ~= SERVER_ONLY then
		return false, `bindServer on a client gave {serverOnClientError}`
	end

	clientEnv.require(REGISTRY):replaceCommands({ Entry(Echo()) })

	local clientContext: any = client:evaluate(LINE, clientEnv.player)
	if not clientContext or clientContext.decree ~= clientPort.decree then
		return false, "a client line's context does not carry the first port's decree"
	end

	return true, nil
end
