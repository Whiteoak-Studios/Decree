--[[
    A game's own type module in a folder inside the type folder, holding one
    type by name
--]]

--!strict
return {
	vegetable = {
		parse = function (text: string): string
			return text
		end,
	},
}
