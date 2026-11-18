--!strict
-- Constants.luau
-- Global game configuration for Skulls & Roses

local Constants = {
	-- Player Constraints
	MIN_PLAYERS = 2,
	MAX_PLAYERS = 6, -- The biggest table; each table's own size is in TABLES

	-- Tables in each server, picked from the main menu. Each is built TABLE_SPACING studs
	-- along +X from the previous one, with its seats laid out evenly round it.
	TABLES = {
		{ name = "Table 1", maxPlayers = 4 },
		{ name = "Table 2", maxPlayers = 6 },
	},
	TABLE_SPACING = 300,
	MENU_SPAWN = Vector3.new(0, 200, -300), -- hidden platform players stand on while in the menu
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
}

return table.freeze(Constants)

