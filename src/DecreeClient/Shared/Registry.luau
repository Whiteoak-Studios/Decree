--[[
    The registry both realms parse with: argument types with their prefixes
    and aliases, and the commands a line names, which the server registers
    from modules and the client takes whole from the server's list
--]]

--!strict
local RunService = game:GetService("RunService")

local Util = require("./Util")

local IS_SERVER: boolean = RunService:IsServer()
local TYPE_NAME: string = "^[%d%l]%w*$" -- Alphanumeric, starting with a lowercase letter or a digit
local TYPE_NAME_RULE: string = "type names must be alphanumeric and start with a lowercase letter or digit."
local SERVER_HALF: string = "Server" -- Follows a command's name in the name of its server half
local DEVICE_HALF: string = "Client" -- Follows a command's name in the name of its device half
local HALVES: { string } = { SERVER_HALF, DEVICE_HALF }
local DEFAULT_PRIORITY: number = 0
local UNION_STEP: number = 2 -- A union alternates its types with the prefixes that pick them
local NONE: string = "" -- What the server's list carries for text a definition leaves out
local NAME_BYTES: number = require("./Constants").NAME_BYTES
local TYPE_BYTES: number = require("./Constants").TYPE_BYTES
local DESCRIPTION_BYTES: number = require("./Constants").DESCRIPTION_BYTES
local ARGUMENT_DESCRIPTION_BYTES: number = require("./Constants").ARGUMENT_DESCRIPTION_BYTES
local LINE_BYTES: number = require("./Constants").LINE_BYTES
local LIST_ENTRIES: number = require("./Constants").LIST_ENTRIES
local ARGUMENTS: number = require("./Constants").ARGUMENTS

-- The names Decree's own commands keep, which no game command may take
local RESERVED: { [string]: true } = Util.makeDictionary({ "confirm", "clear" })

local TYPE_KEYS: { [string]: true } = Util.makeDictionary({
	"transform",
	"validate",
	"validateOnce",
	"autocomplete",
	"parse",
	"displayName",
	"listable",
	"prefixes",
	"default",
	"argumentOperatorAliases",
})

local COMMAND_KEYS: { [string]: true } = Util.makeDictionary({
	"name",
	"aliases",
	"description",
	"group",
	"system",
	"tags",
	"args",
	"autoExec",
	"run",
	"guards",
	"confirm",
	"subcommands",
})

local SUBCOMMAND_KEYS: { [string]: true } = Util.makeDictionary({ "name", "description", "args", "confirm" })
local ARGUMENT_KEYS: { [string]: true } = Util.makeDictionary({ "name", "type", "description", "optional", "default" })

-- Each key a definition no longer holds, by where its code goes now
local MOVED_KEYS: { [string]: string } = {
	clientRun = "now goes in the command's own {Name}Client module beside its definition",
	data = "is removed: the server half reads what it needs on the server",
}

-- Each text field's bytes and each list of text's entries on the wire, by what holds them
local COMMAND_BOUNDS: { [string]: Bound } = {
	name = { least = 1, most = NAME_BYTES },
	aliases = { least = 1, most = NAME_BYTES, entries = LIST_ENTRIES },
	description = { least = 0, most = DESCRIPTION_BYTES },
	group = { least = 1, most = NAME_BYTES, optional = true },
	system = { least = 1, most = NAME_BYTES, optional = true },
	tags = { least = 1, most = NAME_BYTES, entries = LIST_ENTRIES },
	autoExec = { least = 1, most = LINE_BYTES, entries = LIST_ENTRIES },
}

local SUBCOMMAND_BOUNDS: { [string]: Bound } = {
	name = { least = 1, most = NAME_BYTES },
	description = { least = 0, most = DESCRIPTION_BYTES },
}

local ARGUMENT_BOUNDS: { [string]: Bound } = {
	name = { least = 1, most = NAME_BYTES },
	type = { least = 1, most = TYPE_BYTES },
	description = { least = 0, most = ARGUMENT_DESCRIPTION_BYTES },
}

local Types = require("./Config/Types/Command")
local Wire = require("./Wire")

