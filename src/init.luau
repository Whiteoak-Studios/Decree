--[[
    Decree's server entry and object: binds the core to Access and Confirm,
    answers the run and commands calls over Volt, paces each player's lines
    and starts with the game's settings
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Network = require("@self/Network")

local Access = require("@self/Access")
local Confirm = require("@self/Confirm")
local Dispatcher = require("@self/DecreeClient/Shared/Dispatcher")
local Guards = require("@self/Guards")
local Registry = require("@self/DecreeClient/Shared/Registry")
local Util = require("@self/DecreeClient/Shared/Util")

local DecreeClient = script.DecreeClient

local TEXT_BYTES: number = require("@self/DecreeClient/Shared/Constants").TEXT_BYTES
local FRAME_BYTES: number = require("@self/DecreeClient/Shared/Constants").FRAME_BYTES
local FLUSH_SECONDS: number = require("@self/DecreeClient/Shared/Constants").FLUSH_SECONDS
local REPLY_SECONDS: number = require("@self/DecreeClient/Shared/Constants").REPLY_SECONDS
local RUN: string = "Decree.run"
local COMMANDS: string = "Decree.commands"
local HANDSHAKE: string = "handshake" -- The failure kind of a client whose schema does not match the server's
local BEFORE_RUN: HookName = "beforeRun"
local REPLACEMENT: string = "\u{FFFD}" -- What each byte that is not UTF-8 becomes
local NOT_STARTED: string = "Decree has not started"
local BOT_REFUSAL: string = "Decree takes no commands from a bot."
local BUSY: string = "Wait for your last command to finish."
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local NO_HOOK: string = "[Decree] No beforeRun hook is registered, so every command is refused until one is."
local NO_ACCESS: string = "[Decree] start was given no canAccess, so no player holds any command."
local REFUSED: Kind = "Refused"
local ERROR: Kind = "Error"
local QUOTED: string = "%q"

local Types = require("@self/DecreeClient/Shared/Config/Types/Command")
local Wire = require("@self/DecreeClient/Shared/Wire")

export type ArgumentContext = Types.ArgumentContext
export type ArgumentDefinition = Types.ArgumentDefinition
export type CommandDefinition = Types.CommandDefinition
export type Confirm = Types.Confirm
export type Context = Types.Context
export type Guard = Types.Guard
export type Hook = Types.Hook
export type HookName = Types.HookName
export type Kind = Wire.Decree_Kind
export type Run = Types.Run
export type SubcommandDefinition = Types.SubcommandDefinition
export type TypeDefinition = Types.TypeDefinition

type Bot = Wire.Bot
type WireCommands = Wire.Decree_Commands
type Failure = (player: (Player | Bot)?, kind: string, detail: string) -> ()

export type Settings = {
	rate: { perSecond: number, burst: number? }, -- Each of run and commands, per player; burst is perSecond when left out
	canAccess: ((player: Player, command: CommandDefinition) -> boolean)?, -- Synchronous; no command is held without it
	confirmSeconds: number?, -- How long a line waits for confirm, needed once any command asks for confirmation
	onFailure: Failure?, -- Hears every Volt failure on a thread of its own
}

type Line = {
	text: string,
	kind: Kind,
	caller: Player?, -- The command's executor, nil for a line the game's own code sent
}

type Waiter = {
	mark: number, -- How many lines had been queued when the reply came, all of which it waits for
	resolve: () -> (),
}

type Queue = {
	lines: { Line }, -- Waiting to go out, oldest first
	queued: number, -- Every line ever queued
	sent: number, -- Every line ever sent or dropped
	bytes: number, -- The text bytes sent in the current frame
	flushed: number, -- The recipient's bytesOut when that frame's count started
	running: boolean, -- Whether a thread is emptying it
	waiters: { Waiter }, -- The caller's reply waiting on the lines queued before it
}

--- @class Decree
--- @server
--- The server object a game requires from where it installs Decree, which
--- binds Decree to Volt when required and runs commands once started

local Decree = {
	registry = Registry, -- The registry commands, types and hooks register with
	dispatcher = Dispatcher, -- The dispatcher, whose evaluateAndRun runs a line for a player
	util = Util, -- The text helpers and the builders a game's own types are made from
	guards = Guards, -- The guard factories a command's guards list is built from

	_started = false, -- Whether start has run, before which every typed line is refused
	_running = {} :: { [Player]: true }, -- Each player with a typed line on the server
	_queues = {} :: { [Player]: Queue }, -- Each joined player's lines waiting to go out
}

--[[
    Makes text fit Volt's checked UTF-8 fields: each byte utf8.len refuses
    becomes U+FFFD, then the text is cut to TEXT_BYTES at a character's start
--]]

local function clean(text: string): string
	local pieces: { string } = {}
	local start: number = 1
	local length: number?, bad: number? = utf8.len(text)

	while length == nil do
		local at: number = bad :: number

		table.insert(pieces, text:sub(start, at - 1))
		table.insert(pieces, REPLACEMENT)

		start = at + 1
		length, bad = utf8.len(text, start)
	end

	table.insert(pieces, text:sub(start))

	local cleaned: string = table.concat(pieces)
	if #cleaned <= TEXT_BYTES then
		return cleaned
	end

	-- The start of the character holding the first byte past the cap, so no character is cut in two
	local cut: number = utf8.offset(cleaned, 0, TEXT_BYTES + 1) :: number

	return cleaned:sub(1, cut - 1)
end

--[[
    A line one player's command sends another, as that recipient may read
    it, or nil, with a warning, when it fails to filter
--]]

local function filter(text: string, caller: Player, recipient: Player): string?
	local filtered: boolean, result: any = pcall(function (): string
		return TextService:FilterStringAsync(text, caller.UserId):GetNonChatStringForUserAsync(recipient.UserId)
	end)

	if not filtered then
		warn(`[Decree] A line from {caller.Name} to {recipient.Name} failed to filter and was dropped: {result}`)

		return nil
	end

	return clean(result)
end

--[[
    Hands every Volt failure to the game's onFailure on a thread of its own,
    after Volt's own handling of a client whose schema does not match, which
    kicks it with Volt's message and never kicks a bot
--]]

local function route(onFailure: Failure)
	local default: Failure

	default = Network.onFailure(function (player: (Player | Bot)?, kind: string, detail: string)
		if kind == HANDSHAKE then
			default(player, kind, detail)
		end

		task.spawn(onFailure, player, kind, detail)
	end)
end

--[[
    Resolves each reply waiting on lines that have all gone out now
--]]

local function release(queue: Queue)
	for index = #queue.waiters, 1, -1 do
		local waiter: Waiter = queue.waiters[index]

		if waiter.mark <= queue.sent then
			table.remove(queue.waiters, index)
			waiter.resolve()
		end
	end
end

--- Starts Decree with the game's settings, once. It applies the rate to
--- both run and commands, each with its own allowance, hands Volt's
--- failures to onFailure when it is given, and works out every joined
--- player's list. Raises an error on a missing rate or one not above 0, on
--- a second call, and on no confirmSeconds while a command asks for
--- confirmation.
--- @method start
--- @within Decree
--- @param settings Settings

function Decree.start(self: Self, settings: Settings)
	assert(not self._started, "[Decree] start runs once.")
	assert(type(settings) == "table", "[Decree] start takes the game's settings table.")

	local rate: any = settings.rate
	assert(type(rate) == "table", "[Decree] start needs a rate, { perSecond, burst? }, for run and commands.")

	local perSecond: any = rate.perSecond
	local burst: any = rate.burst or perSecond
	assert(type(perSecond) == "number" and perSecond > 0, "[Decree] start's rate.perSecond must be a number above 0.")
	assert(type(burst) == "number" and burst > 0, "[Decree] start's rate.burst must be a number above 0.")

	local confirmSeconds: any = settings.confirmSeconds
	assert(
		confirmSeconds == nil or type(confirmSeconds) == "number" and confirmSeconds > 0,
		"[Decree] start's confirmSeconds must be a number above 0."
	)

	local canAccess: any = settings.canAccess
	local onFailure: any = settings.onFailure
	assert(canAccess == nil or type(canAccess) == "function", "[Decree] start's canAccess must be a function.")
	assert(onFailure == nil or type(onFailure) == "function", "[Decree] start's onFailure must be a function.")

	Confirm:start(confirmSeconds)

	self._started = true
	Network.rate(RUN, perSecond, burst)
	Network.rate(COMMANDS, perSecond, burst)

	if onFailure then
		route(onFailure)
	end

	if not Registry:hasHook(BEFORE_RUN) then
		warn(NO_HOOK)
	end

	if not canAccess then
		warn(NO_ACCESS)
	end

	Access:start(canAccess)
end

--- Asks canAccess about every command again for a player, and when their
--- list changed, matches their device halves to it and pushes them the new
--- list once their console has asked for one.
--- @method refreshAccess
--- @within Decree
--- @param player Player

function Decree.refreshAccess(_: Self, player: Player)
	Access:refresh(player)
end

--[[
    The run call's handler: a bot's line, a line before start and a second
    line while one runs are refused, and any other runs to its reply, with
    the dispatcher's error line for anything that raises
--]]

function Decree._run(self: Self, player: Player | Bot, text: string): (string, Kind)
	local arrived: number = os.clock()

	if Network.isBot(player) then
		return BOT_REFUSAL, REFUSED
	end

	local caller: Player = player :: Player
	if not self._started then
		return NOT_STARTED, REFUSED
	elseif self._running[caller] then
		return BUSY, REFUSED
	end

	self._running[caller] = true
	local answered: boolean, reply: any, kind: any = pcall(self._answer, self, caller, text, arrived)
	self._running[caller] = nil

	if not answered then
		warn(`[Decree] Error occurred while running {QUOTED:format(text)} for {caller.Name}\n{reply}`)

		return ERROR_REPLY, ERROR
	end

	return reply, kind
end

--[[
    Runs a caller's line to its reply, a confirm line through Confirm and
    any other through the dispatcher, then cleans the reply once the lines
    queued for the caller before it have gone out, or by its deadline
--]]

function Decree._answer(self: Self, caller: Player, text: string, arrived: number): (string, Kind)
	local words: { string } = Util.splitString(text)
	local first: string? = words[1]
	local reply: any

	if first and first:lower() == Confirm.entry.name then
		reply = Confirm:run(caller, words)
	else
		reply = Dispatcher:evaluateAndRun(text, caller)
	end

	local _, response: string, kind: Kind = reply:await()

	-- Past the deadline the reply goes first, and the lines still queued follow it
	local remaining: number = math.max(arrived + REPLY_SECONDS - os.clock(), 0)
	local sent: boolean = self:_sent(caller):timeout(remaining):await()
	if not sent then
		warn(`[Decree] {caller.Name}'s earlier lines had not gone out by the reply's deadline, so it went first`)
	end

	return clean(response), kind
end

--[[
    A Promise that resolves once every line queued for a player so far has
    gone out or been dropped, or once they leave
--]]

function Decree._sent(self: Self, player: Player): any
	local queue: Queue? = self._queues[player]
	if not queue or queue.sent >= queue.queued then
		return Promise.resolve()
	end

	local waiting: Queue = queue
	local mark: number = waiting.queued

	return Promise.new(function (resolve: () -> ())
		table.insert(waiting.waiters, { mark = mark, resolve = resolve })
	end)
end

--[[
    The server port's line, which never waits: the text, cleaned, joins the
    recipient's queue, whose one thread filters, paces and sends it
--]]

function Decree._line(self: Self, recipient: Player, text: string, kind: Kind, caller: Player?)
	local queue: Queue? = self._queues[recipient]

	-- A player who left, or whose join Volt has not announced, gets nothing
	if not queue then
		return
	end

	table.insert(queue.lines, { text = clean(text), kind = kind, caller = caller })
	queue.queued += 1

	if not queue.running then
		queue.running = true
		task.spawn(self._drain, self, recipient, queue)
	end
end

--[[
    The thread that empties a recipient's queue in order: a line another
    player's command sent is filtered for them, and each one waits until it
    fits the frame before Volt is handed it
--]]

function Decree._drain(self: Self, recipient: Player, queue: Queue)
	while queue.lines[1] and self._queues[recipient] == queue do
		local line: Line = table.remove(queue.lines, 1) :: Line
		local caller: Player? = line.caller
		local text: string? = line.text

		if caller and caller ~= recipient then
			text = filter(line.text, caller, recipient)
		end

		if text and self:_room(recipient, queue, #text) then
			-- A raise here would end the thread and leave the caller's reply waiting for good
			local fired: boolean, problem: any = pcall(Network.Decree.line.fire, recipient, text, line.kind)
			if not fired then
				warn(`[Decree] A line for {recipient.Name} could not be sent and was dropped: {problem}`)
			end

			queue.bytes += #text
		end

		queue.sent += 1
		release(queue)
	end

	queue.running = false
end

--[[
    Whether a line of a size may go to a recipient now: once a frame's lines
    reach FRAME_BYTES, the next waits until their stats show Volt's flush to
    them, or FLUSH_SECONDS, which warns; false once the recipient has left
--]]

function Decree._room(self: Self, recipient: Player, queue: Queue, bytes: number): boolean
	local flushed: number = Network.stats(recipient).bytesOut

	-- Volt has sent them a packet since the frame's count started, so this line opens a new frame's
	if flushed ~= queue.flushed then
		queue.flushed = flushed
		queue.bytes = 0
	end

	if queue.bytes == 0 or queue.bytes + bytes <= FRAME_BYTES then
		return true
	end

	local deadline: number = os.clock() + FLUSH_SECONDS

	while Network.stats(recipient).bytesOut == flushed and os.clock() < deadline do
		task.wait()
	end

	if self._queues[recipient] ~= queue then
		return false
	end

	if Network.stats(recipient).bytesOut == flushed then
		warn(`[Decree] No flush reached {recipient.Name} in {FLUSH_SECONDS} seconds, so their lines go on`)
	end

	queue.flushed = Network.stats(recipient).bytesOut
	queue.bytes = 0

	return true
end

--[[
    Takes in a player who joined: their line queue, then their list
--]]

function Decree._join(self: Self, player: Player)
	self._queues[player] = {
		lines = {},
		queued = 0,
		sent = 0,
		bytes = 0,
		flushed = 0,
		running = false,
		waiters = {},
	}

	Access:join(player)
end

--[[
    Forgets a player who left: their queue, releasing any reply waiting on
    it, their line on the server, their list and their waiting confirm
--]]

function Decree._drop(self: Self, player: Player)
	local queue: Queue? = self._queues[player]

	self._queues[player] = nil
	self._running[player] = nil

	if queue then
		queue.sent = queue.queued
		release(queue)
	end

	Access:drop(player)
	Confirm:drop(player)
end

-- The core's ports, Volt's handlers and its join and leave callbacks are bound once and live as long as the server
Registry:bind({
	registered = function (definition: CommandDefinition)
		Access:registered(definition)
	end,

	holds = function (player: Player, definition: CommandDefinition): boolean
		return Access:holds(player, definition)
	end,
})

Dispatcher:bindServer({
	decree = Decree,

	line = function (recipient: Player, text: string, kind: Kind, caller: Player?)
		Decree:_line(recipient, text, kind, caller)
	end,

	confirm = function (context: Context): string?
		return Confirm:question(context)
	end,
})

Network.Decree.run.on(function (player: Player | Bot, text: string): (string, Kind)
	return Decree:_run(player, text)
end)

Network.Decree.commands.on(function (player: Player | Bot): WireCommands
	return Access:answer(player)
end)

Network.onJoin(function (player: Player | Bot)
	if not Network.isBot(player) then
		Decree:_join(player :: Player)
	end
end)

Network.onLeave(function (player: Player | Bot)
	if not Network.isBot(player) then
		Decree:_drop(player :: Player)
	end
end)

-- Only now, since the client's Network module waits on Volt's remotes and its calls need their handlers
DecreeClient.Parent = ReplicatedStorage

type Self = typeof(Decree)

return Decree
