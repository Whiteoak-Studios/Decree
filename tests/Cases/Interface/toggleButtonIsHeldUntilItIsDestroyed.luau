--[[
    A registered toggle button is held strongly, so one the game keeps no
    other hold on stays registered, is watched once however often it is
    registered, and its entry and that watch go once it is destroyed
--]]

--!strict
local Environment = require("../../Environment")

local CLIENT_ENTRY: string = "src/DecreeClient"

return function (): (boolean, string | nil)
	local env: any = Environment.new({ side = "client" })
	local client: any = env.require(CLIENT_ENTRY)
	local toggleButtons: any = client._settings.toggleButtons

	local metatable: any = getmetatable(toggleButtons)
	if metatable and metatable.__mode then
		return false, `the toggle buttons are held with mode {metatable.__mode}, so a button can be collected`
	end

	local connects: number = 0
	local disconnected: boolean = false
	local destroy: any = nil

	-- A stand-in for a button, since Lune's instances have no Destroying event
	local button: any = {
		Destroying = {
			Connect = function (_: any, callback: () -> ()): any
				connects += 1
				destroy = callback

				return {
					Disconnect = function (_: any)
						disconnected = true
					end,
				}
			end,
		},
	}

	client:addToggleButton(button)
	client:addToggleButton(button)

	if not toggleButtons[button] or connects ~= 1 then
		return false, `a button registered twice is held {toggleButtons[button] ~= nil} and watched {connects} times`
	end

	destroy()

	if toggleButtons[button] ~= nil or not disconnected then
		return false, "a destroyed button stays registered, or its watch stays connected"
	end

	return true, nil
end
