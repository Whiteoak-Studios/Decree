--[[
    The rank command's definition, which changes another player's rank in
    the dev place and so the commands their console holds
--]]

--!strict
return {
	name = "rank",
	aliases = { "setrank" },
	description = "Sets a player's dev rank, which changes the commands they hold.",
	group = "Admin",
	system = "Access",
	tags = { "Admin only" },
	args = {
		{ name = "player", type = "player", description = "Whose rank to set" },
		{ name = "rank", type = "integer", description = "Their new rank" },
	},
}
