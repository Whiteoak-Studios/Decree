--[[
    A listed device command runs nothing until its device half's clone is in
    the player's DecreeCommands ScreenGui, then runs that clone's half on
    the device, sending nothing, and is held no longer once the clone goes
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Console = require("../../Fixtures/Interface/Console")
local Entry = require("../../Fixtures/Core/Entry")

local FIXTURE: string = "tests/Fixtures/Core/Commands/Moderation/Kill"
local HALF: string = `{FIXTURE}/KillClient` -- Named in other capitals than the command
local KILL: string = "kill"
local WAVE: string = "wave"
local COMMANDS: string = "DecreeCommands"
local UNKNOWN: string = `{KILL} is not a valid command name.`
local KILLED: string = "Killed on the device"
local INFO: string = "Info"
local REFUSED: string = "Refused"

return function (): (boolean, string | nil)
	local console: Console.Console = Console({ FIXTURE })
	local heard: { string } = {} -- Each line the server was sent

	local kill: { [string]: any } = Entry({ name = KILL })
	kill.device = true

	console.server.Decree.commands.on(function (_: any): { any }
		return { kill, Entry({ name = WAVE }) }
	end)

	console.server.Decree.run.on(function (_: any, text: string): (string, string)
		table.insert(heard, text)

		return text, INFO
	end)

	console.listen()
	console.step()

	if console.registry:getCommand(KILL) or not console.registry:getCommand(WAVE) then
		return false, `the console held {KILL} before its half arrived, or never held {WAVE}`
	end

	local early: string?, earlyKind: string? = console.reply(console.dispatcher:evaluateAndRun(KILL))
	if early ~= UNKNOWN or earlyKind ~= REFUSED or #heard ~= 0 then
		return false, `{KILL} answered {early} as {earlyKind} before its half arrived, and {#heard} lines were sent`
	end

	-- The server's side clones the half into the player's own ScreenGui
	local gui: any = roblox.Instance.new("ScreenGui")
	gui.Name = COMMANDS
	gui.ResetOnSpawn = false
	gui.Parent = console.env.player.PlayerGui

	local clone: any = console.env.find(HALF):Clone()
	clone.Parent = gui
	console.session:refresh()

	local killed: string?, killedKind: string? = console.reply(console.dispatcher:evaluateAndRun(KILL))
	if killed ~= KILLED or killedKind ~= INFO or #heard ~= 0 then
		return false, `{KILL} answered {killed} as {killedKind} once its half arrived, and {#heard} lines were sent`
	end

	clone:Destroy()
	console.session:refresh()

	if console.registry:getCommand(KILL) then
		return false, `the console still held {KILL} once its half was gone`
	end

	return true, nil
end
