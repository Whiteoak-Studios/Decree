--[[
    Evaluates a typed line through the dispatcher as the given executor and
    hands back the argument context at an index, or nil and the reason
--]]

--!strict

return function (dispatcher: any, executor: any, line: string, index: number, incomplete: boolean?): (any, string | nil)
	local context: any, reason: string? = dispatcher:evaluate(line, executor, incomplete)
	if not context then
		return nil, `{line} was refused: {reason}`
	end

	local argument: any = context:getArgument(index)
	if not argument then
		return nil, `{line} holds no argument #{index}`
	end

	return argument, nil
end
