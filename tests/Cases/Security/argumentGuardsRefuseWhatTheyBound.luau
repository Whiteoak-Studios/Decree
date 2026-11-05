--[[
    The four argument guards refuse a line past their bound with Cmdr's
    words, each its own argument: a text too long, a forbidden value, a
    list too long and a blank text, and a line inside every bound runs
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local GUARDS: string = "src/Guards"
local BEFORE_RUN: string = "beforeRun"
local MAX_LENGTH: number = 5
local MAX_COUNT: number = 2
local FORBIDDEN: string = "admin"
local POSTED: string = "Posted"
local INFO: string = "Info"
local REFUSED: string = "Refused"

-- Each line, by the reply it gets
local LINES: { { string } } = {
	{ "post hello a,b ok", POSTED },
	{ "post toolong a ok", `Argument #1 exceeds the maximum character limit of {MAX_LENGTH}` },
	{ "post admin a ok", `Argument #1 cannot be "{FORBIDDEN}".` },
	{ "post hello a,b,c ok", `Argument #2 exceeds the maximum allowed limit of {MAX_COUNT} items.` },
	{ "post hello a", "Argument #3 cannot be empty or blank." },
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local Guards: any = core.env.require(GUARDS)

	core.registry:registerHook(BEFORE_RUN, PassingHook)
	core.registry:registerCommandObject({
		name = "post",

		args = {
			{ name = "text", type = "string" },
			{ name = "tags", type = "strings" },
			{ name = "note", type = "string", optional = true },
		},

		guards = {
			Guards.maxStringLength(1, MAX_LENGTH),
			Guards.notEquals(1, FORBIDDEN),
			Guards.maxArrayLength(2, MAX_COUNT),
			Guards.nonEmptyString(3),
		},

		run = function (): string
			return POSTED
		end,
	})

	for _, case: { string } in LINES do
		local reply: string, kind: string = core.run(case[1], core.env.player)
		local expectedKind: string = case[2] == POSTED and INFO or REFUSED

		if reply ~= case[2] or kind ~= expectedKind then
			return false, `{case[1]} was answered {reply} as {kind}`
		end
	end

	return true, nil
end
