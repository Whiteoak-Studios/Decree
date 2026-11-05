--[[
    The server module Volt 0.1.0 generated from Decree.volt: a writer per
    message this side sends, a reader per message it hears, the schema
    table the runtime starts from and the API a game calls. Generated code:
    change the schema and run volt again rather than editing this file
--]]

--!strict
--!native
--!optimize 2
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Volt = require(ReplicatedStorage.Packages.Volt)

export type Decree_Kind = "Info" | "Ok" | "Refused" | "Error"
export type Decree_Argument = { name: string, type: string, description: string, optional: boolean }
export type Decree_Subcommand = { name: string, description: string, args: { Decree_Argument } }
export type Decree_Command = { name: string, aliases: { string }, description: string, group: string?, system: string?, tags: { string }, args: { Decree_Argument }, autoExec: { string }, subcommands: { Decree_Subcommand }, device: boolean }
export type Decree_Commands = { Decree_Command }

type Bot = Volt.Bot

type ServerEvent<A...> = {
	fire: (player: Player | Bot, A...) -> (),
	fireAll: (A...) -> (),
	fireList: (players: { Player | Bot }, A...) -> (),
	fireExcept: (player: Player | Bot, A...) -> (),
	fireSet: (players: { [Player | Bot]: true }, A...) -> (),
}

type ServerListener<A...> = {
	on: (listener: (player: Player | Bot, A...) -> ()) -> () -> (),
	iter: () -> () -> (number, Player | Bot, A...),
}

type ServerPolling<A...> = { iter: () -> () -> (number, Player | Bot, A...) }

type ServerFunction<A..., R...> = {
	on: (handler: (player: Player | Bot, A...) -> R...) -> () -> (),
}

type Exported<T> = {
	write: (value: T) -> (buffer, { any }?),
	read: (packet: buffer, side: { any }?) -> T,
}

local runtime: Volt.Runtime
local beginReliable: (number) -> (number, buffer)
local allocateReliable: (number) -> (number, buffer)
local slotReliable: (any) -> ()
local refuseReliable: (string) -> never

local DECREE_KIND: { "Info" | "Ok" | "Refused" | "Error" } = { "Info", "Ok", "Refused", "Error" }

local function writeDecree_Kind(allocate: (number) -> (number, buffer), _: (any) -> (), refuse: (string) -> never, value: any)
	local offset: number, out: buffer = allocate(1)
	local flags: number = 0
	local valueIndex: number = table.find(DECREE_KIND, value) or 0

	if valueIndex == 0 then
		refuse("Decree.Kind: expected enum { Info, Ok, Refused, Error }")
	end

	flags += valueIndex - 1
	buffer.writeu8(out, offset, flags)
end

