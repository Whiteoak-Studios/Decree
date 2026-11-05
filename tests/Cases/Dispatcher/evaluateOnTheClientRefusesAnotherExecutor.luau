--[[
    On a client, evaluate throws for any executor but the LocalPlayer, no
    executor and blank text included, and evaluates the LocalPlayer's line
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Entry = require("../../Fixtures/Core/Entry")
local Environment = require("../../Environment")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local DISPATCHER: string = "src/DecreeClient/Shared/Dispatcher"
local LINE: string = "echo hello"
local BLANK: string = "" -- Refused for the executor before it is refused as empty
local SECOND: string = "Second"
local NOT_LOCAL: string = "[Decree] Can't evaluate a command that isn't sent by the local player."

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local second: any = env.mock:join(SECOND)
	local dispatcher: any = env.require(DISPATCHER)
	env.require(REGISTRY):replaceCommands({ Entry(Echo()) })

	local forSecond: boolean, secondError: any = pcall(dispatcher.evaluate, dispatcher, LINE, second)
	if forSecond or Thrown(secondError) ~= NOT_LOCAL then
		return false, `a line from another player gave {secondError}`
	end

	local forNobody: boolean, nobodyError: any = pcall(dispatcher.evaluate, dispatcher, LINE, nil)
	if forNobody or Thrown(nobodyError) ~= NOT_LOCAL then
		return false, `a line with no executor gave {nobodyError}`
	end

	local blank: boolean, blankError: any = pcall(dispatcher.evaluate, dispatcher, BLANK, second)
	if blank or Thrown(blankError) ~= NOT_LOCAL then
		return false, `blank text from another player gave {blankError}`
	end

	local context: any, reason: string? = dispatcher:evaluate(LINE, env.player)
	if not context or context.executor ~= env.player then
		return false, `the LocalPlayer's line was refused: {reason}`
	end

	return true, nil
end
