--[[
    The command context: one typed line naming a command, its subcommand
    and its arguments, which parses, validates and runs it, the hooks and
    guards on the server and the device half or the server on the client
--]]

--!strict
local Command = {}
Command.__index = Command

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Promise: any = require(ReplicatedStorage.Packages.Promise)

local Argument = require("./Argument")
local Registry = require("./Registry")
local Util = require("./Util")

local IS_SERVER: boolean = RunService:IsServer()
local PENDING_SECONDS: number = require("./Constants").PENDING_SECONDS
local BEFORE_RUN: HookName = "beforeRun"
local AFTER_RUN: HookName = "afterRun"
local ADD_LINE: string = "AddLine" -- The one event reply sends, which prints a line in the console
local NO_HOOK: string = "No permission hook is registered"
local NO_IMPLEMENTATION: string = "No implementation."
local INFO: Kind = "Info"
local REFUSED: Kind = "Refused"
local SUBCOMMAND_SEPARATOR: string = ", "
local REFUSAL_SEPARATOR: string = "; "
local NONE: string = "" -- The raw text of an argument not yet typed

local Types = require("./Config/Types/Command")
local Wire = require("./Wire")

type ArgumentContext = Types.ArgumentContext
type ArgumentDefinition = Types.ArgumentDefinition
type ClientPort = Types.ClientPort
type CommandDefinition = Types.CommandDefinition
type Fields = Types.ContextFields
type Guard = Types.Guard
type HookName = Types.HookName
type Kind = Wire.Decree_Kind
type Run = Types.Run
type Self = Types.Context
type ServerPort = Types.ServerPort
type SubcommandDefinition = Types.SubcommandDefinition

type Options = {
	dispatcher: any,
	decree: any,
	rawText: string,
	object: CommandDefinition,
	alias: string,
	executor: Player,
	words: { string }, -- Every word typed after the command's name
}

-- Each context validate has run on, which run asks after; weak, so none outlives its line
local Validated: { [Self]: true } = setmetatable({}, { __mode = "k" })

--- @class Context
--- One typed line naming a command, from the dispatcher's evaluate

--- Makes the context of a line naming a command, holding every word typed
--- after the name until parse reads them into its subcommand and arguments.
--- @function new
--- @within Context
--- @param options Options
--- @return Context

function Command.new(options: Options): Self
	local definition: CommandDefinition = options.object
	local fields: Fields = {
		decree = options.decree,
		dispatcher = options.dispatcher,
		name = definition.name,
		alias = options.alias,
		aliases = definition.aliases,
		description = definition.description,
		group = definition.group,
		object = definition,
		subcommand = nil,
		executor = options.executor,
		rawText = options.rawText,
		rawArguments = options.words,
		argumentDefinitions = definition.args or {},
		arguments = {},
		state = {},
		response = nil,
	}

	return setmetatable(fields, Command) :: any
end

--[[
    The subcommand a word names, matched ignoring case
--]]

local function findSubcommand(subcommands: { SubcommandDefinition }, word: string): SubcommandDefinition?
	local lowered: string = word:lower()

	for _, subcommand: SubcommandDefinition in subcommands do
		if subcommand.name:lower() == lowered then
			return subcommand
		end
	end

	return nil
end

--- Reads the words into arguments: a command with subcommands first takes
--- the one its first word names, then the words past the last argument
--- fold into it. A required argument left out refuses the line unless the
--- line is still being typed, when every argument is built.
--- @method parse
--- @within Context
--- @param allowIncompleteArguments boolean?
--- @return (boolean, string?)

