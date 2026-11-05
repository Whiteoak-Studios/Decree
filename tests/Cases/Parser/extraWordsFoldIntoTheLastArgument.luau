--[[
    Words typed past a command's last argument fold into that argument's
    raw value, joined by single spaces with their quotes gone, and a command
    with no arguments takes extra words without holding any of them
--]]

--!strict
local Evaluate = require("../../Fixtures/Parser/Evaluate")
local Server = require("../../Fixtures/Core/Server")

local SAY: string = "say"
local TELL: string = "tell"
local PING: string = "ping"
local PLAYER: string = "Player" -- The Name of the environment's own player
local UNHELD: string = `{PING} extra words`

-- Each typed line, the index of one of its arguments and the raw value that argument holds
local FOLDS: { Fold } = {
	{ line = `{SAY} hello big world`, index = 1, rawValue = "hello big world" },
	{ line = `{SAY} "a b" c`, index = 1, rawValue = "a b c" },
	{ line = `{SAY} a   b`, index = 1, rawValue = "a b" },
	{ line = `{TELL} {PLAYER} hi there`, index = 1, rawValue = PLAYER },
	{ line = `{TELL} {PLAYER} hi there`, index = 2, rawValue = "hi there" },
	{ line = `{TELL} "{PLAYER}" "hi" "there"`, index = 2, rawValue = "hi there" },
}

type Fold = {
	line: string,
	index: number,
	rawValue: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local player: any = core.env.player

	core.registry:registerCommandObject({ name = SAY, args = { { name = "message", type = "string" } } })
	core.registry:registerCommandObject({
		name = TELL,
		args = { { name = "target", type = "player" }, { name = "message", type = "string" } },
	})
	core.registry:registerCommandObject({ name = PING, args = {} })

	for _, fold: Fold in FOLDS do
		local argument: any, reason: string? = Evaluate(core.dispatcher, player, fold.line, fold.index)
		if not argument then
			return false, reason
		end

		if argument.rawValue ~= fold.rawValue then
			return false, `{fold.line} gave argument #{fold.index} the raw value {argument.rawValue}`
		end
	end

	local context: any, reason: string? = core.dispatcher:evaluate(UNHELD, player)
	if not context then
		return false, `{UNHELD} was refused: {reason}`
	end

	if #context.arguments ~= 0 or context.rawArguments[1] ~= nil then
		return false, `{UNHELD} holds {#context.arguments} arguments`
	end

	return true, nil
end
