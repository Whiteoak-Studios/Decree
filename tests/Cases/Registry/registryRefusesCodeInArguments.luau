--[[
    registerCommandObject refuses an argument written as code, or one whose
    type is an inline table, in a command's args or a subcommand's, naming
    its position, and stores none of them
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local NAMES: { string } = { "dynamic", "inline", "wipe" }

type Refused = {
	definition: { [string]: any },
	refusal: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local function argument(): { [string]: any }
		return { name = "target", type = "player" }
	end

	-- Each definition holding code in its arguments, and the refusal it gets
	local refusals: { Refused } = {
		{
			definition = { name = "dynamic", args = { argument(), argument } },
			refusal = `[Decree] Command "dynamic" argument #2 is a function, where an argument is a plain table`,
		},
		{
			definition = { name = "inline", args = { { name = "value", type = { parse = tostring } } } },
			refusal = `[Decree] Command "inline" argument #1 has an inline type, where it names a registered one`,
		},
		{
			definition = { name = "wipe", subcommands = { { name = "now", args = { argument } } } },
			refusal = `[Decree] Command "wipe now" argument #1 is a function, where an argument is a plain table`,
		},
	}

	for _, refused: Refused in refusals do
		local registered: boolean, problem: any = pcall(registry.registerCommandObject, registry, refused.definition)
		if registered or Thrown(problem) ~= refused.refusal then
			return false, `registering {refused.definition.name} gave {problem}`
		end
	end

	for _, name: string in NAMES do
		if registry:getCommand(name) ~= nil then
			return false, `{name} registered with code in its arguments`
		end
	end

	if #core.access.definitions ~= 0 then
		return false, "a refused definition was handed to the access check"
	end

	return true, nil
end
