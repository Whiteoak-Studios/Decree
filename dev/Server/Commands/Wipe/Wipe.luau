--[[
    The wipe command's definition, the confirm check: wipe now asks for
    confirm before it runs, and wipe hold runs at once
--]]

--!strict
return {
	name = "wipe",
	description = "Checks confirm: wipe now waits for it, and wipe hold does not.",
	group = "Admin",
	system = "Data",
	tags = { "Admin only", "Asks to confirm" },
	subcommands = {
		{
			name = "now",
			description = "Runs for a shard once you send confirm",
			confirm = true,
			args = {
				{ name = "shard", type = "integer", description = "The shard it names" },
			},
		},
		{
			name = "hold",
			description = "Runs at once, with no confirm",
		},
	},
}
