--[[
    registerCommandObject throws for a definition with a key Decree does not
    know, or an argument with a property it does not know, and registers
    neither
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local KEYED: string = "keyed"
local PROPERTIED: string = "propertied"
local UNKNOWN_KEY: string = `[Decree] Unknown key/method in command "keyed": Hidden`
local UNKNOWN_PROPERTY: string = `[Decree] Unknown property in command "propertied" argument #2: Required`

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local keyed: { [string]: any } = { name = KEYED, args = {}, Hidden = true }
	local propertied: { [string]: any } = {
		name = PROPERTIED,
		args = {
			{ type = "string", name = "first" },
			{ type = "string", name = "second", Required = true },
		},
	}

	local keyedRegistered: boolean, keyedError: any = pcall(registry.registerCommandObject, registry, keyed)
	if keyedRegistered or Thrown(keyedError) ~= UNKNOWN_KEY then
		return false, `a definition with an unknown key gave {keyedError}`
	end

	local propertiedRegistered: boolean, propertiedError: any =
		pcall(registry.registerCommandObject, registry, propertied)
	if propertiedRegistered or Thrown(propertiedError) ~= UNKNOWN_PROPERTY then
		return false, `an argument with an unknown property gave {propertiedError}`
	end

	if registry:getCommand(KEYED) ~= nil or registry:getCommand(PROPERTIED) ~= nil or #registry:getCommands() ~= 0 then
		return false, "a refused definition was registered"
	end

	return true, nil
end
