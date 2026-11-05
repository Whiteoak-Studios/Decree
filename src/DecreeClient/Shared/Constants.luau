--[[
    The bounds and waits Decree's own correctness needs: the bounds
    Schemas/Decree.volt declares, which these match, the list and frame
    caps the server keeps under Volt's, the prefix it counts by, and each wait
--]]

--!strict
local LINE_BYTES: number = 4096 -- The longest typed line run carries, and the longest autoExec line
local TEXT_BYTES: number = 16384 -- The longest reply or printed line
local PENDING_SECONDS: number = 9 -- How long a half's Promise may stay pending, a server half's inside run's 10 seconds
local FLUSH_SECONDS: number = 1 -- How long a frame's lines wait for Volt's flush to their recipient before going on
local REPLY_SECONDS: number = 9.5 -- How long after a run call arrives its reply may wait, inside run's 10-second timeout
local LIST_BYTES: number = 131072 -- The largest command list the server sends, leaving room for a frame's lines
local LIST_COMMANDS: number = 512 -- The most commands one list holds
local PREFIX_BYTES: number = 2 -- The most a string's length prefix takes on the wire
local FRAME_BYTES: number = 65536 -- The bytes of lines one player is sent in a frame before the rest wait a frame
local NAME_BYTES: number = 64 -- The longest name, alias, group, system, tag or argument name
local TYPE_BYTES: number = 256 -- The longest argument type name
local DESCRIPTION_BYTES: number = 1024 -- The longest command or subcommand description
local ARGUMENT_DESCRIPTION_BYTES: number = 512 -- The longest argument description
local LIST_ENTRIES: number = 16 -- The most aliases, tags, autoExec lines or subcommands one command holds
local ARGUMENTS: number = 32 -- The most arguments one command or subcommand holds

return {
	LINE_BYTES = LINE_BYTES,
	TEXT_BYTES = TEXT_BYTES,
	PENDING_SECONDS = PENDING_SECONDS,
	FLUSH_SECONDS = FLUSH_SECONDS,
	REPLY_SECONDS = REPLY_SECONDS,
	LIST_BYTES = LIST_BYTES,
	LIST_COMMANDS = LIST_COMMANDS,
	PREFIX_BYTES = PREFIX_BYTES,
	FRAME_BYTES = FRAME_BYTES,
	NAME_BYTES = NAME_BYTES,
	TYPE_BYTES = TYPE_BYTES,
	DESCRIPTION_BYTES = DESCRIPTION_BYTES,
	ARGUMENT_DESCRIPTION_BYTES = ARGUMENT_DESCRIPTION_BYTES,
	LIST_ENTRIES = LIST_ENTRIES,
	ARGUMENTS = ARGUMENTS,
}
