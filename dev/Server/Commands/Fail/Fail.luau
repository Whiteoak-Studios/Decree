--[[
    The fail command's definition, a server half that raises, so Decree
    answers with an Error line and keeps working
--]]

--!strict
return {
	name = "fail",
	description = "Raises an error, so Decree replies with an error.",
	group = "Admin",
	system = "Errors",
	tags = { "Admin only" },
	args = {},
}
