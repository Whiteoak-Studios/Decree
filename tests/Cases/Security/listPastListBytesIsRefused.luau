--[[
    A list whose strings pass LIST_BYTES is refused with a server error,
    so the commands call rejects, though Volt would have carried it
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local LIST_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").LIST_BYTES
local DESCRIPTION_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").DESCRIPTION_BYTES
local FILL: string = "d"
local PAST: string = "past"
local PLAIN: boolean = true -- Finds the text as written

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()
	local description: string = FILL:rep(DESCRIPTION_BYTES)

	-- One command more than the descriptions alone need to pass LIST_BYTES
	for index = 1, LIST_BYTES // DESCRIPTION_BYTES + 1 do
		server.decree.registry:registerCommandObject({
			name = `command{index}`,
			description = description,
			args = {},
		})
	end

	server.start()

	local listed: any = server.client.Decree.commands.invoke()
	if not server.settle(listed) then
		return false, "the commands call never settled"
	end

	local resolved: boolean, reason: any = listed:await()
	if resolved then
		return false, `a list of {#reason} commands past LIST_BYTES was sent`
	elseif type(reason) ~= "string" or not (reason :: string):find(PAST, 1, PLAIN) then
		return false, `the commands call was refused with {reason}, not Decree's size check`
	end

	return true, nil
end
