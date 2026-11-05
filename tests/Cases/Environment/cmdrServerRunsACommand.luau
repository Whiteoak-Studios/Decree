--[[
    Cmdr 1.13.1's registry and dispatcher, loaded on the server side with
    every built-in type file registered, refuse a command until a BeforeRun
    hook exists, then run a typed line into its server function
--]]

--!strict
local Environment = require("../../Environment")

local NAME: string = "greet"
local UNKNOWN: string = "Nobody" -- A name no joined player has
local BLOCKED: string = "Command blocked for security as no BeforeRun hook is configured." -- Outside Studio
local NOT_FOUND: string = "#1 target: No player with that name could be found."

-- One type from each file in Cmdr/BuiltInTypes
local BUILT_IN_TYPES: { string } = {
	"brickColor",
	"color3",
	"command",
	"duration",
	"json",
	"mathOperator",
	"player",
	"playerId",
	"string",
	"storedKey",
	"team",
	"type",
	"url",
	"userInput",
	"vector3",
}

return function (): (boolean, string | nil)
	local env: any = Environment.new()
	local cmdr: any = env.cmdr()

	for _, typeName: string in BUILT_IN_TYPES do
		if not cmdr.Registry:GetType(typeName) then
			return false, `the built-in type {typeName} is not registered`
		end
	end

	local reached: { any } = {}

	cmdr.Registry:RegisterCommandObject({
		Name = NAME,
		Args = { { Type = "player", Name = "target", Description = "Who is greeted" } },

		Run = function (_: any, target: any): string
			table.insert(reached, target)

			return `Hello {target.Name}`
		end,
	})

	local line: string = `{NAME} {env.player.Name}`
	local blocked: any = cmdr.Dispatcher:EvaluateAndRun(line, env.player)
	if blocked ~= BLOCKED or #reached ~= 0 then
		return false, `with no BeforeRun hook the line answered {blocked}`
	end

	-- What Cmdr requires outside Studio: a BeforeRun hook, here one that lets every command run
	cmdr.Registry:RegisterHook("BeforeRun", function (): string?
		return nil
	end)

	local reply: any = cmdr.Dispatcher:EvaluateAndRun(line, env.player)
	if reply ~= `Hello {env.player.Name}` or #reached ~= 1 or reached[1] ~= env.player then
		return false, `the line answered {reply} and reached the server function {#reached} times`
	end

	local refused: any = cmdr.Dispatcher:EvaluateAndRun(`{NAME} {UNKNOWN}`, env.player)
	if refused ~= NOT_FOUND or #reached ~= 1 then
		return false, `a line naming no player answered {refused}`
	end

	return true, nil
end
