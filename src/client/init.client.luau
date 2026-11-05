--!strict
-- init.client.luau
-- Client bootstrapper for Skulls & Roses (Theme A: Calavera / Day of the Dead)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Prevent Roblox engine from destroying PlayerGui on character spawn
pcall(function()
	StarterGui.ResetPlayerGuisOnSpawn = false
end)

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
-- 1. CAMERA CONTROLLER SETUP (LOCOfficial Tabletop Over-the-Shoulder Style)
-- ============================================================================
CameraController.Init()

-- ============================================================================
-- 2. SCREEN GUI & MODULAR UI SETUP (Guaranteed persistence on spawn)
-- ============================================================================
local screenGui: ScreenGui
local onSubmitAction: (action: string, data: any) -> ()
local lastKnownPlayers: { [string]: any } = {}

local function buildUI()
	local existing = playerGui:FindFirstChild("SkullsGui") :: ScreenGui?
	if existing then
		screenGui = existing
		print("[Skulls & Roses] Found existing SkullsGui in PlayerGui.")
		return
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkullsGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- 1. Top Banner & Timer
	NotificationBanner.Create(screenGui)

	-- 2. Center Table & Radial Seats
	TableView.Create(screenGui, function(targetUserId: number)
		onSubmitAction(Enums.PlayerAction.RevealCard, { targetUserId = targetUserId })
	end)

	-- 3. Bottom Hand Tray
	HandBar.Create(screenGui, function(cardType: string)
		print("[HandBar] Selected card: " .. cardType)
		ActionBar.SetSelectedCard(cardType)
	end)

	-- 4. Bottom-Right Action Buttons
	ActionBar.Create(screenGui, function(action: string, data: any)
		if action == Enums.PlayerAction.PlaceCard then
			local selected = HandBar.GetSelectedCard() or Enums.CardType.Rose
			data.cardType = selected
			-- Trigger flying card animation towards player's 3D coaster
			CardAnimation.PlayCardFly(
				screenGui,
				UDim2.new(0.5, 0, 0.85, 0),
				UDim2.new(0.5, 0, 0.55, 0),
				selected
			)
			onSubmitAction(action, data)
		else
			onSubmitAction(action, data)
		end
	end)

	-- 5. Center Card Reveal Popup
	CardRevealModal.Create(screenGui)

	print("[Skulls & Roses] ScreenGui built and parented successfully.")
end

-- Initialize UI immediately
buildUI()

-- Auto-heal UI if character respawns or PlayerGui resets
localPlayer.CharacterAdded:Connect(function()
	task.wait(0.2)
	if not playerGui:FindFirstChild("SkullsGui") then
		print("[Skulls & Roses] Rebuilding ScreenGui after character load...")
		buildUI()
		-- Re-sync state
		Network.RequestState:FireServer()
	end
end)

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
	local ok, err = pcall(function()
		lastKnownPlayers = (payload.tableState and payload.tableState.players) or {}
		local isMyTurn = (payload.activePlayerId == localPlayer.UserId)
		local myData = lastKnownPlayers[tostring(localPlayer.UserId)]
		local myStackCount = myData and myData.stackCount or 0
		local myHand = myData and myData.hand
		if not myHand or #myHand == 0 then
			if myStackCount == 0 then
				myHand = { Enums.CardType.Rose, Enums.CardType.Rose, Enums.CardType.Rose, Enums.CardType.Skull }
			else
				myHand = {}
			end
		end
		local challengerData = payload.challengerId and lastKnownPlayers[tostring(payload.challengerId)]

		-- 1. Update Table View (seats, stack heights, score gems)
		CameraController.SetTurnFocus(isMyTurn)
		TableView.UpdateLayout(lastKnownPlayers, payload.activePlayerId, payload.challengerId)
		TableView.UpdateCenter(
			payload.gameState,
			payload.highestBid or 0,
			challengerData and challengerData.name or nil,
			payload.totalCardsOnTable or 0
		)

		-- 2. Update Hand Tray
		local canPlace = (payload.gameState == Enums.GameState.Placement)
		HandBar.UpdateHand(myHand, isMyTurn, canPlace)

		-- 3. Update Action Buttons
		ActionBar.UpdateState(
			isMyTurn,
			payload.gameState,
			payload.highestBid or 0,
			payload.totalCardsOnTable or 0,
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

	if not ok then
		warn("[Skulls & Roses] Error handling GameStateChanged: " .. tostring(err))
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

-- ============================================================================
-- 5. INITIAL STATE SYNC (Request current game state from server)
-- ============================================================================
task.spawn(function()
	task.wait(0.2)
	print("[Skulls & Roses] Requesting initial game state from server...")
	Network.RequestState:FireServer()

	-- Retry once if state hasn't arrived within 1.5 seconds
	task.wait(1.5)
	if next(lastKnownPlayers) == nil then
		print("[Skulls & Roses] Retrying game state request...")
		Network.RequestState:FireServer()
	end
end)

print("[Skulls & Roses] Client ready!")
