--[[
    A folder of modules handed to the environment mounts in
    ReplicatedStorage as Rojo maps it, and a case finds and requires any
    instance in it, or in a root, by its path from the repo root
--]]

--!strict
local Environment = require("../../Environment")

local FIXTURE: string = ".volt/src/Config" -- Modules with no init.luau, in a folder holding one of its own
local NAME: string = "Config" -- FIXTURE's last segment, the name Rojo gives it
local LEAF: string = `{FIXTURE}/Runtime`
local NESTED: string = `{FIXTURE}/Types/Contract` -- Requires its sibling ./Runtime, which requires ./Send
local ROOT_FOLDER: string = "Cmdr/BuiltInTypes"
local ROOT_MODULE: string = "Cmdr/CmdrClient" -- A folder holding an init.luau, which mounts as a ModuleScript

return function (): (boolean, string | nil)
	local env: any = Environment.new({ folders = { FIXTURE } })
	local replicatedStorage: any = env.game:GetService("ReplicatedStorage")

	local fixture: any = env.find(FIXTURE)
	local mounted: string = `{fixture.ClassName} {fixture:GetFullName()}`
	if not fixture:IsA("Folder") or fixture.Parent ~= replicatedStorage or fixture.Name ~= NAME then
		return false, `the fixture mounted as {mounted}`
	end

	local nested: any = env.find(NESTED)
	local nestedPath: string = nested:GetFullName()
	if not nested:IsA("ModuleScript") or nested.Parent.Parent ~= fixture then
		return false, `the nested module mounted as {nestedPath}`
	end

	if type(env.require(NESTED)) ~= "table" then
		return false, "the nested module did not load through its sibling requires"
	end

	if env.require(env.find(LEAF)) ~= env.require(LEAF) then
		return false, "a module required by its instance and by its path loaded twice"
	end

	local rootModule: any = env.find(ROOT_MODULE)
	if not env.find(ROOT_FOLDER):IsA("Folder") or not rootModule:IsA("ModuleScript") then
		return false, "a root's folders mounted as the wrong classes"
	end

	if rootModule ~= env.find(`{ROOT_MODULE}/init`) then
		return false, "a folder's ModuleScript is not the one its init.luau mounted"
	end

	if pcall(env.find, `{FIXTURE}/Missing`) or pcall(env.require, `{FIXTURE}/Types`) then
		return false, "find answered for nothing mounted, or require loaded a folder"
	end

	return true, nil
end
