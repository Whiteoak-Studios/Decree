--[[
    A beforeRun hook that returns anything but nil refuses the command with
    that value as text, before any later hook, guard, run or afterRun hook,
    and a hook that returns nil passes it on
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "act"
local REPLY: string = "Acted"
local REFUSAL: string = "You may not run this."
local REFUSAL_NUMBER: number = 403
local NUMBER_TEXT: string = "403"
local FALSE_TEXT: string = "false"
local REFUSED: string = "Refused"
local INFO: string = "Info"
local LATER_PRIORITY: number = 1 -- Above the refusing hook's default 0, so it runs after it
local LATER_HOOK: string = "later beforeRun hook"
local GUARD: string = "guard"
local RUN: string = "run"
local AFTER_RUN: string = "afterRun hook"
local EXPECTED: { string } = { LATER_HOOK, GUARD, RUN, AFTER_RUN } -- What runs once the first hook passes
local SEPARATOR: string = ", " -- Joins the steps in a failure's reason

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local refusal: any = nil -- What the first hook returns, which each step of the case sets
	local reached: { string } = {}

	core.registry:registerHook("beforeRun", function (): any
		return refusal
	end)

	core.registry:registerHook("beforeRun", function (): string?
		table.insert(reached, LATER_HOOK)

		return nil
	end, LATER_PRIORITY)

	core.registry:registerHook("afterRun", function (): string?
		table.insert(reached, AFTER_RUN)

		return nil
	end)

	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		guards = {
			function (): string?
				table.insert(reached, GUARD)

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

		return core.run(NAME, core.env.player)
	end

	refusal = REFUSAL
	local refused: string, refusedKind: string = run()
	if refused ~= REFUSAL or refusedKind ~= REFUSED or #reached ~= 0 then
		return false, `a refusing hook answered {refused} as {refusedKind}, reaching {table.concat(reached, SEPARATOR)}`
	end

	refusal = false
	local fromFalse: string, falseKind: string = run()
	if fromFalse ~= FALSE_TEXT or falseKind ~= REFUSED or #reached ~= 0 then
		return false, `a hook that returned false answered {fromFalse} as {falseKind}`
	end

	refusal = REFUSAL_NUMBER
	local fromNumber: string, numberKind: string = run()
	if fromNumber ~= NUMBER_TEXT or numberKind ~= REFUSED or #reached ~= 0 then
		return false, `a hook that returned a number answered the {type(fromNumber)} {fromNumber}`
	end

	refusal = nil
	local passed: string, passedKind: string = run()
	local steps: string = table.concat(reached, SEPARATOR)
	if passed ~= REPLY or passedKind ~= INFO or steps ~= table.concat(EXPECTED, SEPARATOR) then
		return false, `a hook that returned nil answered {passed} as {passedKind}, reaching {steps}`
	end

	return true, nil
end
