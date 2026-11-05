--[[
    The names a command list holds, in its order, joined by single spaces
    into one text a case compares
--]]

--!strict
local SEPARATOR: string = " "

return function (list: { any }): string
	local names: { string } = {}

	for _, entry: any in list do
		table.insert(names, entry.name)
	end

	return table.concat(names, SEPARATOR)
end
