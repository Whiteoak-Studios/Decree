--[[
    The longline command's definition, a reply as long as one reply may be,
    which ends in a marker so the console shows the end arrived
--]]

--!strict
return {
	name = "longline",
	description = "Replies with the longest line a reply carries, ending in a marker.",
	group = "Admin",
	system = "Transport",
	tags = { "Admin only" },
	args = {},
}
