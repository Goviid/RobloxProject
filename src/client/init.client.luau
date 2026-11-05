--!strict
-- init.client.luau
-- Client bootstrapper for Skulls & Roses (Theme A: Calavera / Day of the Dead)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Network = require(ReplicatedStorage.Shared.Network)

local Theme = require(script.UI.Theme)
local NotificationBanner = require(script.UI.NotificationBanner)
local TableView = require(script.UI.TableView)
local HandBar = require(script.UI.HandBar)
local ActionBar = require(script.UI.ActionBar)
local CardRevealModal = require(script.UI.CardRevealModal)
local CardAnimation = require(script.UI.CardAnimation)
local CameraController = require(script.CameraController)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

print("[Skulls & Roses] Client UI initializing for " .. localPlayer.Name .. "...")

-- ============================================================================
-- 1. 2.5D CAMERA & SCREEN GUI SETUP (LOCOfficial style)
-- ============================================================================
-- Initialize the 2.5D fixed tabletop camera framing the 3D table & avatars
CameraController.Init()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkullsGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true -- Fills whole screen nicely
screenGui.Parent = playerGui

-- ============================================================================
-- 2. INITIALIZE MODULAR UI COMPONENTS
-- ============================================================================
-- Forward declarations for callbacks
local onSubmitAction: (action: string, data: any) -> ()

-- 1. Top Banner & Timer
NotificationBanner.Create(screenGui)

-- 2. Center Table & Radial Seats
TableView.Create(screenGui, function(targetUserId: number)
	-- When local player is challenger and clicks a stack during Revealing phase
	onSubmitAction(Enums.PlayerAction.RevealCard, { targetUserId = targetUserId })
end)

-- 3. Bottom Hand Tray
HandBar.Create(screenGui, function(cardType: string)
	print("[HandBar] Selected card: " .. cardType)
end)

-- 4. Bottom-Right Action Buttons
ActionBar.Create(screenGui, function(action: string, data: any)
	if action == Enums.PlayerAction.PlaceCard then
		local selected = HandBar.GetSelectedCard()
		if selected then
			data.cardType = selected
			-- Trigger LOCOfficial flying card animation
			CardAnimation.PlayCardFly(
				screenGui,
				UDim2.new(0.5, 0, 1, -50),
				UDim2.new(0.5, 0, 0.45, 0),
				selected
			)
			onSubmitAction(action, data)
		else
			NotificationBanner.Show("Select a card from your hand first!", "warning")
		end
	else
		onSubmitAction(action, data)
	end
end)

-- 5. Center Card Reveal Popup
CardRevealModal.Create(screenGui)

local lastKnownPlayers: { [string]: any } = {}

-- ============================================================================
-- 3. ACTION DISPATCHER (Client -> Server)
-- ============================================================================
onSubmitAction = function(action: string, data: any)
	print("[Client] Submitting action: " .. action)
	local success, err = Network.SubmitAction:InvokeServer(action, data)
	if not success and err then
		NotificationBanner.Show(err, "warning")
	end
end

-- ============================================================================
-- 4. NETWORK EVENT LISTENERS (Server -> Client)
-- ============================================================================
-- State Changed: Main game loop sync
Network.GameStateChanged.OnClientEvent:Connect(function(payload: any)
	lastKnownPlayers = payload.tableState and payload.tableState.players or {}
	local isMyTurn = (payload.activePlayerId == localPlayer.UserId)
	local myData = payload.tableState and payload.tableState.players[tostring(localPlayer.UserId)]
	local myHand = myData and myData.hand or {}
	local myStackCount = myData and myData.stackCount or 0
	local challengerData = payload.challengerId and payload.tableState.players[tostring(payload.challengerId)]

	-- 1. Update Table View (seats, stack heights, score gems)
	CameraController.SetTurnFocus(isMyTurn)
	TableView.UpdateLayout(payload.tableState.players, payload.activePlayerId, payload.challengerId)
	TableView.UpdateCenter(
		payload.gameState,
		payload.highestBid,
		challengerData and challengerData.name or nil,
		payload.totalCardsOnTable
	)

	-- 2. Update Hand Tray
	local canPlace = (payload.gameState == Enums.GameState.Placement)
	HandBar.UpdateHand(myHand, isMyTurn, canPlace)

	-- 3. Update Action Buttons
	ActionBar.UpdateState(
		isMyTurn,
		payload.gameState,
		payload.highestBid,
		payload.totalCardsOnTable,
		#myHand > 0,
		myStackCount > 0
	)

	-- 4. Turn Timer Reset
	if payload.gameState == Enums.GameState.Placement or payload.gameState == Enums.GameState.Bidding or payload.gameState == Enums.GameState.Revealing then
		NotificationBanner.StartTimer(Constants.TURN_TIMEOUT)
		if isMyTurn and payload.gameState == Enums.GameState.Revealing then
			if myStackCount > 0 then
				NotificationBanner.Show("YOU ARE CHALLENGER: Click YOUR stack to flip your cards first!", "warning")
			else
				NotificationBanner.Show("YOUR STACK IS CLEAR: Click an OPPONENT'S stack to flip!", "warning")
			end
		end
	else
		NotificationBanner.StopTimer()
	end
end)

-- Banner Notifications
Network.Notification.OnClientEvent:Connect(function(data: { text: string, style: string? })
	NotificationBanner.Show(data.text, data.style)
end)

-- Card Played SFX / Alert
Network.CardPlayed.OnClientEvent:Connect(function(playerId: number, stackCount: number)
	-- Animated bounce or sound effect hook
end)

-- Card Revealed (Card flipped by Challenger)
Network.CardRevealed.OnClientEvent:Connect(function(data: any)
	local isSkull = (data.cardType == Enums.CardType.Skull)
	local targetP = lastKnownPlayers[tostring(data.targetUserId)]
	local targetName = targetP and targetP.name or "Player"

	-- Trigger center screen flip animation popup
	CardRevealModal.ShowCard(data.cardType, targetName, data.cardsFlipped, data.targetCards)

	if isSkull then
		CameraController.ShakeOnSkull()
	end

	local msg = isSkull and ("💀 " .. targetName .. "'s SKULL was revealed!") or ("🌹 Rose Revealed from " .. targetName .. " (" .. data.cardsFlipped .. "/" .. data.targetCards .. ")")
	NotificationBanner.Show(msg, isSkull and "alert" or "info")
end)

-- Game Over
Network.GameOver.OnClientEvent:Connect(function(winnerId: number)
	local winner = Players:GetPlayerByUserId(winnerId)
	local name = winner and winner.DisplayName or ("Player " .. winnerId)
	NotificationBanner.Show("👑 " .. name .. " WINS THE MATCH! 👑", "success")
end)

print("[Skulls & Roses] Client ready!")
