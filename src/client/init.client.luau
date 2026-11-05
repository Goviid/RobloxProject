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

	-- 2. Center Table & Radial Seats
	TableView.Create(screenGui, function(targetUserId: number)
		onSubmitAction(Enums.PlayerAction.RevealCard, { targetUserId = targetUserId })
	end)

	-- 3. Bottom Hand Tray
	HandBar.Create(screenGui, function(cardType: string)
		print("[HandBar] Selected card: " .. cardType)
		AudioController.PlayButtonClick()
		ActionBar.SetSelectedCard(cardType)

		-- Immediate direct placement on card click if it's our turn during Placement phase!
		if currentGameState == Enums.GameState.Placement and isCurrentPlayerTurn then
			print("[HandBar] Directly placing card: " .. cardType)
			AudioController.PlayCardPlace()
			CardAnimation.PlayCardFly(
				screenGui,
				UDim2.new(0.5, 0, 0.82, 0),
				UDim2.new(0.5, 0, 0.52, 0),
				cardType
			)
			onSubmitAction(Enums.PlayerAction.PlaceCard, { cardType = cardType })
		end
	end)

	-- 4. Bottom-Right Action Buttons
	ActionBar.Create(screenGui, function(action: string, data: any)
		AudioController.PlayButtonClick()
		if action == Enums.PlayerAction.PlaceCard then
			local selected = HandBar.GetSelectedCard() or Enums.CardType.Rose
			data.cardType = selected
			AudioController.PlayCardPlace()
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

	-- 6. Match Victory Overlay
	VictoryModal.Create(screenGui)

	-- 7. Pre-populate initial circular hand & bid controls on startup
	local initHand = { Enums.CardType.Rose, Enums.CardType.Rose, Enums.CardType.Rose, Enums.CardType.Skull }
	for i = #initHand, 2, -1 do
		local j = math.random(1, i)
		initHand[i], initHand[j] = initHand[j], initHand[i]
	end
	HandBar.UpdateHand(initHand, true, true)
	ActionBar.UpdateState(true, Enums.GameState.Placement, 0, 0, true, false)

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
		currentGameState = payload.gameState
		isCurrentPlayerTurn = (payload.activePlayerId == localPlayer.UserId)
		local isMyTurn = isCurrentPlayerTurn
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
		if payload.gameState == Enums.GameState.Bidding or payload.gameState == Enums.GameState.Revealing then
			HandBar.SetVisible(false)
		end

		-- 3. Update Action Buttons
		ActionBar.UpdateState(
			isMyTurn,
			payload.gameState,
			payload.highestBid or 0,
			payload.totalCardsOnTable or 0,
			#myHand > 0,
			myStackCount > 0
		)

		-- 4. Turn Timer Reset & Turn Prompt
		if payload.gameState == Enums.GameState.Placement or payload.gameState == Enums.GameState.Bidding or payload.gameState == Enums.GameState.Revealing then
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
	if data.style == "success" or string.find(data.text, "Point scored") then
		AudioController.PlayPointScored()
	end
end)

-- Card Played SFX / Alert
Network.CardPlayed.OnClientEvent:Connect(function(playerId: number, stackCount: number)
	AudioController.PlayCardPlace()
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
