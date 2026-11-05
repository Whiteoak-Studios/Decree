--[[
    A confirm key that is a function asks the question it returns, or runs
    the line at once when it returns nil, and the line it asked about runs
    on confirm without the function asking again
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local NAME: string = "wipe"
local EVERY: string = "all" -- The scope the function asks about
local ONE: string = "one"
local SECONDS: number = 5 -- Room to send confirm in
local QUESTION: string = "Wipe every shard?"
local CONFIRM: string = "confirm"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local ran: { string } = {}

	server.decree.registry:registerCommandObject({
		name = NAME,
		args = { { name = "scope", type = "string" } },

		confirm = function (context: any): string?
			if context.rawArguments[1] == EVERY then
				return QUESTION
			end

			return nil
		end,

		run = function (_: any, scope: string): string
			table.insert(ran, scope)

			return scope
		end,
	})

	server.start({ confirmSeconds = SECONDS })

	local _, question: string = server.run(`{NAME} {EVERY}`)
	if question ~= QUESTION or #ran ~= 0 then
		return false, `{NAME} {EVERY} was answered {question}`
	end

	local _, one: string = server.run(`{NAME} {ONE}`)
	if one ~= ONE or ran[1] ~= ONE then
		return false, `{NAME} {ONE} was answered {one} where it runs at once`
	end

	local _, confirmed: string = server.run(CONFIRM)
	if confirmed ~= EVERY or ran[2] ~= EVERY then
		return false, `{CONFIRM} was answered {confirmed} where {NAME} {EVERY} runs`
	end

	return true, nil
end
