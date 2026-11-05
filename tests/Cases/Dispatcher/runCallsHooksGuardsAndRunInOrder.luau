--[[
    evaluateAndRun calls the beforeRun hooks, then the definition's guards
    in their order, then run, then the afterRun hooks, each with the one
    context of the run, whatever order the hooks were registered in
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "act"
local REPLY: string = "Acted"
local INFO: string = "Info"
local BEFORE_RUN: string = "beforeRun hook"
local FIRST_GUARD: string = "first guard"
local SECOND_GUARD: string = "second guard"
local RUN: string = "run"
local AFTER_RUN: string = "afterRun hook"
local EXPECTED: { string } = { BEFORE_RUN, FIRST_GUARD, SECOND_GUARD, RUN, AFTER_RUN }
local SEPARATOR: string = ", " -- Joins the steps in a failure's reason

return function (): (boolean, string | nil)
	local core: Server.Core = Server()

	local order: { string } = {}
	local contexts: { any } = {}

	local function record(step: string, context: any)
		table.insert(order, step)
		table.insert(contexts, context)
	end

	-- The afterRun hook first, so only the hook's name can put it last
	core.registry:registerHook("afterRun", function (context: any): string?
		record(AFTER_RUN, context)

		return nil
	end)

	core.registry:registerHook("beforeRun", function (context: any): string?
		record(BEFORE_RUN, context)

		return nil
	end)

	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		guards = {
			function (context: any): string?
				record(FIRST_GUARD, context)

				return nil
			end,

			function (context: any): string?
				record(SECOND_GUARD, context)

				return nil
			end,
		},

		run = function (context: any): string
			record(RUN, context)

			return REPLY
		end,
	})

	local reply: string, kind: string = core.run(NAME, core.env.player)
	if reply ~= REPLY or kind ~= INFO then
		return false, `the line answered {reply} as {kind}`
	end

	if table.concat(order, SEPARATOR) ~= table.concat(EXPECTED, SEPARATOR) then
		return false, `the steps ran as {table.concat(order, SEPARATOR)}`
	end

	for index: number, context: any in contexts do
		if context ~= contexts[1] or context.name ~= NAME then
			return false, `the {order[index]} was handed another context`
		end
	end

	return true, nil
end
