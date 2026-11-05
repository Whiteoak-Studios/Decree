--[[
    replaceCommands runs the autoExec lines of each command it newly holds
    on a deferred thread, one at a time in list order, skips a command held
    already, and runs them again when a command that left comes back
--]]

--!strict
local Client = require("../../Fixtures/Core/Client")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Entry = require("../../Fixtures/Core/Entry")
local Listed = require("../../Fixtures/Parser/Listed")
local WaitFor = require("../../Fixtures/Core/WaitFor")

local INTRO_LINES: { string } = { "echo one", "echo two" }
local OUTRO_LINES: { string } = { "echo three" }
local REPLY: string = "Heard"
local OK: string = "Ok"
local LIMIT: number = 2 -- Seconds a case waits for a line it expects to be sent
local SETTLE: number = 0.25 -- Seconds a case waits to see that no further line is sent
local SEPARATOR: string = ", " -- Joins the lines sent in a failure message

-- Every line sent across the case: intro's, outro's, then intro's again once it comes back
local EXPECTED: { string } = { "echo one", "echo two", "echo three", "echo one", "echo two" }

return function (): (boolean, string | nil)
	local core: Client.Core = Client()
	local port: any = core.port
	local registry: any = core.registry
	local waiting: { (...any) -> () } = {} -- Each sent line's resolve, in the order the lines were sent

	-- Every sent line waits for its answer until the case gives it
	port.answer = function (_: string): any
		return core.Promise.new(function (resolve: (...any) -> ())
			table.insert(waiting, resolve)
		end)
	end

	local function sent(count: number): () -> boolean
		return function (): boolean
			return #port.sent >= count
		end
	end

	-- Answers the line waiting longest, as the server would
	local function answer()
		local resolve: ((...any) -> ())? = table.remove(waiting, 1)
		if resolve then
			resolve(REPLY, OK)
		end
	end

	local intro: { [string]: any } = Entry({ name = "intro", autoExec = INTRO_LINES })
	local outro: { [string]: any } = Entry({ name = "outro", autoExec = OUTRO_LINES })
	local echo: { [string]: any } = Entry(Echo())

	registry:replaceCommands({ intro, echo })
	if #port.sent ~= 0 then
		return false, "an autoExec line was sent before replaceCommands returned"
	end

	if not WaitFor(sent(1), LIMIT) then
		return false, "intro's first autoExec line was never sent"
	end

	if WaitFor(sent(2), SETTLE) then
		return false, "intro's second line was sent before its first was answered"
	end

	answer()
	if not WaitFor(sent(2), LIMIT) then
		return false, "intro's second line was never sent once its first was answered"
	end

	answer()

	-- intro is held already, so only outro's line runs
	registry:replaceCommands({ intro, echo, outro })
	if not WaitFor(sent(3), LIMIT) then
		return false, "outro's autoExec line was never sent"
	end

	answer()
	if WaitFor(sent(4), SETTLE) then
		return false, "a line ran again for a command held already"
	end

	-- intro and outro leave, and nothing runs
	registry:replaceCommands({ echo })
	if WaitFor(sent(4), SETTLE) then
		return false, "a line ran for a list that holds no new command"
	end

	-- intro comes back, and its lines run again
	registry:replaceCommands({ intro, echo })
	if not WaitFor(sent(4), LIMIT) then
		return false, "intro's lines did not run again when it came back"
	end

	answer()
	if not WaitFor(sent(5), LIMIT) then
		return false, "intro's second line did not run again when it came back"
	end

	answer()

	if not Listed(port.sent, EXPECTED) then
		return false, `the lines sent were {table.concat(port.sent, SEPARATOR)}`
	end

	return true, nil
end
