--[[
    A fresh stand-in for the server path's access check per call: it records
    each definition registered, and every player holds every command but
    the ones a case withholds by name
--]]

--!strict
export type Access = {
	registered: (definition: any) -> (),
	holds: (player: any, definition: any) -> boolean,
	definitions: { any }, -- Each definition the registry handed over, in order
	withheld: { [string]: true }, -- The names of the commands no player holds, which a case sets
}

return function (): Access
	local definitions: { any } = {}
	local withheld: { [string]: true } = {}

	return {
		definitions = definitions,
		withheld = withheld,

		registered = function (definition: any)
			table.insert(definitions, definition)
		end,

		holds = function (_: any, definition: any): boolean
			return not withheld[definition.name]
		end,
	}
end
