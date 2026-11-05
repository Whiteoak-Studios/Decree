--[[
    A fresh two-argument command per call, both of them required strings: a
    first word and the rest of the line
--]]

--!strict
return function (): { [string]: any }
	return {
		name = "pair",
		args = {
			{ type = "string", name = "first" },
			{ type = "string", name = "rest" },
		},
	}
end
