--[[
    A reply a command sends while it runs reaches the caller's console over
    the line event, with its text and kind, beside the line's own reply
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local LINE: string = "announce"
local PRINTED: string = "The round starts in ten seconds"
local PRINTED_KIND: string = "Ok"
local DONE: string = "Announced"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()

	server.decree.registry:registerCommandObject({
		name = LINE,
		args = {},

		run = function (context: any): string
			context:reply(PRINTED, PRINTED_KIND)

			return DONE
		end,
	})

	server.start()

	local lines: { { string } } = {}
	server.client.Decree.line.on(function (text: string, kind: string)
		table.insert(lines, { text, kind })
	end)

	local replied: any = server.client.Decree.run.invoke(LINE)
	if not server.settle(replied) then
		return false, "the reply never came"
	end

	local _, text: string = replied:await()
	if text ~= DONE then
		return false, `the line was answered {text}`
	end

	if #lines ~= 1 or lines[1][1] ~= PRINTED or lines[1][2] ~= PRINTED_KIND then
		return false, `the console heard {#lines} lines, the first {lines[1] and lines[1][1]}`
	end

	return true, nil
end
