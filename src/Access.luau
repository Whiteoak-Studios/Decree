--[[
    Each player's command list: what canAccess grants them, the list their
    console asks for and is pushed whenever it changes, and the device
    halves cloned to them for the commands they hold
--]]

--!strict
local Network = require("./Network")

local Confirm = require("./Confirm")
local Registry = require("./DecreeClient/Shared/Registry")
local Util = require("./DecreeClient/Shared/Util")

local LIST_BYTES: number = require("./DecreeClient/Shared/Constants").LIST_BYTES
local LIST_COMMANDS: number = require("./DecreeClient/Shared/Constants").LIST_COMMANDS
local PREFIX_BYTES: number = require("./DecreeClient/Shared/Constants").PREFIX_BYTES
local COMMANDS_GUI: string = "DecreeCommands" -- The ScreenGui each player's device halves are cloned into
local DEVICE_HALF: string = "Client" -- Follows a command's name in its clone's, the name the console finds it by
local NONE: string = ""

local Types = require("./DecreeClient/Shared/Config/Types/Command")
local Wire = require("./DecreeClient/Shared/Wire")

type ArgumentDefinition = Types.ArgumentDefinition
type Bot = Wire.Bot
type CommandDefinition = Types.CommandDefinition
type SubcommandDefinition = Types.SubcommandDefinition
type WireArgument = Wire.Decree_Argument
type WireCommand = Wire.Decree_Command
type WireCommands = Wire.Decree_Commands
type WireSubcommand = Wire.Decree_Subcommand

type CanAccess = (player: Player, command: CommandDefinition) -> boolean
type Held = { [CommandDefinition]: true }

local Access = {
	_started = false, -- Whether start has handed over canAccess, before which every list is empty
	_canAccess = nil :: CanAccess?, -- The game's check, which grants nothing when it is left out
	_refreshing = false, -- Whether a refresh of every player waits on task.defer
	_players = {} :: { [Player]: true }, -- Every player who joined and has not left, bots never among them
	_asked = {} :: { [Player]: true }, -- Every player whose console has asked for their list
	_held = {} :: { [Player]: Held }, -- The commands each player's list holds
	_guis = {} :: { [Player]: ScreenGui }, -- Each player's DecreeCommands ScreenGui
	_clones = {} :: { [Player]: { [CommandDefinition]: ModuleScript } }, -- The device halves cloned to each player
	_entries = {} :: { [CommandDefinition]: WireCommand }, -- Each command's list entry, built once
	_untyped = {} :: { [CommandDefinition]: true }, -- Each command already warned about for a type no client has
}

--[[
    Whether two sets hold the same keys
--]]

local function same(a: Held, b: Held): boolean
	for key: CommandDefinition in a do
		if not b[key] then
			return false
		end
	end

	for key: CommandDefinition in b do
		if not a[key] then
			return false
		end
	end

	return true
end

--[[
    The bytes a list takes as the size check counts them: every string's
    bytes and its length prefix
--]]

local function measure(value: any): number
	if type(value) == "string" then
		return #value + PREFIX_BYTES
	elseif type(value) ~= "table" then
		return 0
	end

	local bytes: number = 0

	for _, field: any in value do
		bytes += measure(field)
	end

	return bytes
end

--[[
    The first argument type in a list that the registry does not hold, or
    nil when it holds every one
--]]

local function untyped(arguments: { ArgumentDefinition }?): string?
	for _, argument: ArgumentDefinition in arguments or {} do
		if not Registry:hasType(argument.type) then
			return argument.type
		end
	end

	return nil
end

--[[
    An argument as the wire carries it, optional when it has a default,
    which the server keeps and applies
--]]

local function argumentEntry(argument: ArgumentDefinition): WireArgument
	return {
		name = argument.name,
		type = argument.type,
		description = argument.description or NONE,
		optional = argument.optional == true or argument.default ~= nil,
	}
end

--[[
    Takes start's canAccess and works out the list of every player who has
    joined, pushing it to each whose console already asked
--]]

function Access.start(self: Self, canAccess: CanAccess?)
	self._canAccess = canAccess
	self._started = true

	for player: Player in self._players do
		self:refresh(player)
	end
end

--[[
    The registry's access port, handed each command before it is stored:
    refuses one asking for confirmation that start's settings cannot time,
    and after start refreshes every list once the registry holds it
--]]

function Access.registered(self: Self, definition: CommandDefinition)
	Confirm:check(definition)

	if not self._started or self._refreshing then
		return
	end

	self._refreshing = true

	task.defer(function ()
		self._refreshing = false

		for player: Player in self._players do
			self:refresh(player)
		end
	end)
end

--[[
    The registry's other access port: whether a player's list holds a command
--]]

function Access.holds(self: Self, player: Player, definition: CommandDefinition): boolean
	local held: Held? = self._held[player]

	return held ~= nil and held[definition] == true
end

--[[
    Takes in a player who joined: makes their DecreeCommands ScreenGui once
    their PlayerGui is there, then works out their list
--]]

function Access.join(self: Self, player: Player)
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui -- Join thread: the PlayerGui may not be there yet

	local gui: ScreenGui = Instance.new("ScreenGui")
	gui.Name = COMMANDS_GUI
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	self._players[player] = true
	self._held[player] = {}
	self._guis[player] = gui
	self._clones[player] = {}

	self:refresh(player)
end

--[[
    Works a player's list out again from canAccess, and when it changed,
    clones and destroys their device halves to match and pushes the new
    list once their console has asked
--]]

