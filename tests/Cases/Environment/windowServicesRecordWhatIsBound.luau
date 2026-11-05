--[[
    The window's input services keep what the console binds and connects,
    so a case reads each bound action and calls it, fires the input and
    menu signals in the engine's place, and reads the chat it hides
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local ACTION: string = "Activate"
local PRIORITY: number = 2001 -- Above the engine's default action priority, as the console binds its keys
local PRESSES: number = 1 -- How many times the case calls the bound action

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local key: any = roblox.Enum.KeyCode.F2
	local input: { [string]: any } = { KeyCode = key } -- Standing in for the InputObject the engine passes

	local contextActionService: any = env.game:GetService("ContextActionService")
	local pressed: number = 0

	contextActionService:BindActionAtPriority(ACTION, function (): any
		pressed += 1

		return nil
	end, false, PRIORITY, key)

	local action: any = contextActionService.actions[ACTION]
	if not action or action.priority ~= PRIORITY or action.inputs[1] ~= key or action.touchButton then
		return false, "the bound action was not kept as it was bound"
	end

	action.callback(ACTION, roblox.Enum.UserInputState.Begin, input)
	if pressed ~= PRESSES then
		return false, `the action ran {pressed} times`
	end

	contextActionService:UnbindAction(ACTION)
	if contextActionService.actions[ACTION] ~= nil then
		return false, "the action stayed bound after UnbindAction"
	end

	local inputBegan: any = env.game:GetService("UserInputService").InputBegan
	local heard: { any } = {}
	local connection: any = inputBegan:Connect(function (began: any)
		table.insert(heard, began)
	end)

	inputBegan:Fire(input, false)
	connection:Disconnect()
	inputBegan:Fire(input, false)

	if #heard ~= 1 or heard[1] ~= input then
		return false, `InputBegan reached its connection {#heard} times`
	end

	local menuOpened: any = env.game:GetService("GuiService").MenuOpened
	local opened: number = 0
	menuOpened:Connect(function ()
		opened += 1
	end)

	menuOpened:Fire()
	if opened ~= 1 then
		return false, `MenuOpened reached its connection {opened} times`
	end

	local chatWindow: any = env.game:GetService("TextChatService").ChatWindowConfiguration
	if not chatWindow.Enabled then
		return false, "the chat window starts hidden"
	end

	chatWindow.Enabled = false
	if env.game:GetService("TextChatService").ChatWindowConfiguration.Enabled then
		return false, "the chat window did not stay hidden"
	end

	return true, nil
end
