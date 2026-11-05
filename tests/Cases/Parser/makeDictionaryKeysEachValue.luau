--[[
    Util's makeDictionary turns each value of a list, of any type, into a
    key set to true, once however often it repeats
--]]

--!strict
local Environment = require("../../Environment")

local UTIL: string = "src/DecreeClient/Shared/Util"
local VALUES: { any } = { "a", "b", "a", 1, true }
local KEYS: { any } = { "a", "b", 1, true } -- VALUES without the repeat

return function (): (boolean, string | nil)
	local util: any = Environment.new().require(UTIL)

	local dictionary: { [any]: boolean } = util.makeDictionary(VALUES)
	local count: number = 0

	for key: any, value: boolean in dictionary do
		count += 1

		if value ~= true or not table.find(KEYS, key) then
			return false, `makeDictionary set {key} to {value}`
		end
	end

	if count ~= #KEYS then
		return false, `makeDictionary made {count} keys, where the list holds {#KEYS} distinct values`
	end

	if next(util.makeDictionary({})) ~= nil then
		return false, "makeDictionary made a key of an empty list"
	end

	return true, nil
end
