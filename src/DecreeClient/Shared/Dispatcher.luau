--[[
    The dispatcher both realms run typed lines with: it evaluates a line
    into a command context, runs it to its reply and the reply's kind, and
    sends the events a command sends, through the port its realm binds
--]]

--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Command = require("./Command")
local Registry = require("./Registry")
local Util = require("./Util")

local IS_SERVER: boolean = RunService:IsServer()
local ADD_LINE: string = "AddLine" -- The one event the server sends, which prints a line in a player's console
local EMPTY: string = "Command cannot be empty."
local EXECUTED: string = "Command executed."
local NO_CALLER: string = "A command run from the server needs the player who runs it."
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local QUOTED: string = "%q"
local INFO: Kind = "Info"
local REFUSED: Kind = "Refused"
local ERROR: Kind = "Error"
local KINDS: { [string]: true } = Util.makeDictionary({ "Info", "Ok", "Refused", "Error" })

local Types = require("./Config/Types/Command")
local Wire = require("./Wire")

type ClientPort = Types.ClientPort
type CommandDefinition = Types.CommandDefinition
type Context = Types.Context
type Kind = Wire.Decree_Kind
type ServerPort = Types.ServerPort

--- @class Dispatcher
--- Evaluates and runs typed lines on this realm, a singleton called with a
--- colon, its ports bound once by the realm's entry

local Dispatcher = {
	_serverPort = nil :: ServerPort?, -- What bindServer gives the server
	_clientPort = nil :: ClientPort?, -- What bindClient gives the client
}

--[[
    The kind a reply's kind stands for: one of the four as given, and
    anything else, nothing, a Color3 or an options table included, Info
--]]

local function kindOf(kind: any): Kind
	if type(kind) == "string" and KINDS[kind] then
		return kind :: Kind
	end

	return INFO
end

--- Gives the server dispatcher the port its replies, lines and
--- confirmations go through. Called once, when the server entry loads.
--- @method bindServer
--- @within Dispatcher
--- @server
--- @param port ServerPort

function Dispatcher.bindServer(self: Self, port: ServerPort)
	assert(IS_SERVER, "[Decree] bindServer runs on the server.")
	assert(self._serverPort == nil, "[Decree] The server dispatcher is bound once.")

	self._serverPort = port
end

--- Gives the client dispatcher the port its sent lines, local events and
--- device halves go through, and the registry the way its autoExec lines
--- run. Called once, when the client entry loads.
--- @method bindClient
--- @within Dispatcher
--- @client
--- @param port ClientPort

function Dispatcher.bindClient(self: Self, port: ClientPort)
	assert(not IS_SERVER, "[Decree] bindClient runs on the client.")
	assert(self._clientPort == nil, "[Decree] The client dispatcher is bound once.")

	self._clientPort = port

	Registry._runLine = function (line: string): any
		return self:evaluateAndRun(line)
	end
end

--- Evaluates a typed line into the context of the command it names,
--- parsed but not yet validated, or refuses it with false and the reason.
--- On the client only the LocalPlayer's lines evaluate.
--- @method evaluate
--- @within Dispatcher
--- @param text string
--- @param executor Player
--- @param allowIncompleteArguments boolean? -- True while the line is still being typed
--- @return (Context | false, string?)

function Dispatcher.evaluate(
	self: Self,
	text: string,
	executor: Player,
	allowIncompleteArguments: boolean?
): (Context | false, string | nil)
	assert(
		IS_SERVER or executor == Players.LocalPlayer,
		"[Decree] Can't evaluate a command that isn't sent by the local player."
	)

	if typeof(text) ~= "string" or Util.trimString(text) == "" then
		return false, EMPTY
	end

	local words: { string } = Util.splitString(text)
	local alias: string = table.remove(words, 1) :: string -- The trim above leaves a word to take

	local definition: CommandDefinition? = Registry:getCommand(alias)
	if not definition then
		return false, `{alias} is not a valid command name.`
	end

	local port: (ServerPort | ClientPort)? = self._serverPort or self._clientPort
	local context: Context = Command.new({
		dispatcher = self,
		decree = port and port.decree,
		rawText = text,
		object = definition,
		alias = alias,
		executor = executor,
		words = words,
	})

	local parsed: boolean, reason: string? = context:parse(allowIncompleteArguments)
	if not parsed then
		return false, reason
	end

	return context, nil
end

--- Evaluates, validates and runs a typed line, never blocking its caller,
--- to a Promise of the reply's text and kind that never rejects. On the
--- client the executor is the LocalPlayer, and on the server a run with
--- no executor is refused. A thrown error, a parse error and a server or
--- device half that rejects, or is still pending after PENDING_SECONDS,
--- answer Error.
--- @method evaluateAndRun
--- @within Dispatcher
--- @param text string
--- @param executor Player?
--- @return Promise -- Resolves with (text: string, kind: Decree_Kind)

function Dispatcher.evaluateAndRun(self: Self, text: string, executor: Player?): any
	local caller: Player? = executor or Players.LocalPlayer
	if IS_SERVER and caller == nil then
		return Promise.resolve(NO_CALLER, REFUSED)
	end

	return Promise.try(function (): ...any
		local context: Context | false, refusal: string? = self:evaluate(text, caller :: Player)
		if not context then
			return refusal, REFUSED
		end

		local valid: boolean, invalid: string = context:validate(true)
		if not valid then
			return invalid, REFUSED
		end

		return context:run()
	end)
		:andThen(function (response: any, kind: any): (string, Kind)
			if not response then
				return EXECUTED, INFO
			end

			return tostring(response), kindOf(kind)
		end)
		:catch(function (problem: any): (string, Kind)
			warn(`[Decree] Error occurred while evaluating command string {QUOTED:format(text)}\n{problem}`)

			return ERROR_REPLY, ERROR
		end)
end

--[[
    Sends an event to a player for a caller: on the server AddLine alone,
    to the player's console through the port, and on the client a local
    event for the LocalPlayer
--]]

function Dispatcher._event(self: Self, player: Player, event: string, caller: Player?, ...: any)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "[Decree] Argument #1 must be a Player")
	assert(typeof(event) == "string", "[Decree] Argument #2 must be a string")

	if IS_SERVER then
		assert(
			event == ADD_LINE,
			`[Decree] The server sends only AddLine, since every other event and its remote are removed: {event}`
		)

		local port: ServerPort =
			assert(self._serverPort, "[Decree] The server sends lines once bindServer binds its port.")
		local text: any, kind: any = ...
		port.line(player, tostring(text), kindOf(kind), caller)

		return
	end

	assert(player == Players.LocalPlayer, "[Decree] Event messages can only be sent to the local player on the client.")

	local port: ClientPort =
		assert(self._clientPort, "[Decree] The client sends events once bindClient binds its port.")
	port.event(event, ...)
end

--- Sends an event to a player: on the server only AddLine, which prints a
--- line in that player's console, and on the client a local event for the
--- LocalPlayer.
--- @method sendEvent
--- @within Dispatcher
--- @param player Player
--- @param event string
--- @param ... any

function Dispatcher.sendEvent(self: Self, player: Player, event: string, ...: any)
	self:_event(player, event, nil, ...)
end

--- Raises an error: Decree sends no event to every client, so a game that
--- broadcasts uses its own event.
--- @method broadcastEvent
--- @within Dispatcher
--- @param event string

function Dispatcher:broadcastEvent(event: string)
	assert(IS_SERVER, "[Decree] Can't broadcast event messages from the client.")
	error(`[Decree] broadcastEvent is removed, since Decree sends no event to every client: {event}`)
end

type Self = typeof(Dispatcher)

return Dispatcher
