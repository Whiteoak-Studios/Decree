--[[
    The text helpers both realms split typed lines with, and the builders a
    game's own argument types are made from: enums, lists and sequences
--]]

--!strict
local WHITESPACE: string = "%s" -- The character set a simple split breaks at when it is given none
local WORD: string = "[^ ]+" -- A typed line splits at spaces only
local START_QUOTE: string = `^(['"])`
local END_QUOTE: string = `(['"])$`
local BACKSLASHES_BEFORE_END_QUOTE: string = `(\\*)['"]$`
local NONE: string = ""

-- What an escaped backslash, quote or line break stands as while a line splits, so it neither splits nor groups
local BACKSLASH_HOLDER: string = "___!DECREE_ESCAPE!___"
local DOUBLE_QUOTE_HOLDER: string = "___!DECREE_QUOTE!___"
local SINGLE_QUOTE_HOLDER: string = "___!DECREE_SQUOTE!___"
local LINE_BREAK_HOLDER: string = "___!DECREE_NL!___"
local ESCAPED_BACKSLASH: string = "\\\\"
local ESCAPED_DOUBLE_QUOTE: string = `\\"`
local ESCAPED_SINGLE_QUOTE: string = "\\'"
local ESCAPED_LINE_BREAK: string = "\\\n"
local BACKSLASH: string = "\\"
local DOUBLE_QUOTE: string = `"`
local SINGLE_QUOTE: string = "'"
local LINE_BREAK: string = "\n"

local ESCAPE: string = "\\(.)"
local ESCAPES: { [string]: string } = { t = "\t", n = "\n" } -- The letters an escape turns into a tab and a line break
local UNICODE_ESCAPE: string = "\\u(%x%x%x%x)"
local HEX_ESCAPE: string = "\\x(%x%x)"
local HEX: number = 16

local LEADING_WHITESPACE: string = "^%s*"
local UP_TO_LAST_NON_WHITESPACE: string = ".*%S"

local EXACT: number = 0 -- A finder's rank for a name the text matches whole
local AT_START: number = 1 -- Its rank for a name the text starts, when only starts count
local PLAIN: boolean = true -- Finds the text as written, with no pattern characters
local RETURN_FIRST: boolean = true -- Asks a finder for its best match alone
local QUOTED: string = "%q"
local SEQUENCE_DELIMITERS: { string } = { ",", WHITESPACE } -- A sequence splits at commas, or else at whitespace

local Types = require("./Config/Types/Command")

type TypeDefinition = Types.TypeDefinition

type SequenceOptions = {
	transform: ((text: string, executor: Player) -> any)?,
	parse: ((elements: { any }) -> any)?,
	constructor: ((...any) -> any)?,
	transformEach: ((element: string) -> any)?,
	validateEach: ((element: any, index: number) -> (boolean, string?))?,
	prefixes: string?,
	length: number?,
}

--- @class Util
--- Plain functions, called with a dot, that the registry, the dispatcher,
--- the console and a game's own types share

local Util = {}

--- Turns each value of a list into a key set to true.
--- @function makeDictionary
--- @within Util
--- @param list { T }
--- @return { [T]: true }

function Util.makeDictionary<T>(list: { T }): { [T]: true }
	local dictionary: { [T]: true } = {}

	for _, value: T in list do
		dictionary[value] = true
	end

	return dictionary
end

--- Makes a finder over a list of strings, a list of Instances, EnumItems
--- or tables with a Name, an Enum's items or an Instance's children. The
--- finder matches names ignoring case and ranks an exact match first, then
--- by where the text starts in the name, then the shorter name.
--- @function makeFuzzyFinder
--- @within Util
--- @param set any -- A list, an Enum or an Instance
--- @return (text: string, returnFirst: boolean?, matchStart: boolean?) -> any -- Every match, or the best one alone

