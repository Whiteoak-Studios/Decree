--[[
    evaluateAndRun hands its caller a pending Promise while a type's
    validateOnce waits, so another line runs to its reply meanwhile, and
    the waiting line answers once its check is done
--]]

--!strict
local task = require("@lune/task")

local Echo = require("../../Fixtures/Dispatcher/Echo")
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local TYPE: string = "slow"
local NAME: string = "await"
local LINE: string = "await here"
local VALUE: string = "here"
local ECHO_LINE: string = "echo meanwhile"
local ECHOED: string = "meanwhile"
local INFO: string = "Info"
local STARTED: string = "Started" -- Promise.Status.Started
local WAIT: number = 0.5 -- Seconds the type's validateOnce waits, as a web lookup would

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player
	local checked: boolean = false

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject(Echo())
	core.registry:registerType(TYPE, {
		validateOnce = function (_: string): (boolean, string?)
			task.wait(WAIT)
			checked = true

			return true, nil
		end,

		parse = function (text: string): string
			return text
		end,
	})

	core.registry:registerCommandObject({
		name = NAME,
		args = { { name = "value", type = TYPE } },

		run = function (_: any, value: string): string
			return value
		end,
	})

	local waiting: any = core.dispatcher:evaluateAndRun(LINE, player)
	if checked or waiting:getStatus() ~= STARTED then
		return false, `evaluateAndRun returned only once validateOnce was done, its Promise {waiting:getStatus()}`
	end

	local echoed: string, echoedKind: string = core.run(ECHO_LINE, player)
	if echoed ~= ECHOED or echoedKind ~= INFO or checked then
		return false, `the line run meanwhile answered {echoed} as {echoedKind}, the check done: {checked}`
	end

	local _, reply: string, kind: string = waiting:await()
	if reply ~= VALUE or kind ~= INFO or not checked then
		return false, `the waiting line answered {reply} as {kind}`
	end

	return true, nil
end
