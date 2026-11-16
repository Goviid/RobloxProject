--!strict
-- init.server.luau
-- Server entry point for Skulls & Roses

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)
local RoundManager = require(script.RoundManager)
local TableBuilder = require(script.TableBuilder)
local LobbyManager = require(script.LobbyManager)

print("[Skulls & Roses] Server initializing...")

-- Build the 3D Table Arena in Workspace
TableBuilder.Build()
workspace:SetAttribute("TableReady", true) -- the client loading screen waits for this

-- Action Dispatcher from Client
Network.SubmitAction.OnServerInvoke = function(player: Player, action: string, data: any)
	return RoundManager.HandlePlayerAction(player.UserId, action, data)
end

-- Client Initial State Request (guarantees UI gets synced immediately upon client load)
Network.RequestState.OnServerEvent:Connect(function(player: Player)
	RoundManager.SendStateToPlayer(player.UserId)
	LobbyManager.Broadcast()
end)

-- Lobby: seating, ready check, bots and match start (see LobbyManager.luau)
LobbyManager.Init()

local function onPlayerAdded(player: Player)
	print("[Skulls & Roses] Player joined: " .. player.Name .. " (" .. player.UserId .. ")")
	LobbyManager.OnPlayerAdded(player)
end

local function onPlayerRemoving(player: Player)
	print("[Skulls & Roses] Player left: " .. player.Name)
	LobbyManager.OnPlayerRemoving(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle any players already in game (e.g. during live reload)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("[Skulls & Roses] Server ready!")
