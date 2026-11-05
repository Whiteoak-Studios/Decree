--[[
    replaceCommands refuses a list holding autoExec lines until bindClient
    has run, replacing nothing, so the same list given once bound runs its
    lines, while a list holding none needs no dispatcher
--]]

--!strict
local ClientPort = require("../../Fixtures/Core/ClientPort")
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Entry = require("../../Fixtures/Core/Entry")
local Environment = require("../../Environment")
local Listed = require("../../Fixtures/Parser/Listed")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")
local WaitFor = require("../../Fixtures/Core/WaitFor")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local DISPATCHER: string = "src/DecreeClient/Shared/Dispatcher"
local PROMISE: string = "Packages/Promise"
local INTRO: string = "intro"
local ECHO: string = "echo"
local LINES: { string } = { "echo one", "echo two" }
local UNBOUND: string = "[Decree] autoExec lines run through the dispatcher, which bindClient binds first."
local LIMIT: number = 2 -- Seconds the case waits for the lines to be sent

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local registry: any = env.require(REGISTRY)
	local intro: { [string]: any } = Entry({ name = INTRO, autoExec = LINES })
	local echo: { [string]: any } = Entry(Echo())

	local replaced: boolean, problem: any = pcall(registry.replaceCommands, registry, { intro, echo })
	if replaced or Thrown(problem) ~= UNBOUND then
		return false, `a list with autoExec lines before bindClient gave {problem}`
	end

	if registry:getCommand(INTRO) ~= nil or #registry:getCommands() ~= 0 then
		return false, "the refused list replaced the client's commands"
	end

	registry:replaceCommands({ echo })
	if registry:getCommand(ECHO) == nil then
		return false, "a list with no autoExec lines was refused before bindClient"
	end

	local port: ClientPort.ClientPort = ClientPort(env.require(PROMISE))
	env.require(DISPATCHER):bindClient(port)

	registry:replaceCommands({ intro, echo })

	local ran: boolean = WaitFor(function (): boolean
		return #port.sent >= #LINES
	end, LIMIT)

	if not ran or not Listed(port.sent, LINES) then
		return false, `once bound, the list refused before sent {#port.sent} of its lines`
	end

	return true, nil
end
