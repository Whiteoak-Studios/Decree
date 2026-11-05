--[[
    A game's own type module holding two types by name, a type and its
    listable, as the built-in type modules hold theirs
--]]

--!strict
return {
	fruit = {
		parse = function (text: string): string
			return text
		end,
	},

	fruits = {
		listable = true,

		parse = function (text: string): { string }
			return { text }
		end,
	},
}
