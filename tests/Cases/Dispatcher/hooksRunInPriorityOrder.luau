--[[
    Hooks of each kind run from the lowest priority to the highest, one
    registered with none at 0, and hooks of equal priority in the order
    they registered
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "act"
local SEPARATOR: string = ", " -- Joins the hooks in a failure's reason

-- Each hook by the name it records and the priority it registers with, in the order it registers
local HOOKS: { Hook } = {
	{ name = "late", priority = 10 },
	{ name = "early", priority = -5 },
	{ name = "unset" },
	{ name = "zero", priority = 0 },
	{ name = "lateAgain", priority = 10 },
	{ name = "zeroAgain", priority = 0 },
}

-- The two at 10 keep the order they registered in, as the two at 0 do
local EXPECTED: { string } = { "early", "unset", "zero", "zeroAgain", "late", "lateAgain" }

type Hook = { name: string, priority: number? }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local beforeOrder: { string } = {}
	local afterOrder: { string } = {}

	for _, hook: Hook in HOOKS do
		core.registry:registerHook("beforeRun", function (): string?
			table.insert(beforeOrder, hook.name)

			return nil
		end, hook.priority)

		core.registry:registerHook("afterRun", function (): string?
			table.insert(afterOrder, hook.name)

			return nil
		end, hook.priority)
	end

	core.registry:registerCommandObject({ name = NAME, args = {}, run = function (): () end })
	core.run(NAME, core.env.player)

	local expected: string = table.concat(EXPECTED, SEPARATOR)
	local before: string = table.concat(beforeOrder, SEPARATOR)
	local after: string = table.concat(afterOrder, SEPARATOR)
	if before ~= expected or after ~= expected then
		return false, `the beforeRun hooks ran as {before} and the afterRun hooks as {after}`
	end

	return true, nil
end