type Access = Types.Access
type ArgumentDefinition = Types.ArgumentDefinition
type CommandDefinition = Types.CommandDefinition
type Hook = Types.Hook
type HookName = Types.HookName
type SubcommandDefinition = Types.SubcommandDefinition
type TypeDefinition = Types.TypeDefinition
type WireArgument = Wire.Decree_Argument
type WireCommand = Wire.Decree_Command
type WireCommands = Wire.Decree_Commands

type HookEntry = {
	callback: Hook,
	priority: number,
}

type Bound = {
	least: number, -- The fewest bytes the text, or each text of the list, takes
	most: number, -- The most bytes the same text takes
	entries: number?, -- The most entries the field holds, when it is a list
	optional: boolean?, -- Whether the wire carries the field left out, where other text left out counts as empty
}

--- @class Registry
--- The argument types and commands Decree knows on this realm, a singleton
--- both the dispatcher and a game's own code call with a colon

local Registry = {
	_types = {} :: { [string]: TypeDefinition }, -- Each type's definition by the name it registered under
	_typeAliases = {} :: { [string]: string }, -- Each alias and prefixed name by the union it expands to
	_commands = {} :: { [string]: CommandDefinition }, -- Each command by its name and aliases, lowercased
	_commandList = {} :: { CommandDefinition }, -- Each command once, in the order it registered
	_deviceHalves = {} :: { [CommandDefinition]: ModuleScript }, -- Each server command's {Name}Client module
	_hooks = { beforeRun = {}, afterRun = {} } :: { [string]: { HookEntry } }, -- Each name's hooks in run order
	_access = nil :: Access?, -- The server's access check, which bind gives it
	_runLine = nil :: ((line: string) -> any)?, -- How the client runs an autoExec line, which bindClient gives it
}

--[[
    Raises an error unless a name is one a type or a type alias may take:
    alphanumeric, starting with a lowercase letter or a digit
--]]

local function checkTypeName(name: string)
	assert(typeof(name) == "string", `[Decree] Invalid type name provided: {tostring(name)}`)
	assert(name:find(TYPE_NAME) ~= nil, `[Decree] Invalid type name provided: "{name}", {TYPE_NAME_RULE}`)
end

--- Registers an argument type on this realm under a name no other type
--- has. The definition is kept as it is given, so one table may register
--- under several names, and its prefixes register with it.
--- @method registerType
--- @within Registry
--- @param name string -- Alphanumeric, starting with a lowercase letter or a digit
--- @param definition TypeDefinition

function Registry.registerType(self: Self, name: string, definition: TypeDefinition)
	checkTypeName(name)

	for key: string in definition :: { [string]: any } do
		assert(TYPE_KEYS[key], `[Decree] Unknown key/method in type "{name}": {key}`)
	end

	assert(self._types[name] == nil, `[Decree] Type "{name}" has already been registered.`)
	self._types[name] = definition

	if definition.prefixes then
		self:registerTypePrefix(name, definition.prefixes)
	end
end

--- Adds a prefixed union after a type's name, after any union it holds
--- already, so a prefix can pick another type for the same argument.
--- @method registerTypePrefix
--- @within Registry
--- @param name string
--- @param union string -- Starts with a prefix, as in "# integer ! boolean"

function Registry.registerTypePrefix(self: Self, name: string, union: string)
	self._typeAliases[name] = `{self._typeAliases[name] or name} {union}`
end

--- Names a union of types, which an argument's type then expands to. The
--- name follows a type name's rule and is neither a type's nor an alias's.
--- @method registerTypeAlias
--- @within Registry
--- @param name string
--- @param alias string -- The whole union, its first type included, as in "string # integer"

function Registry.registerTypeAlias(self: Self, name: string, alias: string)
	checkTypeName(name)
	assert(self._typeAliases[name] == nil, `[Decree] Type alias "{name}" already exists!`)
	assert(self._types[name] == nil, `[Decree] Type alias "{name}" is already the name of a type.`)

	self._typeAliases[name] = alias
end

--- Registers every type of every ModuleScript in a container and the
--- folders inside it, each module returning its definitions by name.
--- @method registerTypesIn
--- @within Registry
--- @param container Instance

