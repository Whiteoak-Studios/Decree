--[[
    A fresh stand-in for the console's port per call: it records each line
    sent, each local event and each device half asked for, and answers a
    sent line with itself as Ok unless a case sets another answer
--]]

--!strict
local OK: string = "Ok"

export type Event = {
	name: string,
	values: { n: number, [number]: any },
}

export type ClientPort = {
	decree: { [string]: any },
	sent: { string }, -- Each line send was given, in order
	events: { Event }, -- Each local event, in order
	asked: { string }, -- Each command name clientRun was asked for, in order
	halves: { [string]: (...any) -> ...any }, -- The device half clientRun gives each command name, which a case sets
	answer: (text: string) -> any, -- The Promise send answers a line with, which a case may replace
	send: (text: string) -> any,
	event: (name: string, ...any) -> (),
	clientRun: (name: string) -> ((...any) -> ...any)?,
}

return function (Promise: any): ClientPort
	local port: ClientPort

	port = {
		decree = {},
		sent = {},
		events = {},
		asked = {},
		halves = {},

		answer = function (text: string): any
			return Promise.resolve(text, OK)
		end,

		send = function (text: string): any
			table.insert(port.sent, text)

			return port.answer(text)
		end,

		event = function (name: string, ...: any)
			table.insert(port.events, { name = name, values = table.pack(...) })
		end,

		clientRun = function (name: string): ((...any) -> ...any)?
			table.insert(port.asked, name)

			return port.halves[name]
		end,
	}

	return port
end
