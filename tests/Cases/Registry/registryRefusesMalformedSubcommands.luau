--[[
    registerCommandObject keeps plain subcommands, each with its own args
    and confirm, and refuses args or a confirm beside them, a malformed or
    misordered subcommand and a name held twice, storing none
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local NAME: string = "wipe"
local SHARD: { [string]: any } = { name = "shard", type = "integer" }
local OPTIONAL_SHARD: { [string]: any } = { name = "shard", type = "integer", default = 1 }
local REASON: { [string]: any } = { name = "reason", type = "string" }

type Refused = {
	definition: { [string]: any },
	refusal: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local function ask(): string?
		return nil
	end

	-- Each definition with malformed subcommands, and the refusal it gets
	local refusals: { Refused } = {
		{
			definition = { name = NAME, args = {}, subcommands = { { name = "now" } } },
			refusal = `[Decree] Command "wipe" holds both args and subcommands`,
		},
		{
			definition = { name = NAME, confirm = true, subcommands = { { name = "now" } } },
			refusal = `[Decree] Command "wipe" holds confirm beside subcommands, which hold their own`,
		},
		{
			definition = { name = NAME, subcommands = { "now" } },
			refusal = `[Decree] Command "wipe" subcommand #1 is not a table`,
		},
		{
			definition = { name = NAME, subcommands = { { name = "now", run = ask } } },
			refusal = `[Decree] Unknown key in command "wipe" subcommand #1: run`,
		},
		{
			definition = { name = NAME, subcommands = { { name = "now" }, { description = "Holds the wipe" } } },
			refusal = `[Decree] Command "wipe" subcommand #2 has no name`,
		},
		{
			definition = { name = NAME, subcommands = { { name = "now" }, { name = "NOW" } } },
			refusal = `[Decree] Command "wipe" holds the subcommand NOW twice`,
		},
		{
			definition = { name = NAME, subcommands = { { name = "now", args = { OPTIONAL_SHARD, REASON } } } },
			refusal = "[Decree] Command wipe now has required arguments after optional arguments.",
		},
	}

	for index: number, refused: Refused in refusals do
		local registered: boolean, problem: any = pcall(registry.registerCommandObject, registry, refused.definition)
		if registered or Thrown(problem) ~= refused.refusal then
			return false, `malformed subcommands #{index} gave {problem}`
		end
	end

	if registry:getCommand(NAME) ~= nil or #core.access.definitions ~= 0 then
		return false, "a refused definition was stored or handed to the access check"
	end

	local definition: { [string]: any } = {
		name = NAME,

		subcommands = {
			{ name = "now", description = "Wipes the shard now", args = { SHARD, REASON }, confirm = true },
			{ name = "hold", confirm = ask },
			{ name = "open" },
		},
	}

	registry:registerCommandObject(definition)
	if registry:getCommand(NAME) ~= definition then
		return false, "plain subcommands, each with its own args and confirm, did not register"
	end

	return true, nil
end
