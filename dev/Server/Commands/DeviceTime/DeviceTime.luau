--[[
    The devicetime command's definition, a command with only a device half,
    which runs on the caller's own device and sends nothing
--]]

--!strict
return {
	name = "devicetime",
	description = "Answers with your device's clock, from your device.",
	group = "Admin",
	system = "Device",
	tags = { "Admin only", "Runs on your device" },
	args = {},
}
