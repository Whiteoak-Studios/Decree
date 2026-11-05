--[[
    The spelling gate: fails on any name in src/, tests/ and dev/ that takes
    a British spelling, in an identifier or a file or folder name. Its word
    list follows Standards/Spelling/Spelling.md
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS: { string } = { "src", "tests", "dev" }
local LUAU_FILE: string = "%.luau$"
local NAME: string = "^[%a_][%w_]*"
local NUMBER: string = "^%.?%d[%w_.]*" -- Taken whole, so a hex digit or an exponent never reads as a name
local LONG_BRACKET: string = "^%[(=*)%[" -- Opens a long string, or a block comment after --
local TEMPLATE_STOPS: string = "[\\`{]" -- What ends a run of an interpolated string's text
local ISE_STEM: string = "^(.+)ise$"
local LL_STEM: string = "^(.+)led$"
local FAILED: number = 1 -- The exit code a British spelling ends the run with

-- The modules Volt's compiler writes, which keep the names it gives them
local GENERATED: { [string]: boolean } = {
	["src/Network.luau"] = true,
	["src/DecreeClient/Network.luau"] = true,
	["src/DecreeClient/Shared/Wire.luau"] = true,
}

-- Folders of installed or copied code, whose names belong to their own projects
local FOREIGN: { [string]: boolean } = {
	Packages = true,
	DevPackages = true,
	[".volt"] = true,
}

-- The word list's rows, each British spelling with the endings its words take
local WORDS: { { string } } = {
	{ "armour", "armours", "armoured", "armouring", "armoury" },
	{ "centre", "centres", "centred", "centring" },
	{ "colour", "colours", "coloured", "colouring", "colourful", "colourless" },
	{ "behaviour", "behaviours", "behavioural" },
	{ "favour", "favours", "favoured", "favouring", "favourite", "favourites", "favourable" },
	{ "neighbour", "neighbours", "neighbouring", "neighbourhood" },
	{ "grey", "greys", "greyed", "greying" },
	{ "defence", "defences" },
	{ "licence", "licences" },
	{ "metre", "metres", "litre", "litres", "calibre", "calibres" },
	{ "catalogue", "catalogues", "catalogued", "cataloguing" },
	{ "analyse", "analysed", "analysing", "analyser" }, -- Never analyses, the plural of analysis in both
	{ "cancellable" },
	{ "judgement", "judgements" },
	{ "maths" },
	{ "learnt" },
	{ "storey", "storeys" },
}

-- The word list's -ise verbs, each taking every ending in ISE_ENDINGS in place of its ise
local ISE_VERBS: { string } = {
	"authorise",
	"initialise",
	"normalise",
	"serialise",
	"synchronise",
	"recognise",
	"organise",
	"optimise",
	"quantise",
	"randomise",
	"prioritise",
	"summarise",
	"visualise",
	"customise",
	"finalise",
	"stabilise",
	"utilise",
	"generalise",
	"minimise",
	"maximise",
	"categorise",
}

local ISE_ENDINGS: { string } = { "ise", "ised", "ises", "ising", "iser", "isers", "isable", "isation", "isations" }

-- The word list's doubled-l verbs, each taking every ending in LL_ENDINGS in place of its led
local LL_VERBS: { string } = { "modelled", "labelled", "travelled", "fuelled", "levelled", "signalled", "cancelled" }
local LL_ENDINGS: { string } = { "led", "ling", "ler", "lers" }

local British: { [string]: boolean } = {}
local Files: { string } = {}
local Hits: { string } = {}

for _, row: { string } in WORDS do
	for _, word: string in row do
		British[word] = true
	end
end

for _, verb: string in ISE_VERBS do
	local stem: string = verb:match(ISE_STEM) :: string

	for _, ending: string in ISE_ENDINGS do
		British[`{stem}{ending}`] = true
	end
end

for _, verb: string in LL_VERBS do
	local stem: string = verb:match(LL_STEM) :: string

	for _, ending: string in LL_ENDINGS do
		British[`{stem}{ending}`] = true
	end
end

--[[
    Splits a name into its lowercase words at each change of case and at
    every underscore, digit and dot, so camelCase, PascalCase,
    SCREAMING_SNAKE and file names all split alike
--]]

local function split(name: string): { string }
	-- A lowercase letter before a capital, then an acronym's last capital before a word, as in HTTPServer
	local camel: string = name:gsub("(%l)(%u)", "%1 %2")
	local spaced: string = camel:gsub("(%u)(%u%l)", "%1 %2")
	local words: { string } = {}

	for word: string in spaced:lower():gmatch("%a+") do
		table.insert(words, word)
	end

	return words
end

--[[
    Whether a word is a British spelling or ends in one, as deserialise
    ends in serialise
--]]

local function isBritish(word: string): boolean
	for start: number = 1, #word do
		if British[word:sub(start)] then
			return true
		end
	end

	return false
end

--[[
    Records each British word in a name, beside where the name was found
--]]

local function check(name: string, place: string)
	-- Whiteoak TODO: fails on a name another project owns, such as Promise.Status.Cancelled; keep a list of
	-- such names to pass once Decree's code uses one
	for _, word: string in split(name) do
		if isBritish(word) then
			table.insert(Hits, `{place}: {word}, in {name}`)
		end
	end
end

--[[
    Calls back with each identifier in a Luau source and its line, past
    every comment, number and string's text, and into the code inside an
    interpolated string's braces
--]]

local function scan(source: string, found: (name: string, line: number) -> ())
	local length: number = #source
	local position: number = 1
	local line: number = 1
	local braces: { number } = {} -- For each interpolation still open, the table braces opened inside it

	-- Moves to stop, counting the lines it passes
	local function skipTo(stop: number)
		local _: string, lines: number = source:sub(position, stop - 1):gsub("\n", "")
		line += lines
		position = stop
	end

	-- Where a string's text ends: its first stop character that no backslash escapes
	local function textEnd(stops: string, from: number): number?
		local stop: number? = source:find(stops, from)

		while stop and source:sub(stop, stop) == "\\" do
			stop = source:find(stops, stop + 2)
		end

		return stop
	end

	-- Moves past an interpolated string's text, out at its closing backtick or into its next braces
	local function skipTemplate()
		local stop: number? = textEnd(TEMPLATE_STOPS, position)

		if stop and source:sub(stop, stop) == "{" then
			table.insert(braces, 0)
		end

		skipTo((stop or length) + 1)
	end

	-- Moves past a long bracket's body and its closing bracket
	local function skipLong(level: string, from: number)
		local _: number?, last: number? = source:find(`]{level}]`, from, true)
		skipTo((last or length) + 1)
	end

	while position <= length do
		local character: string = source:sub(position, position)
		local level: string? = source:match(LONG_BRACKET, position)

		if character == "\n" then
			line += 1
			position += 1
		elseif source:sub(position, position + 1) == "--" then
			local commentLevel: string? = source:match(LONG_BRACKET, position + 2)
			local lineEnd: number? = source:find("\n", position, true)

			if commentLevel then
				skipLong(commentLevel, position + 2)
			else
				skipTo(lineEnd or length + 1)
			end
		elseif level then
			skipLong(level, position)
		elseif character == '"' or character == "'" then
			local stop: number? = textEnd(`[\\{character}]`, position + 1)
			skipTo((stop or length) + 1)
		elseif character == "`" then
			position += 1
			skipTemplate()
		elseif character == "{" and #braces > 0 then
			braces[#braces] += 1
			position += 1
		elseif character == "}" and #braces > 0 and braces[#braces] == 0 then
			table.remove(braces)
			position += 1
			skipTemplate()
		elseif character == "}" and #braces > 0 then
			braces[#braces] -= 1
			position += 1
		elseif character:match("[%a_]") then
			local name: string = source:match(NAME, position) :: string
			found(name, line)
			position += #name
		else
			local number: string = source:match(NUMBER, position) or character
			position += #number
		end
	end
end

--[[
    Checks the name of every file and folder under a directory and gathers
    its .luau files, past installed, copied and generated code
--]]

local function collect(directory: string)
	local entries: { string } = fs.readDir(directory)
	table.sort(entries)

	for _, entry: string in entries do
		local path: string = `{directory}/{entry}`
		local folder: boolean = fs.isDir(path)

		if GENERATED[path] or folder and FOREIGN[entry] then
			continue
		end

		check(entry, path)

		if folder then
			collect(path)
		elseif entry:match(LUAU_FILE) then
			table.insert(Files, path)
		end
	end
end

for _, root: string in ROOTS do
	if fs.isDir(root) then
		collect(root)
	end
end

for _, path: string in Files do
	scan(fs.readFile(path), function (name: string, line: number)
		check(name, `{path}:{line}`)
	end)
end

for _, hit: string in Hits do
	print(hit)
end

if #Hits > 0 then
	print(`British spellings: {#Hits}; Standards/Spelling/Spelling.md gives the American form of each`)
	process.exit(FAILED)
end

print(`No British spelling; .luau files checked: {#Files}`)
