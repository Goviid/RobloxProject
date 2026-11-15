--!strict
-- Constants.luau
-- Global game configuration for Skulls & Roses

local Constants = {
	-- Player Constraints
	MIN_PLAYERS = 2,
	MAX_PLAYERS = 4, -- The 3D table has 4 seats (TableBuilder.SEAT_CONFIGS)
	ENABLE_BOTS = true, -- Lets the lobby host fill empty seats with bots

	-- Arena / Visual Mode ("Void" for LOCOfficial Light Blue Void, "Table" for Classic Parlor Table)
	DEFAULT_ARENA_MODE = "Void",

	-- Gameplay Rules
	POINTS_TO_WIN = 2,
	CARDS_PER_PLAYER = 4,
	ROSES_PER_PLAYER = 3,
	SKULLS_PER_PLAYER = 1,

	-- Timers (Seconds)
	LOBBY_COUNTDOWN = 5, -- Seconds between "everyone is ready" and the match starting
	TURN_TIMEOUT = 30,
	ROUND_TRANSITION_DELAY = 4,
	REVEAL_ANIMATION_DELAY = 1.2,
	MATCH_OVER_DELAY = 30, -- How long the winner screen stays up before a new match
	BOT_THINK_DELAY = 3, -- Seconds a bot waits before acting, so humans can follow along

	-- Table Positions (Degrees for radial seat distribution)
	SEAT_DISTRIBUTIONS = {
		[2] = { 180, 0 },
		[3] = { 210, 330, 90 },
		[4] = { 225, 315, 45, 135 },
		[5] = { 252, 324, 36, 108, 180 },
		[6] = { 240, 300, 0, 60, 120, 180 },
	},
}

return table.freeze(Constants)

