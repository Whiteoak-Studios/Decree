--[[
    A module the server clones into a player's PlayerGui reaches that
    player's own client environment, which requires the clone from its
    Source, as a command's device half reaches the console
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local FIXTURE: string = ".volt/src/Config"
local MODULE: string = `{FIXTURE}/Runtime` -- A module that requires nothing, standing in for a device half
local COMMANDS: string = "DecreeCommands" -- The ScreenGui a granted command's device half is cloned into
local SECOND: string = "Second"

return function (): (boolean, string | nil)
	local env: any = Environment.new({ folders = { FIXTURE } })
	local second: any, transport: any = env.mock:join(SECOND)
	local client: any = env.connect(transport, second)

	-- The server's side parents a clone into a ScreenGui in the player's PlayerGui
	local gui: any = roblox.Instance.new("ScreenGui")
	gui.Name = COMMANDS
	gui.ResetOnSpawn = false
	gui.Parent = second.PlayerGui

	local clone: any = env.find(MODULE):Clone()
	clone.Parent = gui

	-- The client's side finds it through its own LocalPlayer
	local localPlayer: any = client.game:GetService("Players").LocalPlayer
	local found: any = localPlayer:WaitForChild("PlayerGui"):FindFirstChild(COMMANDS)
	if not found or found:FindFirstChild(clone.Name) ~= clone then
		return false, "the client's LocalPlayer does not hold what the server parented"
	end

	local loaded: any = client.require(clone)
	local original: any = env.require(MODULE)
	if type(loaded) ~= "table" or loaded == original then
		return false, "the clone did not load apart from the server's own module"
	end

	for key: string, value: any in original do
		if type(value) ~= "table" and loaded[key] ~= value then
			return false, `the clone's {key} is {loaded[key]}, where the original's is {value}`
		end
	end

	if pcall(client.require, gui) or pcall(client.require, roblox.Instance.new("ModuleScript")) then
		return false, "require loaded a ScreenGui or a ModuleScript with no Source"
	end

	return true, nil
end
