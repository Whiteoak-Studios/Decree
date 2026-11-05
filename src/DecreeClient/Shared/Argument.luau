--[[
    The argument context: one argument of a typed line, read through the
    type its prefix picks from its raw text into segments, each segment's
    transformed values, and its value
--]]

--!strict
local Argument = {}
Argument.__index = Argument

local Registry = require("./Registry")
local Util = require("./Util")

local DEFAULT: string = "." -- Stands for the type's default, the executor's own value
local RANDOM: string = "?" -- One of the type's suggestions at random
local ALL: string = "*" -- Every suggestion, in a listable argument
local OTHERS: string = "**" -- Every suggestion but the default, in a listable argument
local RANDOM_COUNT: string = "^%?(%d+)$" -- ?N, N of the suggestions at random, in a listable argument
local ESCAPED_OPERATOR: string = "\\([%.%?%*])" -- A backslash before an operator's character keeps it as text
local CAPTURED: string = "%1"
local LIST_SEPARATOR: string = ","
local NONE: string = ""
local UNION_STEP: number = 2 -- A union alternates its types with the prefixes that pick them

local Types = require("./Config/Types/Command")

type ArgumentDefinition = Types.ArgumentDefinition
type Context = Types.Context
type Fields = Types.ArgumentFields
type Self = Types.ArgumentContext
type TypeDefinition = Types.TypeDefinition

type Choice = {
	prefix: string,
	type: string,
}

type Options = {
	isPartial: boolean?,
}

--- @class ArgumentContext
--- One argument of a typed line, read through its type

--[[
    Picks an argument's type from a union by the prefix its raw text starts
    with, giving the type's name, the text after the prefix and the prefix
--]]

