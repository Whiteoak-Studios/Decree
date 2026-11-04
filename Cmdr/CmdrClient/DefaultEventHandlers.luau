const TextChatService = game:GetService("TextChatService")

const TextChannels = TextChatService:WaitForChild("TextChannels")
const RBXSystem: TextChannel = TextChannels:WaitForChild("RBXSystem")

return function(CmdrClient)
	CmdrClient:HandleEvent("Message", function(text: string)
		RBXSystem:DisplaySystemMessage(`<font color="rgb(249, 217, 56)">[Announcement] {text}</font>`)
	end)

	CmdrClient:HandleEvent("AddLine", function(...: any)
		CmdrClient._interface.Window:AddLine(...)
	end)

	CmdrClient:HandleEvent("RunBeforeCommandRegisterHooks", function()
		CmdrClient.Dispatcher:RunBeforeCommandRegisterHooks()
	end)
end
