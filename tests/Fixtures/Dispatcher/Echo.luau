--[[
    A fresh echo command per call, since a case may change the table it is
    given: one string argument, an alias, a group and a description, and a
    run that answers the text it is given
--]]

--!strict
return function (): { [string]: any }
	return {
		name = "echo",
		aliases = { "say" },
		description = "Answers the text it is given",
		group = "Tests",
		args = {
			{ type = "string", name = "text", description = "What is answered" },
		},

		run = function (_: any, text: string): string
			return text
		end,
	}
end
