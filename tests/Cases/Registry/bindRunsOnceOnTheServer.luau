--[[
    The registry binds its access check once and only on the server, a
    command registered before bind is refused, and on a client no command
    registers at all
--]]

--!strict
local Access = require("../../Fixtures/Core/Access")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Environment = require("../../Environment")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local NAME: string = "echo"
local UNBOUND: string = "[Decree] The registry registers commands once bind has given it the access check."
local BOUND_ONCE: string = "[Decree] The registry is bound once."
local SERVER_ONLY: string = "[Decree] bind runs on the server, where commands register."
local REGISTERS_ON_SERVER: string = "[Decree] Commands register on the server, which hands each player their own list."

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)

	local early: boolean, earlyError: any = pcall(registry.registerCommandObject, registry, Echo())
	if early or Thrown(earlyError) ~= UNBOUND or registry:getCommand(NAME) ~= nil then
		return false, `a command registered before bind gave {earlyError}`
	end

	local first: Access.Access = Access()
	local second: Access.Access = Access()
	registry:bind(first)

	local rebound: boolean, reboundError: any = pcall(registry.bind, registry, second)
	if rebound or Thrown(reboundError) ~= BOUND_ONCE then
		return false, `a second bind gave {reboundError}`
	end

	-- The first access check stays the registry's
	registry:registerCommandObject(Echo())
	if registry:getCommand(NAME) == nil or #first.definitions ~= 1 or #second.definitions ~= 0 then
		return false, "the command did not register through the first access check"
	end

	local client: any = Environment.new({ side = "client" }).require(REGISTRY)

	local clientBound: boolean, clientBindError: any = pcall(client.bind, client, Access())
	if clientBound or Thrown(clientBindError) ~= SERVER_ONLY then
		return false, `bind on a client gave {clientBindError}`
	end

	local clientRegistered: boolean, clientError: any = pcall(client.registerCommandObject, client, Echo())
	if clientRegistered or Thrown(clientError) ~= REGISTERS_ON_SERVER or client:getCommand(NAME) ~= nil then
		return false, `registering a command on a client gave {clientError}`
	end

	return true, nil
end
