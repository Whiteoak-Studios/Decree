--[[
    A fresh command per call whose required argument follows an optional
    one, the order the registry refuses
--]]

--!strict
return function (): { [string]: any }
	return {
		name = "misordered",
		args = {
			{ type = "string", name = "first", optional = true },
			{ type = "string", name = "second" },
		},
	}
end
