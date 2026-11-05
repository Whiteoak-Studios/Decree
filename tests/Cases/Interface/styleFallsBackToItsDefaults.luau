--[[
    A partial style keeps each key it gives, a reply kind's color and the
    echo's among them, and takes the default for every other, in a frozen
    copy that leaves the defaults as they were
--]]

--!strict
local roblox: any = require("@lune/roblox") -- Its typedefs leave out the datatypes it provides

local Environment = require("../../Environment")

local RESOLVE_STYLE: string = "src/DecreeClient/Window/Functions/ResolveStyle"

-- Each reply kind's key and the echo's, which the partial style gives some of
local KINDS: { string } = { "info", "ok", "refused", "error", "echo" }

return function (): (boolean, string | nil)
	local resolve: any = Environment.new({ side = "client" }).require(RESOLVE_STYLE)
	local Color3: any = roblox.Color3

	local defaults: { [string]: any } = {
		background = Color3.fromRGB(17, 17, 17),
		info = Color3.fromRGB(255, 255, 255),
		ok = Color3.fromRGB(131, 255, 131),
		refused = Color3.fromRGB(255, 153, 153),
		error = Color3.fromRGB(255, 73, 73),
		echo = Color3.fromRGB(255, 223, 93),
		outputFont = roblox.Font.fromEnum(roblox.Enum.Font.Code),
	}

	local given: { [string]: any } = {
		refused = Color3.fromRGB(200, 120, 0),
		echo = Color3.fromRGB(0, 160, 255),
		outputFont = roblox.Font.fromEnum(roblox.Enum.Font.RobotoMono),
	}

	local original: { [string]: any } = table.clone(defaults)
	local resolved: { [string]: any } = resolve(given, defaults)

	for key: string, default: any in defaults do
		local expected: any = given[key] or default
		if resolved[key] ~= expected then
			return false, `the style's {key} resolved to {resolved[key]}, where {expected} was expected`
		end
	end

	for _, key: string in KINDS do
		if resolved[key] == nil then
			return false, `the style resolved no color for {key}`
		end
	end

	for key: string, value: any in original do
		if defaults[key] ~= value then
			return false, `resolving the style changed the default {key}`
		end
	end

	if not table.isfrozen(resolved) then
		return false, "the resolved style can still change"
	end

	local untouched: { [string]: any } = resolve(nil, defaults)
	for key: string, default: any in defaults do
		if untouched[key] ~= default then
			return false, `with no style given, {key} resolved to {untouched[key]}`
		end
	end

	return true, nil
end
