--[[
    The context run receives carries the command's name, the word it was
    typed as, the raw text, the executor, the definition's fields, a state
    fresh to each run, the raw arguments and each argument by position
--]]

--!strict
local Echo = require("../../Fixtures/Dispatcher/Echo")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "echo"
local ALIAS: string = "SAY"
local LINE: string = "SAY  hello there" -- Two spaces after the alias, which the raw text keeps
local TEXT: string = "hello there"
local ARGUMENT: string = "text"
local MARK: string = "marked" -- The state key the beforeRun hook sets for run to read

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local definition: { [string]: any } = Echo()
	local contexts: { any } = {}
	local marks: { any } = {} -- What each run's run read from state under MARK

	definition.run = function (context: any, text: string): string
		table.insert(contexts, context)
		table.insert(marks, context.state[MARK])

		return text
	end

	core.registry:registerCommandObject(definition)
	core.registry:registerHook("beforeRun", function (context: any): string?
		context.state[MARK] = #contexts + 1

		return nil
	end)

	core.run(LINE, core.env.player)
	core.run(LINE, core.env.player)

	local context: any = contexts[1]
	if not context or not contexts[2] then
		return false, `run was reached {#contexts} times for two lines`
	end

	if
		context.name ~= NAME
		or context.alias ~= ALIAS
		or context.rawText ~= LINE
		or context.executor ~= core.env.player
	then
		return false, `the context was {context.name}, typed as {context.alias} in {context.rawText}`
	end

	if
		context.object ~= definition
		or context.group ~= definition.group
		or context.description ~= definition.description
	then
		return false, "the context does not carry the definition's group and description"
	end

	if context.aliases ~= definition.aliases or context.argumentDefinitions ~= definition.args then
		return false, "the context's aliases and argumentDefinitions are not the definition's own"
	end

	local raw: { string } = context.rawArguments
	if #raw ~= 1 or raw[1] ~= TEXT then
		return false, `the context's raw arguments are {#raw}, the first {raw[1]}`
	end

	local argument: any = context:getArgument(1)
	if not argument or argument.name ~= ARGUMENT or argument:getValue() ~= TEXT or context:getArgument(2) ~= nil then
		return false, "getArgument does not answer each argument by its position"
	end

	if type(context.state) ~= "table" or context.state == contexts[2].state or marks[1] ~= 1 or marks[2] ~= 2 then
		return false, `the runs shared a state, or run read {marks[1]} and {marks[2]} from the hook`
	end

	return true, nil
end
