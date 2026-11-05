--[[
    validate names each invalid argument by position and name, joined in
    order, with a fallback for a type that gives no message, and
    evaluateAndRun refuses with it before any hook, guard or run
--]]

--!strict
local Checked = require("../../Fixtures/Dispatcher/Checked")
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local TYPE: string = "checked"
local NAME: string = "check"
local VALID: string = "check ok ok ok"
local REPLY: string = "Ran"
local BLOCKED: string = "No permission hook is registered"
local REFUSED: string = "Refused"
local INFO: string = "Info"

-- Each refused line by the reason validate gives it
local REFUSALS: { [string]: string } = {
	["check bad ok ok"] = "#1 first: Bad value.",
	["check ok bad bad"] = "#2 second: Bad value.; #3 third: Bad value.",
	["check bad quiet bad"] = "#1 first: Bad value.; #2 second: Invalid value; #3 third: Bad value.",
	[`check "" ok ok`] = "#1 first: This argument is required.",
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player
	local runs: number = 0

	core.registry:registerType(TYPE, Checked())
	core.registry:registerCommandObject({
		name = NAME,
		args = {
			{ type = TYPE, name = "first" },
			{ type = TYPE, name = "second" },
			{ type = TYPE, name = "third" },
		},

		guards = {
			function (): string?
				runs += 1

				return nil
			end,
		},

		run = function (): string
			runs += 1

			return REPLY
		end,
	})

	for line: string, expected: string in REFUSALS do
		local context: any, evaluateReason: string? = core.dispatcher:evaluate(line, player)
		if not context then
			return false, `{line} was refused before validation: {evaluateReason}`
		end

		local valid: boolean, reason: string = context:validate(true)
		if valid or reason ~= expected then
			return false, `validate of {line} gave {valid} and {reason}`
		end

		-- No hook is registered yet, so a reply other than the refusal would be the block
		local reply: string, kind: string = core.run(line, player)
		if reply ~= expected or kind ~= REFUSED or runs ~= 0 then
			return false, `evaluateAndRun answered {reply} for {line}, reaching the guard or run {runs} times`
		end
	end

	local context: any = core.dispatcher:evaluate(VALID, player)
	local valid: boolean, reason: string = context:validate(true)
	if not valid or reason ~= "" then
		return false, `validate of a valid line gave {valid} and {reason}`
	end

	local blocked: string, blockedKind: string = core.run(VALID, player)
	core.registry:registerHook("beforeRun", PassingHook)
	local reply: string, kind: string = core.run(VALID, player)
	if blocked ~= BLOCKED or blockedKind ~= REFUSED or reply ~= REPLY or kind ~= INFO then
		return false, `a valid line answered {blocked}, then {reply} once a hook passed it`
	end

	return true, nil
end