function Access.refresh(self: Self, player: Player)
	if not self._started or not self._players[player] then
		return
	end

	local held: Held = {}

	for _, definition: CommandDefinition in Registry:getCommands() do
		if self:_typed(definition) and self:_grants(player, definition) then
			held[definition] = true
		end
	end

	if same(held, self._held[player]) then
		return
	end

	self._held[player] = held
	self:_deliver(player)

	if not self._asked[player] then
		return
	end

	local list: WireCommands?, problem: string? = self:list(player)
	if list then
		Network.Decree.access.fire(player, list)
	else
		warn(problem)
	end
end

--[[
    Whether every argument type a command and its subcommands name is one
    the registry holds, which a client then has too; warns once about a
    command left out for one it lacks
--]]

function Access._typed(self: Self, definition: CommandDefinition): boolean
	local missing: string? = untyped(definition.args)

	for _, subcommand: SubcommandDefinition in definition.subcommands or {} do
		missing = missing or untyped(subcommand.args)
	end

	if not missing then
		return true
	end

	if not self._untyped[definition] then
		self._untyped[definition] = true
		warn(`[Decree] Command "{definition.name}" is left out of every list, since no type {missing} is registered`)
	end

	return false
end

--[[
    What canAccess answers for a player and a command, where only true
    grants it and an error answers false with a warning
--]]

function Access._grants(self: Self, player: Player, definition: CommandDefinition): boolean
	local canAccess: CanAccess? = self._canAccess
	if not canAccess then
		return false
	end

	local asked: boolean, granted: any = pcall(canAccess, player, definition)
	if not asked then
		warn(`[Decree] canAccess raised for {player.Name} and "{definition.name}", so it answers false: {granted}`)

		return false
	end

	return granted == true
end

--[[
    Makes a player's device halves match their list: the clone of a command
    they no longer hold is destroyed, and each held command's {Name}Client
    module they lack is cloned into their DecreeCommands ScreenGui, named
    after the definition's name, whatever its module is called
--]]

function Access._deliver(self: Self, player: Player)
	local held: Held = self._held[player]
	local clones: { [CommandDefinition]: ModuleScript } = self._clones[player]

	for definition: CommandDefinition, clone: ModuleScript in clones do
		if not held[definition] then
			clone:Destroy()
			clones[definition] = nil
		end
	end

	for definition: CommandDefinition in held do
		local half: ModuleScript? = Registry:getDeviceHalf(definition.name)

		if half and not clones[definition] then
			local clone: ModuleScript = half:Clone()
			clone.Name = `{definition.name}{DEVICE_HALF}`
			clone.Parent = self._guis[player]
			clones[definition] = clone
		end
	end
end

--[[
    A command's list entry, built the first time a list holds it, once the
    registry has stored its device half
--]]

function Access._entry(self: Self, definition: CommandDefinition): WireCommand
	local built: WireCommand? = self._entries[definition]
	if built then
		return built
	end

	local entry: WireCommand = {
		name = definition.name,
		aliases = definition.aliases or {},
		description = definition.description or NONE,
		group = definition.group,
		system = definition.system,
		tags = definition.tags or {},
		args = Util.map(definition.args or {}, argumentEntry),
		autoExec = definition.autoExec or {},

		subcommands = Util.map(definition.subcommands or {}, function (subcommand: SubcommandDefinition): WireSubcommand
			return {
				name = subcommand.name,
				description = subcommand.description or NONE,
				args = Util.map(subcommand.args or {}, argumentEntry),
			}
		end),

		device = Registry:getDeviceHalf(definition.name) ~= nil,
	}

	self._entries[definition] = entry

	return entry
end

--[[
    A player's list in registration order, with Decree's confirm after it
    when a command it holds asks for confirmation, or nil and the reason
    when it holds more commands or bytes than one list may carry
--]]

function Access.list(self: Self, player: Player): (WireCommands | nil, string | nil)
	local held: Held = self._held[player] or {}
	local list: WireCommands = {}
	local confirms: boolean = false

	for _, definition: CommandDefinition in Registry:getCommands() do
		if held[definition] then
			table.insert(list, self:_entry(definition))
			confirms = confirms or Confirm:asks(definition)
		end
	end

	if confirms then
		table.insert(list, Confirm.entry)
	end

	local bytes: number = measure(list)
	if #list > LIST_COMMANDS or bytes > LIST_BYTES then
		local size: string = `{#list} commands in {bytes} bytes`
		local limit: string = `{LIST_COMMANDS} commands or {LIST_BYTES} bytes`

		return nil, `[Decree] {player.Name}'s command list holds {size}, past {limit}, so it is not sent`
	end

	return list, nil
end

--[[
    The commands call's answer: a bot's empty list, or the player's own,
    after which every change to it is pushed to them; refuses one too
    large to send
--]]

function Access.answer(self: Self, player: Player | Bot): WireCommands
	if Network.isBot(player) then
		return {}
	end

	local asker: Player = player :: Player
	self._asked[asker] = true

	local list: WireCommands?, problem: string? = self:list(asker)
	if not list then
		error(problem, 0)
	end

	return list
end

--[[
    Forgets a player who left: their list, their asking and their clones
--]]

function Access.drop(self: Self, player: Player)
	self._players[player] = nil
	self._asked[player] = nil
	self._held[player] = nil
	self._guis[player] = nil
	self._clones[player] = nil
end

type Self = typeof(Access)

return Access
