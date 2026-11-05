--[[
    The fill command's server half: fills the caller's list to LIST_BYTES
    with filler commands at the wire's longest description and arguments,
    the last keeping only the arguments that fit, and answers the list's size
--]]

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Decree = require(ServerScriptService.ServerPackages.Decree)

local Access = require(ServerScriptService.ServerPackages.Decree.Access)

-- Decree moves its client half here as it loads; the sourcemap holds it where it is installed, which types it
local Constants: Constants = (require :: any)((ReplicatedStorage :: any).DecreeClient.Shared.Constants)

local LIST_BYTES: number = Constants.LIST_BYTES
local LIST_COMMANDS: number = Constants.LIST_COMMANDS
local PREFIX_BYTES: number = Constants.PREFIX_BYTES
local NAME_BYTES: number = Constants.NAME_BYTES
local DESCRIPTION_BYTES: number = Constants.DESCRIPTION_BYTES
local ARGUMENT_DESCRIPTION_BYTES: number = Constants.ARGUMENT_DESCRIPTION_BYTES
local ARGUMENTS: number = Constants.ARGUMENTS
local FILLER: string = "filler" -- Each filler's name, before its number
local FIRST: string = `{FILLER}1` -- The filler every fill registers first
local FILL: string = "x"
local OK: Kind = "Ok"
local INFO: Kind = "Info"
local ERROR: Kind = "Error"

type ArgumentDefinition = Decree.ArgumentDefinition
type CommandDefinition = Decree.CommandDefinition
type Constants = typeof(require(ServerScriptService.ServerPackages.Decree.DecreeClient.Shared.Constants))
type Context = Decree.Context
type Kind = Decree.Kind

--[[
    The bytes a value takes as Access.luau's size check counts them, since
    Decree exposes no size function: each string's bytes and its prefix
--]]

local function measure(value: any): number
	if type(value) == "string" then
		return #value + PREFIX_BYTES -- Access.luau's measure, the rule the server refuses a list by
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
    Every filler's server half, which replies with the filler's own name
--]]

local function reply(context: Context): (string, Kind)
	return context.name, OK
end

--[[
    A filler at the wire's longest description and argument list, each
    argument optional so the console runs it with none
--]]

local function filler(index: number): CommandDefinition
	local arguments: { ArgumentDefinition } = {}

	for argument = 1, ARGUMENTS do
		table.insert(arguments, {
			name = `{FILL:rep(NAME_BYTES - #tostring(argument))}{argument}`,
			type = "string",
			description = FILL:rep(ARGUMENT_DESCRIPTION_BYTES),
			optional = true,
		})
	end

	return {
		name = `{FILLER}{index}`,
		description = FILL:rep(DESCRIPTION_BYTES),
		group = "Admin",
		args = arguments,
		run = reply,
	}
end

return function (context: Context): (string, Kind)
	local list: { any }?, problem: string? = Access:list(context.executor)
	if not list then
		return problem :: string, ERROR
	end

	local commands: number = #list
	local bytes: number = measure(list)
	local count: number = 0

	-- A filler already registered means an earlier fill filled the list
	local room: number = Decree.registry:getCommand(FIRST) and 0 or LIST_COMMANDS - commands

	for index = 1, room do
		local definition: CommandDefinition = filler(index)
		local arguments: { ArgumentDefinition } = definition.args :: { ArgumentDefinition }
		local entry: number = measure(definition) -- The text its list entry carries, so the same bytes

		-- The last filler drops arguments until it fits in what the list has left
		while bytes + entry > LIST_BYTES and #arguments > 0 do
			local dropped: ArgumentDefinition = table.remove(arguments) :: ArgumentDefinition
			entry -= measure(dropped)
		end

		if bytes + entry > LIST_BYTES then
			break
		end

		-- Registrations after start share one deferred refresh, so the caller is pushed one list
		Decree.registry:registerCommandObject(definition)
		bytes += entry
		count = index
	end

	local size: string = `{commands + count} commands in {bytes} of {LIST_BYTES} bytes`

	if count == 0 then
		return `Your list is already full, with {size}.`, INFO
	end

	return `Registered {FIRST} to {FILLER}{count}, so your list holds {size}.`, OK
end
