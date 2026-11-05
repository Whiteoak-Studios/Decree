--[[
    registerCommandObject refuses confirm and clear, the names Decree's own
    commands keep, as a command's name or an alias in any case, and stores
    nothing and hands nothing to the access check
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

-- Each definition taking a reserved word, and the refusal it gets
local REFUSED: { Refused } = {
	{
		definition = { name = "confirm", args = {} },
		refusal = `[Decree] Command "confirm" takes the name confirm, which Decree's own confirm command keeps`,
	},
	{
		definition = { name = "Clear", args = {} },
		refusal = `[Decree] Command "Clear" takes the name clear, which Decree's own clear command keeps`,
	},
	{
		definition = { name = "check", aliases = { "yes", "CONFIRM" }, args = {} },
		refusal = `[Decree] Command "check" takes the name confirm, which Decree's own confirm command keeps`,
	},
	{
		definition = { name = "wipe", aliases = { "clear" }, args = {} },
		refusal = `[Decree] Command "wipe" takes the name clear, which Decree's own clear command keeps`,
	},
}

-- Every word the refused definitions hold, none of which finds a command afterward
local WORDS: { string } = { "confirm", "clear", "check", "yes", "wipe" }

type Refused = {
	definition: { [string]: any },
	refusal: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	for _, refused: Refused in REFUSED do
		local registered: boolean, problem: any = pcall(registry.registerCommandObject, registry, refused.definition)
		if registered or Thrown(problem) ~= refused.refusal then
			return false, `registering {refused.definition.name} gave {problem}`
		end
	end

	for _, word: string in WORDS do
		if registry:getCommand(word) ~= nil then
			return false, `{word} found a command after every registration was refused`
		end
	end

	if #registry:getCommands() ~= 0 or #core.access.definitions ~= 0 then
		return false, "a refused definition was stored or handed to the access check"
	end

	return true, nil
end
