--[[
    Words past a command's last argument fold into that argument, one space
    between each however many were typed, and a command with no arguments
    evaluates with every word after its name left out
--]]

--!strict
local Pair = require("../../Fixtures/Dispatcher/Pair")
local Server = require("../../Fixtures/Core/Server")

local LINE: string = "pair one two   three four" -- A run of spaces between two of the folded words
local FIRST: string = "one"
local REST: string = "two three four"
local BARE_NAME: string = "ping"
local BARE_LINE: string = "ping these words go nowhere"
local SEPARATOR: string = " | " -- Joins the raw arguments in a failure's reason

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	core.registry:registerCommandObject(Pair())
	core.registry:registerCommandObject({ name = BARE_NAME, args = {} })

	local context: any, reason: string? = core.dispatcher:evaluate(LINE, core.env.player)
	if not context then
		return false, `the line was refused: {reason}`
	end

	local raw: { string } = context.rawArguments
	if #raw ~= 2 or raw[1] ~= FIRST or raw[2] ~= REST then
		return false, `the raw arguments are {table.concat(raw, SEPARATOR)}`
	end

	local first: any = context:getArgument(1):getValue()
	local rest: any = context:getArgument(2):getValue()
	if first ~= FIRST or rest ~= REST then
		return false, `the arguments' values are {first} and {rest}`
	end

	local bare: any, bareReason: string? = core.dispatcher:evaluate(BARE_LINE, core.env.player)
	if not bare then
		return false, `the command with no arguments was refused: {bareReason}`
	end

	if #bare.rawArguments ~= 0 or #bare.arguments ~= 0 then
		return false, `the command with no arguments kept {#bare.rawArguments} raw arguments`
	end

	return true, nil
end
