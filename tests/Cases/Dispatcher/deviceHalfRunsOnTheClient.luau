--[[
    On a client a command runs the device half its port gives, with its
    values and no hook or guard, answering what the half's Promise settles
    to, and a command with no half, or one answering nil, sends its line
--]]

--!strict
local Client = require("../../Fixtures/Core/Client")
local Entry = require("../../Fixtures/Core/Entry")
local Listed = require("../../Fixtures/Parser/Listed")

local KILL: string = "kill" -- Holds a device half that answers
local QUIET: string = "quiet" -- Holds a device half that answers nothing
local WAVE: string = "wave" -- Holds no device half
local TARGET: string = "bob"
local KILL_LINE: string = `{KILL} {TARGET}`
local KILLED: string = "Killed on the device"
local LATER: string = "Answered later"
local PROBLEM: string = "Rejected by the case"
local GUARD_REFUSAL: string = "Refused by a guard"
local ERROR_REPLY: string = "An error occurred while running this command. Check the console for more information."
local OK: string = "Ok"
local REFUSED: string = "Refused"
local ERROR: string = "Error"
local SENT: { string } = { QUIET, WAVE } -- The lines that reach the server, in order
local SEPARATOR: string = ", " -- Joins the lines sent in a failure message

return function (): (boolean, string | nil)
	local core: Client.Core = Client()
	local port: any = core.port
	local heard: { any } = {} -- Each context and value the kill half was called with
	local guarded: boolean = false

	core.registry:replaceCommands({
		Entry({ name = KILL, args = { { name = "target", type = "string" } } }),
		Entry({ name = QUIET }),
		Entry({ name = WAVE }),
	})

	port.halves[KILL] = function (context: any, target: string): (string, string)
		table.insert(heard, { context = context, target = target })

		return KILLED, OK
	end

	port.halves[QUIET] = function (): any
		return nil
	end

	-- No beforeRun hook is registered, which on the server refuses every line, and this guard never runs
	core.registry:getCommand(KILL).guards = {
		function (): string?
			guarded = true

			return GUARD_REFUSAL
		end,
	}

	local killed: string, killedKind: string = core.run(KILL_LINE)
	local call: any = heard[1]
	if killed ~= KILLED or killedKind ~= OK or not call or call.target ~= TARGET or guarded then
		return false, `the device half answered {killed} as {killedKind}, the guard run: {guarded}`
	end

	if call.context.executor ~= core.env.player or port.asked[1] ~= KILL or #port.sent ~= 0 then
		return false, "the device half ran for someone else, was not asked for by name, or the line was sent"
	end

	port.halves[KILL] = function (): any
		return core.Promise.resolve(LATER, REFUSED)
	end

	local later: string, laterKind: string = core.run(KILL_LINE)
	port.halves[KILL] = function (): any
		return core.Promise.reject(PROBLEM)
	end

	local rejected: string, rejectedKind: string = core.run(KILL_LINE)
	if later ~= LATER or laterKind ~= REFUSED or rejected ~= ERROR_REPLY or rejectedKind ~= ERROR then
		return false, `the half's Promise answered {later} as {laterKind}, and a rejection {rejected}`
	end

	local quiet: string, quietKind: string = core.run(QUIET)
	local wave: string, waveKind: string = core.run(WAVE)
	if quiet ~= QUIET or quietKind ~= OK or wave ~= WAVE or waveKind ~= OK then
		return false, `a line sent to the server answered {quiet} and {wave}, not the port's answers`
	end

	if not Listed(port.sent, SENT) then
		return false, `the lines sent were {table.concat(port.sent, SEPARATOR)}`
	end

	return true, nil
end