function Registry.registerTypesIn(self: Self, container: Instance)
	for _, child: Instance in container:GetChildren() do
		if not child:IsA("ModuleScript") then
			self:registerTypesIn(child)
			continue
		end

		local definitions: any = require(child) :: any
		assert(
			type(definitions) == "table",
			`[Decree] Type module {child.Name} returned a {typeof(definitions)}, where it returns its types by name`
		)

		for name: string, definition: TypeDefinition in definitions do
			self:registerType(name, definition)
		end
	end
end

--- Registers a hook on the server, where hooks run. Hooks run from the
--- lowest priority up, and hooks of one priority in the order they
--- registered. A hook returns nil to pass a command, or text to refuse it.
--- @method registerHook
--- @within Registry
--- @server
--- @param name HookName -- "beforeRun" or "afterRun"
--- @param callback Hook
--- @param priority number? -- 0 when left out

function Registry.registerHook(self: Self, name: HookName, callback: Hook, priority: number?)
	assert(IS_SERVER, "[Decree] registerHook runs on the server, where hooks run.")

	local hooks: { HookEntry }? = self._hooks[name]
	assert(hooks, `[Decree] Invalid hook name: {name}`)

	local level: number = priority or DEFAULT_PRIORITY
	local position: number = #hooks + 1

	-- After every hook of its own priority, so a tie runs in the order hooks registered
	for index: number, hook: HookEntry in hooks do
		if hook.priority > level then
			position = index
			break
		end
	end

	table.insert(hooks, position, { callback = callback, priority = level })
end

--- Whether any hook of a name is registered.
--- @method hasHook
--- @within Registry
--- @param name HookName
--- @return boolean

function Registry.hasHook(self: Self, name: HookName): boolean
	local hooks: { HookEntry }? = self._hooks[name]

	return hooks ~= nil and #hooks > 0
end

--- Gives the server registry the access check every command's
--- registration is handed to, and which decides each player's command
--- names. Called once, before any command registers.
--- @method bind
--- @within Registry
--- @server
--- @param access Access

function Registry.bind(self: Self, access: Access)
	assert(IS_SERVER, "[Decree] bind runs on the server, where commands register.")
	assert(self._access == nil, "[Decree] The registry is bound once.")

	self._access = access
end

--[[
    Raises an error naming where a field is when the wire would refuse it:
    text outside its bytes, or a list past its entries or holding such text
--]]

