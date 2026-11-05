--[[
    The dev place's client: starts Decree's console in the dev game's style,
    opens it from a touch button and D-pad Left as well as F2, and shows the
    context line while the player holds the context rank
--]]

--!strict
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Player = Players.LocalPlayer
local Client = Player.PlayerScripts.Dev

local ConsoleConfig = require(Client.Config.Console)
local Style = require(Client.Config.Style)

local MAX_LINES: number = ConsoleConfig.maxLines
local PLACE_NAME: string = ConsoleConfig.placeName
local TOGGLE_KEY: Enum.KeyCode = ConsoleConfig.toggleKey
local CONTEXT_RANK: number = ConsoleConfig.contextRank
local RANK: string = ConsoleConfig.rankAttribute
local BOOT_SECONDS: number = ConsoleConfig.bootSeconds
local TOGGLE_ACTION: string = "DevToggleConsole"
local BUTTON_GUI: string = "DevConsoleButton"
local BUTTON_TEXT: string = "Console"

-- Typed where it is installed, since the client half reaches ReplicatedStorage only once the server moves it
type DecreeClient = typeof(require(ServerScriptService.ServerPackages.Decree.DecreeClient))

-- Boot-time waits: the server moves DecreeClient here as Decree loads, and the PlayerGui may not be there yet
local DecreeModule = ReplicatedStorage:WaitForChild("DecreeClient", BOOT_SECONDS) :: ModuleScript?
local PlayerGui = Player:WaitForChild("PlayerGui", BOOT_SECONDS) :: PlayerGui?

assert(DecreeModule, `[Dev] ReplicatedStorage.DecreeClient did not arrive within {BOOT_SECONDS} seconds`)
assert(PlayerGui, `[Dev] The PlayerGui did not arrive within {BOOT_SECONDS} seconds`)

local DecreeClient: DecreeClient = (require :: any)(DecreeModule)

--[[
    Shows the place, the server and whether it runs in Studio above the
    prompt while the player holds the context rank, and hides it otherwise
--]]

local function showContextLine()
	if Player:GetAttribute(RANK) ~= CONTEXT_RANK then
		DecreeClient:setContextLine(nil)

		return
	end

	local realm: string = RunService:IsStudio() and "Studio" or "live"

	DecreeClient:setContextLine(`Place {game.PlaceId} | Job {game.JobId} | {realm}`)
end

DecreeClient:setPlaceName(PLACE_NAME)
-- A client script can't name Decree's Style type, and start errors on an unknown key or a value of the wrong kind
DecreeClient:start({ style = Style :: any, maxLines = MAX_LINES })

local buttonGui: ScreenGui = Instance.new("ScreenGui")
buttonGui.Name = BUTTON_GUI
buttonGui.ResetOnSpawn = false
buttonGui.Parent = PlayerGui

-- Bottom center, clear of the console window and of the thumbstick and jump button on a phone
local button: TextButton = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -16)
button.Size = UDim2.fromOffset(112, 44)
button.Text = BUTTON_TEXT
button.Parent = buttonGui

DecreeClient:addToggleButton(button)

-- The button, the action and the rank listener all last the client session
button.Activated:Connect(function ()
	DecreeClient:toggle()
end)

local touchButton: boolean = false -- The dev game's own button above is the touch opener

ContextActionService:BindAction(TOGGLE_ACTION, function (_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		DecreeClient:toggle()
	end

	return Enum.ContextActionResult.Sink
end, touchButton, TOGGLE_KEY)

Player:GetAttributeChangedSignal(RANK):Connect(showContextLine)
showContextLine()
