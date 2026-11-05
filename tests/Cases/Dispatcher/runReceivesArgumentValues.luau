--[[
    run receives the context, then one parsed value per argument definition:
    an absent optional argument as nil and an absent or empty argument with
    a default as that default
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "values"
local WORD: string = "hello"
local AMOUNT: number = 5 -- What the number type parses AMOUNT_TEXT to
local AMOUNT_TEXT: string = "5"
local LABEL: string = "tag"
local DEFAULT: string = "unnamed"
local VALUES: number = 3 -- One per argument definition, whatever the line gave

-- The word alone, then with an amount, with every argument, and with an empty label
local LINES: { string } = {
	`{NAME} {WORD}`,
	`{NAME} {WORD} {AMOUNT_TEXT}`,
	`{NAME} {WORD} {AMOUNT_TEXT} {LABEL}`,
	`{NAME} {WORD} {AMOUNT_TEXT} ""`,
}

type Received = { length: number, context: any, word: any, amount: any, label: any }

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local received: { Received } = {}

	core.registry:registerHook("beforeRun", PassingHook)
	core.registry:registerCommandObject({
		name = NAME,
		args = {
			{ type = "string", name = "word" },
			{ type = "number", name = "amount", optional = true },
			{ type = "string", name = "label", default = DEFAULT },
		},

		run = function (context: any, ...: any): ()
			local word: any, amount: any, label: any = ...
			local values: Received =
				{ length = select("#", ...), context = context, word = word, amount = amount, label = label }

			table.insert(received, values)
		end,
	})

	for _, line: string in LINES do
		core.run(line, core.env.player)
	end

	if #received ~= #LINES then
		return false, `run was reached {#received} times for {#LINES} lines`
	end

	for _, values: Received in received do
		if values.context.name ~= NAME or values.length ~= VALUES or values.word ~= WORD then
			return false, `run received {values.length} values after its context, the first {values.word}`
		end
	end

	local onlyWord: Received = received[1]
	if onlyWord.amount ~= nil or onlyWord.label ~= DEFAULT then
		return false, `with only its first argument run received {onlyWord.amount} and {onlyWord.label}`
	end

	local withAmount: Received = received[2]
	if withAmount.amount ~= AMOUNT or withAmount.label ~= DEFAULT then
		return false, `with an amount run received the {type(withAmount.amount)} {withAmount.amount}`
	end

	local every: Received = received[3]
	if every.amount ~= AMOUNT or every.label ~= LABEL then
		return false, `with every argument run received {every.amount} and {every.label}`
	end

	local emptyLabel: Received = received[4]
	if emptyLabel.label ~= DEFAULT then
		return false, `with an empty label run received {emptyLabel.label}`
	end

	return true, nil
end