local function checkBounds(where: string, entry: { [string]: any }, bounds: { [string]: Bound })
	for field: string, bound: Bound in bounds do
		local value: any = entry[field]
		if value == nil and bound.optional then
			continue
		end

		-- Left out, a list is sent empty and other text as NONE, as the server's list carries them
		local entries: number? = bound.entries
		local texts: { any } = entries and (value or {}) or { value or NONE }
		assert(entries == nil or #texts <= entries, `[Decree] {where} holds {#texts} {field}, past {entries}`)

		for index: number, text: any in texts do
			local label: string = entries and `{field} #{index}` or field
			local fits: boolean = type(text) == "string" and #text >= bound.least and #text <= bound.most
			assert(fits, `[Decree] {where}'s {label} is not text of {bound.least} to {bound.most} bytes`)
		end
	end
end

--[[
    Raises an error for an argument list past the wire's bounds or holding
    anything but plain tables, each with known keys and its type named by
    text, or holding a required argument after an optional one
--]]

local function checkArguments(command: string, arguments: { any })
	assert(#arguments <= ARGUMENTS, `[Decree] Command "{command}" holds {#arguments} args, past {ARGUMENTS}`)

	local hadOptional: boolean = false

	for index: number, argument: any in arguments do
		assert(
			type(argument) == "table",
			`[Decree] Command "{command}" argument #{index} is a {type(argument)}, where an argument is a plain table`
		)

		for key: string in argument do
			assert(ARGUMENT_KEYS[key], `[Decree] Unknown property in command "{command}" argument #{index}: {key}`)
		end

		assert(
			type(argument.type) == "string",
			`[Decree] Command "{command}" argument #{index} has an inline type, where it names a registered one`
		)

		local optional: boolean = argument.default ~= nil or argument.optional == true
		assert(
			optional or not hadOptional,
			`[Decree] Command {command} has required arguments after optional arguments.`
		)

		hadOptional = hadOptional or optional
		checkBounds(`Command "{command}" argument #{index}`, argument, ARGUMENT_BOUNDS)
	end
end

--[[
    Raises an error for a subcommand list past the wire's bounds or holding
    anything but plain subcommands with known keys and plain arguments, or
    one name twice
--]]

local function checkSubcommands(command: string, subcommands: { any })
	assert(
		#subcommands <= LIST_ENTRIES,
		`[Decree] Command "{command}" holds {#subcommands} subcommands, past {LIST_ENTRIES}`
	)

	local names: { [string]: true } = {}

	for index: number, subcommand: any in subcommands do
		assert(type(subcommand) == "table", `[Decree] Command "{command}" subcommand #{index} is not a table`)

		for key: string in subcommand do
			assert(SUBCOMMAND_KEYS[key], `[Decree] Unknown key in command "{command}" subcommand #{index}: {key}`)
		end

		local name: string = subcommand.name
		assert(type(name) == "string", `[Decree] Command "{command}" subcommand #{index} has no name`)
		assert(not names[name:lower()], `[Decree] Command "{command}" holds the subcommand {name} twice`)

		names[name:lower()] = true
		checkBounds(`Command "{command}" subcommand #{index}`, subcommand, SUBCOMMAND_BOUNDS)
		checkArguments(`{command} {name}`, subcommand.args or {})
	end
end

--- Registers a command definition on the server, after handing it to the
--- access check. A definition holds known keys only, plain arguments with
--- no required one after an optional one, args or subcommands but never
--- both, and text and lists inside the wire's bounds, and no word that
--- finds it may find another command or one of Decree's own.
--- @method registerCommandObject
--- @within Registry
--- @server
--- @param definition CommandDefinition

function Registry.registerCommandObject(self: Self, definition: CommandDefinition)
	assert(IS_SERVER, "[Decree] Commands register on the server, which hands each player their own list.")

	local access: Access? = self._access
	assert(access, "[Decree] The registry registers commands once bind has given it the access check.")

	local label: string = definition.name or "unknown command"

	for key: string in definition :: { [string]: any } do
		local moved: string? = MOVED_KEYS[key]
		if moved then
			error(`[Decree] Command "{label}" holds {key}, which {moved}`)
		end

		assert(COMMAND_KEYS[key], `[Decree] Unknown key/method in command "{label}": {key}`)
	end

	local name: string = definition.name
	assert(type(name) == "string", "[Decree] A command's name is text.")

	local system: any = definition.system
	assert(
		system == nil or type(system) == "string",
		`[Decree] Command "{name}"'s system is a {type(system)}, not text`
	)

	local tags: any = definition.tags
	if tags ~= nil then
		assert(type(tags) == "table", `[Decree] Command "{name}"'s tags are a {type(tags)}, not a list of text`)

		for _, tag: any in tags do
			assert(type(tag) == "string", `[Decree] Command "{name}" holds a tag that is a {type(tag)}, not text`)
		end
	end

	local subcommands: { SubcommandDefinition }? = definition.subcommands
	if subcommands then
		assert(definition.args == nil, `[Decree] Command "{name}" holds both args and subcommands`)
		assert(
			definition.confirm == nil,
			`[Decree] Command "{name}" holds confirm beside subcommands, which hold their own`
		)
		checkSubcommands(name, subcommands)
	end

	checkArguments(name, definition.args or {})
	checkBounds(`Command "{name}"`, definition :: { [string]: any }, COMMAND_BOUNDS)

	-- Every word that finds the command, its name first
	local words: { string } = { name:lower() }

	for _, alias: string in definition.aliases or {} do
		table.insert(words, alias:lower())
	end

	local listed: { [string]: true } = {}

	for _, word: string in words do
		local holder: CommandDefinition? = self._commands[word]

		if RESERVED[word] then
			error(`[Decree] Command "{name}" takes the name {word}, which Decree's own {word} command keeps`)
		elseif holder then
			error(`[Decree] Command "{name}" takes {word}, which command "{holder.name}" already has`)
		elseif listed[word] then
			error(`[Decree] Command "{name}" lists {word} twice`)
		end

		listed[word] = true
	end

	access.registered(definition)
	table.insert(self._commandList, definition)

	for _, word: string in words do
		self._commands[word] = definition
	end
end

--- Registers the command a ModuleScript defines, with its server half's
--- run and its device half, a module the server clones to each player who
--- holds the command.
--- @method registerCommand
--- @within Registry
--- @server
--- @param module ModuleScript -- Returns the CommandDefinition
--- @param serverModule ModuleScript? -- Returns the server half's run
--- @param clientModule ModuleScript? -- The device half

function Registry.registerCommand(
	self: Self,
	module: ModuleScript,
	serverModule: ModuleScript?,
	clientModule: ModuleScript?
)
	assert(IS_SERVER, "[Decree] Commands register on the server, which hands each player their own list.")

	local definition: any = require(module) :: any
	local returned: string = typeof(definition)
	assert(
		returned == "table",
		`[Decree] Invalid return value from command script "{module.Name}" (CommandDefinition expected, got {returned})`
	)

	if serverModule then
		definition.run = require(serverModule) :: any
	end

	self:registerCommandObject(definition)

	if clientModule then
		self._deviceHalves[definition] = clientModule
	end
end

--[[
    Whether a module is a command's server or device half: its name is a
    sibling module's name followed by Server or Client
--]]

local function isHalf(container: Instance, name: string): boolean
	for _, suffix: string in HALVES do
		local command: string? = name:match(`^(.+){suffix}$`)

		if command then
			local sibling: Instance? = container:FindFirstChild(command)
			if sibling and sibling:IsA("ModuleScript") then
				return true
			end
		end
	end

	return false
end

--- Registers every command in a container and the folders inside it,
--- pairing each {Name} module with the {Name}Server and {Name}Client
--- modules beside it, and leaves every module where it is. A module is a
--- half only when its name is a sibling module's followed by Server or
--- Client, so every other module, ServerStatus and ClientInfo too, is a
--- command.
--- @method registerCommandsIn
--- @within Registry
--- @server
--- @param container Instance

function Registry.registerCommandsIn(self: Self, container: Instance)
	for _, child: Instance in container:GetChildren() do
		if not child:IsA("ModuleScript") then
			self:registerCommandsIn(child)
			continue
		end

		if isHalf(container, child.Name) then
			continue
		end

		local serverModule = container:FindFirstChild(`{child.Name}{SERVER_HALF}`) :: ModuleScript?
		local clientModule = container:FindFirstChild(`{child.Name}{DEVICE_HALF}`) :: ModuleScript?

		self:registerCommand(child, serverModule, clientModule)
	end
end

--- The command a name or alias finds, in any case.
--- @method getCommand
--- @within Registry
--- @param name string
--- @return CommandDefinition?

function Registry.getCommand(self: Self, name: string): CommandDefinition?
	return self._commands[name:lower()]
end

--- Every command once, in the order it registered or the server listed it.
--- @method getCommands
--- @within Registry
--- @return { CommandDefinition }

function Registry.getCommands(self: Self): { CommandDefinition }
	return self._commandList
end

--- Every command's name as it registered, each with its aliases before it
--- when asked. With an executor on the server, only the commands the
--- access check gives that player.
--- @method getCommandNames
--- @within Registry
--- @param includeAliases boolean?
--- @param executor Player?
--- @return { string }

function Registry.getCommandNames(self: Self, includeAliases: boolean?, executor: Player?): { string }
	local access: Access? = IS_SERVER and executor and self._access or nil
	local names: { string } = {}

	for _, definition: CommandDefinition in self._commandList do
		if access and not access.holds(executor :: Player, definition) then
			continue
		end

		if includeAliases then
			for _, alias: string in definition.aliases or {} do
				table.insert(names, alias)
			end
		end

		table.insert(names, definition.name)
	end

	return names
end

--- The device half a command registered with, its {Name}Client module.
--- @method getDeviceHalf
--- @within Registry
--- @server
--- @param name string -- The command's name or an alias
--- @return ModuleScript?

function Registry.getDeviceHalf(self: Self, name: string): ModuleScript?
	assert(IS_SERVER, "[Decree] Device halves stay on the server, which clones them out.")

	local definition: CommandDefinition? = self:getCommand(name)
	if not definition then
		return nil
	end

	return self._deviceHalves[definition]
end

--- The definition a type registered under a name, which no alias reaches.
--- @method getType
--- @within Registry
--- @param name string
--- @return TypeDefinition?

function Registry.getType(self: Self, name: string): TypeDefinition?
	return self._types[name]
end

--- The union a type name expands to through its alias or prefixes, or the
--- name itself when it has neither.
--- @method getTypeName
--- @within Registry
--- @param name string
--- @return string

function Registry.getTypeName(self: Self, name: string): string
	return self._typeAliases[name] or name
end

--- Every registered type's name, with no alias.
--- @method getTypeNames
--- @within Registry
--- @return { string }

function Registry.getTypeNames(self: Self): { string }
	local names: { string } = {}

	for name: string in self._types do
		table.insert(names, name)
	end

	return names
end

--- Whether every type the name's alias-expanded union holds is registered,
--- so an argument of that type can parse.
--- @method hasType
--- @within Registry
--- @param typeName string
--- @return boolean

function Registry.hasType(self: Self, typeName: string): boolean
	local union: { string } = Util.splitStringSimple(self:getTypeName(typeName))
	if #union == 0 then
		return false
	end

	for index = 1, #union, UNION_STEP do
		if self._types[union[index]] == nil then
			return false
		end
	end

	return true
end

--[[
    An argument as the client registry holds it, from its entry in the
    server's list
--]]

local function argumentFromWire(argument: WireArgument): ArgumentDefinition
	return {
		name = argument.name,
		type = argument.type,
		description = argument.description,
		optional = argument.optional,
		default = nil, -- The server keeps an argument's default and applies it
	}
end

--[[
    A command as the client registry holds it, from its entry in the
    server's list
--]]

local function commandFromWire(command: WireCommand): CommandDefinition
	return {
		name = command.name,
		aliases = command.aliases,
		description = command.description,
		group = command.group,
		system = command.system,
		tags = command.tags,
		args = Util.map(command.args, argumentFromWire),
		autoExec = command.autoExec,

		subcommands = Util.map(command.subcommands, function (subcommand: Wire.Decree_Subcommand): SubcommandDefinition
			return {
				name = subcommand.name,
				description = subcommand.description,
				args = Util.map(subcommand.args, argumentFromWire),
			}
		end),
	}
end

--- Replaces the client's commands with the server's list, the commands
--- that left going with their aliases. Then, on a deferred thread, each
--- newly held command's autoExec lines run one at a time. A list holding
--- autoExec lines is refused, replacing nothing, until bindClient runs.
--- @method replaceCommands
--- @within Registry
--- @client
--- @param list Decree_Commands

function Registry.replaceCommands(self: Self, list: WireCommands)
	assert(not IS_SERVER, "[Decree] replaceCommands runs on the client, which takes the server's list.")

	local held: { [string]: true } = {}

	for _, definition: CommandDefinition in self._commandList do
		held[definition.name:lower()] = true
	end

	local commands: { [string]: CommandDefinition } = {}
	local commandList: { CommandDefinition } = {}
	local lines: { string } = {}

	for _, entry: WireCommand in list do
		local definition: CommandDefinition = commandFromWire(entry)
		local name: string = entry.name:lower()

		table.insert(commandList, definition)
		commands[name] = definition

		for _, alias: string in entry.aliases do
			commands[alias:lower()] = definition
		end

		if not held[name] then
			table.move(entry.autoExec, 1, #entry.autoExec, #lines + 1, lines)
		end
	end

	-- Refused before anything is replaced, so the same list given again still runs its lines
	local runLine: ((line: string) -> any)? = self._runLine
	assert(
		#lines == 0 or runLine ~= nil,
		"[Decree] autoExec lines run through the dispatcher, which bindClient binds first."
	)

	self._commands = commands
	self._commandList = commandList

	if not runLine or #lines == 0 then
		return
	end

	local run: (line: string) -> any = runLine

	-- One at a time, each waiting for the last's reply, which is thrown away
	task.defer(function ()
		for _, line: string in lines do
			run(line):await()
		end
	end)
end

Registry:registerTypesIn(script.Parent.Types)

type Self = typeof(Registry)

return Registry
