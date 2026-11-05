--[[
    The dev game's console settings on the client: the lines it keeps, its
    place name, its gamepad opener and who sees the context line
--]]

--!strict
return {
	maxLines = 100, -- The lines the console keeps, under Decree's default so the cap shows sooner
	placeName = "Dev", -- Shown after the player's name in the prompt, as Name@Dev$
	toggleKey = Enum.KeyCode.DPadLeft, -- The gamepad button that opens and closes the console, beside F2
	contextRank = 255, -- The rank that sees the context line above the prompt
	rankAttribute = "Rank", -- The player attribute the server sets to their rank
	bootSeconds = 30, -- How long boot waits for Decree's client half and the PlayerGui
}
