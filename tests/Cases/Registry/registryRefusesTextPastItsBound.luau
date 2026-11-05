--[[
    registerCommandObject refuses text one byte past a bound of the wire's,
    or text that is no text at all, in a command, in an argument and in a
    subcommand, naming the field and where it is, and stores none of them
--]]

--!strict
local Server = require("../../Fixtures/Core/Server")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local NAME_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").NAME_BYTES
local TYPE_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").TYPE_BYTES
local DESCRIPTION_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").DESCRIPTION_BYTES
local ARGUMENT_DESCRIPTION_BYTES: number =
	require("../../../src/DecreeClient/Shared/Constants").ARGUMENT_DESCRIPTION_BYTES
local LINE_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").LINE_BYTES
local NAME: string = "audit"
local FILL: string = "a"
local EMPTY: string = "" -- One byte under a name's fewest
local NUMBER: number = 5 -- A group the wire cannot carry as text

type Refused = {
	definition: { [string]: any },
	refusal: string,
}

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local registry: any = core.registry

	local longName: string = FILL:rep(NAME_BYTES + 1)
	local nameBounds: string = `1 to {NAME_BYTES} bytes`
	local descriptionBounds: string = `0 to {DESCRIPTION_BYTES} bytes`
	local argumentDescriptionBounds: string = `0 to {ARGUMENT_DESCRIPTION_BYTES} bytes`

	-- Each definition with one field past its bound, and the refusal naming it
	local refusals: { Refused } = {
		{
			definition = { name = longName, args = {} },
			refusal = `[Decree] Command "{longName}"'s name is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, aliases = { "check", longName } },
			refusal = `[Decree] Command "audit"'s aliases #2 is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, description = FILL:rep(DESCRIPTION_BYTES + 1) },
			refusal = `[Decree] Command "audit"'s description is not text of {descriptionBounds}`,
		},
		{
			definition = { name = NAME, group = EMPTY },
			refusal = `[Decree] Command "audit"'s group is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, group = NUMBER },
			refusal = `[Decree] Command "audit"'s group is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, system = longName },
			refusal = `[Decree] Command "audit"'s system is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, tags = { longName } },
			refusal = `[Decree] Command "audit"'s tags #1 is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, autoExec = { FILL:rep(LINE_BYTES + 1) } },
			refusal = `[Decree] Command "audit"'s autoExec #1 is not text of 1 to {LINE_BYTES} bytes`,
		},
		{
			definition = { name = NAME, args = { { name = longName, type = "string" } } },
			refusal = `[Decree] Command "audit" argument #1's name is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, args = { { type = "string" } } },
			refusal = `[Decree] Command "audit" argument #1's name is not text of {nameBounds}`,
		},
		{
			definition = { name = NAME, args = { { name = "target", type = FILL:rep(TYPE_BYTES + 1) } } },
			refusal = `[Decree] Command "audit" argument #1's type is not text of 1 to {TYPE_BYTES} bytes`,
		},
		{
			definition = {
				name = NAME,
				args = { { name = "target", type = "player", description = FILL:rep(ARGUMENT_DESCRIPTION_BYTES + 1) } },
			},
			refusal = `[Decree] Command "audit" argument #1's description is not text of {argumentDescriptionBounds}`,
		},
		{
			definition = { name = NAME, subcommands = { { name = "now" }, { name = longName } } },
			refusal = `[Decree] Command "audit" subcommand #2's name is not text of {nameBounds}`,
		},
		{
			definition = {
				name = NAME,
				subcommands = { { name = "now", description = FILL:rep(DESCRIPTION_BYTES + 1) } },
			},
			refusal = `[Decree] Command "audit" subcommand #1's description is not text of {descriptionBounds}`,
		},
		{
			definition = {
				name = NAME,
				subcommands = {
					{
						name = "now",
						args = {
							{
								name = "shard",
								type = "integer",
								description = FILL:rep(ARGUMENT_DESCRIPTION_BYTES + 1),
							},
						},
					},
				},
			},
			refusal = `[Decree] Command "audit now" argument #1's description is not text of {argumentDescriptionBounds}`,
		},
	}

	for index: number, refused: Refused in refusals do
		local registered: boolean, problem: any = pcall(registry.registerCommandObject, registry, refused.definition)
		if registered or Thrown(problem) ~= refused.refusal then
			return false, `text past its bound #{index} gave {problem}`
		end
	end

	if registry:getCommand(NAME) ~= nil or registry:getCommand(longName) ~= nil or #core.access.definitions ~= 0 then
		return false, "a refused definition was stored or handed to the access check"
	end

	return true, nil
end
