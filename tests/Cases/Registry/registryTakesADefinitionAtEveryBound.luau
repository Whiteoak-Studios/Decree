--[[
    registerCommandObject takes definitions whose every text and list sits
    at a bound of the wire's, its most or its fewest, in a command, in its
    arguments and in its subcommands, and stores each one
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local NAME_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").NAME_BYTES
local TYPE_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").TYPE_BYTES
local DESCRIPTION_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").DESCRIPTION_BYTES
local ARGUMENT_DESCRIPTION_BYTES: number =
	require("../../../src/DecreeClient/Shared/Constants").ARGUMENT_DESCRIPTION_BYTES
local LINE_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").LINE_BYTES
local LIST_ENTRIES: number = require("../../../src/DecreeClient/Shared/Constants").LIST_ENTRIES
local ARGUMENTS: number = require("../../../src/DecreeClient/Shared/Constants").ARGUMENTS
local FILL: string = "a"
local OTHER: string = "b" -- Fills the name of the second command, which no word of the first may find
local EMPTY: string = "" -- A description of no bytes, the fewest one takes

--[[
    Count texts of the given bytes each, no two the same
--]]

local function distinct(count: number, bytes: number): { string }
	local texts: { string } = {}

	for index = 1, count do
		table.insert(texts, `{FILL:rep(bytes - #tostring(index))}{index}`)
	end

	return texts
end

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local longest: { [string]: any } = {
		name = FILL:rep(NAME_BYTES),
		type = FILL:rep(TYPE_BYTES),
		description = FILL:rep(ARGUMENT_DESCRIPTION_BYTES),
	}

	local subcommands: { { [string]: any } } = {}

	for _, name: string in distinct(LIST_ENTRIES, NAME_BYTES) do
		local subcommand: { [string]: any } = {
			name = name,
			description = FILL:rep(DESCRIPTION_BYTES),
			args = table.create(ARGUMENTS, longest),
		}

		table.insert(subcommands, subcommand)
	end

	local definitions: { { [string]: any } } = {
		{
			name = FILL:rep(NAME_BYTES),
			aliases = distinct(LIST_ENTRIES, NAME_BYTES),
			description = FILL:rep(DESCRIPTION_BYTES),
			group = FILL:rep(NAME_BYTES),
			system = FILL:rep(NAME_BYTES),
			tags = table.create(LIST_ENTRIES, FILL:rep(NAME_BYTES)),
			args = table.create(ARGUMENTS, longest),
			autoExec = table.create(LIST_ENTRIES, FILL:rep(LINE_BYTES)),
		},
		{
			name = OTHER:rep(NAME_BYTES),
			subcommands = subcommands,
		},
		{
			name = "c",
			aliases = { "d" },
			description = EMPTY,
			group = "e",
			system = "f",
			tags = { "g" },
			args = { { name = "h", type = "i", description = EMPTY } },
			autoExec = { "j" },
		},
		{
			name = "k",
			aliases = {},
			tags = {},
			autoExec = {},
			subcommands = { { name = "l", description = EMPTY, args = {} } },
		},
	}

	for index: number, definition: { [string]: any } in definitions do
		local registered: boolean, problem: any = pcall(registry.registerCommandObject, registry, definition)
		if not registered then
			return false, `definition #{index} at the wire's bounds was refused: {problem}`
		end

		if registry:getCommand(definition.name) ~= definition then
			return false, `definition #{index} at the wire's bounds was not stored`
		end
	end

	if #core.access.definitions ~= #definitions then
		return false, `the access check was handed {#core.access.definitions} of {#definitions} definitions`
	end

	return true, nil
end
