--[[
    The entry the server's list carries for a command definition, every
    field the wire requires filled in, which the client registry takes from
    replaceCommands; it holds no device half
--]]

--!strict
local NONE: string = ""

--[[
    The entries of an argument list, each optional when it has a default
--]]

local function arguments(definitions: { any }): { any }
	local entries: { any } = {}

	for _, definition: any in definitions do
		table.insert(entries, {
			name = definition.name,
			type = definition.type,
			description = definition.description or NONE,
			optional = definition.optional == true or definition.default ~= nil,
		})
	end

	return entries
end

return function (definition: { [string]: any }): { [string]: any }
	local subcommands: { any } = {}

	for _, subcommand: any in definition.subcommands or {} do
		table.insert(subcommands, {
			name = subcommand.name,
			description = subcommand.description or NONE,
			args = arguments(subcommand.args or {}),
		})
	end

	return {
		name = definition.name,
		aliases = definition.aliases or {},
		description = definition.description or NONE,
		group = definition.group,
		system = definition.system,
		tags = definition.tags or {},
		args = arguments(definition.args or {}),
		autoExec = definition.autoExec or {},
		subcommands = subcommands,
		device = false,
	}
end
