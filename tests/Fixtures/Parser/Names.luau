--[[
    The names of a set of values, each a string or anything with a Name,
    sorted and joined with commas, so sets in any order compare alike
--]]

--!strict

local SEPARATOR: string = ","

return function (values: { any }): string
	local names: { string } = {}

	for _, value: any in values do
		table.insert(names, type(value) == "string" and value or value.Name)
	end

	table.sort(names)

	return table.concat(names, SEPARATOR)
end
