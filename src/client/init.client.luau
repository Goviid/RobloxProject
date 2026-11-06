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
local ChatBox = require(script.UI.ChatBox)
local CardRevealModal = require(script.UI.CardRevealModal)
local VictoryModal = require(script.UI.VictoryModal)
local CardAnimation = require(script.UI.CardAnimation)
local CameraController = require(script.CameraController)
local AudioController = require(script.AudioController)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

print("[Skulls & Roses] Client UI initializing for " .. localPlayer.Name .. "...")

-- ============================================================================
-- 1. CONTROLLERS SETUP (Camera & Audio)
-- ============================================================================
CameraController.Init()
AudioController.Init()

-- ============================================================================
-- 2. SCREEN GUI & MODULAR UI SETUP (Guaranteed persistence on spawn)
-- ============================================================================
local screenGui: ScreenGui
local onSubmitAction: (action: string, data: any) -> ()
local lastKnownPlayers: { [string]: any } = {}
local currentGameState: string = Enums.GameState.Placement
local isCurrentPlayerTurn: boolean = true

local function buildUI()
	local existing = playerGui:FindFirstChild("SkullsGui") :: ScreenGui?
	if existing then
		existing:Destroy()
	end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SkullsGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	-- 1. Top Banner & Timer
	NotificationBanner.Create(screenGui)

	-- 2. Center Match Announcements
	TableView.Create(screenGui, function(targetUserId: number)
		onSubmitAction(Enums.PlayerAction.RevealCard, { targetUserId = targetUserId })
	end)

	-- 3. Bottom Hand Tray (Oversized, raised 2.5D circular hand)
	HandBar.Create(screenGui, function(cardType: string, cardIndex: number)
		print("[HandBar] Selected card: " .. cardType .. " at idx " .. tostring(cardIndex))
		AudioController.PlayButtonClick()

		-- Immediate direct placement on card click during Placement phase!
		if currentGameState == Enums.GameState.Placement then
			print("[HandBar] Submitting card placement: " .. cardType)
			task.spawn(function()
				local success, err = onSubmitAction(Enums.PlayerAction.PlaceCard, { cardType = cardType })
				if success then
					AudioController.PlayCardPlace()
				else
					NotificationBanner.Show(err or "Not your turn to place a card!", "warning")
				end
			end)
		else
			NotificationBanner.Show("Cards can only be placed during Placement Phase!", "warning")
		end
	end)

	-- 4. Clean Large Bidding Controls
	ActionBar.Create(screenGui, function(action: string, data: any)
		AudioController.PlayButtonClick()
		onSubmitAction(action, data)
	end)

	-- 5. Translucent Roblox-style 2D Chat Box (Top-Left)
	ChatBox.Create(screenGui)

	-- 6. Center Card Reveal Popup
	CardRevealModal.Create(screenGui)

	-- 7. Match Victory Overlay
	VictoryModal.Create(screenGui)

	-- 7. Pre-populate initial circular hand & bid controls on startup (Roses left, Skull right)
	local initHand = { Enums.CardType.Rose, Enums.CardType.Rose, Enums.CardType.Rose, Enums.CardType.Skull }
	HandBar.UpdateHand(initHand, true, true)
	ActionBar.UpdateState(true, Enums.GameState.Placement, 0, 0, true, false, false)

	print("[Skulls & Roses] Fresh SkullsGui built and parented successfully.")
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
onSubmitAction = function(action: string, data: any): (boolean, any)
	print("[Client] Submitting action: " .. action)
	local success, err = Network.SubmitAction:InvokeServer(action, data)
	if not success then
		warn("[Client] Action '" .. action .. "' was rejected: " .. tostring(err))
		if err then
			NotificationBanner.Show(err, "warning")
		end
		-- Re-sync state with server if action was rejected
		Network.RequestState:FireServer()
	else
		print("[Client] Action confirmed by server: " .. action)
	end
	return success, err
end

