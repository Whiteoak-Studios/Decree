--[[
    A line typed on the client reaches Decree's run handler over Volt, and
    its reply resolves the Promise invoke returned with the text and kind
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")
local Echo = require("../../Fixtures/Dispatcher/Echo")

local LINE: string = "echo hello there"
local REPLY: string = "hello there"
local INFO: string = "Info"

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	server.decree.registry:registerCommandObject(Echo())
	server.start()

	local replied: any = server.client.Decree.run.invoke(LINE)
	if not server.settle(replied) then
		return false, "the reply never came"
	end

	local resolved: boolean, text: string, kind: string = replied:await()
	if not resolved or text ~= REPLY or kind ~= INFO then
		return false, `the line was answered {text} as {kind}`
	end

	return true, nil
end
