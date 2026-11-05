--[[
    The environment rewrites each const that starts a line to local, after
    any indentation, and leaves every other const and every line in place
--]]

--!strict
local luau = require("@lune/luau")

local Environment = require("../../Environment")

-- A const at the top, indented, before a function and before a pair, then one inside a string and one inside a name
local SOURCE: string = table.concat({
	"const first = 1",
	"local function second(): number",
	"\tconst inner = 2",
	"\treturn inner",
	"end",
	"const function third(): number",
	"\treturn 3",
	"end",
	`const fourth, fifth = 4, "a const stays"`,
	"local constant = 6",
	`return first + second() + third() + fourth + constant, fifth, debug.info(1, "l")`,
}, "\n")

local EXPECTED: string = table.concat({
	"local first = 1",
	"local function second(): number",
	"\tlocal inner = 2",
	"\treturn inner",
	"end",
	"local function third(): number",
	"\treturn 3",
	"end",
	`local fourth, fifth = 4, "a const stays"`,
	"local constant = 6",
	`return first + second() + third() + fourth + constant, fifth, debug.info(1, "l")`,
}, "\n")

local TOTAL: number = 16 -- What the rewritten chunk's sum comes to
local TEXT: string = "a const stays"
local LINE: number = 11 -- The return's line, which the rewrite must not move

return function (): (boolean, string | nil)
	local rewritten: string = Environment.rewrite(SOURCE)
	if rewritten ~= EXPECTED then
		return false, `the rewrite gave:\n{rewritten}`
	end

	local total: number, text: string, line: number = luau.load(rewritten, { debugName = "rewritten" })()
	if total ~= TOTAL or text ~= TEXT or line ~= LINE then
		return false, `the rewritten chunk returned {total} and {text} on line {line}`
	end

	return true, nil
end
