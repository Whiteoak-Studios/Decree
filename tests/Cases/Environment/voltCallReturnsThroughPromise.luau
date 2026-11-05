--[[
    A test schema's generated modules start over Volt's mock, each on its
    side's transport, and a client's call comes back through the installed
    Promise, whose delays end on the fake Heartbeat
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local Environment = require("../../Environment")

local SCHEMA: string = "tests/Schemas/Smoke.volt"
local OUTPUT: string = ".volt/Smoke" -- Where the schema's options write its modules, which volt needs to exist
local ARGUMENTS: { string } = { SCHEMA, "--quiet" }
local SERVER: string = `{OUTPUT}/Server`
local CLIENT: string = `{OUTPUT}/Client`
local TEXT: string = "hello"
local REPLY: string = "olleh" -- The text the server's handler sends back, reversed
local RESOLVED: string = "Resolved" -- Promise.Status.Resolved
local DELAY: number = 0.05 -- Seconds of a Promise.delay only the fake Heartbeat can end

return function (): (boolean, string | nil)
	fs.writeDir(OUTPUT)

	local compiled: process.ExecResult = process.exec("volt", ARGUMENTS)
	if not compiled.ok then
		return false, `volt could not compile {SCHEMA}: {compiled.stdout}{compiled.stderr}`
	end

	local env: any = Environment.new({ files = { `{SERVER}.luau`, `{CLIENT}.luau` } })
	local server: any = env.require(SERVER)
	local client: any = env.require(CLIENT)

	local caller: any = nil
	server.Smoke.echo.on(function (player: any, text: string): string
		caller = player

		return text:reverse()
	end)

	local reply: any = client.Smoke.echo.invoke(TEXT)
	for _ = 1, Environment.ROUND_TRIP do
		env.mock:step()
	end

	if reply:getStatus() ~= RESOLVED then
		return false, `the call was {reply:getStatus()} after {Environment.ROUND_TRIP} steps`
	end

	local _: boolean, text: string = reply:await()
	if text ~= REPLY or caller ~= env.player then
		return false, `the server heard {caller and caller.Name} and the client got {text}`
	end

	-- The client module's promise is the environment's own Promise, not a copy
	local Promise: any = env.require("Packages/Promise")
	if getmetatable(reply) ~= Promise then
		return false, "the client module's promise is not the installed Promise"
	end

	local waited: boolean, elapsed: number = Promise.delay(DELAY):await()
	if not waited or elapsed < DELAY then
		return false, `Promise.delay settled {waited} after {elapsed} s`
	end

	return true, nil
end
