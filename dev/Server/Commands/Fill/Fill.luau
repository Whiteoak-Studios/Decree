--[[
    The fill command's definition, which fills the caller's command list
    with filler commands to the most bytes one list may carry
--]]

--!strict
return {
	name = "fill",
	description = "Fills your command list with filler commands, to the most bytes one list carries.",
	group = "Admin",
	system = "Transport",
	tags = { "Admin only" },
	args = {},
}
