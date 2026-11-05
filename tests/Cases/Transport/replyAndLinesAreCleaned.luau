--[[
    Decree cleans what it sends to fit Volt's UTF-8 fields: a byte that is
    not UTF-8 becomes U+FFFD in a printed line, and a reply past TEXT_BYTES
    is cut there, before the character the cap would split
--]]

--!strict
local Decree = require("../../Fixtures/Server/Decree")

local TEXT_BYTES: number = require("../../../src/DecreeClient/Shared/Constants").TEXT_BYTES
local LINE: string = "garble"
local BROKEN: string = "half \255 a line" -- 0xFF is never UTF-8
local MENDED: string = "half \u{FFFD} a line"
local FILL: string = "a"
local SPLIT: string = "\u{E9}" -- Two bytes, the second past the cap
local CUT: string = FILL:rep(TEXT_BYTES - 1) -- What the reply keeps, the split character gone whole

return function (): (boolean, string | nil)
	local server: Decree.Decree = Decree()

	server.decree.registry:registerCommandObject({
		name = LINE,
		args = {},

		run = function (context: any): string
			context:reply(BROKEN)

			return `{FILL:rep(TEXT_BYTES - 1)}{SPLIT}{FILL}`
		end,
	})

	server.start()

	local printed: string? = nil
	server.client.Decree.line.on(function (text: string)
		printed = text
	end)

	local answered: boolean, reply: string = server.run(LINE)
	if not answered or reply ~= CUT then
		return false, `the long reply came back as {answered and #reply or reply} bytes, not cut whole`
	elseif printed ~= MENDED then
		return false, `the broken line printed {printed}`
	end

	return true, nil
end
