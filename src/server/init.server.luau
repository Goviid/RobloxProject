--!strict
-- init.server.luau
-- Server entry point for Skulls & Roses

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerManager = require(script.PlayerManager)
local RoundManager = require(script.RoundManager)

print("[Skulls & Roses] Server initializing...")

-- Action Dispatcher from Client
Network.SubmitAction.OnServerInvoke = function(player: Player, action: string, data: any)
	return RoundManager.HandlePlayerAction(player.UserId, action, data)
end

-- Bot Spawner Helper
local function spawnTestBots(neededCount: number)
	local botNames = { "Doña Flor", "El Bandido", "Don Diego", "La Catrina", "Señor Hueso" }
	for i = 1, neededCount do
		local name = botNames[i] or ("Bot " .. i)
		PlayerManager.AddBot(name)
		print("[Skulls & Roses] Added bot: " .. name)
	end
end

-- Player Join / Leave
local function onPlayerAdded(player: Player)
	print("[Skulls & Roses] Player joined: " .. player.Name .. " (" .. player.UserId .. ")")
	PlayerManager.AddPlayer(player)

	-- Solo / Test mode: Auto-populate bots if we don't have enough players
	local active = PlayerManager.GetActivePlayers()
	if Constants.ENABLE_BOTS and #active < (Constants.DEFAULT_TEST_BOTS + 1) then
		local botsToSpawn = (Constants.DEFAULT_TEST_BOTS + 1) - #active
		spawnTestBots(botsToSpawn)
	end

	-- Start the game if currently in Lobby
	if RoundManager.GetGameState() == require(ReplicatedStorage.Shared.Enums).GameState.Lobby then
		task.delay(2, function()
			RoundManager.StartRound()
		end)
	end
end

local function onPlayerRemoving(player: Player)
	print("[Skulls & Roses] Player left: " .. player.Name)
	PlayerManager.RemovePlayer(player.UserId)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle any players already in game (e.g. during live reload)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- If running in Studio edit mode or empty test server with bots enabled
task.defer(function()
	if #Players:GetPlayers() == 0 and Constants.ENABLE_BOTS then
		print("[Skulls & Roses] Headless test server detected, initializing bots...")
		spawnTestBots(Constants.DEFAULT_TEST_BOTS + 1)
		RoundManager.StartRound()
	end
end)

print("[Skulls & Roses] Server ready!")
