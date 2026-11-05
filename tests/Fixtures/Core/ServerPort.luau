--[[
    A fresh stand-in for the server path's port per call: it records each
    line sent through it, and its confirmation asks the question a case
    sets, running every command at once while there is none
--]]

--!strict
export type Line = {
	recipient: any,
	text: string,
	kind: string,
	caller: any,
}

export type ServerPort = {
	decree: { [string]: any },
	lines: { Line }, -- Each line sent, in order
	question: string?, -- What confirm asks, which a case sets
	line: (recipient: any, text: string, kind: string, caller: any) -> (),
	confirm: (context: any) -> string?,
}

return function (): ServerPort
	local port: ServerPort

	port = {
		decree = {},
		lines = {},
		question = nil :: string?,

		line = function (recipient: any, text: string, kind: string, caller: any)
			table.insert(port.lines, { recipient = recipient, text = text, kind = kind, caller = caller })
		end,

		confirm = function (_: any): string?
			return port.question
		end,
	}

	return port
end