function Command.parse(self: Self, allowIncompleteArguments: boolean?): (boolean, string | nil)
	local subcommands: { SubcommandDefinition }? = self.object.subcommands

	if subcommands and #subcommands > 0 and not self.subcommand then
		local word: string? = self.rawArguments[1]
		if not word then
			local names: { string } = Util.map(subcommands, function (subcommand: SubcommandDefinition): string
				return subcommand.name
			end)

			return false, `{self.name} takes a subcommand: {table.concat(names, SUBCOMMAND_SEPARATOR)}.`
		end

		local subcommand: SubcommandDefinition? = findSubcommand(subcommands, word)
		if not subcommand then
			return false, `{word} is not a subcommand of {self.name}.`
		end

		self.subcommand = subcommand
		self.argumentDefinitions = subcommand.args or {}
		self.rawArguments = table.move(self.rawArguments, 2, #self.rawArguments, 1, {})
	end

	self.rawArguments = Util.mashExcessArguments(self.rawArguments, #self.argumentDefinitions)

	for index: number, definition: ArgumentDefinition in self.argumentDefinitions do
		local required: boolean = definition.default == nil and definition.optional ~= true
		local rawArgument: string? = self.rawArguments[index]
		if rawArgument == nil and required and not allowIncompleteArguments then
			return false, `Required argument #{index} {definition.name} is missing.`
		end

		if rawArgument or allowIncompleteArguments then
			self.arguments[index] = Argument.new(self, definition, rawArgument or NONE)
		end
	end

	return true, nil
end

--- Checks every argument, joining each refusal with its position and name.
--- @method validate
--- @within Context
--- @param isFinal boolean? -- True once the line is sent, when each type's validateOnce runs
--- @return (boolean, string) -- The refusals joined, empty when every argument is valid

function Command.validate(self: Self, isFinal: boolean?): (boolean, string)
	Validated[self] = true

	local refusals: { string } = {}

	for index: number, argument: ArgumentContext in self.arguments do
		local valid: boolean, reason: string? = argument:validate(isFinal)
		if not valid then
			table.insert(refusals, `#{index} {argument.name}: {reason or "error"}`)
		end
	end

	return #refusals == 0, table.concat(refusals, REFUSAL_SEPARATOR)
end

--- One value per argument definition: each argument's value, or the
--- definition's default for one left out, and how many there are.
--- @method gatherArgumentValues
--- @within Context
--- @return ({ any }, number)

function Command.gatherArgumentValues(self: Self): ({ any }, number)
	local values: { any } = {}

	for index: number, definition: ArgumentDefinition in self.argumentDefinitions do
		local argument: ArgumentContext? = self.arguments[index]

		if argument then
			values[index] = argument:getValue()
		else
			values[index] = definition.default
		end
	end

	return values, #self.argumentDefinitions
end

--[[
    Runs the hooks of one name in their order, giving the first refusal as
    text. With no beforeRun hook registered, every command is refused
--]]

local function runHooks(context: Self, name: HookName): string?
	local hooks = Registry._hooks[name]
	if name == BEFORE_RUN and #hooks == 0 then
		return NO_HOOK
	end

	for _, hook in hooks do
		local result: any = hook.callback(context)
		if result ~= nil then
			return tostring(result)
		end
	end

	return nil
end

--[[
    Runs the definition's guards in their order, each handed the context
    alone, giving the first refusal as text
--]]

local function runGuards(context: Self): string?
	local guards: { Guard }? = context.object.guards
	if not guards then
		return nil
	end

	assert(typeof(guards) == "table", `expected a table for Command.guards, got {typeof(guards)}`)

	for _, guard: Guard in guards do
		assert(typeof(guard) == "function", `expected a function for a value in Command.guards, got {typeof(guard)}`)

		local result: any = guard(context)
		if result ~= nil then
			return tostring(result)
		end
	end

	return nil
end

--[[
    Calls a half with the context and one value per argument definition,
    giving every value it returns
--]]

local function runHalf(context: Self, run: Run): { n: number, [number]: any }
	local values: { any }, count: number = context:gatherArgumentValues()

	return table.pack(run(context, table.unpack(values, 1, count)))
end

--[[
    The Promise of what a half returned: its values at once, or what the
    Promise it returned settles to, which may stay pending for
    PENDING_SECONDS before it answers an error
--]]

local function settle(context: Self, results: { n: number, [number]: any }): any
	if not Promise.is(results[1]) then
		return Promise.resolve(table.unpack(results, 1, results.n))
	end

	local pending: string = `[Decree] {context.name} was still pending after {PENDING_SECONDS} seconds`

	return Promise.resolve(results[1]):timeout(PENDING_SECONDS, pending)
end

--[[
    The server's run past the hooks and guards: the confirmation question
    when the port asks one, or else what the server half answers, which
    rejects when the half raises
--]]

local function runOnServer(context: Self): any
	local port: ServerPort =
		assert(context.dispatcher._serverPort, "[Decree] The server runs commands once bindServer binds its port.")

	local question: string? = port.confirm(context)
	if question then
		return Promise.resolve(question, INFO)
	end

	local run: Run? = context.object.run
	if not run then
		if Registry:getDeviceHalf(context.name) then
			local reason: string = "its device half returned nil, but there is no server implementation"
			warn(`[Decree] {context.name} command fell back to the server because {reason}!`)
		else
			warn(`[Decree] {context.name} command has no implementation!`)
		end

		return Promise.resolve(NO_IMPLEMENTATION, INFO)
	end

	return Promise.try(function (): any
		return settle(context, runHalf(context, run))
	end)
end

--[[
    The afterRun hooks hear a reply as the context's response, and the
    first one to answer replaces it as Info
--]]

local function afterRun(context: Self, ...: any): ...any
	context.response = (...)

	local replaced: string? = runHooks(context, AFTER_RUN)
	if replaced then
		return replaced, INFO
	end

	return ...
end

--[[
    The client's run: what the device half the port holds for the command
    answers, or the server through the port when there is none or it
    answers nothing
--]]

local function runOnDevice(context: Self): any
	local port: ClientPort =
		assert(context.dispatcher._clientPort, "[Decree] The client runs commands once bindClient binds its port.")

	local run: Run? = port.clientRun(context.name)
	if run then
		local results: { n: number, [number]: any } = runHalf(context, run)

		-- A device half that answers nothing hands the line to the server
		if results[1] ~= nil then
			return settle(context, results)
		end
	end

	return port.send(context.rawText)
end

--- Runs the validated command. On the server the beforeRun hooks run,
--- then the guards, the port's confirmation and the server half, then the
--- afterRun hooks, whose first answer replaces the reply. A server half
--- that raises, rejects or stays pending warns once and reaches the
--- afterRun hooks with the Error reply. On the client the device half
--- runs, or else the line goes to the server.
--- @method run
--- @within Context
--- @return Promise -- Resolves with the reply's text and its kind

function Command.run(self: Self): any
	assert(Validated[self], "[Decree] Must validate a command before running.")

	if not IS_SERVER then
		return runOnDevice(self)
	end

	local refusal: string? = runHooks(self, BEFORE_RUN)
	if refusal == nil then
		refusal = runGuards(self)
	end

	if refusal then
		return Promise.resolve(refusal, REFUSED)
	end

	return runOnServer(self):andThen(function (...: any): ...any
		return afterRun(self, ...)
	end, function (problem: any): ...any
		return afterRun(self, self.dispatcher:_fail(self.rawText, problem))
	end)
end

--- The argument at a position.
--- @method getArgument
--- @within Context
--- @param index number
--- @return ArgumentContext?

function Command.getArgument(self: Self, index: number): ArgumentContext?
	return self.arguments[index]
end

--- Nothing: the data a client gathered for the server is removed.
--- @method getData
--- @within Context
--- @return nil

function Command.getData(_: Self): nil
	return nil
end

--- Sends an event to a player as this command's executor: on the server
--- only AddLine, which prints a line in that player's console, and on the
--- client a local event for the executor.
--- @method sendEvent
--- @within Context
--- @param player Player
--- @param event string
--- @param ... any

function Command.sendEvent(self: Self, player: Player, event: string, ...: any)
	self.dispatcher:_event(player, event, self.executor, ...)
end

--- Raises the error naming broadcastEvent's removal.
--- @method broadcastEvent
--- @within Context
--- @param event string
--- @param ... any

function Command.broadcastEvent(self: Self, event: string, ...: any)
	self.dispatcher:broadcastEvent(event, ...)
end

--- Prints a line in the executor's console, of a reply kind: Info, Ok,
--- Refused or Error, where none, a Color3 or an options table is Info.
--- @method reply
--- @within Context
--- @param text any -- Printed through tostring
--- @param kind Decree_Kind?

function Command.reply(self: Self, text: any, kind: (Kind | Color3 | { [string]: any })?)
	self:sendEvent(self.executor, ADD_LINE, text, kind)
end

local _: Types.ContextMethods = Command

return Command