local function parsePrefixedUnionType(union: string, rawValue: string): (string?, string, string)
	local split: { string } = Util.splitStringSimple(union)
	local choices: { Choice } = {}

	for index = 1, #split, UNION_STEP do
		table.insert(choices, { prefix = split[index - 1] or NONE, type = split[index] })
	end

	-- The longest prefix first, so a prefix that starts another never takes its place
	table.sort(choices, function (a: Choice, b: Choice): boolean
		return #a.prefix > #b.prefix
	end)

	for _, choice: Choice in choices do
		if rawValue:sub(1, #choice.prefix) == choice.prefix then
			return choice.type, rawValue:sub(#choice.prefix + 1), choice.prefix
		end
	end

	return nil, rawValue, NONE
end

--[[
    Frees every operator character a backslash keeps as text
--]]

local function unescapeOperators(text: string): string
	return (text:gsub(ESCAPED_OPERATOR, CAPTURED))
end

--- Makes the context of one argument from its definition and the raw text
--- typed for it, and transforms that text at once.
--- @function new
--- @within ArgumentContext
--- @param command Context
--- @param definition ArgumentDefinition
--- @param value string
--- @return ArgumentContext

function Argument.new(command: Context, definition: ArgumentDefinition, value: string): Self
	local typeName: string?, rawValue: string, prefix: string =
		parsePrefixedUnionType(Registry:getTypeName(definition.type), value)
	local typeDefinition: TypeDefinition? = Registry:getType(typeName :: string)
	assert(
		typeDefinition,
		`[Decree] Argument "{definition.name or "none"}" has an unregistered type {typeName or "<none>"}`
	)

	local fields: Fields = {
		command = command,
		type = typeDefinition,
		name = definition.name,
		displayName = typeDefinition.displayName or typeName :: string,
		object = definition,
		required = definition.default == nil and definition.optional ~= true,
		executor = command.executor,
		rawValue = rawValue,
		rawSegments = {},
		transformedValues = {},
		prefix = prefix,
		textSegmentInProgress = NONE,
		rawSegmentsAreAutocomplete = false,
	}

	local argument: Self = setmetatable(fields, Argument) :: any
	argument:transform()

	return argument
end

--- One raw segment through the type's transform, every value it gives, or
--- the segment as it is when the type has none.
--- @method transformSegment
--- @within ArgumentContext
--- @param rawSegment string
--- @return ...any

function Argument.transformSegment(self: Self, rawSegment: string): ...any
	local transform = self.type.transform
	if transform then
		return transform(rawSegment, self.executor)
	end

	return rawSegment
end

--- The type's suggestions for an empty segment, and their options, which
--- are empty for a type that suggests nothing.
--- @method getDefaultAutocomplete
--- @within ArgumentContext
--- @return ({ string }, { isPartial: boolean? })

function Argument.getDefaultAutocomplete(self: Self): ({ string }, Options)
	local autocomplete = self.type.autocomplete
	if not autocomplete then
		return {}, {}
	end

	local suggestions: { string }, options: Options? = autocomplete(self:transformSegment(NONE))

	return suggestions, options or {}
end

--[[
    Expands a listable argument's ?N, * or ** into the type's suggestions:
    N of them at random, every one, or every one but the executor's
    default. A type that suggests nothing, or part of a name, keeps the text
--]]

local function expandListOperators(argument: Self, rawValue: string): string
	local count: string? = rawValue:match(RANDOM_COUNT)
	if count then
		local size: number = tonumber(count) :: number -- The pattern holds only digits
		local offered: { string }, options: Options = argument:getDefaultAutocomplete()
		if size <= 0 or options.isPartial or #offered == 0 then
			return rawValue
		end

		local remaining: { string } = table.clone(offered) -- A copy, so a list the type keeps stays whole
		local picked: { string } = {}

		for _ = 1, math.min(size, #remaining) do
			table.insert(picked, table.remove(remaining, math.random(1, #remaining)) :: string)
		end

		argument.rawSegmentsAreAutocomplete = true

		return table.concat(picked, LIST_SEPARATOR)
	end

	if rawValue ~= ALL and rawValue ~= OTHERS then
		return rawValue
	end

	local suggestions: { string }, options: Options = argument:getDefaultAutocomplete()
	if options.isPartial or #suggestions == 0 then
		return rawValue
	end

	local default = argument.type.default
	if rawValue == OTHERS and default then
		local own: string = default(argument.executor) or NONE
		local others: { string } = {}

		for _, suggestion: string in suggestions do
			if suggestion ~= own then
				table.insert(others, suggestion)
			end
		end

		suggestions = others
	end

	argument.rawSegmentsAreAutocomplete = true

	return table.concat(suggestions, LIST_SEPARATOR)
end

--- Reads the raw text into segments and transforms each, once: the type's
--- operator words first, then . for its default and ? for a random
--- suggestion, then in a listable argument ?N, * and **, and the commas.
--- @method transform
--- @within ArgumentContext

function Argument.transform(self: Self)
	if #self.transformedValues ~= 0 then
		return
	end

	local definition: TypeDefinition = self.type
	local rawValue: string = self.rawValue
	local aliases: { [string]: string }? = definition.argumentOperatorAliases

	if aliases then
		rawValue = aliases[rawValue] or rawValue
	end

	if rawValue == DEFAULT and definition.default then
		rawValue = definition.default(self.executor) or NONE
		self.rawSegmentsAreAutocomplete = true
	end

	if rawValue == RANDOM and definition.autocomplete then
		local suggestions: { string }, options: Options = self:getDefaultAutocomplete()

		if not options.isPartial and #suggestions > 0 then
			rawValue = suggestions[math.random(1, #suggestions)]
			self.rawSegmentsAreAutocomplete = true
		end
	end

	if not definition.listable or #self.rawValue == 0 then
		local unescaped: string = unescapeOperators(rawValue)

		self.rawSegments[1] = unescaped
		self.transformedValues[1] = table.pack(self:transformSegment(unescaped))
		self.textSegmentInProgress = self.rawValue

		return
	end

	local listed: string = unescapeOperators(expandListOperators(self, rawValue))
	local rawSegments: { string } = Util.splitStringSimple(listed, LIST_SEPARATOR)

	if #rawSegments == 0 then
		rawSegments = { NONE }
	end

	-- A trailing comma starts the next segment, so completion moves on to it
	if listed:sub(-1) == LIST_SEPARATOR then
		table.insert(rawSegments, NONE)
	end

	for index: number, rawSegment: string in rawSegments do
		self.rawSegments[index] = rawSegment
		self.transformedValues[index] = table.pack(self:transformSegment(rawSegment))
	end

	self.textSegmentInProgress = rawSegments[#rawSegments]
end

--- Every value one segment's transform gave.
--- @method getTransformedValue
--- @within ArgumentContext
--- @param segment number
--- @return ...any

function Argument.getTransformedValue(self: Self, segment: number): ...any
	local values: { n: number, [number]: any } = self.transformedValues[segment]

	return table.unpack(values, 1, values.n)
end

--- Checks every segment through the type's validate, and when final its
--- validateOnce too, giving the first refusal. An optional argument left
--- empty is valid, and a required one is refused.
--- @method validate
--- @within ArgumentContext
--- @param isFinal boolean? -- True once the line is sent, when validateOnce runs
--- @return (boolean, string?)

function Argument.validate(self: Self, isFinal: boolean?): (boolean, string | nil)
	if not self.rawValue or #self.rawValue == 0 and self.required == false then
		return true, nil
	end

	if self.required and (not self.rawSegments[1] or #self.rawSegments[1] == 0) then
		return false, "This argument is required."
	end

	local validate = self.type.validate
	local validateOnce = self.type.validateOnce

	for index = 1, #self.transformedValues do
		if validate then
			local valid: boolean, reason: string? = validate(self:getTransformedValue(index))
			if not valid then
				return false, reason or "Invalid value"
			end
		end

		if isFinal and validateOnce then
			local validOnce: boolean, reasonOnce: string? = validateOnce(self:getTransformedValue(index))
			if not validOnce then
				return false, reasonOnce
			end
		end
	end

	return true, nil
end

--- The type's suggestions for the segment in progress, and their options.
--- @method getAutocomplete
--- @within ArgumentContext
--- @return ({ string }, { isPartial: boolean? }?)

function Argument.getAutocomplete(self: Self): ({ string }, Options?)
	local autocomplete = self.type.autocomplete
	if not autocomplete then
		return {}, nil
	end

	return autocomplete(self:getTransformedValue(#self.transformedValues))
end

--[[
    One segment's value through the type's parse, or its transformed value
    when the type has none
--]]

local function parseValue(argument: Self, segment: number): any
	local parse = argument.type.parse
	if parse then
		return parse(argument:getTransformedValue(segment))
	end

	return (argument:getTransformedValue(segment))
end

--- The argument's value: the definition's default for an optional
--- argument left empty, the parsed value, or for a listable type every
--- distinct value its segments parse to.
--- @method getValue
--- @within ArgumentContext
--- @return any

function Argument.getValue(self: Self): any
	if #self.rawValue == 0 and not self.required and self.object.default ~= nil then
		return self.object.default
	end

	if not self.type.listable then
		return parseValue(self, 1)
	end

	local distinct: { [any]: true } = {}

	for index = 1, #self.transformedValues do
		local parsed: any = parseValue(self, index)
		assert(type(parsed) == "table", `[Decree] Listable types must return a table from parse {self.displayName}`)

		for _, value: any in parsed do
			distinct[value] = true
		end
	end

	local values: { any } = {}

	for value: any in distinct do
		table.insert(values, value)
	end

	return values
end

local _: Types.ArgumentMethods = Argument

return Argument
