--[[
    The dev game's console settings: the rate, the confirm window, how each
    player's rank is found and which ranks hold each command group, and the
    bounds its test commands keep to
--]]

--!strict
return {
	rate = { perSecond = 1, burst = 4 } :: { perSecond: number, burst: number? }, -- Each of run and commands, per player
	confirmSeconds = 30, -- How long a line asking for confirmation waits for confirm

	groupId = 16359964, -- The Whiteoak group, whose rank a real account holds
	rankSeconds = 10, -- How long a join waits for the group's answer before the player is a guest
	rankAttribute = "Rank", -- The player attribute holding their rank, which the gate reads and the client shows

	-- The lowest rank that holds each command group, by the group a definition names
	groupRanks = {
		Player = 0,
		Admin = 255,
	} :: { [string]: number },

	-- Studio's test players, whose UserIds are negative, by name; any other is a guest
	testRanks = {
		Player1 = 255,
		Player2 = 0,
	} :: { [string]: number },

	motd = "Welcome to the Decree dev place.", -- What motd answers, and what its autoExec line echoes
	slowSeconds = 8, -- The longest slow waits, inside the 9 seconds Decree gives a server half's Promise
	longLineCharacters = 16384, -- longline's reply, the most text one reply carries
	floodLines = 16, -- The most lines one flood sends
	floodBytes = 16000, -- The filler in each of flood's lines, so four fill a frame
	auditCharacters = 200, -- How much of a reply the audit line prints
}
