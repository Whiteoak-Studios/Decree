--[[
    A game's partial style table filled in from the defaults and frozen, so
    the window's style is fixed once the client starts
--]]

--!strict

return function<S, T>(given: S?, defaults: T): T
	local resolved: { [string]: any } = table.clone(defaults :: any)
	local partial: { [string]: any } = (given :: any) or {}

	for key: string, value: any in partial do
		local default: any = resolved[key]
		assert(default ~= nil, `[Decree] The style has no key {key}`)
		assert(
			typeof(value) == typeof(default),
			`[Decree] The style's {key} is a {typeof(value)}, where it takes a {typeof(default)}`
		)

		resolved[key] = value
	end

	return table.freeze(resolved) :: any
end
