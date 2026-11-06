--!strict
-- init.server.luau
-- Server entry point for Skulls & Roses

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerManager = require(script.PlayerManager)
local RoundManager = require(script.RoundManager)
local TableBuilder = require(script.TableBuilder)

print("[Skulls & Roses] Server initializing...")

-- Build the 3D Table Arena in Workspace
TableBuilder.Build()

-- Action Dispatcher from Client
Network.SubmitAction.OnServerInvoke = function(player: Player, action: string, data: any)
	return RoundManager.HandlePlayerAction(player.UserId, action, data)
end

-- Client Initial State Request (guarantees UI gets synced immediately upon client load)
Network.RequestState.OnServerEvent:Connect(function(player: Player)
	print("[Server] Client requested state: " .. player.Name .. " (" .. player.UserId .. ")")
	if RoundManager.GetGameState() == require(ReplicatedStorage.Shared.Enums).GameState.Lobby then
		RoundManager.StartRound()
	else
		RoundManager.SendStateToPlayer(player.UserId)
	end
end)

-- Bot Spawner Helper (Matching exact bots in concept mockup: BLUFFER_99, BLUFFE_99, ROSE_KING)
local function spawnTestBots(neededCount: number)
	local botNames = { "BLUFFER_99", "BLUFFE_99", "ROSE_KING" }
	for i = 1, neededCount do
		local name = botNames[i] or ("Player_" .. i)
		local botData = PlayerManager.AddBot(name)
		if botData then
			TableBuilder.SpawnStandingBot(name, botData.seatIndex)
		end
		print("[Skulls & Roses] Added standing bot: " .. name)
	end
end

-- Re-spawn any existing bots in Workspace if arena was re-created
for _, p in pairs(PlayerManager.GetAllPlayers()) do
	if p.isBot then
		TableBuilder.SpawnStandingBot(p.name, p.seatIndex)
	end
end

-- Pre-spawn default bots so the table is immediately populated with standing avatars
local activeAtStartup = PlayerManager.GetActivePlayers()
if Constants.ENABLE_BOTS and #activeAtStartup < Constants.DEFAULT_TEST_BOTS then
	spawnTestBots(Constants.DEFAULT_TEST_BOTS - #activeAtStartup)
end

-- Player Join / Leave
local function onPlayerAdded(player: Player)
	print("[Skulls & Roses] Player joined: " .. player.Name .. " (" .. player.UserId .. ")")
	local pData = PlayerManager.AddPlayer(player)
	if pData then
		TableBuilder.StandPlayer(player, pData.seatIndex)
	end

	-- Ensure models exist in Workspace for all registered bots
	for _, p in pairs(PlayerManager.GetAllPlayers()) do
		if p.isBot then
			TableBuilder.SpawnStandingBot(p.name, p.seatIndex)
		end
	end

	-- Solo / Test mode: Auto-populate bots if we don't have enough players
	local active = PlayerManager.GetActivePlayers()
	if Constants.ENABLE_BOTS and #active < (Constants.DEFAULT_TEST_BOTS + 1) then
		local botsToSpawn = (Constants.DEFAULT_TEST_BOTS + 1) - #active
		spawnTestBots(botsToSpawn)
	end

	-- Start the game immediately if currently in Lobby so player can act without delay
	if RoundManager.GetGameState() == require(ReplicatedStorage.Shared.Enums).GameState.Lobby then
		RoundManager.StartRound()
	else
		RoundManager.SendStateToPlayer(player.UserId)
	end

	-- Allow live switching between "Void" and "Table" modes via chat ("/void" or "/table")
	player.Chatted:Connect(function(msg: string)
		local lower = string.lower(msg)
		if lower == "/table" or lower == "/mode table" then
			print("[Server] Switching arena mode to Table...")
			TableBuilder.Build("Table")
			for _, p in pairs(PlayerManager.GetAllPlayers()) do
				if p.isBot then
					TableBuilder.SpawnStandingBot(p.name, p.seatIndex)
				else
					local pl = Players:GetPlayerByUserId(p.userId)
					if pl then TableBuilder.StandPlayer(pl, p.seatIndex) end
				end
			end
		elseif lower == "/void" or lower == "/mode void" then
			print("[Server] Switching arena mode to Void...")
			TableBuilder.Build("Void")
			for _, p in pairs(PlayerManager.GetAllPlayers()) do
				if p.isBot then
					TableBuilder.SpawnStandingBot(p.name, p.seatIndex)
				else
					local pl = Players:GetPlayerByUserId(p.userId)
					if pl then TableBuilder.StandPlayer(pl, p.seatIndex) end
				end
			end
		end
	end)
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

print("[Skulls & Roses] Server ready!")
