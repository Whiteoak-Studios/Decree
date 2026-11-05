--[[
    hasCharacter refuses a line whose executor, or whose player argument,
    has no character with a HumanoidRootPart, in the words for one or for
    several, and passes once the character is there
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local GUARDS: string = "src/Guards"
local BEFORE_RUN: string = "beforeRun"
local SECOND: string = "Second"
local ROOT_PART: string = "HumanoidRootPart"
local DONE: string = "Done"
local JUMP: string = "jump" -- Checks the executor
local FLING: string = `fling {SECOND}` -- Checks one player argument
local GATHER: string = "gather *" -- Checks a list argument holding every player
local NO_CHARACTER: string = "You don't have a character."
local TARGET_NO_CHARACTER: string = "Target player has no character."
local TARGETS_NO_CHARACTER: string = "One or more target players don't have a character."

--[[
    A character standing in the world, its root part inside it
--]]

local function character(): any
	local model: any = roblox.Instance.new("Model")
	local root: any = roblox.Instance.new("Part")
	root.Name = ROOT_PART
	root.Parent = model

	return model
end

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local Guards: any = core.env.require(GUARDS)
	local player: any = core.env.player
	local second: any = core.env.mock:join(SECOND)

	local function done(): string
		return DONE
	end

	core.registry:registerHook(BEFORE_RUN, PassingHook)
	core.registry:registerCommandObject({ name = "jump", args = {}, guards = { Guards.hasCharacter() }, run = done })
	core.registry:registerCommandObject({
		name = "fling",
		args = { { name = "target", type = "player" } },
		guards = { Guards.hasCharacter(1) },
		run = done,
	})
	core.registry:registerCommandObject({
		name = "gather",
		args = { { name = "targets", type = "players" } },
		guards = { Guards.hasCharacter(1) },
		run = done,
	})

	if core.run(JUMP, player) ~= NO_CHARACTER then
		return false, "jump ran for an executor with no character"
	elseif core.run(FLING, player) ~= TARGET_NO_CHARACTER then
		return false, "fling ran at a target with no character"
	end

	player.Character = character()

	if core.run(JUMP, player) ~= DONE then
		return false, "jump was refused for an executor with a character"
	elseif core.run(GATHER, player) ~= TARGETS_NO_CHARACTER then
		return false, "gather ran at a list holding a player with no character"
	end

	second.Character = character()

	if core.run(GATHER, player) ~= DONE then
		return false, "gather was refused once every target had a character"
	end

	return true, nil
end
