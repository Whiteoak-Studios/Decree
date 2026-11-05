--[[
    A type's validateOnce runs only when validate is final, as it is in
    evaluateAndRun, while its validate runs either way, and a validateOnce
    refusal with no message is named as an error
--]]

--!strict
local Checked = require("../../Fixtures/Dispatcher/Checked")
local Server = require("../../Fixtures/Core/Server")

local TYPE: string = "checked"
local NAME: string = "check"
local LATE_LINE: string = "check late"
local HUSHED_LINE: string = "check hushed"
local BAD_LINE: string = "check bad"
local LATE: string = "#1 value: Late value."
local HUSHED: string = "#1 value: error"
local BAD: string = "#1 value: Bad value."
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player

	core.registry:registerType(TYPE, Checked())
	core.registry:registerCommandObject({
		name = NAME,
		args = { { type = TYPE, name = "value" } },
	})

	local late: any = core.dispatcher:evaluate(LATE_LINE, player)

	local unset: boolean, unsetReason: string = late:validate()
	local notFinal: boolean, notFinalReason: string = late:validate(false)
	if not unset or not notFinal or unsetReason ~= "" or notFinalReason ~= "" then
		return false, `a line only validateOnce refuses failed a validate that is not final: {unsetReason}`
	end

	local final: boolean, finalReason: string = late:validate(true)
	if final or finalReason ~= LATE then
		return false, `a final validate gave {final} and {finalReason}`
	end

	local reply: string, kind: string = core.run(LATE_LINE, player)
	if reply ~= LATE or kind ~= REFUSED then
		return false, `evaluateAndRun answered {reply} as {kind}, where its validation is final`
	end

	local hushed: any = core.dispatcher:evaluate(HUSHED_LINE, player)
	local hushedValid: boolean, hushedReason: string = hushed:validate(true)
	if hushedValid or hushedReason ~= HUSHED then
		return false, `a validateOnce refusal with no message gave {hushedReason}`
	end

	local bad: any = core.dispatcher:evaluate(BAD_LINE, player)
	local badValid: boolean, badReason: string = bad:validate(false)
	if badValid or badReason ~= BAD then
		return false, `a validate that is not final passed a value validate refuses: {badReason}`
	end

	return true, nil
end
