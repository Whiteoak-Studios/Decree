--[[
    A quoted argument reaches the argument context whole, in its raw value,
    its one segment and its value, an open quote stays in the text, and an
    empty pair of quotes fails validation as a missing argument
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Listed = require("../../Fixtures/Parser/Listed")
local Server = require("../../Fixtures/Core/Server")

local SAY: string = "say"
local TELL: string = "tell"
local PLAYER: string = "Player" -- The Name of the environment's own player
local EMPTY: string = `{SAY} ""`
local REQUIRED: string = "This argument is required."

-- Each typed line, the index of its quoted argument and the text that argument holds
local QUOTED: { Quoted } = {
	{ line = `{SAY} "hello world"`, index = 1, text = "hello world" },
	{ line = `{SAY} 'hello world'`, index = 1, text = "hello world" },
	{ line = `{SAY} "a, b"`, index = 1, text = "a, b" },
	{ line = `{TELL} {PLAYER} "hi there"`, index = 2, text = "hi there" },
	{ line = `{SAY} "open quote`, index = 1, text = `"open quote` },
}

type Quoted = {
	line: string,
	index: number,
	text: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player

	core.registry:registerCommandObject({ name = SAY, args = { { name = "message", type = "string" } } })
	core.registry:registerCommandObject({
		name = TELL,
		args = { { name = "target", type = "player" }, { name = "message", type = "string" } },
	})

	for _, quoted: Quoted in QUOTED do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, quoted.line, quoted.index)
		if not argument then
			return false, reason
		end

		local value: any = argument:getValue()
		local valid: boolean, invalid: string? = argument:validate()
		if argument.rawValue ~= quoted.text or not Listed(argument.rawSegments, { quoted.text }) then
			return false, `{quoted.line} gave the raw value {argument.rawValue} in {#argument.rawSegments} segments`
		end

		if value ~= quoted.text or not valid then
			return false, `{quoted.line} gave the value {value}, valid {valid}: {invalid}`
		end
	end

	local empty: any, reason: string? = Evaluate(core.dispatcher, player, EMPTY, 1)
	if not empty then
		return false, reason
	end

	local valid: boolean, invalid: string? = empty:validate()
	if empty.rawValue ~= "" or valid or invalid ~= REQUIRED then
		return false, `{EMPTY} gave the raw value {empty.rawValue} and validated {valid}: {invalid}`
	end

	return true, nil
end
