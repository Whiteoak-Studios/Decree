--[[
    A command's reply prints in its executor's console, and its sendEvent
    AddLine in another player's, each through the port with the executor as
    the caller, and a Color3, a table or no kind is Info
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "tell"
local SECOND: string = "Second"
local TEXT: string = "Told"
local NUMBER: number = 5
local NUMBER_TEXT: string = "5"
local OTHER_TEXT: string = "Told you too"
local DONE: string = "Done"
local ADD_LINE: string = "AddLine"
local INFO: string = "Info"
local OK: string = "Ok"
local REFUSED: string = "Refused"
local RED: any = roblox.Color3.new(1, 0, 0)

-- Each line the run sends, in order, by whom it reaches
local EXPECTED: { Line } = {
	{ recipient = "executor", text = TEXT, kind = INFO },
	{ recipient = "executor", text = TEXT, kind = OK },
	{ recipient = "executor", text = TEXT, kind = INFO }, -- Sent with a Color3
	{ recipient = "executor", text = TEXT, kind = INFO }, -- Sent with an options table
	{ recipient = "executor", text = NUMBER_TEXT, kind = INFO },
	{ recipient = "second", text = OTHER_TEXT, kind = REFUSED },
}

type Line = {
	recipient: string, -- "executor" or "second"
	text: string,
	kind: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player
	local second: any = core.env.mock:join(SECOND)
	local recipients: { [string]: any } = { executor = player, second = second }

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (context: any): string
			context:reply(TEXT)
			context:reply(TEXT, OK)
			context:reply(TEXT, RED)
			context:reply(TEXT, { Color = RED })
			context:reply(NUMBER)
			context:sendEvent(second, ADD_LINE, OTHER_TEXT, REFUSED)

			return DONE
		end,
	})

	local reply: string = core.run(NAME, player)
	local lines: { any } = core.port.lines
	if reply ~= DONE or #lines ~= #EXPECTED then
		return false, `the run answered {reply} after sending {#lines} lines`
	end

	for index: number, expected: Line in EXPECTED do
		local line: any = lines[index]

		if
			line.recipient ~= recipients[expected.recipient]
			or line.text ~= expected.text
			or line.kind ~= expected.kind
			or line.caller ~= player
		then
			return false, `line #{index} reached the port as {line.text}, {line.kind}`
		end
	end

	return true, nil
end
