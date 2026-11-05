--[[
    With no beforeRun hook registered, every command is refused with the
    text that says so, before its guards, run or afterRun hooks, an afterRun
    hook alone lifting nothing
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "act"
local REPLY: string = "Acted"
local BLOCKED: string = "No permission hook is registered"
local REFUSED: string = "Refused"
local INFO: string = "Info"
local GUARD: string = "guard"
local RUN: string = "run"
local AFTER_RUN: string = "afterRun hook"
local EXPECTED: { string } = { GUARD, RUN, AFTER_RUN } -- What runs once a beforeRun hook passes the line
local SEPARATOR: string = ", " -- Joins the steps in a failure's reason

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local reached: { string } = {}

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

	local blocked: string, blockedKind: string = core.run(NAME, core.env.player)
	if blocked ~= BLOCKED or blockedKind ~= REFUSED or #reached ~= 0 then
		return false, `with no hook the line answered {blocked}, reaching {table.concat(reached, SEPARATOR)}`
	end

	core.registry:registerHook("afterRun", function (): string?
		table.insert(reached, AFTER_RUN)

		return nil
	end)

	local afterOnly: string, afterOnlyKind: string = core.run(NAME, core.env.player)
	if afterOnly ~= BLOCKED or afterOnlyKind ~= REFUSED or #reached ~= 0 then
		return false, `with only an afterRun hook the line answered {afterOnly}`
	end

	core.registry:registerHook("beforeRun", PassingHook)

	local reply: string, kind: string = core.run(NAME, core.env.player)
	local steps: string = table.concat(reached, SEPARATOR)
	if reply ~= REPLY or kind ~= INFO or steps ~= table.concat(EXPECTED, SEPARATOR) then
		return false, `with a beforeRun hook the line answered {reply}, reaching {steps}`
	end

	return true, nil
end