-- ============================================================================
-- 4. NETWORK EVENT LISTENERS (Server -> Client)
-- ============================================================================
-- State Changed: Main game loop sync
Network.GameStateChanged.OnClientEvent:Connect(function(payload: any)
	local ok, err = pcall(function()
		lastKnownPlayers = (payload.tableState and payload.tableState.players) or {}
		currentGameState = payload.gameState
		isCurrentPlayerTurn = (tonumber(payload.activePlayerId) ~= nil and tonumber(payload.activePlayerId) == tonumber(localPlayer.UserId))
		local isMyTurn = isCurrentPlayerTurn
		local myData = lastKnownPlayers[tostring(localPlayer.UserId)] or lastKnownPlayers[localPlayer.UserId]
		local myStackCount = myData and myData.stackCount or 0
		local myHand = if myData and myData.hand then table.clone(myData.hand) else {}
		table.sort(myHand, function(a, b)
			return a == Enums.CardType.Rose and b == Enums.CardType.Skull
		end)
		local challengerData = payload.challengerId and lastKnownPlayers[tostring(payload.challengerId)]

		local activePlayerData = payload.activePlayerId and lastKnownPlayers[tostring(payload.activePlayerId)]
		local activePlayerName = activePlayerData and activePlayerData.name or "Opponent"
		local activeStackCount = activePlayerData and activePlayerData.stackCount or 0
		-- Turn number is based on active player's stack count so it reflects the true current turn
		local turnNumber = math.max(1, activeStackCount + 1)

		print(string.format("[Client GameStateChanged] State: %s | Active: %s (isMyTurn: %s) | Hand: %d | Stack: %d",
			tostring(payload.gameState), tostring(payload.activePlayerId), tostring(isMyTurn), #myHand, myStackCount))

		-- Determine left pill override based on phase
		local pillOverride = nil
		if payload.gameState == Enums.GameState.Bidding then
			pillOverride = "BID: " .. tostring(payload.highestBid or 1)
		elseif payload.gameState == Enums.GameState.Revealing then
			pillOverride = "FLIPS: " .. tostring(payload.cardsFlipped or 0) .. "/" .. tostring(payload.targetCards or 1)
		end

		-- 1. Update Table View (seats, stack heights, score gems)
		CameraController.SetTurnFocus(isMyTurn)
		TableView.UpdateLayout(lastKnownPlayers, payload.activePlayerId, payload.challengerId)
		TableView.UpdateTurn(turnNumber, activePlayerName, isMyTurn, pillOverride)
		TableView.UpdateCenter(
			payload.gameState,
			payload.highestBid or 0,
			challengerData and challengerData.name or nil,
			payload.totalCardsOnTable or 0
		)

		-- 2. Update Hand Tray (Remains visible across all phases matching reference)
		local canPlace = (payload.gameState == Enums.GameState.Placement)
		HandBar.UpdateHand(myHand, isMyTurn, canPlace)
		HandBar.SetVisible(#myHand > 0)

		-- 3. Update Action Buttons
		ActionBar.UpdateState(
			isMyTurn,
			payload.gameState,
			payload.highestBid or 0,
			payload.totalCardsOnTable or 0,
			#myHand > 0,
			myStackCount > 0,
			payload.canStartBid
		)

		-- 4. Turn Timer Reset & Turn Prompt
		if payload.gameState == Enums.GameState.Placement or payload.gameState == Enums.GameState.Bidding or payload.gameState == Enums.GameState.Revealing then
			TableView.StartTurnTimer(Constants.TURN_TIMEOUT)
			NotificationBanner.StartTimer(Constants.TURN_TIMEOUT)
			if isMyTurn then
				if payload.gameState == Enums.GameState.Placement then
					NotificationBanner.Show("👉 YOUR TURN: Choose a card from your hand to place!", "info")
				elseif payload.gameState == Enums.GameState.Bidding then
					NotificationBanner.Show("👉 YOUR TURN: Raise your bid or Pass!", "info")
				elseif payload.gameState == Enums.GameState.Revealing then
					if myStackCount > 0 then
						NotificationBanner.Show("YOU ARE CHALLENGER: Click YOUR stack to flip your cards first!", "warning")
					else
						NotificationBanner.Show("YOUR STACK IS CLEAR: Click an OPPONENT'S stack to flip!", "warning")
					end
				end
			end
		else
			TableView.StopTurnTimer()
			NotificationBanner.StopTimer()
		end
	end)

	if not ok then
		warn("[Skulls & Roses] Error handling GameStateChanged: " .. tostring(err))
	end
end)

-- Banner & Top HUD Notifications
Network.Notification.OnClientEvent:Connect(function(data: { text: string, style: string? })
	NotificationBanner.Show(data.text, data.style)
	ChatBox.AddMessage("SYSTEM", data.text, "#FFD23F")
	if data.style == "success" or string.find(data.text, "Point scored") then
		AudioController.PlayPointScored()
	end
end)

-- Live Bid Updates (e.g. "BLUFFER_99 raised the bid to 3!")
Network.BidUpdated.OnClientEvent:Connect(function(bidderId: number, bid: number)
	local p = lastKnownPlayers[tostring(bidderId)]
	local pName = p and p.name or ("Player " .. bidderId)
	local msg = pName .. " raised the bid to " .. bid .. "!"
	TableView.SetAlertText(msg)
	ChatBox.AddMessage(pName, "raised the bid to " .. bid .. "!", "#FFD23F")
end)

-- Card Played SFX / Alert
Network.CardPlayed.OnClientEvent:Connect(function(playerId: number, stackCount: number)
	AudioController.PlayCardPlace()
	local p = lastKnownPlayers[tostring(playerId)]
	local pName = p and p.name or ("Player " .. playerId)
	ChatBox.AddMessage(pName, "placed a card face-down.", "#4ECCA3")
end)

-- Card Revealed (Card flipped by Challenger)
Network.CardRevealed.OnClientEvent:Connect(function(data: any)
	local isSkull = (data.cardType == Enums.CardType.Skull)
	local targetP = lastKnownPlayers[tostring(data.targetUserId)]
	local targetName = targetP and targetP.name or "Player"

	-- Sound effects
	AudioController.PlayCardFlip()
	if isSkull then
		task.delay(0.12, function()
			AudioController.PlaySkullReveal()
		end)
	else
		task.delay(0.12, function()
			AudioController.PlayRoseReveal()
		end)
	end

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
	AudioController.PlayVictory()
	VictoryModal.Show(name, winnerId == localPlayer.UserId)
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
