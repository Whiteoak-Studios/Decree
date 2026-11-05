--[[
    The whisper command's definition, which prints a line in another
    player's console, filtered for them
--]]

--!strict
return {
	name = "whisper",
	description = "Prints your text in another player's console.",
	group = "Player",
	args = {
		{ name = "player", type = "player", description = "Whose console prints it" },
		{ name = "text", type = "string", description = "What to print" },
	},
}
