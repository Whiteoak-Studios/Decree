--[[
    The client module Volt 0.1.0 generated from Decree.volt: a writer per
    message this side sends, a reader per message it hears, the schema
    table the runtime starts from and the API a game calls. Generated code:
    change the schema and run volt again rather than editing this file
--]]

--!strict
--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Volt = require(ReplicatedStorage.Packages.Volt)
local Promise: any = require(ReplicatedStorage.Packages.Promise)

export type Decree_Kind = "Info" | "Ok" | "Refused" | "Error"
export type Decree_Argument = { name: string, type: string, description: string, optional: boolean }
export type Decree_Subcommand = { name: string, description: string, args: { Decree_Argument } }
export type Decree_Command = { name: string, aliases: { string }, description: string, group: string?, system: string?, tags: { string }, args: { Decree_Argument }, autoExec: { string }, subcommands: { Decree_Subcommand }, device: boolean }
export type Decree_Commands = { Decree_Command }

type Bot = Volt.Bot

type ClientEvent<A...> = { fire: (A...) -> () }

type ClientListener<A...> = {
	on: (listener: (A...) -> ()) -> () -> (),
	iter: () -> () -> (number, A...),
}

type ClientPolling<A...> = { iter: () -> () -> (number, A...) }

type ClientFunction<A..., R...> = { invoke: (A...) -> (boolean, R...) }

type ClientPromise<A...> = { invoke: (A...) -> any }

type Exported<T> = {
	write: (value: T) -> (buffer, { any }?),
	read: (packet: buffer, side: { any }?) -> T,
}

local runtime: Volt.Runtime
local beginReliable: (number) -> (number, buffer)
local trimReliable: (number) -> ()
local refuseReliable: (string) -> never

local DECREE_KIND: { "Info" | "Ok" | "Refused" | "Error" } = { "Info", "Ok", "Refused", "Error" }

local function readDecree_Kind(packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number, Decree_Kind)
	if cursor + 1 > length then
		error("Decree.Kind: truncated")
	end

	local flags: number = buffer.readu8(packet, cursor)
	local value: ("Info" | "Ok" | "Refused" | "Error")? = DECREE_KIND[bit32.extract(flags, 0, 2) + 1]

	if not value then
		error("Decree.Kind: out of range")
	end

	cursor += 1

	return cursor, sideCursor, value
end

local function readDecree_Argument(packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number, Decree_Argument)
	if cursor + 5 > length then
		error("Decree.Argument: truncated")
	end

	local flags: number = buffer.readu8(packet, cursor)
	local nameLength: number = 1 + buffer.readu8(packet, cursor + 1)

	if nameLength > 64 then
		error("Decree.Argument.name: length out of range")
	end

	local typeLength: number = 1 + buffer.readu8(packet, cursor + 2)
	local descriptionLength: number = buffer.readu16(packet, cursor + 3)

	if descriptionLength > 512 then
		error("Decree.Argument.description: length out of range")
	end

	cursor += 5

	if cursor + nameLength > length then
		error("Decree.Argument.name: truncated")
	end

	local name: string = buffer.readstring(packet, cursor, nameLength)
	cursor += nameLength

	if cursor + typeLength > length then
		error("Decree.Argument.type: truncated")
	end

	local type_2: string = buffer.readstring(packet, cursor, typeLength)
	cursor += typeLength

	if cursor + descriptionLength > length then
		error("Decree.Argument.description: truncated")
	end

	local description: string = buffer.readstring(packet, cursor, descriptionLength)
	cursor += descriptionLength
	local value = { name = name, type = type_2, description = description, optional = bit32.btest(flags, 1) }

	return cursor, sideCursor, value
end

