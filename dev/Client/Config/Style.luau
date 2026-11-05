--[[
    The dev game's partial style table for Decree's console, a few keys off
    the defaults so the live run sees them applied and the rest fall back
--]]

--!strict
return {
	background = Color3.fromRGB(16, 24, 48), -- Navy
	prompt = Color3.fromRGB(120, 200, 255), -- Sky blue, the prompt and the context line
	ok = Color3.fromRGB(64, 224, 176), -- Teal
	titleFont = Font.fromEnum(Enum.Font.FredokaOne), -- The suggested argument's name
}
