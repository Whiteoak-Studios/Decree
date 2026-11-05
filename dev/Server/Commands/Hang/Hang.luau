--[[
    The hang command's definition, a server half whose Promise never
    settles, so Decree answers it with an Error line
--]]

--!strict
return {
	name = "hang",
	description = "Never answers, so Decree replies with an error once it gives up.",
	group = "Admin",
	system = "Timing",
	tags = { "Admin only" },
	args = {},
}
