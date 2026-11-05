--[[
    An afterRun hook reads run's return as the context's response, and the
    first one to return anything but nil replaces the reply with that value
    as Info text, skipping the afterRun hooks after it
--]]

--!strict
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Server = require("../../Fixtures/Core/Server")

local NAME: string = "act"
local REPLY: string = "Acted"
local REPLACED: string = "Replaced"
local REPLACED_NUMBER: number = 7
local NUMBER_TEXT: string = "7"
local EXECUTED: string = "Command executed."
local INFO: string = "Info"
local LATER_PRIORITY: number = 1 -- Above the replacing hook's default 0, so it runs after it

return function (): (boolean, string | nil)
	local core: Server.Core = Server()
	local answer: string? = REPLY -- What run returns, which a step of the case sets
	local replacement: any = nil -- What the first afterRun hook returns, which each step sets

	-- What one run's afterRun hooks saw, the response kept beside a flag so a nil one still shows
	local seen: { [string]: any } = { heard = false, response = nil, later = false }

	core.registry:registerHook("beforeRun", PassingHook)

	core.registry:registerHook("afterRun", function (context: any): any
		seen.heard = true
		seen.response = context.response

		return replacement
	end)

	core.registry:registerHook("afterRun", function (): string?
		seen.later = true

		return nil
	end, LATER_PRIORITY)

	core.registry:registerCommandObject({
		name = NAME,
		args = {},

		run = function (): string?
			return answer
		end,
	})

	local function run(): (string, string)
		seen.heard = false
		seen.response = nil
		seen.later = false

		return core.run(NAME, core.env.player)
	end

	local kept: string, keptKind: string = run()
	if kept ~= REPLY or keptKind ~= INFO or seen.response ~= REPLY or not seen.later then
		return false, `with no replacement the line answered {kept} as {keptKind}, the hook reading {seen.response}`
	end

	replacement = REPLACED
	local replaced: string, replacedKind: string = run()
	if replaced ~= REPLACED or replacedKind ~= INFO or seen.response ~= REPLY or seen.later then
		return false, `a replacing hook answered {replaced} as {replacedKind}, the later hook running: {seen.later}`
	end

	replacement = REPLACED_NUMBER
	local fromNumber: string = run()
	if fromNumber ~= NUMBER_TEXT then
		return false, `a hook that returned a number answered the {type(fromNumber)} {fromNumber}`
	end

	replacement = nil
	answer = nil
	local executed: string, executedKind: string = run()
	if executed ~= EXECUTED or executedKind ~= INFO or not seen.heard or seen.response ~= nil or not seen.later then
		return false, `a run that returned nil answered {executed}, the hook reading {seen.response}`
	end

	return true, nil
end
