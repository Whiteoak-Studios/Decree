--[[
    A subcommand's own confirm key decides whether its line asks: the
    subcommand with confirm asks for it, and its sibling without one runs
    at once
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local NAME: string = "wipe"
local ASKING: string = "now"
local PLAIN: string = "hold"
local SECONDS: number = 5 -- Room to send confirm in
local QUESTION: string = `Send confirm within {SECONDS} seconds to run: {NAME} {ASKING}`

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local ran: { [string]: boolean } = {}

	server.decree.registry:registerCommandObject({
		name = NAME,

		subcommands = {
			{ name = ASKING, confirm = true },
			{ name = PLAIN },
		},

		run = function (context: any): string
			ran[context.subcommand.name] = true

			return context.subcommand.name
		end,
	})

	server.start({ confirmSeconds = SECONDS })

	local _, held: string = server.run(`{NAME} {PLAIN}`)
	if held ~= PLAIN or not ran[PLAIN] then
		return false, `{NAME} {PLAIN} was answered {held} where it runs at once`
	end

	local _, question: string = server.run(`{NAME} {ASKING}`)
	if question ~= QUESTION or ran[ASKING] then
		return false, `{NAME} {ASKING} was answered {question} where it asks for confirmation`
	end

	return true, nil
end
