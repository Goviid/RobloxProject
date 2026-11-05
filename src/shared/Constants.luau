--!strict
-- Constants.luau
-- Global game configuration for Skulls & Roses

local Constants = {
	-- Player Constraints
	MIN_PLAYERS = 2,
	MAX_PLAYERS = 6,
	DEFAULT_TEST_BOTS = 3, -- Creates 3 bots in solo test mode for a 4-player game
	ENABLE_BOTS = true,

	-- Gameplay Rules
	POINTS_TO_WIN = 2,
	CARDS_PER_PLAYER = 4,
	ROSES_PER_PLAYER = 3,
	SKULLS_PER_PLAYER = 1,

	-- Timers (Seconds)
	LOBBY_COUNTDOWN = 5,
	TURN_TIMEOUT = 15,
	ROUND_TRANSITION_DELAY = 4,
	REVEAL_ANIMATION_DELAY = 1.2,
	MATCH_OVER_DELAY = 8,

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
