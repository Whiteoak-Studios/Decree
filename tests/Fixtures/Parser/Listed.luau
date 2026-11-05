--[[
    Whether a list holds exactly the expected values, in the same order and
    no more
--]]

--!strict

return function (actual: { any }, expected: { any }): boolean
	if #actual ~= #expected then
		return false
	end

	for index: number, value: any in expected do
		if actual[index] ~= value then
			return false
		end
	end

	return true
end
