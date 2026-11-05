--[[
    The message an error was thrown with, without the chunk and line Luau
    puts before an assert's or an error's message
--]]

--!strict
-- The chunk and line, as in [string "src/DecreeClient/Shared/Registry.luau"]:627:
local POSITION: string = `^%[string "[^"]*"%]:%d+: `

return function (thrown: any): string
	return (tostring(thrown):gsub(POSITION, ""))
end
