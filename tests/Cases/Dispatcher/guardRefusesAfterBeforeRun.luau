--[[
    The definition's guards run after the beforeRun hooks, each handed only
    the context, and the first to return anything but nil refuses with that
    value as text, before the later guards, run and the afterRun hooks
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "act"
local LINE: string = "act now"
local REPLY: string = "Acted"
local REFUSAL: string = "Not now."
local REFUSAL_NUMBER: number = 9
local NUMBER_TEXT: string = "9"
local REFUSED: string = "Refused"
local INFO: string = "Info"
local BEFORE_RUN: string = "beforeRun hook"
local FIRST_GUARD: string = "first guard"
local SECOND_GUARD: string = "second guard"
local THIRD_GUARD: string = "third guard"
local RUN: string = "run"
local AFTER_RUN: string = "afterRun hook"
local REFUSED_STEPS: { string } = { BEFORE_RUN, FIRST_GUARD, SECOND_GUARD } -- What runs when the second guard refuses
local PASSED: { string } = { BEFORE_RUN, FIRST_GUARD, SECOND_GUARD, THIRD_GUARD, RUN, AFTER_RUN }
local SEPARATOR: string = ", " -- Joins the steps in a failure's reason

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local refusal: any = nil -- What the second guard returns, which each step of the case sets
	local reached: { string } = {}
	local handed: { number } = {} -- How many values each guard call was handed

	core.registry:registerHook("beforeRun", function (): string?
		table.insert(reached, BEFORE_RUN)

		return nil
	end)

	core.registry:registerHook("afterRun", function (): string?
		table.insert(reached, AFTER_RUN)

		return nil
	end)

	core.registry:registerCommandObject({
		name = NAME,
		args = { { type = "string", name = "word" } },

		guards = {
			function (...: any): string?
				table.insert(reached, FIRST_GUARD)
				table.insert(handed, select("#", ...))

				return nil
			end,

			function (): any
				table.insert(reached, SECOND_GUARD)

				return refusal
			end,

			function (): string?
				table.insert(reached, THIRD_GUARD)

				return nil
			end,
		},

		run = function (): string
			table.insert(reached, RUN)

			return REPLY
		end,
	})

	local function run(): (string, string)
		table.clear(reached)

		return core.run(LINE, core.env.player)
	end

	refusal = REFUSAL
	local refused: string, refusedKind: string = run()
	local refusedSteps: string = table.concat(reached, SEPARATOR)
	if refused ~= REFUSAL or refusedKind ~= REFUSED or refusedSteps ~= table.concat(REFUSED_STEPS, SEPARATOR) then
		return false, `a refusing guard answered {refused} as {refusedKind}, reaching {refusedSteps}`
	end

	refusal = REFUSAL_NUMBER
	local fromNumber: string, numberKind: string = run()
	if fromNumber ~= NUMBER_TEXT or numberKind ~= REFUSED then
		return false, `a guard that returned a number answered the {type(fromNumber)} {fromNumber}`
	end

	refusal = nil
	local passed: string, passedKind: string = run()
	local passedSteps: string = table.concat(reached, SEPARATOR)
	if passed ~= REPLY or passedKind ~= INFO or passedSteps ~= table.concat(PASSED, SEPARATOR) then
		return false, `with every guard passing the line answered {passed}, reaching {passedSteps}`
	end

	if handed[1] ~= 1 then
		return false, `a guard was handed {handed[1]} values, where it takes only the context`
	end

	return true, nil
end
