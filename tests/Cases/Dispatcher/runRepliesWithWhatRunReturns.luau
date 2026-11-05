--[[
    evaluateAndRun answers with what run returns as Info text, a number or
    a table through tostring, and with "Command executed." when run returns
    nil or false
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "answer"
local TEXT: string = "Answered"
local NUMBER: number = 42
local NUMBER_TEXT: string = "42"
local EXECUTED: string = "Command executed."
local INFO: string = "Info"

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local returned: any = nil -- What run returns, which each step of the case sets

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): any
			return returned
		end,
	})

	local function run(): (string, string)
		return core.run(NAME, core.env.player)
	end

	returned = TEXT
	local text: string, textKind: string = run()
	if text ~= TEXT or textKind ~= INFO then
		return false, `a run that returned text answered {text} as {textKind}`
	end

	returned = nil
	local fromNil: string, nilKind: string = run()
	returned = false
	local fromFalse: string, falseKind: string = run()
	if fromNil ~= EXECUTED or fromFalse ~= EXECUTED or nilKind ~= INFO or falseKind ~= INFO then
		return false, `a run that returned nil answered {fromNil}, and one that returned false {fromFalse}`
	end

	returned = NUMBER
	local number: string = run()
	if number ~= NUMBER_TEXT then
		return false, `a run that returned a number answered the {type(number)} {number}`
	end

	local tableValue: { [string]: any } = {}
	returned = tableValue
	local fromTable: string = run()
	if fromTable ~= tostring(tableValue) then
		return false, `a run that returned a table answered {fromTable}`
	end

	return true, nil
end