local function readDecree_Commands(packet: buffer, cursor: number, side: { any }, sideCursor: number, length: number): (number, number, Decree_Commands)
	if cursor + 2 > length then
		error("Decree.Commands: truncated")
	end

	local valueLength: number = buffer.readu16(packet, cursor)

	if valueLength > 512 then
		error("Decree.Commands: length out of range")
	end

	cursor += 2

	if cursor + 10 * valueLength > length then
		error("Decree.Commands: truncated")
	end

	local value: { Decree_Command } = table.create(valueLength) :: { Decree_Command }

	for index = 1, valueLength do
		if cursor + 9 > length then
			error("Decree.Commands: truncated")
		end

		local flags: number = buffer.readu8(packet, cursor)
		local nameLength: number = 1 + buffer.readu8(packet, cursor + 1)

		if nameLength > 64 then
			error("Decree.Commands[].name: length out of range")
		end

		local aliasesLength: number = buffer.readu8(packet, cursor + 2)

		if aliasesLength > 16 then
			error("Decree.Commands[].aliases: length out of range")
		end

		local descriptionLength: number = buffer.readu16(packet, cursor + 3)

		if descriptionLength > 1024 then
			error("Decree.Commands[].description: length out of range")
		end

		local group: string?
		local system: string?
		local tagsLength: number = buffer.readu8(packet, cursor + 5)

		if tagsLength > 16 then
			error("Decree.Commands[].tags: length out of range")
		end

		local argsLength: number = buffer.readu8(packet, cursor + 6)

		if argsLength > 32 then
			error("Decree.Commands[].args: length out of range")
		end

		local autoExecLength: number = buffer.readu8(packet, cursor + 7)

		if autoExecLength > 16 then
			error("Decree.Commands[].autoExec: length out of range")
		end

		local subcommandsLength: number = buffer.readu8(packet, cursor + 8)

		if subcommandsLength > 16 then
			error("Decree.Commands[].subcommands: length out of range")
		end

		cursor += 9

		if cursor + nameLength > length then
			error("Decree.Commands[].name: truncated")
		end

		local name: string = buffer.readstring(packet, cursor, nameLength)
		cursor += nameLength

		if cursor + 2 * aliasesLength > length then
			error("Decree.Commands[].aliases: truncated")
		end

		local aliases: { string } = table.create(aliasesLength) :: { string }

		for index_2 = 1, aliasesLength do
			if cursor + 1 > length then
				error("Decree.Commands[].aliases: truncated")
			end

			local aliasesEntryLength: number = 1 + buffer.readu8(packet, cursor)

			if aliasesEntryLength > 64 then
				error("Decree.Commands[].aliases[]: length out of range")
			end

			cursor += 1

			if cursor + aliasesEntryLength > length then
				error("Decree.Commands[].aliases[]: truncated")
			end

			local aliasesEntry: string = buffer.readstring(packet, cursor, aliasesEntryLength)
			cursor += aliasesEntryLength
			aliases[index_2] = aliasesEntry
		end

		if cursor + descriptionLength > length then
			error("Decree.Commands[].description: truncated")
		end

		local description: string = buffer.readstring(packet, cursor, descriptionLength)
		cursor += descriptionLength

		if bit32.btest(flags, 1) then
			if cursor + 1 > length then
				error("Decree.Commands[].group: truncated")
			end

			local groupLength: number = 1 + buffer.readu8(packet, cursor)

			if groupLength > 64 then
				error("Decree.Commands[].group: length out of range")
			end

			cursor += 1

			if cursor + groupLength > length then
				error("Decree.Commands[].group: truncated")
			end

			local group_2: string = buffer.readstring(packet, cursor, groupLength)
			cursor += groupLength
			group = group_2
		end

		if bit32.btest(flags, 2) then
			if cursor + 1 > length then
				error("Decree.Commands[].system: truncated")
			end

			local systemLength: number = 1 + buffer.readu8(packet, cursor)

			if systemLength > 64 then
				error("Decree.Commands[].system: length out of range")
			end

			cursor += 1

			if cursor + systemLength > length then
				error("Decree.Commands[].system: truncated")
			end

			local system_2: string = buffer.readstring(packet, cursor, systemLength)
			cursor += systemLength
			system = system_2
		end

		if cursor + 2 * tagsLength > length then
			error("Decree.Commands[].tags: truncated")
		end

		local tags: { string } = table.create(tagsLength) :: { string }

		for index_3 = 1, tagsLength do
			if cursor + 1 > length then
				error("Decree.Commands[].tags: truncated")
			end

			local tagsEntryLength: number = 1 + buffer.readu8(packet, cursor)

			if tagsEntryLength > 64 then
				error("Decree.Commands[].tags[]: length out of range")
			end

			cursor += 1

			if cursor + tagsEntryLength > length then
				error("Decree.Commands[].tags[]: truncated")
			end

			local tagsEntry: string = buffer.readstring(packet, cursor, tagsEntryLength)
			cursor += tagsEntryLength
			tags[index_3] = tagsEntry
		end

		if cursor + 7 * argsLength > length then
			error("Decree.Commands[].args: truncated")
		end

		local args: { Decree_Argument } = table.create(argsLength) :: { Decree_Argument }

		for index_4 = 1, argsLength do
			local argsEntry: Decree_Argument
			cursor, sideCursor, argsEntry = readDecree_Argument(packet, cursor, side, sideCursor, length)
			args[index_4] = argsEntry
		end

		if cursor + 3 * autoExecLength > length then
			error("Decree.Commands[].autoExec: truncated")
		end

		local autoExec: { string } = table.create(autoExecLength) :: { string }

		for index_5 = 1, autoExecLength do
			if cursor + 2 > length then
				error("Decree.Commands[].autoExec: truncated")
			end

			local autoExecEntryLength: number = 1 + buffer.readu16(packet, cursor)

			if autoExecEntryLength > 4096 then
				error("Decree.Commands[].autoExec[]: length out of range")
			end

			cursor += 2

			if cursor + autoExecEntryLength > length then
				error("Decree.Commands[].autoExec[]: truncated")
			end

			local autoExecEntry: string = buffer.readstring(packet, cursor, autoExecEntryLength)
			cursor += autoExecEntryLength
			autoExec[index_5] = autoExecEntry
		end

		if cursor + 5 * subcommandsLength > length then
			error("Decree.Commands[].subcommands: truncated")
		end

		local subcommands: { Decree_Subcommand } = table.create(subcommandsLength) :: { Decree_Subcommand }

		for index_6 = 1, subcommandsLength do
			if cursor + 4 > length then
				error("Decree.Commands[].subcommands: truncated")
			end

			local nameLength_2: number = 1 + buffer.readu8(packet, cursor)

			if nameLength_2 > 64 then
				error("Decree.Commands[].subcommands[].name: length out of range")
			end

			local descriptionLength_2: number = buffer.readu16(packet, cursor + 1)

			if descriptionLength_2 > 1024 then
				error("Decree.Commands[].subcommands[].description: length out of range")
			end

			local argsLength_2: number = buffer.readu8(packet, cursor + 3)

			if argsLength_2 > 32 then
				error("Decree.Commands[].subcommands[].args: length out of range")
			end

			cursor += 4

			if cursor + nameLength_2 > length then
				error("Decree.Commands[].subcommands[].name: truncated")
			end

			local name_2: string = buffer.readstring(packet, cursor, nameLength_2)
			cursor += nameLength_2

			if cursor + descriptionLength_2 > length then
				error("Decree.Commands[].subcommands[].description: truncated")
			end

			local description_2: string = buffer.readstring(packet, cursor, descriptionLength_2)
			cursor += descriptionLength_2

			if cursor + 7 * argsLength_2 > length then
				error("Decree.Commands[].subcommands[].args: truncated")
			end

			local args_2: { Decree_Argument } = table.create(argsLength_2) :: { Decree_Argument }

			for index_7 = 1, argsLength_2 do
				local argsEntry_2: Decree_Argument
				cursor, sideCursor, argsEntry_2 = readDecree_Argument(packet, cursor, side, sideCursor, length)
				args_2[index_7] = argsEntry_2
			end

			local subcommandsEntry = { name = name_2, description = description_2, args = args_2 }
			subcommands[index_6] = subcommandsEntry
		end

		local valueEntry = { name = name, aliases = aliases, description = description, group = group, system = system, tags = tags, args = args, autoExec = autoExec, subcommands = subcommands, device = bit32.btest(flags, 4) }
		value[index] = valueEntry
	end

	return cursor, sideCursor, value
