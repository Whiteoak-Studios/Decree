--[[
    Decree's own confirm command: one waiting line per player, which a
    command's confirm key asks for and which runs again through the
    dispatcher when that player sends confirm within confirmSeconds
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Dispatcher = require("./DecreeClient/Shared/Dispatcher")
local Registry = require("./DecreeClient/Shared/Registry")

local NAME: string = "confirm" -- The reserved name no game command may take
local DESCRIPTION: string = "Runs the command waiting for your confirmation."
local NOTHING_WAITING: string = "Nothing is waiting for confirm."
local EXPIRED: string = "The command waiting for confirm has expired."
local EXTRA_WORDS: string = "confirm takes no arguments."
local REFUSED: Kind = "Refused"

local Types = require("./DecreeClient/Shared/Config/Types/Command")
local Wire = require("./DecreeClient/Shared/Wire")

type CommandDefinition = Types.CommandDefinition
type Context = Types.Context
type Kind = Wire.Decree_Kind
type WireCommand = Wire.Decree_Command

type Waiting = {
	line: string,
	expires: number, -- The os.clock time past which confirm refuses it
}

local Confirm = {
	-- The list entry a player who holds a command that asks for confirmation is given
	entry = {
		name = NAME,
		aliases = {},
		description = DESCRIPTION,
		tags = {},
		args = {},
		autoExec = {},
		subcommands = {},
		device = false,
	} :: WireCommand,

	_started = false, -- Whether start has run, so a later registration is checked against its seconds
	_seconds = nil :: number?, -- How long a line waits for confirm, from start's confirmSeconds
	_waiting = {} :: { [Player]: Waiting }, -- Each player's one waiting line
	_passing = {} :: { [Player]: string }, -- The line confirm reruns for each player, which runs without asking again
}

--[[
    Whether a definition or any of its subcommands carries a confirm key
--]]

function Confirm.asks(_: Self, definition: CommandDefinition): boolean
	if definition.confirm ~= nil then
		return true
	end

	for _, subcommand in definition.subcommands or {} do
		if subcommand.confirm ~= nil then
			return true
		end
	end

	return false
end

--[[
    Raises an error for a definition that asks for confirmation while no
    confirmSeconds says how long its line waits
--]]

function Confirm._check(self: Self, definition: CommandDefinition, seconds: number?)
	assert(
		seconds ~= nil or not self:asks(definition),
		`[Decree] Command "{definition.name}" asks for confirmation, which needs start's confirmSeconds`
	)
end

--[[
    Takes start's confirmSeconds, refusing nil while a registered command
    asks for confirmation, before anything is kept
--]]

function Confirm.start(self: Self, seconds: number?)
	for _, definition: CommandDefinition in Registry:getCommands() do
		self:_check(definition, seconds)
	end

	self._seconds = seconds
	self._started = true
end

--[[
    Refuses a command registering after start that asks for confirmation
    when start was given no confirmSeconds
--]]

function Confirm.check(self: Self, definition: CommandDefinition)
	if self._started then
		self:_check(definition, self._seconds)
	end
end

--[[
    The server port's confirm: the question for a line whose command or
    subcommand asks, which then waits as the executor's one line, or nil
    to run it, as the line confirm reruns always does
--]]

function Confirm.question(self: Self, context: Context): string?
	local player: Player = context.executor
	if self._passing[player] == context.rawText then
		self._passing[player] = nil

		return nil
	end

	local confirm: Types.Confirm? = context.object.confirm
	if context.subcommand then
		confirm = context.subcommand.confirm
	end

	if confirm == nil then
		return nil
	end

	local seconds: number =
		assert(self._seconds, "[Decree] A command that asks for confirmation runs once start has its confirmSeconds.")

	local question: string?
	if confirm == true then
		question = `Send confirm within {seconds} seconds to run: {context.rawText}`
	else
		question = (confirm :: (context: Context) -> string?)(context)
	end

	if question == nil then
		return nil
	end

	self._waiting[player] = { line = context.rawText, expires = os.clock() + seconds }

	return question
end

--[[
    Answers a player's confirm line: refused with any word after it, with
    nothing waiting or once the wait has expired, and otherwise the waiting
    line runs again through the dispatcher, past the hooks again
--]]

function Confirm.run(self: Self, player: Player, words: { string }): any
	if #words > 1 then
		return Promise.resolve(EXTRA_WORDS, REFUSED)
	end

	local waiting: Waiting? = self._waiting[player]
	self._waiting[player] = nil

	if not waiting then
		return Promise.resolve(NOTHING_WAITING, REFUSED)
	elseif os.clock() > waiting.expires then
		return Promise.resolve(EXPIRED, REFUSED)
	end

	self._passing[player] = waiting.line

	return Dispatcher:evaluateAndRun(waiting.line, player):finally(function ()
		self._passing[player] = nil
	end)
end

--[[
    Forgets a player who left, with their waiting line
--]]

function Confirm.drop(self: Self, player: Player)
	self._waiting[player] = nil
	self._passing[player] = nil
end

type Self = typeof(Confirm)

return Confirm
