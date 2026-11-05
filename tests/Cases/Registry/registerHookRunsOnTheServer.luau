--[[
    registerHook takes a hook on the server and refuses one on a client,
    and hasHook answers whether a name holds any hook, false for a name no
    hook may take
--]]

--!strict
local Environment = require("../../Environment")
local PassingHook = require("../../Fixtures/Dispatcher/PassingHook")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local BEFORE_RUN: string = "beforeRun"
local AFTER_RUN: string = "afterRun"
local UNKNOWN: string = "duringRun"
local CLIENT_REFUSAL: string = "[Decree] registerHook runs on the server, where hooks run."

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)

	if registry:hasHook(BEFORE_RUN) or registry:hasHook(AFTER_RUN) or registry:hasHook(UNKNOWN) then
		return false, "hasHook found a hook before any registered"
	end

	registry:registerHook(AFTER_RUN, PassingHook)
	if not registry:hasHook(AFTER_RUN) or registry:hasHook(BEFORE_RUN) then
		return false, "hasHook did not tell an afterRun hook from a beforeRun one"
	end

	registry:registerHook(BEFORE_RUN, PassingHook)
	if not registry:hasHook(BEFORE_RUN) or registry:hasHook(UNKNOWN) then
		return false, `hasHook did not find the beforeRun hook, or found one for {UNKNOWN}`
	end

	local client: any = Environment.new({ side = "client" }).require(REGISTRY)

	local registered: boolean, problem: any = pcall(client.registerHook, client, BEFORE_RUN, PassingHook)
	if registered or Thrown(problem) ~= CLIENT_REFUSAL or client:hasHook(BEFORE_RUN) then
		return false, `registerHook on a client gave {problem}`
	end

	return true, nil
end
