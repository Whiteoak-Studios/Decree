--[[
    Past the hooks and guards the port's confirm is asked about the line,
    and a question it gives answers as Info in place of the server half,
    with the afterRun hooks still reading it, while nil runs the half
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "wipe"
local GUARDED: string = "guarded"
local QUESTION: string = "Send confirm within 30 seconds to run: wipe"
local WIPED: string = "Wiped"
local GUARD_REFUSAL: string = "Refused by the guard"
local INFO: string = "Info"
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local port: any = core.port
	local player: any = core.env.player
	local ran: number = 0 -- How many times the server half ran
	local heard: any = nil -- What the afterRun hook read as the response
	local asked: { any } = {} -- Each context confirm was asked about

	local confirm = port.confirm
	port.confirm = function (context: any): string?
		table.insert(asked, context)

		return confirm(context)
	end

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerHook("afterRun", function (context: any): string?
		heard = context.response

		return nil
	end)

	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): string
			ran += 1

			return WIPED
		end,
	})

	core.registry:registerCommandObject({
		name = GUARDED,
		args = {},

		guards = {
			function (): string?
				return GUARD_REFUSAL
			end,
		},

		run = function (): string
			ran += 1

			return WIPED
		end,
	})

	port.question = QUESTION

	local question: string, questionKind: string = core.run(NAME, player)
	if question ~= QUESTION or questionKind ~= INFO or ran ~= 0 then
		return false, `a confirmation answered {question} as {questionKind}, the server half run {ran} times`
	end

	if heard ~= QUESTION or #asked ~= 1 or asked[1].name ~= NAME or asked[1].executor ~= player then
		return false, `the afterRun hook read {heard}, or confirm was not asked about the line`
	end

	local refused: string, refusedKind: string = core.run(GUARDED, player)
	if refused ~= GUARD_REFUSAL or refusedKind ~= REFUSED or #asked ~= 1 then
		return false, `a guard's refusal answered {refused} as {refusedKind}, confirm asked {#asked} times`
	end

	port.question = nil

	local wiped: string, wipedKind: string = core.run(NAME, player)
	if wiped ~= WIPED or wipedKind ~= INFO or ran ~= 1 or heard ~= WIPED then
		return false, `with no question the line answered {wiped} as {wipedKind}`
	end

	return true, nil
end