end

local function writeDecree_run(slot: number, text: string)
	local offset: number, out: buffer = beginReliable(4101)
	buffer.writeu8(out, offset, 1)
	buffer.writeu16(out, offset + 1, slot)

	if type(text) ~= "string" then
		refuseReliable("Decree.run.text: expected string")
	end

	if #text < 1 or #text > 4096 then
		refuseReliable("Decree.run.text: length out of range")
	end

	buffer.writeu16(out, offset + 3, #text - 1)

	if utf8.len(text) == nil then
		refuseReliable("Decree.run.text: invalid UTF-8")
	end

	offset += 5
	buffer.writestring(out, offset, text)
	offset += #text
	trimReliable(offset)
end

local function readDecree_run(player: (Player | Bot)?, packet: buffer, cursor: number, side: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Decree.run: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local status: number = buffer.readu8(packet, cursor + 2)
	cursor += 3

	if status == 0 then
		if cursor + 2 > length then
			error("Decree.run: truncated")
		end

		local textLength: number = buffer.readu16(packet, cursor)

		if textLength > 16384 then
			error("Decree.run.text: length out of range")
		end

		local kind: Decree_Kind
		cursor += 2

		if cursor + textLength > length then
			error("Decree.run.text: truncated")
		end

		local text: string = buffer.readstring(packet, cursor, textLength)
		cursor += textLength

		if utf8.len(text) == nil then
			error("Decree.run.text: invalid UTF-8")
		end

		cursor, sideCursor, kind = readDecree_Kind(packet, cursor, side, sideCursor, length)

		return runtime:reply(1, player, slot, cursor, sideCursor, text, kind)
	end

	return runtime:refused(1, player, slot, status, packet, cursor, sideCursor, length)
end

local function writeDecree_commands(slot: number)
	local offset: number, out: buffer = beginReliable(3)
	buffer.writeu8(out, offset, 2)
	buffer.writeu16(out, offset + 1, slot)
end

local function readDecree_commands(player: (Player | Bot)?, packet: buffer, cursor: number, side: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 3 > length then
		error("Decree.commands: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local status: number = buffer.readu8(packet, cursor + 2)
	cursor += 3

	if status == 0 then
		local value: Decree_Commands
		cursor, sideCursor, value = readDecree_Commands(packet, cursor, side, sideCursor, length)

		return runtime:reply(2, player, slot, cursor, sideCursor, value)
	end

	return runtime:refused(2, player, slot, status, packet, cursor, sideCursor, length)
end

local function readDecree_line(player: (Player | Bot)?, packet: buffer, cursor: number, side: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 2 > length then
		error("Decree.line: truncated")
	end

	local textLength: number = buffer.readu16(packet, cursor)

	if textLength > 16384 then
		error("Decree.line.text: length out of range")
	end

	local kind: Decree_Kind
	cursor += 2

	if cursor + textLength > length then
		error("Decree.line.text: truncated")
	end

	local text: string = buffer.readstring(packet, cursor, textLength)
	cursor += textLength

	if utf8.len(text) == nil then
		error("Decree.line.text: invalid UTF-8")
	end

	cursor, sideCursor, kind = readDecree_Kind(packet, cursor, side, sideCursor, length)

	return runtime:deliver(3, player, cursor, sideCursor, text, kind)
end

local function readDecree_access(player: (Player | Bot)?, packet: buffer, cursor: number, side: { any }, sideCursor: number, length: number): (number, number)
	local value: Decree_Commands
	cursor, sideCursor, value = readDecree_Commands(packet, cursor, side, sideCursor, length)

	return runtime:deliver(4, player, cursor, sideCursor, value)
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0xACBE8A88,
	scope = "Decree",
	side = "client",
	idBytes = 1,
	promise = Promise,
	options = {
		flush = 1,
		manualReplication = false,
		maxOutgoing = 262144,
		maxPacket = 8192,
		maxPacketsPerSecond = 240,
		unreliableBudget = 900,
		writeValidation = true,
	},

	messages = {
		[1] = { name = "Decree.run", kind = "reply", timeout = 10, promise = Promise, read = readDecree_run },
		[2] = { name = "Decree.commands", kind = "reply", timeout = 10, promise = Promise, read = readDecree_commands },
		[3] = { name = "Decree.line", kind = "event", mode = "SingleSync", queue = 64, read = readDecree_line },
		[4] = { name = "Decree.access", kind = "event", mode = "SingleSync", queue = 64, read = readDecree_access },
	},

	outgoing = {
		[1] = { name = "Decree.run", kind = "call", reliable = true, minBytes = 6, maxBytes = 4101 },
		[2] = { name = "Decree.commands", kind = "call", reliable = true, minBytes = 3, maxBytes = 3 },
	},
})

beginReliable = runtime.reliable.begin
trimReliable = runtime.reliable.trim
refuseReliable = runtime.reliable.refuse

local Network = {
	Decree = table.freeze({
		run = table.freeze({
			invoke = function (text: string)
				return runtime:invoke(1, writeDecree_run, text)
			end,
		}) :: ClientPromise<(string)>,

		commands = table.freeze({
			invoke = function ()
				return runtime:invoke(2, writeDecree_commands)
			end,
		}) :: ClientPromise<()>,

		line = table.freeze({
			on = function (listener: (text: string, kind: Decree_Kind) -> ()): () -> ()
				return runtime:on(3, listener)
			end,

			iter = function (): () -> (number, string, Decree_Kind)
				return runtime:iter(3)
			end,
		}) :: ClientListener<(string, Decree_Kind)>,

		access = table.freeze({
			on = function (listener: (value: Decree_Commands) -> ()): () -> ()
				return runtime:on(4, listener)
			end,

			iter = function (): () -> (number, Decree_Commands)
				return runtime:iter(4)
			end,
		}) :: ClientListener<(Decree_Commands)>,
	}),

	version = "0.1.0",

	hooks = table.freeze({
		beforeSend = runtime.beforeSend,
		afterReceive = runtime.afterReceive,
	}),

	rate = runtime.rate,

	flush = function ()
		runtime:flush()
	end,

	onFailure = function (handler: Volt.Failure): Volt.Failure
		return runtime:onFailure(handler)
	end,

	stats = function (player: (Player | Bot)?): Volt.Stats
		return runtime:stats(player)
	end,
}

Network.events = table.freeze({
	["Decree.line"] = Network.Decree.line,
	["Decree.access"] = Network.Decree.access,
}) :: { [string]: any }

Network.functions = table.freeze({
	["Decree.run"] = Network.Decree.run,
	["Decree.commands"] = Network.Decree.commands,
}) :: { [string]: any }

Network.exports = table.freeze({}) :: { [string]: any }

return table.freeze(Network)
