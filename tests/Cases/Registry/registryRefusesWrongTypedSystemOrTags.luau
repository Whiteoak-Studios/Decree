--[[
    registerCommandObject keeps a system given as text and tags given as a
    list of text, and refuses a system of another type, tags that are no
    list, or a tag that is not text, storing none of them
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local NAME: string = "audit"
local SYSTEM: string = "Moderation"
local TAGS: { string } = { "admin", "studio" }
local PLAIN: string = "plain" -- Holds neither key

-- Each definition with a wrong-typed system or tags, and the refusal it gets
local REFUSED: { Refused } = {
	{
		definition = { name = NAME, system = 5, args = {} },
		refusal = `[Decree] Command "audit"'s system is a number, not text`,
	},
	{
		definition = { name = NAME, tags = "admin", args = {} },
		refusal = `[Decree] Command "audit"'s tags are a string, not a list of text`,
	},
	{
		definition = { name = NAME, tags = { "admin", 3 }, args = {} },
		refusal = `[Decree] Command "audit" holds a tag that is a number, not text`,
	},
}

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
			return false, `a wrong-typed system or tags gave {problem}`
		end
	end

	if registry:getCommand(NAME) ~= nil or #core.access.definitions ~= 0 then
		return false, "a refused definition was stored or handed to the access check"
	end

	registry:registerCommandObject({ name = NAME, system = SYSTEM, tags = TAGS, args = {} })
	registry:registerCommandObject({ name = PLAIN, args = {} })

	local audit: any = registry:getCommand(NAME)
	if not audit or audit.system ~= SYSTEM or audit.tags ~= TAGS or registry:getCommand(PLAIN) == nil then
		return false, "a text system and a list of text tags, or neither, did not register as given"
	end

	return true, nil
end
