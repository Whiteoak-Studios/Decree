--[[
    Waits a frame at a time until a condition holds or a number of seconds
    has passed, and gives whether the condition held
--]]

--!strict
local task = require("@lune/task")

return function (condition: () -> boolean, seconds: number): boolean
	local deadline: number = os.clock() + seconds

	while not condition() and os.clock() < deadline do
		task.wait()
	end

	return condition()
end
