--[[
    The client entry loads on a client, its window's fonts included, to the
    client object with each call a game makes, which a game may make before
    start, and the client's own registry, dispatcher and util
--]]

--!strict
local Environment = require("../../Environment")

local CLIENT_ENTRY: string = "src/DecreeClient"
local PLACE_NAME: string = "Lobby"
local CONTEXT_LINE: string = "Round 1"

-- Each module the client object hands a game, by its key there
local MODULES: { [string]: string } = {
	registry = "src/DecreeClient/Shared/Registry",
	dispatcher = "src/DecreeClient/Shared/Dispatcher",
	util = "src/DecreeClient/Shared/Util",
}

-- Each call the client object takes, the window's among them
local CALLS: { string } = {
	"start",
	"setEnabled",
	"setActivationKeys",
	"setActivationUnlocksMouse",
	"setHideOnLostFocus",
	"setMashToEnable",
	"setPlaceName",
	"setContextLine",
	"addToggleButton",
	"show",
	"hide",
	"toggle",
	"handleEvent",
}

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })

	local loaded: boolean, client: any = pcall(env.require, CLIENT_ENTRY)
	if not loaded then
		return false, `the client entry could not load: {client}`
	end

	for _, name: string in CALLS do
		if type(client[name]) ~= "function" then
			return false, `the client object has no {name} call`
		end
	end

	for key: string, path: string in MODULES do
		if client[key] ~= env.require(path) then
			return false, `the client object's {key} is not {path}`
		end
	end

	local toggled: any = client.toggled
	if type(toggled) ~= "table" or type(toggled.Connect) ~= "function" or type(toggled.Fire) ~= "function" then
		return false, "the client object's toggled is no signal"
	end

	-- A game may set the window up before start, while there is no window yet to change
	local early: boolean, problem: any = pcall(function ()
		client:setPlaceName(PLACE_NAME)
		client:setContextLine(CONTEXT_LINE)
		client:setActivationKeys({})
		client:setActivationUnlocksMouse(true)
		client:setEnabled(false)
		client:show()
		client:toggle()
	end)

	if not early then
		return false, `a window call before start raised {problem}`
	end

	if client.gui ~= nil then
		return false, "the client object has a ScreenGui before start built one"
	end

	return true, nil
end
