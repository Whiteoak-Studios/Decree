--[[
    registerCommandObject refuses a definition listing one alias twice in
    any case, or an alias repeating its own name, and stores neither
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local TWICE: { [string]: any } = { name = "echo", aliases = { "say", "SAY" }, args = {} }
local TWICE_REFUSAL: string = `[Decree] Command "echo" lists say twice`
local OWN: { [string]: any } = { name = "ping", aliases = { "Ping" }, args = {} }
local OWN_REFUSAL: string = `[Decree] Command "ping" lists ping twice`
local WORDS: { string } = { "echo", "say", "ping" }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local twice: boolean, twiceError: any = pcall(registry.registerCommandObject, registry, TWICE)
	if twice or Thrown(twiceError) ~= TWICE_REFUSAL then
		return false, `an alias listed twice gave {twiceError}`
	end

	local own: boolean, ownError: any = pcall(registry.registerCommandObject, registry, OWN)
	if own or Thrown(ownError) ~= OWN_REFUSAL then
		return false, `an alias repeating the name gave {ownError}`
	end

	for _, word: string in WORDS do
		if registry:getCommand(word) ~= nil then
			return false, `{word} found a command after its registration was refused`
		end
	end

	if #registry:getCommands() ~= 0 or #core.access.definitions ~= 0 then
		return false, "a refused definition was stored or handed to the access check"
	end

	return true, nil
end
