--[[
    Checks that a type maps exactly the four player operator words, me, all,
    others and random, to the operators each stands for
--]]

--!strict
-- Each word a player argument takes, by the operator it stands for
local OPERATORS: { [string]: string } = {
	me = ".",
	all = "*",
	others = "**",
	random = "?",
}

return function (aliases: { [string]: string }?): (boolean, string | nil)
	if not aliases then
		return false, "the type maps no operator words"
	end

	for word: string, operator: string in OPERATORS do
		if aliases[word] ~= operator then
			return false, `the word {word} stands for {aliases[word]}, not {operator}`
		end
	end

	for word: string in aliases do
		if not OPERATORS[word] then
			return false, `the type maps the extra word {word}`
		end
	end

	return true, nil
end
