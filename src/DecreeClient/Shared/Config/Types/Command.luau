--[[
    The core's shared types: hooks, guards and runs, the definitions a game
    registers, the command and argument contexts, and the ports the server
    path and the console hand the core
--]]

--!strict
local Wire = require("../../Wire")

export type HookName = "beforeRun" | "afterRun"

export type Hook = (context: Context) -> string? -- Nil passes, and a string refuses

export type Guard = (context: Context) -> string?

export type Run = (context: Context, ...any) -> ...any -- The reply's text and kind, or a Promise of them

export type Confirm = true | ((context: Context) -> string?)

export type ArgumentDefinition = {
	name: string,
	type: string,
	description: string?,
	optional: boolean?,
	default: any,
}

export type SubcommandDefinition = {
	name: string,
	description: string?,
	args: { ArgumentDefinition }?,
	confirm: Confirm?,
}

export type CommandDefinition = {
	name: string,
	aliases: { string }?,
	description: string?,
	group: string?,
	system: string?,
	tags: { string }?,
	args: { ArgumentDefinition }?,
	autoExec: { string }?,
	run: Run?,
	guards: { Guard }?,
	confirm: Confirm?,
	subcommands: { SubcommandDefinition }?,
}

export type TypeDefinition = {
	transform: ((text: string, executor: Player) -> ...any)?,
	validate: ((value: any) -> (boolean, string?))?,
	validateOnce: ((value: any) -> (boolean, string?))?,
	autocomplete: ((value: any) -> ({ string }, { isPartial: boolean? }?))?,
	parse: (value: any) -> any,
	displayName: string?,
	listable: boolean?,
	prefixes: string?,
	default: ((executor: Player) -> string)?,
	argumentOperatorAliases: { [string]: string }?,
}

export type ContextFields = {
	decree: any,
	dispatcher: any,
	name: string,
	alias: string,
	aliases: { string }?,
	description: string?,
	group: string?,
	object: CommandDefinition,
	subcommand: SubcommandDefinition?,
	executor: Player,
	rawText: string,
	rawArguments: { string },
	argumentDefinitions: { ArgumentDefinition },
	arguments: { ArgumentContext },
	state: { [any]: any },
	response: any,
}

export type ContextMethods = {
	parse: (self: Context, allowIncompleteArguments: boolean?) -> (boolean, string | nil),
	validate: (self: Context, isFinal: boolean?) -> (boolean, string),
	gatherArgumentValues: (self: Context) -> ({ any }, number),
	run: (self: Context) -> any, -- A Promise of the reply's text and kind
	getArgument: (self: Context, index: number) -> ArgumentContext?,
	getData: (self: Context) -> nil,
	sendEvent: (self: Context, player: Player, event: string, ...any) -> (),
	broadcastEvent: (self: Context, event: string, ...any) -> (),
	reply: (self: Context, text: any, kind: (Wire.Decree_Kind | Color3 | { [string]: any })?) -> (),
}

export type Context = ContextFields & ContextMethods

export type ArgumentFields = {
	command: Context,
	type: TypeDefinition,
	name: string,
	displayName: string, -- The type's displayName, or the name the type was registered under
	object: ArgumentDefinition,
	required: boolean,
	executor: Player,
	rawValue: string,
	rawSegments: { string },
	transformedValues: { any },
	prefix: string,
	textSegmentInProgress: string,
	rawSegmentsAreAutocomplete: boolean,
}

export type ArgumentMethods = {
	transform: (self: ArgumentContext) -> (),
	transformSegment: (self: ArgumentContext, rawSegment: string) -> ...any,
	getDefaultAutocomplete: (self: ArgumentContext) -> ({ string }, { isPartial: boolean? }),
	getTransformedValue: (self: ArgumentContext, segment: number) -> ...any,
	validate: (self: ArgumentContext, isFinal: boolean?) -> (boolean, string | nil),
	getAutocomplete: (self: ArgumentContext) -> ({ string }, { isPartial: boolean? }?),
	getValue: (self: ArgumentContext) -> any,
}

export type ArgumentContext = ArgumentFields & ArgumentMethods

export type Access = {
	registered: (definition: CommandDefinition) -> (),
	holds: (player: Player, definition: CommandDefinition) -> boolean,
}

export type ServerPort = {
	decree: any,
	line: (recipient: Player, text: string, kind: Wire.Decree_Kind, caller: Player?) -> (),
	confirm: (context: Context) -> string?,
}

export type ClientPort = {
	decree: any,
	send: (text: string) -> any,
	event: (name: string, ...any) -> (),
	clientRun: (name: string) -> Run?,
}

return {}
