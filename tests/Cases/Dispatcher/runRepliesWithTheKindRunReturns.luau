--[[
    A run's second return is its reply's kind, one of Info, Ok, Refused and
    Error as written, and any other kind, a Color3, a table or none is
    Info, as is a run that returns no text
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "answer"
local TEXT: string = "Answered"
local EXECUTED: string = "Command executed."
local INFO: string = "Info"
local ERROR: string = "Error"

-- Each kind run returns beside its text, and the kind the reply takes
local KINDS: { Returned } = {
	{ given = "Info", kind = "Info" },
	{ given = "Ok", kind = "Ok" },
	{ given = "Refused", kind = "Refused" },
	{ given = "Error", kind = "Error" },
	{ given = "ok", kind = "Info" }, -- A kind is written as it is named
	{ given = "Warning", kind = "Info" },
	{ given = roblox.Color3.new(1, 0, 0), kind = "Info" },
	{ given = { Color = roblox.Color3.new(0, 1, 0) }, kind = "Info" },
	{ given = nil, kind = "Info" },
}

type Returned = {
	given: any,
	kind: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local text: string? = TEXT -- What run returns first, which a step of the case sets
	local given: any = nil -- What run returns second, which each step sets

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): (string?, any)
			return text, given
		end,
	})

	for _, expected: Returned in KINDS do
		given = expected.given

		local reply: string, kind: string = core.run(NAME, core.env.player)
		if reply ~= TEXT or kind ~= expected.kind then
			return false, `a run returning the kind {expected.given} answered {reply} as {kind}`
		end
	end

	-- A run that returns no text answers that it ran, as Info whatever its kind
	text = nil
	given = ERROR

	local executed: string, executedKind: string = core.run(NAME, core.env.player)
	if executed ~= EXECUTED or executedKind ~= INFO then
		return false, `a run returning no text and an Error kind answered {executed} as {executedKind}`
	end

	return true, nil
end
