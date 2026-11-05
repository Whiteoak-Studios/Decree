--[[
    Copies the Volt runtime Wally installed under DevPackages/ into the
    gitignored .volt/src, which the dev place mounts and the suite loads
--]]

--!strict
local fs = require("@lune/fs")

local LINK_FILE: string = "DevPackages/Volt.lua"
local LINK: string = `_Index%["([^"]+)"%]%["([^"]+)"%]` -- The folder a Wally link file points its alias at
local FOLDER: string = ".volt"
local TARGET: string = `{FOLDER}/src`

assert(fs.isFile(LINK_FILE), `{LINK_FILE} is missing; run wally install`)

local link: string = fs.readFile(LINK_FILE)
local installed: string?, name: string? = link:match(LINK)
assert(installed and name, `{LINK_FILE} names no installed folder; run wally install`)

local source: string = `DevPackages/_Index/{installed}/{name}/src`

-- A copy over an older one would keep the files the newer version dropped
if fs.isDir(TARGET) then
	fs.removeDir(TARGET)
end

fs.writeDir(FOLDER)
fs.copy(source, TARGET)

print(`Copied {source} to {TARGET}`)
