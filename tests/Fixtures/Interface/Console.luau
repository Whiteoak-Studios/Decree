--[[
    A fresh console session per call on a fresh client environment, its port
    bound, with Decree's server module on the same mock and each line and
    clear the session's listen gives recorded
--]]

--!strict
local Environment = require("../../Environment")

local SESSION: string = "src/DecreeClient/Session"
local SERVER: string = "src/Network"
local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local DISPATCHER: string = "src/DecreeClient/Shared/Dispatcher"
local RESOLVED: string = "Resolved" -- Promise.Status.Resolved

export type Line = {
	text: string,
	kind: string,
}

export type Console = {
	env: any,
	server: any, -- Decree's generated server module, on the same mock as the session
	session: any,
	registry: any,
	dispatcher: any,
	lines: { Line }, -- Each line listen printed, in order
	clears: number, -- How many times listen's clear ran
	listen: () -> (), -- Starts the session's listen, recording what it prints and each clear
	step: () -> (), -- Steps the mock the round trip a client's call takes
	reply: (promise: any) -> (string?, string?), -- A Promise's text and kind after a round trip, nil while it waits
}

return function (folders: { string }?): Console -- Further folders to mount, such as a device half's
	local env: any = Environment.new({ side = "client", folders = folders })
	local server: any = env.require(SERVER)
	local session: any = env.require(SESSION)
	local console: Console

	console = {
		env = env,
		server = server,
		session = session,
		registry = env.require(REGISTRY),
		dispatcher = env.require(DISPATCHER),
		lines = {},
		clears = 0,

		listen = function ()
			session:listen(function (text: string, kind: string)
				table.insert(console.lines, { text = text, kind = kind })
			end, function ()
				console.clears += 1
			end)
		end,

		step = function ()
			for _ = 1, Environment.ROUND_TRIP do
				env.mock:step()
			end
		end,

		reply = function (promise: any): (string?, string?)
			console.step()

			if promise:getStatus() ~= RESOLVED then
				return nil, nil
			end

			local _: boolean, text: string, kind: string = promise:await()

			return text, kind
		end,
	}

	-- No case sends a local event, so they go nowhere
	session:bind({}, function () end)

	return console
end
