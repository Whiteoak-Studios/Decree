--[[
    The console's side of the wire: the port it binds the dispatcher with,
    the one typed line it lets wait on the server, and the server's lists,
    each device command held back until its clone is in DecreeCommands
--]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Network = require("./Network")

local Dispatcher = require("./Shared/Dispatcher")
local Registry = require("./Shared/Registry")

local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui -- Boot-time wait: it may not have replicated yet

local LINE_BYTES: number = require("./Shared/Constants").LINE_BYTES
local DECREE_COMMANDS: string = "DecreeCommands" -- The ScreenGui each granted command's device half is cloned into
local DEVICE_HALF: string = "Client" -- Follows a command's name in its device half's name
local CLEAR: string = "clear"
local CLEARED: string = "" -- What clear answers, which prints nothing
local EMPTY: string = "Command cannot be empty."
local NOT_TEXT: string = "A command must be valid UTF-8 text."
local WAIT: string = "Wait for your last command to finish."
local REFUSED: Kind = "Refused"
local ERROR: Kind = "Error"

local Types = require("./Shared/Config/Types/Command")
local Wire = require("./Shared/Wire")

type Commands = Wire.Decree_Commands
type Context = Types.Context
type Kind = Wire.Decree_Kind
type Run = Types.Run
type WireCommand = Wire.Decree_Command

-- How listen prints a line in the console
type Print = (text: string, kind: Kind) -> ()

-- Decree's own clear, which the list gains whenever it holds a command
local CLEAR_ENTRY: WireCommand = {
	name = CLEAR,
	aliases = {},
	description = "Clears the console's lines.",
	tags = {},
	args = {},
	autoExec = {},
	subcommands = {},
	device = true,
}

local Session = {
	_waiting = false, -- Whether a sent line still waits for the server's answer
	_list = nil :: Commands?, -- The server's last list, handed to the registry again when a clone comes or goes
	_clear = nil :: (() -> ())?, -- Empties the console's lines, which listen gives
}

--[[
    The device half cloned for a command, the {Name}Client module in the
    DecreeCommands ScreenGui, matched by name in any case
--]]

local function findHalf(name: string): ModuleScript?
	local commands: Instance? = PlayerGui:FindFirstChild(DECREE_COMMANDS)
	if not commands then
		return nil
	end

	local wanted: string = (`{name}{DEVICE_HALF}`):lower()

	for _, child: Instance in commands:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:lower() == wanted then
			return child
		end
	end

	return nil
end

--- Binds the dispatcher's client port: lines go to the server through
--- send, local events to the event function, and device halves come from
--- clientRun. Called once, when the client entry loads.
--- @method bind
--- @within Session
--- @param decree any -- The client object, which a context carries as decree
--- @param event (name: string, ...any) -> () -- Runs the handler a local event names

function Session.bind(self: Self, decree: any, event: (name: string, ...any) -> ())
	Dispatcher:bindClient({
		decree = decree,
		event = event,

		send = function (text: string): any
			return self:send(text)
		end,

		clientRun = function (name: string): Run?
			return self:clientRun(name)
		end,
	})
end

--- Sends a typed line to the server, to a Promise of the reply's text and
--- kind that never rejects. A line of no bytes, of more than LINE_BYTES or
--- of invalid UTF-8, and a line while another waits, are refused at once,
--- and a call Volt fails answers its reason as an Error.
--- @method send
--- @within Session
--- @param text string
--- @return Promise -- Resolves with (text: string, kind: Decree_Kind)

function Session.send(self: Self, text: string): any
	if #text < 1 then
		return Promise.resolve(EMPTY, REFUSED)
	elseif #text > LINE_BYTES then
		return Promise.resolve(`A command is at most {LINE_BYTES} bytes, and this one is {#text}.`, REFUSED)
	elseif utf8.len(text) == nil then
		return Promise.resolve(NOT_TEXT, REFUSED)
	elseif self._waiting then
		return Promise.resolve(WAIT, REFUSED)
	end

	self._waiting = true

	return Promise.try(Network.Decree.run.invoke, text):andThen(function (reply: string, kind: Kind): (string, Kind)
		self._waiting = false

		return reply, kind
	end, function (reason: any): (string, Kind)
		self._waiting = false

		return `The command failed: {reason}`, ERROR
	end)
end

--- The run a command's device half returns, from its clone in the
--- DecreeCommands ScreenGui, or nil while none is there; clear's empties
--- the console and sends nothing.
--- @method clientRun
--- @within Session
--- @param name string -- The command's name
--- @return Run?

function Session.clientRun(self: Self, name: string): Run?
	if name == CLEAR then
		local clear: () -> () = assert(self._clear, "[Decree] clear runs once the console listens.")

		return function (_: Context): string
			clear()

			return CLEARED
		end
	end

	local half: ModuleScript? = findHalf(name)
	if not half then
		return nil
	end

	local run: any = require(half) :: any
	assert(type(run) == "function", `[Decree] {half.Name} returned a {type(run)}, where a device half returns its run`)

	return run
end

--[[
    Takes the server's list: every command but a device command whose
    clone has not arrived goes to the registry, and clear with them when
    the list holds a command
--]]

function Session._apply(self: Self, list: Commands)
	self._list = list

	local held: Commands = {}

	for _, entry: WireCommand in list do
		if not entry.device or findHalf(entry.name) then
			table.insert(held, entry)
		end
	end

	if #list > 0 then
		table.insert(held, CLEAR_ENTRY)
	end

	Registry:replaceCommands(held)
end

--- Hands the registry the server's last list again, as a device half's
--- clone arrives or leaves.
--- @method refresh
--- @within Session

function Session.refresh(self: Self)
	local list: Commands? = self._list
	if list then
		self:_apply(list)
	end
end

--- Prints the server's lines through addLine and takes each list it
--- pushes, then asks for the player's list. Called once, at the client's
--- start, with the window's addLine and clear.
--- @method listen
--- @within Session
--- @param addLine Print
--- @param clear () -> ()

function Session.listen(self: Self, addLine: Print, clear: () -> ())
	self._clear = clear

	-- Both listeners live for the client session, as the console does
	Network.Decree.line.on(addLine)
	Network.Decree.access.on(function (list: Commands)
		self:_apply(list)
	end)

	Network.Decree.commands
		.invoke()
		:andThen(function (list: Commands)
			self:_apply(list)
		end)
		:catch(function (reason: any)
			addLine(`Decree could not load your commands: {reason}`, ERROR)
		end)
end

--- Refreshes the list whenever a child comes or goes in the DecreeCommands
--- ScreenGui, or the ScreenGui itself does. Called once, at the client's
--- start; the connections live for the client session.
--- @method watch
--- @within Session

function Session.watch(self: Self)
	local function follow(commands: Instance)
		commands.ChildAdded:Connect(function ()
			self:refresh()
		end)

		commands.ChildRemoved:Connect(function ()
			self:refresh()
		end)
	end

	PlayerGui.ChildAdded:Connect(function (child: Instance)
		if child.Name == DECREE_COMMANDS then
			follow(child)
			self:refresh()
		end
	end)

	PlayerGui.ChildRemoved:Connect(function (child: Instance)
		if child.Name == DECREE_COMMANDS then
			self:refresh()
		end
	end)

	local present: Instance? = PlayerGui:FindFirstChild(DECREE_COMMANDS)
	if present then
		follow(present)
	end
end

type Self = typeof(Session)

return Session
