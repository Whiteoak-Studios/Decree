--[[
    registerTypesIn registers every key of every module in a folder and the
    folders inside it, each definition as its module holds it, and refuses
    a module that returns anything but a table
--]]

--!strict
local Environment = require("../../Environment")
local Thrown = require("../../Fixtures/Dispatcher/Thrown")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local TYPE_MODULES: string = "tests/Fixtures/Core/TypeModules"
local FRUITS: string = `{TYPE_MODULES}/Fruits`
local VEGETABLES: string = `{TYPE_MODULES}/Garden/Vegetables` -- In a folder inside the folder registered
local NOT_TABLES: string = "tests/Fixtures/Core/NotTables"
local TEXT_REFUSAL: string = "[Decree] Type module Text returned a string, where it returns its types by name"

-- Each type the folder holds, by the module that holds it
local EXPECTED: { [string]: string } = {
	fruit = FRUITS,
	fruits = FRUITS,
	vegetable = VEGETABLES,
}

return function (): (boolean, string | nil)
	local env: any = Environment.new({ folders = { TYPE_MODULES, NOT_TABLES } })
	local registry: any = env.require(REGISTRY)

	registry:registerTypesIn(env.find(TYPE_MODULES))

	for name: string, path: string in EXPECTED do
		local held: any = env.require(path)[name]
		if held == nil or registry:getType(name) ~= held then
			return false, `registerTypesIn did not register {name} as {path} holds it`
		end
	end

	local registered: boolean, problem: any = pcall(registry.registerTypesIn, registry, env.find(NOT_TABLES))
	if registered or Thrown(problem) ~= TEXT_REFUSAL then
		return false, `a module that returns text gave {problem}`
	end

	return true, nil
end
