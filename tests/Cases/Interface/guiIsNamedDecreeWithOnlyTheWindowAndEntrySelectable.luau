--[[
    The GUI built from the default style is a ScreenGui named Decree that
    outlives a respawn and shows over the game's own, and only the window
    and the entry's TextBox take gamepad selection
--]]

--!strict
local Environment = require("../../Environment")

local CREATE_GUI: string = "src/DecreeClient/Window/Functions/CreateGui"
local RESOLVE_STYLE: string = "src/DecreeClient/Window/Functions/ResolveStyle"
local WINDOW_CONFIG: string = "src/DecreeClient/Config/Window"
local GUI_CLASS: string = "ScreenGui"
local GUI_NAME: string = "Decree"
local DISPLAY_ORDER: number = 1000

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local style: any = env.require(RESOLVE_STYLE)(nil, env.require(WINDOW_CONFIG).style)
	local gui: any = env.require(CREATE_GUI)(style)

	if gui.ClassName ~= GUI_CLASS or gui.Name ~= GUI_NAME then
		return false, `the GUI is the {gui.ClassName} {gui.Name}, where the {GUI_CLASS} {GUI_NAME} was expected`
	end

	if gui.ResetOnSpawn then
		return false, "the GUI resets when the player respawns"
	end

	if gui.DisplayOrder ~= DISPLAY_ORDER then
		return false, `the GUI shows at display order {gui.DisplayOrder}, where {DISPLAY_ORDER} was expected`
	end

	local window: any = gui:FindFirstChild("Frame")
	local textBox: any = window:FindFirstChild("Entry"):FindFirstChild("TextBox")

	for _, descendant: any in gui:GetDescendants() do
		local selectable: boolean = descendant == window or descendant == textBox

		if descendant:IsA("GuiObject") and descendant.Selectable ~= selectable then
			return false,
				`{descendant:GetFullName()}'s Selectable is {descendant.Selectable}, where {selectable} was expected`
		end
	end

	return true, nil
end