function Util.makeFuzzyFinder(set: any): (text: string, returnFirst: boolean?, matchStart: boolean?) -> any
	local kind: string = typeof(set)
	assert(
		kind == "table" or kind == "Enum" or kind == "Instance",
		"[Decree] makeFuzzyFinder only accepts a table, Enum, or Instance."
	)

	local values: { any } = kind == "Enum" and set:GetEnumItems() or kind == "Instance" and set:GetChildren() or set
	local names: { string } = {}

	-- The first value decides how every name is read
	if #values > 0 then
		local first: any = values[1]
		local firstKind: string = typeof(first)
		local named: boolean = firstKind == "Instance"
			or firstKind == "EnumItem"
			or firstKind == "table" and typeof(first.Name) == "string"

		assert(firstKind == "string" or named, "[Decree] makeFuzzyFinder only accepts tables of instances or strings.")
		names = firstKind == "string" and values or Util.getNames(values)
	end

	return function (text: string, returnFirst: boolean?, matchStart: boolean?): any
		local lowered: string = text:lower()
		local matched: { number } = {}
		local ranks: { [number]: number } = {}

		for index: number, name: string in names do
			local lowerName: string = name:lower()
			local rank: number? = nil

			if lowerName == lowered then
				if returnFirst then
					return values[index]
				end

				rank = EXACT
			elseif matchStart then
				rank = lowerName:sub(1, #text) == lowered and AT_START or nil
			else
				rank = lowerName:find(lowered, 1, PLAIN)
			end

			if rank then
				table.insert(matched, index)
				ranks[index] = rank
			end
		end

		table.sort(matched, function (a: number, b: number): boolean
			if ranks[a] ~= ranks[b] then
				return ranks[a] < ranks[b]
			end

			return #names[a] < #names[b]
		end)

		if returnFirst then
			local best: number? = matched[1]
			return best and values[best]
		end

		return Util.map(matched, function (index: number): any
			return values[index]
		end)
	end
end

--- Gives each value's Name, or the value through tostring when it has
--- none, in order.
--- @function getNames
--- @within Util
--- @param values { any }
--- @return { string }

function Util.getNames(values: { any }): { string }
	local names: { string } = {}

	for index: number, value: any in values do
		names[index] = value.Name or tostring(value)
	end

	return names
end

--- Splits a text at any one character of the separator, whitespace by
--- default, with no quotes read and no empty pieces kept.
--- @function splitStringSimple
--- @within Util
--- @param text string
--- @param separator string? -- A set of characters, as a pattern's [] holds them
--- @return { string }

function Util.splitStringSimple(text: string, separator: string?): { string }
	local pieces: { string } = {}

	for piece: string in text:gmatch(`([^{separator or WHITESPACE}]+)`) do
		table.insert(pieces, piece)
	end

	return pieces
end

--[[
    Turns the hexadecimal digits of an escape into their character
--]]

local function hexToChar(digits: string): string
	return utf8.char(tonumber(digits, HEX) :: number)
end

--- Turns the escapes \t, \n, \xHH and \uHHHH into their characters, and
--- leaves any other backslash as written.
--- @function parseEscapeSequences
--- @within Util
--- @param text string
--- @return string

function Util.parseEscapeSequences(text: string): string
	return (text:gsub(ESCAPE, ESCAPES):gsub(UNICODE_ESCAPE, hexToChar):gsub(HEX_ESCAPE, hexToChar))
end

--[[
    Swaps each escaped backslash, quote and line break for its holder, so
    splitString neither splits at nor groups by it
--]]

local function encodeControlCharacters(text: string): string
	return (
		text:gsub(ESCAPED_BACKSLASH, BACKSLASH_HOLDER)
			:gsub(ESCAPED_DOUBLE_QUOTE, DOUBLE_QUOTE_HOLDER)
			:gsub(ESCAPED_SINGLE_QUOTE, SINGLE_QUOTE_HOLDER)
			:gsub(ESCAPED_LINE_BREAK, LINE_BREAK_HOLDER)
	)
end

--[[
    Puts each holder back as the character it stands for
--]]

local function decodeControlCharacters(text: string): string
	return (
		text:gsub(BACKSLASH_HOLDER, BACKSLASH)
			:gsub(DOUBLE_QUOTE_HOLDER, DOUBLE_QUOTE)
			:gsub(SINGLE_QUOTE_HOLDER, SINGLE_QUOTE)
			:gsub(LINE_BREAK_HOLDER, LINE_BREAK)
	)
end

--[[
    Strips one quote from each end of a finished piece and puts its
    escaped characters back
--]]

local function finish(piece: string): string
	return decodeControlCharacters((piece:gsub(START_QUOTE, NONE):gsub(END_QUOTE, NONE)))
end

--- Splits a typed line at its spaces, keeping a run of words in matching
--- quotes as one piece and reading each word's escapes. With a max it keeps
--- at most that many pieces, adding every later word to the last in order.
--- @function splitString
--- @within Util
--- @param text string
--- @param max number? -- The most pieces to keep, 1 or more
--- @return { string }

function Util.splitString(text: string, max: number?): { string }
	local limit: number = max or math.huge
	assert(limit >= 1, `[Decree] splitString's max must be 1 or more, not {limit}`)

	local pieces: { string } = {}
	local buffer: string? = nil
	local quote: string? = nil

	local function add(piece: string)
		if #pieces >= limit then
			pieces[limit] ..= ` {piece}`
		else
			table.insert(pieces, piece)
		end
	end

	-- Whiteoak FIXME: A listable value typed with a space in it, such as me, others, splits into two pieces here
	for word: string in encodeControlCharacters(text):gmatch(WORD) do
		local segment: string = Util.parseEscapeSequences(word)
		local opening: string? = segment:match(START_QUOTE)
		local closing: string? = segment:match(END_QUOTE)
		local backslashes: string? = segment:match(BACKSLASHES_BEFORE_END_QUOTE)

		-- A closing quote counts only when no odd run of backslashes escapes it
		if opening and not quote and not closing then
			buffer = segment
			quote = opening
		elseif buffer and closing == quote and #(backslashes :: string) % 2 == 0 then
			add(finish(`{buffer} {segment}`))
			buffer = nil
			quote = nil
		elseif buffer then
			buffer ..= ` {segment}`
		else
			add(finish(segment))
		end
	end

	-- A quote left open keeps its words, its quote included
	if buffer then
		add(decodeControlCharacters(buffer))
	end

	return pieces
end

--- Joins every argument past the max onto the argument at the max, each
--- after a space, into a new list.
--- @function mashExcessArguments
--- @within Util
--- @param arguments { string }
--- @param max number
--- @return { string }

function Util.mashExcessArguments(arguments: { string }, max: number): { string }
	local mashed: { string } = {}

	for index: number, argument: string in arguments do
		if index > max then
			mashed[max] = `{mashed[max] or NONE} {argument}`
		else
			mashed[index] = argument
		end
	end

	return mashed
end

--- Strips whitespace of every kind from both ends of a text.
--- @function trimString
--- @within Util
--- @param text string
--- @return string

function Util.trimString(text: string): string
	local _, leading: number? = text:find(LEADING_WHITESPACE)
	local skipped: number = leading :: number -- The pattern always matches, if only nothing

	return skipped == #text and NONE or text:match(UP_TO_LAST_NON_WHITESPACE, skipped + 1) :: string
end

--- Makes a type whose values are a set's, found by name as makeFuzzyFinder
--- finds them, and refuses any other text with the type's name.
--- @function makeEnumType
--- @within Util
--- @param name string -- The name the refusal gives the type
--- @param values any -- A set makeFuzzyFinder takes
--- @return TypeDefinition

function Util.makeEnumType(name: string, values: any): TypeDefinition
	local find: (text: string, returnFirst: boolean?, matchStart: boolean?) -> any = Util.makeFuzzyFinder(values)

	return {
		validate = function (text: string): (boolean, string?)
			return find(text, RETURN_FIRST) ~= nil, `Value {QUOTED:format(text)} is not a valid {name}.`
		end,

		autocomplete = function (text: string): { string }
			local list: { any } = find(text)

			return type(list[1]) ~= "string" and Util.getNames(list) or list
		end,

		parse = function (text: string): any
			return find(text, RETURN_FIRST)
		end,
	}
end

--- Makes the listable type of a single type: a copy of its transform,
--- checks, completion, default and operator words, whose parse gives a
--- list of what the single type's parse gives. The override's keys are
--- set over the copy.
--- @function makeListableType
--- @within Util
--- @param definition TypeDefinition
--- @param override { [string]: any }?
--- @return TypeDefinition

function Util.makeListableType(definition: TypeDefinition, override: { [string]: any }?): TypeDefinition
	local listable: { [string]: any } = {
		listable = true,
		transform = definition.transform,
		validate = definition.validate,
		validateOnce = definition.validateOnce,
		autocomplete = definition.autocomplete,
		default = definition.default,
		argumentOperatorAliases = definition.argumentOperatorAliases,

		parse = function (...: any): { any }
			return { definition.parse(...) }
		end,
	}

	for key: string, value: any in override or {} do
		listable[key] = value
	end

	return listable
end

--- Makes a type for a sequence such as a Vector3 or a Color3: its text
--- splits at commas, or else at whitespace, each element is transformed
--- and checked, and the value is built through parse or else constructor.
--- @function makeSequenceType
--- @within Util
--- @param options SequenceOptions -- transform, parse, constructor, transformEach, validateEach, prefixes and length
--- @return TypeDefinition

function Util.makeSequenceType(options: SequenceOptions): TypeDefinition
	assert(
		options.parse ~= nil or options.constructor ~= nil,
		"[Decree] makeSequenceType: Must provide one of: constructor, parse"
	)

	local transformEach: (element: string) -> any = options.transformEach
		or function (element: string): any
			return element
		end

	local validateEach: (element: any, index: number) -> (boolean, string?) = options.validateEach
		or function (): (boolean, string?)
			return true, nil
		end

	return {
		prefixes = options.prefixes,

		transform = options.transform or function (text: string): { any }
			local elements: { string } = Util.splitPrioritizedDelimiter(text, SEQUENCE_DELIMITERS) or {}

			return Util.map(elements, function (element: string): any
				return transformEach(element)
			end)
		end,

		validate = function (elements: { any }): (boolean, string?)
			if options.length and #elements > options.length then
				return false, `Maximum of {options.length} values allowed in sequence`
			end

			for index = 1, options.length or #elements do
				local valid: boolean, reason: string? = validateEach(elements[index], index)
				if not valid then
					return false, reason
				end
			end

			return true, nil
		end,

		parse = options.parse or function (elements: { any }): any
			return (options.constructor :: (...any) -> any)(table.unpack(elements))
		end,
	}
end

--- Splits a text at the first delimiter whose characters it holds, or at
--- the last delimiter when it holds none, as splitStringSimple splits.
--- @function splitPrioritizedDelimiter
--- @within Util
--- @param text string
--- @param delimiters { string } -- Character sets, in the order they are tried
--- @return { string }? -- Nil when there are no delimiters

function Util.splitPrioritizedDelimiter(text: string, delimiters: { string }): { string }?
	for index: number, delimiter: string in delimiters do
		-- Looked for as the same character set splitStringSimple splits at
		if text:find(`[{delimiter}]`) or index == #delimiters then
			return Util.splitStringSimple(text, delimiter)
		end
	end

	return nil
end

--- Calls back with each value of a list and its index, in order, into a
--- new list, stopping at the first hole.
--- @function map
--- @within Util
--- @param list { T }
--- @param callback (value: T, index: number) -> U
--- @return { U }

function Util.map<T, U>(list: { T }, callback: (value: T, index: number) -> U): { U }
	local mapped: { U } = {}

	for index = 1, #list do
		local value: T? = list[index]
		if value == nil then
			break
		end

		mapped[index] = callback(value, index)
	end

	return mapped
end

return Util
