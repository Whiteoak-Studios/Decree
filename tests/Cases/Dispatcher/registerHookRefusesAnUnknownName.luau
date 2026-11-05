--[[
    registerHook throws for a hook name Decree does not know, matched in its
    exact case, and the refused hook never counts as a beforeRun hook
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local NAME: string = "act"
local REPLY: string = "Acted"
local BLOCKED: string = "No permission hook is registered"
local REFUSED: string = "Refused"
local INVALID: string = "[Decree] Invalid hook name:"

-- A name no hook has, and beforeRun in lowercase
local UNKNOWN_NAMES: { string } = { "BeforeParse", "beforerun" }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry
	local hooked: number = 0

	local function hook(): string?
		hooked += 1

		return nil
	end

	registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): string
			return REPLY
		end,
	})

	for _, name: string in UNKNOWN_NAMES do
		local registered: boolean, thrown: any = pcall(registry.registerHook, registry, name, hook)
		if registered or Thrown(thrown) ~= `{INVALID} {name}` then
			return false, `registerHook of {name} gave {thrown}`
		end
	end

	local reply: string, kind: string = core.run(NAME, core.env.player)
	if reply ~= BLOCKED or kind ~= REFUSED or hooked ~= 0 then
		return false, `after the refused hooks the line answered {reply}, a refused hook running {hooked} times`
	end

	return true, nil
end
