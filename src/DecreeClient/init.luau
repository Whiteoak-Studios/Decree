--[[
    The client entry and the client object a game requires from
    ReplicatedStorage.DecreeClient: the window calls, local events, and
    start, which builds the console and asks the server for its commands
--]]

--!strict
local Dispatcher = require("./DecreeClient/Shared/Dispatcher")
local Registry = require("./DecreeClient/Shared/Registry")
local ResolveStyle = require("./DecreeClient/Window/Functions/ResolveStyle")
local Session = require("./DecreeClient/Session")
local Util = require("./DecreeClient/Shared/Util")
local Window = require("./DecreeClient/Window")
local WindowConfig = require("./DecreeClient/Config/Window")

local MAX_LINES: number = WindowConfig.maxLines
local ACTIVATION_KEYS: { Enum.KeyCode } = WindowConfig.activationKeys
local PLACE_NAME: string = WindowConfig.placeName
local ADD_LINE: string = "AddLine" -- The local event a device half's reply prints through
local NONE: string = ""

local CommandTypes = require("./DecreeClient/Shared/Config/Types/Command")
local Wire = require("./DecreeClient/Shared/Wire")

export type Context = CommandTypes.Context
export type ArgumentContext = CommandTypes.ArgumentContext
export type TypeDefinition = CommandTypes.TypeDefinition
export type Run = CommandTypes.Run
export type Kind = Wire.Decree_Kind
export type Style = WindowConfig.Style

export type ClientSettings = {
	style: Style?, -- The console's colors and fonts, each key left out keeping its default
	maxLines: number?, -- The lines the console keeps, 500 when left out
}

type Connection = Window.Connection
type Settings = Window.Settings
type Toggled = Window.Toggled

-- Each callback toggled runs, by the token its connection holds
local Listeners: { [{ nil }]: (visible: boolean) -> () } = {}

local toggled: Toggled = {
	Connect = function (_: Toggled, callback: (visible: boolean) -> ()): Connection
		local token: { nil } = {}
		Listeners[token] = callback

		return {
			Disconnect = function (_: Connection)
				Listeners[token] = nil
			end,
		}
	end,

	Fire = function (_: Toggled, visible: boolean)
		-- A copy, so a callback that disconnects another mid-fire skips none and runs no disconnected one
		for token: { nil }, callback: (visible: boolean) -> () in table.clone(Listeners) do
			if Listeners[token] then
				task.spawn(callback, visible)
			end
		end
	end,
}

--- @class Client
--- The console's client object, a singleton a game calls with a colon

local Client = {
	registry = Registry,
	dispatcher = Dispatcher,
	util = Util,
	gui = nil :: ScreenGui?, -- The console's ScreenGui, once start builds it
	toggled = toggled, -- Fires with whether the window shows, each time that changes

	_settings = {
		enabled = true,
		activationKeys = table.clone(ACTIVATION_KEYS),
		activationUnlocksMouse = false,
		hideOnLostFocus = true,
		mashToEnable = false,
		placeName = PLACE_NAME,
		contextLine = NONE,
		maxLines = MAX_LINES,
		toggleButtons = {},
	} :: Settings, -- What the window reads, kept from before start
	_window = nil :: Window.Window?, -- The window, once start builds it
	_events = {} :: { [string]: (...any) -> () }, -- Each local event's handler by its name
	_started = false,
}

--- Builds the console in the game's style, then listens for the server's
--- lines and lists and asks for the player's commands. Errors on a second
--- call, an unknown style key or a style value of the wrong kind.
--- @method start
--- @within Client
--- @param settings ClientSettings?

function Client.start(self: Self, settings: ClientSettings?)
	assert(not self._started, "[Decree] The client starts once.")

	local given: ClientSettings = settings or {}
	local maxLines: number = given.maxLines or MAX_LINES
	assert(
		type(maxLines) == "number" and maxLines >= 1 and maxLines % 1 == 0,
		`[Decree] maxLines is a whole number of 1 or more, not {maxLines}`
	)

	local style: WindowConfig.ResolvedStyle = ResolveStyle(given.style, WindowConfig.style)

	self._started = true
	self._settings.maxLines = maxLines

	local window: Window.Window = Window.new(self, style)
	self._window = window
	self.gui = window.gui

	Session:watch()
	Session:listen(function (text: string, kind: Kind)
		window:addLine(text, kind)
	end, function ()
		window:clear()
	end)
