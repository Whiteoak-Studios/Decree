--[[
    Formats every .luau file under Decree's own roots with StyLua, then
    restores the space after an anonymous function's keyword, which StyLua
    removes and the house style keeps. Cmdr/ and a missing root are skipped
--]]

--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS: { string } = { "src", "tests", "dev", ".lune" }
local IGNORE_FILE: string = ".styluaignore" -- The generated modules, which the editor's StyLua skips too

local Skipped: { [string]: boolean } = {}
local Files: { string } = {}

-- Whiteoak TODO: each .styluaignore line is read as an exact path; match its globs here once it holds one
for line: string in fs.readFile(IGNORE_FILE):gmatch("[^\r\n]+") do
	Skipped[line] = true
end

--[[
    Collects every .luau file under a directory, skipping the generated
    modules
--]]

local function collect(directory: string)
	for _, name: string in fs.readDir(directory) do
		local path: string = `{directory}/{name}`

		if Skipped[path] then
			continue
		end

		if fs.isDir(path) then
			collect(path)
		elseif name:match("%.luau$") then
			table.insert(Files, path)
		end
	end
end

for _, root: string in ROOTS do
	if fs.isDir(root) then
		collect(root)
	end
end

-- Whiteoak TODO: one command line carries every path and caps out near a thousand files on Windows; batch it then
local result: process.ExecResult = process.exec("stylua", Files, { stdio = "forward" })

if not result.ok then
	process.exit(result.code)
end

-- Only an anonymous function puts a parenthesis straight after the keyword, so the restore is safe
for _, path: string in Files do
	local source: string = fs.readFile(path)
	local restored: string = source:gsub("%f[%w_]function%(", "function (")

	if restored ~= source then
		fs.writeFile(path, restored)
	end
end
