--[[
    The lookup argument types: command and type, which find the names the
    registry holds, the server's command type only the executor's own, and
    userInput, which finds keys and input types, each with its listable
--]]

--!strict
local Util = require("../Util")

local NO_COMMAND: string = "No command with that name could be found."
local NO_TYPE: string = "No type with that name could be found."

local Types = require("../Config/Types/Command")

type TypeDefinition = Types.TypeDefinition

local Inputs: { EnumItem } = {} -- Every UserInputType, then every KeyCode, which userInput finds

for _, input: Enum.UserInputType in Enum.UserInputType:GetEnumItems() do
	table.insert(Inputs, input)
end

for _, key: Enum.KeyCode in Enum.KeyCode:GetEnumItems() do
	table.insert(Inputs, key)
end

--[[
    The registry, required at the first lookup: the registry loads this
    file while it loads, so a require at the top would find it unfinished
--]]

local function registry()
	return require("../Registry")
end

--[[
    Makes a type that finds names, or items by their names, among what the
    list gives for the executor at each transform, as makeFuzzyFinder ranks
    them, and refuses text that finds none with the refusal
--]]

local function nameList(list: (executor: Player) -> { any }, refusal: string?): TypeDefinition
	return {
		transform = function (text: string, executor: Player): { any }
			return Util.makeFuzzyFinder(list(executor))(text)
		end,

		validate = function (found: { any }): (boolean, string?)
			return #found > 0, refusal
		end,

		autocomplete = Util.getNames,

		parse = function (found: { any }): any
			return found[1]
		end,
	}
end

local Definitions: { [string]: TypeDefinition } = {
	command = nameList(function (executor: Player): { string }
		return registry():getCommandNames(nil, executor)
	end, NO_COMMAND),

	type = nameList(function (): { string }
		return registry():getTypeNames()
	end, NO_TYPE),

	userInput = nameList(function (): { EnumItem }
		return Inputs
	end, nil),
}

Definitions.commands = Util.makeListableType(Definitions.command)
Definitions.types = Util.makeListableType(Definitions.type)
Definitions.userInputs = Util.makeListableType(Definitions.userInput)

return Definitions