local function writeDecree_Argument(allocate: (number) -> (number, buffer), _: (any) -> (), refuse: (string) -> never, value: any)
	local offset: number, out: buffer = allocate(5)
	local flags: number = 0

	if type(value) ~= "table" then
		refuse("Decree.Argument: expected table")
	end

	local name = value.name

	if type(name) ~= "string" then
		refuse("Decree.Argument.name: expected string")
	end

	if #name < 1 or #name > 64 then
		refuse("Decree.Argument.name: length out of range")
	end

	buffer.writeu8(out, offset + 1, #name - 1)
	local type_2 = value.type

	if type(type_2) ~= "string" then
		refuse("Decree.Argument.type: expected string")
	end

	if #type_2 < 1 or #type_2 > 256 then
		refuse("Decree.Argument.type: length out of range")
	end

	buffer.writeu8(out, offset + 2, #type_2 - 1)
	local description = value.description

	if type(description) ~= "string" then
		refuse("Decree.Argument.description: expected string")
	end

	if #description > 512 then
		refuse("Decree.Argument.description: length out of range")
	end

	buffer.writeu16(out, offset + 3, #description)
	local optional = value.optional

	if type(optional) ~= "boolean" then
		refuse("Decree.Argument.optional: expected boolean")
	end

	flags += optional and 1 or 0
	buffer.writeu8(out, offset, flags)
	local nameOffset: number, nameOut: buffer = allocate(#name)
	buffer.writestring(nameOut, nameOffset, name)
	local typeOffset: number, typeOut: buffer = allocate(#type_2)
	buffer.writestring(typeOut, typeOffset, type_2)
	local descriptionOffset: number, descriptionOut: buffer = allocate(#description)
	buffer.writestring(descriptionOut, descriptionOffset, description)
end

local function writeDecree_Commands(allocate: (number) -> (number, buffer), slot: (any) -> (), refuse: (string) -> never, value: any)
	local offset: number, out: buffer = allocate(2)

	if type(value) ~= "table" then
		refuse("Decree.Commands: expected table")
	end

	if #value > 512 then
		refuse("Decree.Commands: length out of range")
	end

	buffer.writeu16(out, offset, #value)

	for index = 1, #value do
		local offset_2: number, out_2: buffer = allocate(9)
		local flags: number = 0
		local valueEntry = value[index]

		if type(valueEntry) ~= "table" then
			refuse("Decree.Commands[]: expected table")
		end

		local name = valueEntry.name

		if type(name) ~= "string" then
			refuse("Decree.Commands[].name: expected string")
		end

		if #name < 1 or #name > 64 then
			refuse("Decree.Commands[].name: length out of range")
		end

		buffer.writeu8(out_2, offset_2 + 1, #name - 1)
		local aliases = valueEntry.aliases

		if type(aliases) ~= "table" then
			refuse("Decree.Commands[].aliases: expected table")
		end

		if #aliases > 16 then
			refuse("Decree.Commands[].aliases: length out of range")
		end

		buffer.writeu8(out_2, offset_2 + 2, #aliases)
		local description = valueEntry.description

		if type(description) ~= "string" then
			refuse("Decree.Commands[].description: expected string")
		end

		if #description > 1024 then
			refuse("Decree.Commands[].description: length out of range")
		end

		buffer.writeu16(out_2, offset_2 + 3, #description)
		local group = valueEntry.group
		flags += group ~= nil and 1 or 0
		local system = valueEntry.system
		flags += system ~= nil and 2 or 0
		local tags = valueEntry.tags

		if type(tags) ~= "table" then
			refuse("Decree.Commands[].tags: expected table")
		end

		if #tags > 16 then
			refuse("Decree.Commands[].tags: length out of range")
		end

		buffer.writeu8(out_2, offset_2 + 5, #tags)
		local args = valueEntry.args

		if type(args) ~= "table" then
			refuse("Decree.Commands[].args: expected table")
		end

		if #args > 32 then
			refuse("Decree.Commands[].args: length out of range")
		end

		buffer.writeu8(out_2, offset_2 + 6, #args)
		local autoExec = valueEntry.autoExec

		if type(autoExec) ~= "table" then
			refuse("Decree.Commands[].autoExec: expected table")
		end

		if #autoExec > 16 then
			refuse("Decree.Commands[].autoExec: length out of range")
		end

		buffer.writeu8(out_2, offset_2 + 7, #autoExec)
		local subcommands = valueEntry.subcommands

		if type(subcommands) ~= "table" then
			refuse("Decree.Commands[].subcommands: expected table")
		end

		if #subcommands > 16 then
			refuse("Decree.Commands[].subcommands: length out of range")
		end

		buffer.writeu8(out_2, offset_2 + 8, #subcommands)
		local device = valueEntry.device

		if type(device) ~= "boolean" then
			refuse("Decree.Commands[].device: expected boolean")
		end

		flags += device and 4 or 0
		buffer.writeu8(out_2, offset_2, flags)
		local nameOffset: number, nameOut: buffer = allocate(#name)
		buffer.writestring(nameOut, nameOffset, name)

		for index_2 = 1, #aliases do
			local offset_3: number, out_3: buffer = allocate(1)
			local aliasesEntry = aliases[index_2]

			if type(aliasesEntry) ~= "string" then
				refuse("Decree.Commands[].aliases[]: expected string")
			end

			if #aliasesEntry < 1 or #aliasesEntry > 64 then
				refuse("Decree.Commands[].aliases[]: length out of range")
			end

			buffer.writeu8(out_3, offset_3, #aliasesEntry - 1)
			local aliasesEntryOffset: number, aliasesEntryOut: buffer = allocate(#aliasesEntry)
			buffer.writestring(aliasesEntryOut, aliasesEntryOffset, aliasesEntry)
		end

		local descriptionOffset: number, descriptionOut: buffer = allocate(#description)
		buffer.writestring(descriptionOut, descriptionOffset, description)

		if group ~= nil then
			local offset_4: number, out_4: buffer = allocate(1)

			if type(group) ~= "string" then
				refuse("Decree.Commands[].group: expected string")
			end

			if #group < 1 or #group > 64 then
				refuse("Decree.Commands[].group: length out of range")
			end

			buffer.writeu8(out_4, offset_4, #group - 1)
			local groupOffset: number, groupOut: buffer = allocate(#group)
			buffer.writestring(groupOut, groupOffset, group)
		end

		if system ~= nil then
			local offset_5: number, out_5: buffer = allocate(1)

			if type(system) ~= "string" then
				refuse("Decree.Commands[].system: expected string")
			end

			if #system < 1 or #system > 64 then
				refuse("Decree.Commands[].system: length out of range")
			end

			buffer.writeu8(out_5, offset_5, #system - 1)
			local systemOffset: number, systemOut: buffer = allocate(#system)
			buffer.writestring(systemOut, systemOffset, system)
		end

		for index_3 = 1, #tags do
			local offset_6: number, out_6: buffer = allocate(1)
			local tagsEntry = tags[index_3]

			if type(tagsEntry) ~= "string" then
				refuse("Decree.Commands[].tags[]: expected string")
			end

			if #tagsEntry < 1 or #tagsEntry > 64 then
				refuse("Decree.Commands[].tags[]: length out of range")
			end

			buffer.writeu8(out_6, offset_6, #tagsEntry - 1)
			local tagsEntryOffset: number, tagsEntryOut: buffer = allocate(#tagsEntry)
			buffer.writestring(tagsEntryOut, tagsEntryOffset, tagsEntry)
		end

		for index_4 = 1, #args do
			writeDecree_Argument(allocate, slot, refuse, args[index_4])
		end

		for index_5 = 1, #autoExec do
			local offset_8: number, out_8: buffer = allocate(2)
			local autoExecEntry = autoExec[index_5]

			if type(autoExecEntry) ~= "string" then
				refuse("Decree.Commands[].autoExec[]: expected string")
			end

			if #autoExecEntry < 1 or #autoExecEntry > 4096 then
				refuse("Decree.Commands[].autoExec[]: length out of range")
			end

			buffer.writeu16(out_8, offset_8, #autoExecEntry - 1)
			local autoExecEntryOffset: number, autoExecEntryOut: buffer = allocate(#autoExecEntry)
			buffer.writestring(autoExecEntryOut, autoExecEntryOffset, autoExecEntry)
		end

		for index_6 = 1, #subcommands do
			local offset_9: number, out_9: buffer = allocate(4)
			local subcommandsEntry = subcommands[index_6]

			if type(subcommandsEntry) ~= "table" then
				refuse("Decree.Commands[].subcommands[]: expected table")
			end

			local name_2 = subcommandsEntry.name

			if type(name_2) ~= "string" then
				refuse("Decree.Commands[].subcommands[].name: expected string")
			end

			if #name_2 < 1 or #name_2 > 64 then
				refuse("Decree.Commands[].subcommands[].name: length out of range")
			end

			buffer.writeu8(out_9, offset_9, #name_2 - 1)
			local description_2 = subcommandsEntry.description

			if type(description_2) ~= "string" then
				refuse("Decree.Commands[].subcommands[].description: expected string")
			end

			if #description_2 > 1024 then
				refuse("Decree.Commands[].subcommands[].description: length out of range")
			end

			buffer.writeu16(out_9, offset_9 + 1, #description_2)
			local args_2 = subcommandsEntry.args

			if type(args_2) ~= "table" then
				refuse("Decree.Commands[].subcommands[].args: expected table")
			end

			if #args_2 > 32 then
				refuse("Decree.Commands[].subcommands[].args: length out of range")
			end

			buffer.writeu8(out_9, offset_9 + 3, #args_2)
			local nameOffset_2: number, nameOut_2: buffer = allocate(#name_2)
			buffer.writestring(nameOut_2, nameOffset_2, name_2)
			local descriptionOffset_2: number, descriptionOut_2: buffer = allocate(#description_2)
			buffer.writestring(descriptionOut_2, descriptionOffset_2, description_2)

			for index_7 = 1, #args_2 do
				writeDecree_Argument(allocate, slot, refuse, args_2[index_7])
			end
		end
	end
end

local function readDecree_run(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 4 > length then
		error("Decree.run: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	local textLength: number = 1 + buffer.readu16(packet, cursor + 2)

	if textLength > 4096 then
		error("Decree.run.text: length out of range")
	end

	cursor += 4

	if cursor + textLength > length then
		error("Decree.run.text: truncated")
	end

	local text: string = buffer.readstring(packet, cursor, textLength)
	cursor += textLength

	if utf8.len(text) == nil then
		error("Decree.run.text: invalid UTF-8")
	end

	return runtime:call(1, player, slot, cursor, sideCursor, text)
end

local function writeDecree_run(slot: number, status: number, text: string, kind: Decree_Kind)
	local offset: number, out: buffer = beginReliable(4)
	buffer.writeu8(out, offset, 1)
	buffer.writeu16(out, offset + 1, slot)
	buffer.writeu8(out, offset + 3, status)

	if status == 0 then
		local offset_2: number, out_2: buffer = allocateReliable(2)

		if type(text) ~= "string" then
			refuseReliable("Decree.run.text: expected string")
		end

		if #text > 16384 then
			refuseReliable("Decree.run.text: length out of range")
		end

		buffer.writeu16(out_2, offset_2, #text)

		if utf8.len(text) == nil then
			refuseReliable("Decree.run.text: invalid UTF-8")
		end

		local textOffset: number, textOut: buffer = allocateReliable(#text)
		buffer.writestring(textOut, textOffset, text)
		writeDecree_Kind(allocateReliable, slotReliable, refuseReliable, kind)
	end
end

local function readDecree_commands(player: (Player | Bot)?, packet: buffer, cursor: number, _: { any }, sideCursor: number, length: number): (number, number)
	if cursor + 2 > length then
		error("Decree.commands: truncated")
	end

	local slot: number = buffer.readu16(packet, cursor)
	cursor += 2

	return runtime:call(2, player, slot, cursor, sideCursor)
end

local function writeDecree_commands(slot: number, status: number, value: Decree_Commands)
	local offset: number, out: buffer = beginReliable(4)
	buffer.writeu8(out, offset, 2)
	buffer.writeu16(out, offset + 1, slot)
	buffer.writeu8(out, offset + 3, status)

	if status == 0 then
		writeDecree_Commands(allocateReliable, slotReliable, refuseReliable, value)
	end
end

local function writeDecree_line(text: string, kind: Decree_Kind)
	local offset: number, out: buffer = beginReliable(3)
	buffer.writeu8(out, offset, 3)

	if type(text) ~= "string" then
		refuseReliable("Decree.line.text: expected string")
	end

	if #text > 16384 then
		refuseReliable("Decree.line.text: length out of range")
	end

	buffer.writeu16(out, offset + 1, #text)

	if utf8.len(text) == nil then
		refuseReliable("Decree.line.text: invalid UTF-8")
	end

	local textOffset: number, textOut: buffer = allocateReliable(#text)
	buffer.writestring(textOut, textOffset, text)
	writeDecree_Kind(allocateReliable, slotReliable, refuseReliable, kind)
end

local function writeDecree_access(value: Decree_Commands)
	local offset: number, out: buffer = beginReliable(1)
	buffer.writeu8(out, offset, 4)
	writeDecree_Commands(allocateReliable, slotReliable, refuseReliable, value)
end

runtime = Volt.start({
	version = "0.1.0",
	hash = 0xACBE8A88,
	scope = "Decree",
	side = "server",
	idBytes = 1,
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
		[1] = { name = "Decree.run", kind = "call", rate = 10, read = readDecree_run, reply = writeDecree_run },
		[2] = { name = "Decree.commands", kind = "call", rate = 1, read = readDecree_commands, reply = writeDecree_commands },
	},

	outgoing = {
		[1] = { name = "Decree.run", kind = "reply", reliable = true, minBytes = 6, maxBytes = 16391 },
		[2] = { name = "Decree.commands", kind = "reply", reliable = true, minBytes = 6, maxBytes = 277337606 },
		[3] = { name = "Decree.line", kind = "event", reliable = true, minBytes = 4, maxBytes = 16388 },
		[4] = { name = "Decree.access", kind = "event", reliable = true, minBytes = 3, maxBytes = 277337603 },
	},
})

beginReliable = runtime.reliable.begin
allocateReliable = runtime.reliable.allocate
slotReliable = runtime.reliable.slot
refuseReliable = runtime.reliable.refuse

local before: { [number]: Volt.Hook } = runtime.before

local Network = {
	Decree = table.freeze({
		run = table.freeze({
			on = function (handler: (player: Player | Bot, text: string) -> (string, Decree_Kind)): () -> ()
				return runtime:handle(1, handler)
			end,
		}) :: ServerFunction<(string), (string, Decree_Kind)>,

		commands = table.freeze({
			on = function (handler: (player: Player | Bot) -> (Decree_Commands)): () -> ()
				return runtime:handle(2, handler)
			end,
		}) :: ServerFunction<(), (Decree_Commands)>,

		line = table.freeze({
			fire = function (player: Player | Bot, text: string, kind: Decree_Kind)
				if (before[3] == nil or before[3](player, text, kind)) and runtime:target(player) then
					writeDecree_line(text, kind)
				end
			end,

			fireAll = function (text: string, kind: Decree_Kind)
				runtime:broadcast(3, nil, nil, writeDecree_line, text, kind)
			end,

			fireList = function (players: { Player | Bot }, text: string, kind: Decree_Kind)
				runtime:broadcast(3, players, nil, writeDecree_line, text, kind)
			end,

			fireExcept = function (player: Player | Bot, text: string, kind: Decree_Kind)
				runtime:broadcast(3, nil, player, writeDecree_line, text, kind)
			end,

			fireSet = function (players: { [Player | Bot]: true }, text: string, kind: Decree_Kind)
				runtime:broadcast(3, players, nil, writeDecree_line, text, kind)
			end,
		}) :: ServerEvent<(string, Decree_Kind)>,

		access = table.freeze({
			fire = function (player: Player | Bot, value: Decree_Commands)
				if (before[4] == nil or before[4](player, value)) and runtime:target(player) then
					writeDecree_access(value)
				end
			end,

			fireAll = function (value: Decree_Commands)
				runtime:broadcast(4, nil, nil, writeDecree_access, value)
			end,

			fireList = function (players: { Player | Bot }, value: Decree_Commands)
				runtime:broadcast(4, players, nil, writeDecree_access, value)
			end,

			fireExcept = function (player: Player | Bot, value: Decree_Commands)
				runtime:broadcast(4, nil, player, writeDecree_access, value)
			end,

			fireSet = function (players: { [Player | Bot]: true }, value: Decree_Commands)
				runtime:broadcast(4, players, nil, writeDecree_access, value)
			end,
		}) :: ServerEvent<(Decree_Commands)>,
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

	onJoin = function (callback: (player: Player | Bot) -> ()): () -> ()
		return runtime:onJoin(callback)
	end,

	onLeave = function (callback: (player: Player | Bot) -> ()): () -> ()
		return runtime:onLeave(callback)
	end,

	onHandshake = function (callback: (player: Player | Bot) -> ()): () -> ()
		return runtime:onHandshake(callback)
	end,

	traffic = function (player: Player | Bot): (number, number)
		return runtime:traffic(player)
	end,

	budget = function (bytesPerSecond: number?)
		runtime:budget(bytesPerSecond)
	end,

	isBot = runtime.isBot,
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
