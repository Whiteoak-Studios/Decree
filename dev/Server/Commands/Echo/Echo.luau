--[[
    The echo command's definition, a reply check open to every player, whose
    server half replies with the text it is given
--]]

--!strict
return {
	name = "echo",
	description = "Replies with the text you give it.",
	group = "Player",
	args = {
		{ name = "text", type = "string", description = "What to reply with" },
	},
}
