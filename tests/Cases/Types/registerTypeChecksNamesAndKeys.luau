--[[
    registerType takes an alphanumeric name that starts with a lowercase
    letter or a digit and a definition of known keys, refuses a name taken
    already, and leaves the definition as given, so it takes several names
--]]

--!strict
local Environment = require("../../Environment")
local Refuses = require("../../Fixtures/Types/Refuses")

local REGISTRY: string = "src/DecreeClient/Shared/Registry"
local ACCEPTED: { string } = { "fruit", "9lives", "aBc123" }
local REFUSED: { string } = { "Fruit", "fruit-salad", "two words", "_fruit", "" }
local NAME_RULE: string = "type names must be alphanumeric and start with a lowercase letter or digit."
local NOT_TEXT: number = 5
local NOT_TEXT_REFUSAL: string = `[Decree] Invalid type name provided: {NOT_TEXT}`
local DISPLAYED: string = "veggie"
local DISPLAY_NAME: string = "Vegetable"
local UNKNOWN_KEY_NAME: string = "fruitbowl"
local UNKNOWN_KEY: string = "Color"
local UNKNOWN_KEY_REFUSAL: string = `[Decree] Unknown key/method in type "{UNKNOWN_KEY_NAME}": {UNKNOWN_KEY}`
local TAKEN: string = "string" -- A built-in type's name
local TAKEN_REFUSAL: string = `[Decree] Type "{TAKEN}" has already been registered.`
local REUSED: string = "reused" -- A second name for a definition registered once
local FULL: string = "everything" -- A type that holds every key a definition may
local FULL_PREFIXES: string = "# string"

-- Every key a definition may hold
local KEYS: { string } = {
	"transform",
	"validate",
	"autocomplete",
	"parse",
	"displayName",
	"listable",
	"validateOnce",
	"prefixes",
	"default",
	"argumentOperatorAliases",
}

return function (): (boolean, string | nil)
	local registry: any = Environment.new().require(REGISTRY)

	local function parse(text: string): string
		return text
	end

	for _, name: string in ACCEPTED do
		local definition: { [string]: any } = { parse = parse }
		registry:registerType(name, definition)

		if registry:getType(name) ~= definition or definition.name ~= nil or definition.displayName ~= nil then
			return false, `registerType did not register {name}, or wrote a name onto its definition`
		end
	end

	for _, name: string in REFUSED do
		local expected: string = `[Decree] Invalid type name provided: "{name}", {NAME_RULE}`
		if
			not Refuses(expected, registry.registerType, registry, name, { parse = parse })
			or registry:getType(name) ~= nil
		then
			return false, `registerType took the name "{name}"`
		end
	end

	if not Refuses(NOT_TEXT_REFUSAL, registry.registerType, registry, NOT_TEXT, { parse = parse }) then
		return false, "registerType took a name that is not text"
	end

	local displayed: { [string]: any } = { parse = parse, displayName = DISPLAY_NAME }
	registry:registerType(DISPLAYED, displayed)
	if displayed.displayName ~= DISPLAY_NAME then
		return false, `registerType replaced the display name {DISPLAY_NAME} with {displayed.displayName}`
	end

	local unknown: { [string]: any } = { parse = parse, [UNKNOWN_KEY] = true }
	local unknownRefused: boolean =
		Refuses(UNKNOWN_KEY_REFUSAL, registry.registerType, registry, UNKNOWN_KEY_NAME, unknown)
	if not unknownRefused or registry:getType(UNKNOWN_KEY_NAME) ~= nil then
		return false, `registerType took a definition with the unknown key {UNKNOWN_KEY}`
	end

	local builtIn: any = registry:getType(TAKEN)
	local takenRefused: boolean = Refuses(TAKEN_REFUSAL, registry.registerType, registry, TAKEN, { parse = parse })
	if not takenRefused or registry:getType(TAKEN) ~= builtIn then
		return false, `registerType took the name {TAKEN} a second time`
	end

	local registered: any = registry:getType(ACCEPTED[1])
	registry:registerType(REUSED, registered)
	if registry:getType(REUSED) ~= registered or registry:getType(ACCEPTED[1]) ~= registered then
		return false, "registerType did not take a definition already registered under another name"
	end

	local full: { [string]: any } = {}

	for _, key: string in KEYS do
		full[key] = parse
	end

	full.prefixes = FULL_PREFIXES
	registry:registerType(FULL, full)

	if registry:getType(FULL) ~= full then
		return false, "registerType refused a definition holding every key it knows"
	end

	return true, nil
end