end

--- Sets whether the activation keys, show and toggle open the console,
--- and hides it when turned off.
--- @method setEnabled
--- @within Client
--- @param enabled boolean

function Client.setEnabled(self: Self, enabled: boolean)
	self._settings.enabled = enabled

	if not enabled then
		self:hide()
	end
end

--- Sets the keys that open and close the console, F2 until a game sets
--- its own.
--- @method setActivationKeys
--- @within Client
--- @param keys { Enum.KeyCode }

function Client.setActivationKeys(self: Self, keys: { Enum.KeyCode })
	self._settings.activationKeys = keys

	local window: Window.Window? = self._window
	if window then
		window:bindActivationKeys()
	end
end

--- Sets whether the mouse is freed while the console shows.
--- @method setActivationUnlocksMouse
--- @within Client
--- @param enabled boolean

function Client.setActivationUnlocksMouse(self: Self, enabled: boolean)
	self._settings.activationUnlocksMouse = enabled

	local window: Window.Window? = self._window
	if window then
		window:updateMouseUnlock()
	end
end

--- Sets whether a click or tap outside the console hides it, on until a
--- game turns it off.
--- @method setHideOnLostFocus
--- @within Client
--- @param enabled boolean

function Client.setHideOnLostFocus(self: Self, enabled: boolean)
	self._settings.hideOnLostFocus = enabled
end

--- Sets whether the console first opens only once an activation key is
--- pressed five times within a second.
--- @method setMashToEnable
--- @within Client
--- @param enabled boolean

function Client.setMashToEnable(self: Self, enabled: boolean)
	self._settings.mashToEnable = enabled
end

--- Sets the place name the prompt shows after the player's name, as
--- Name@Place$; an empty name shows Name$.
--- @method setPlaceName
--- @within Client
--- @param name string

function Client.setPlaceName(self: Self, name: string)
	self._settings.placeName = name

	local window: Window.Window? = self._window
	if window then
		window:updatePrompt()
	end
end

--- Sets the line shown above the prompt; no text hides it.
--- @method setContextLine
--- @within Client
--- @param text string?

function Client.setContextLine(self: Self, text: string?)
	self._settings.contextLine = text or NONE

	local window: Window.Window? = self._window
	if window then
		window:updateContextLine()
	end
end

--- Registers a button of the game's that toggles the console, so a tap on
--- it never counts as a tap outside the console, until it is destroyed.
--- @method addToggleButton
--- @within Client
--- @param button GuiObject

function Client.addToggleButton(self: Self, button: GuiObject)
	local toggleButtons: { [GuiObject]: RBXScriptConnection } = self._settings.toggleButtons
	if toggleButtons[button] then
		return
	end

	-- Held until it is destroyed, since a game may keep no other hold on its button
	local destroying: RBXScriptConnection
	destroying = button.Destroying:Connect(function ()
		destroying:Disconnect()
		toggleButtons[button] = nil
	end)

	toggleButtons[button] = destroying
end

--- Shows the console, once it has started and while it is enabled.
--- @method show
--- @within Client

function Client.show(self: Self)
	local window: Window.Window? = self._window
	if window and self._settings.enabled then
		window:show()
	end
end

--- Hides the console.
--- @method hide
--- @within Client

function Client.hide(self: Self)
	local window: Window.Window? = self._window
	if window then
		window:hide()
	end
end

--- Shows the console when it is hidden and hides it when it shows, once it
--- has started and while it is enabled.
--- @method toggle
--- @within Client

function Client.toggle(self: Self)
	local window: Window.Window? = self._window
	if window and self._settings.enabled then
		window:setVisible(not window:isVisible())
	end
end

--- Sets the handler a local event runs, in place of any before it, such as
--- AddLine, which prints a device half's reply in the console.
--- @method handleEvent
--- @within Client
--- @param name string
--- @param callback (...any) -> ()

function Client.handleEvent(self: Self, name: string, callback: (...any) -> ())
	self._events[name] = callback
end

Client:handleEvent(ADD_LINE, function (text: any, kind: any)
	local window: Window.Window? = Client._window
	if window then
		window:addLine(text, kind)
	end
end)

Session:bind(Client, function (name: string, ...: any)
	local handler: ((...any) -> ())? = Client._events[name]
	if handler then
		handler(...)
	end
end)

export type Client = Self
type Self = typeof(Client)

return Client
