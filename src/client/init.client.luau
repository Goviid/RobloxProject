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
local CardArt = require(ReplicatedStorage.Shared.CardArt)

local StatusBar = require(script.UI.StatusBar)
local Toast = require(script.UI.Toast)
local HandBar = require(script.UI.Hand3D) -- hand as floating 3D cards (old 2D hand: UI.HandBar)
local ActionBar = require(script.UI.ActionBar)
local CardRevealModal = require(script.UI.CardRevealModal)
local VictoryModal = require(script.UI.VictoryModal)
local DiscardModal = require(script.UI.DiscardModal)
local PhaseOverlay = require(script.UI.PhaseOverlay)
local LobbyPanel = require(script.UI.LobbyPanel)
local CardAnimation = require(script.UI.CardAnimation)
local CameraController = require(script.CameraController)
local TableView = require(script.TableView)
local MainMenu = require(script.UI.MainMenu)
local LeaveTable = require(script.UI.LeaveTable)
local PileOutlines = require(script.UI.PileOutlines)
local AudioController = require(script.AudioController)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

print("[Skulls & Roses] Client UI initializing for " .. localPlayer.Name .. "...")

-- ============================================================================
-- 1. CONTROLLERS SETUP (Camera & Audio)
-- ============================================================================
CameraController.Init()
AudioController.Init()

-- Preload all card art and sounds so nothing pops in blank the first time it's used.
-- The loading screen (ReplicatedFirst/LoadingScreen) waits for "ClientReady".
task.spawn(function()
	local assets: { any } = {}
	for _, image in ipairs(CardArt.AllImages()) do
		table.insert(assets, image)
	end
	for _, snd in ipairs(AudioController.GetSounds()) do
		table.insert(assets, snd)
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(assets)
	end)
	localPlayer:SetAttribute("ClientReady", true)
end)

-- ============================================================================
-- 2. SCREEN GUI & MODULAR UI SETUP (Guaranteed persistence on spawn)
-- ============================================================================
local screenGui: ScreenGui
local onSubmitAction: (action: string, data: any) -> (boolean, any)
local lastKnownPlayers: { [string]: any } = {}
local currentGameState: string = Enums.GameState.Placement
local previousGameState: string? = nil
local lastTurnKey: string? = nil -- "<state>:<activeId>" while it's your turn, for the turn cue
local tickThread: thread? = nil -- last-seconds timer ticks
local TICK_SECONDS = 5
local lastLobbyCountdown: number? = nil

local HAND_DOCK_POS = UDim2.fromScale(0.5, 0.86)

-- Per-client view of the shared table: pile outlines as set by the "Piles" pill, and
-- your own fanned hand tokens (rendered by the server for everyone else) hidden from you.
local mySeatIndex: number? = nil

local function hideOwnHandModel(inst: Instance)
	if mySeatIndex and inst.Name == "OpponentHand_" .. mySeatIndex then
		inst:Destroy() -- local only; other players still see it
	end
end

local function applySeatView(seatIndex: number?)
	mySeatIndex = seatIndex
	local arena = TableView.GetArena()
	if not arena then
		return
	end
	PileOutlines.Apply(arena)
	for _, child in ipairs(arena:GetChildren()) do
		hideOwnHandModel(child)
	end
	-- Your own chair sits right under the camera; hide it locally like your own avatar
	-- (chairs are part of the saved world: Workspace.World.Room_<table>.Table.Chair_<seat>)
	local world = workspace:FindFirstChild("World")
	local room = world and world:FindFirstChild("Room_" .. tostring(TableView.GetTableId()))
	local tableModel = room and room:FindFirstChild("Table")
	if tableModel then
		for _, chair in ipairs(tableModel:GetChildren()) do
			local seat = tonumber(string.match(chair.Name, "^Chair_(%d+)$"))
			if seat then
				for _, p in ipairs(chair:GetDescendants()) do
					if p:IsA("BasePart") then
						p.LocalTransparencyModifier = if seat == seatIndex then 1 else 0
					end
				end
			end
		end
	end
end

TableView.OnJoined(function(arena: Model)
	arena.ChildAdded:Connect(hideOwnHandModel)
	PileOutlines.Apply(arena)
end)

-- Hovering a pile (its mat or any of its cards) enlarges that pile's card counter.
-- Mouse only; the counters are readable without it.
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local hoveredPileSeat: number? = nil
local hoverRayParams = RaycastParams.new()
hoverRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function setPileHover(seatIndex: number?, hovered: boolean)
	if not seatIndex then
		return
	end
	local arena = TableView.GetArena()
	local bill = arena and arena:FindFirstChild("PileCount_" .. seatIndex, true)
	local pill = bill and bill:FindFirstChild("Pill")
	local scale = pill and pill:FindFirstChild("HoverScale")
	if scale and scale:IsA("UIScale") then
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = if hovered then 1.35 else 1 }):Play()
	end
end

UserInputService.InputChanged:Connect(function(input: InputObject)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	hoverRayParams.FilterDescendantsInstances = if localPlayer.Character then { localPlayer.Character } else {}
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, hoverRayParams)
	local seat: number? = nil
	if hit then
		local name = hit.Instance.Name
		seat = tonumber(string.match(name, "^PlayerMat_(%d+)$") or string.match(name, "^Card3D_Seat(%d+)_"))
	end
	if seat ~= hoveredPileSeat then
		setPileHover(hoveredPileSeat, false)
		hoveredPileSeat = seat
		setPileHover(seat, true)
	end
end)
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
	screenGui.Enabled = TableView.GetTableId() ~= nil -- hidden while the main menu is up
	screenGui.Parent = playerGui

	-- Big monitors: Roblox draws UI in real pixels, so scale it up on large screens
	-- (never below the designed size). Small screens are handled in the layout itself.
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ScreenScale"
	uiScale.Parent = screenGui
	local function updateScale()
		local camera = workspace.CurrentCamera
		if camera then
			local vp = camera.ViewportSize
			uiScale.Scale = math.clamp(math.min(vp.X / 1600, vp.Y / 900), 1, 1.5)
		end
	end
	updateScale()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	-- Roblox's player list only repeats what the seat tags already show
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	-- 1. Status card (bottom left: phase, whose turn, the one timer) and event pop-ups (above the hand)
	StatusBar.Create(screenGui)
	Toast.Create(screenGui)

	-- 3. Your hand: oversized 3D cards floating at the bottom of the view
	HandBar.SetPileTarget(function(): Vector3?
		local myData = lastKnownPlayers[tostring(localPlayer.UserId)]
		local arena = TableView.GetArena()
		local mat = myData and arena and arena:FindFirstChild("PlayerMat_" .. tostring(myData.seatIndex), true)
		return if mat and mat:IsA("BasePart") then mat.Position + Vector3.new(0, 0.6, 0) else nil
	end)
	HandBar.Create(screenGui, function(cardType: string, cardIndex: number)
		print("[HandBar] Selected card: " .. cardType .. " at idx " .. tostring(cardIndex))
		AudioController.PlayButtonClick()

		-- Immediate direct placement on card click during Placement phase!
		if currentGameState == Enums.GameState.Placement then
			print("[HandBar] Submitting card placement: " .. cardType)
			task.spawn(function()
				local success, err = onSubmitAction(Enums.PlayerAction.PlaceCard, { cardType = cardType })
				if not success then
					Toast.Show(err or "Not your turn to place a card", "warning")
					-- Immediately restore hand by requesting ground-truth state from server
					Network.RequestState:FireServer()
				end
			end)
		else
			Toast.Show("Cards can only be placed before the bidding starts", "info", 1.5)
			Network.RequestState:FireServer()
		end
	end)

	-- 4. Clean Large Bidding Controls
	ActionBar.Create(screenGui, function(action: string, data: any)
		AudioController.PlayButtonClick()
		onSubmitAction(action, data)
	end)

	-- 6. Center Card Reveal Popup
	CardRevealModal.Create(screenGui)

	-- 7. Match Victory Overlay
	VictoryModal.Create(screenGui)

	-- 8. Round intro card + "you're out" pill
	PhaseOverlay.Create(screenGui)

	-- 8b. Pre-match lobby
	LobbyPanel.Create(screenGui, function(action: string, value: any)
		AudioController.PlayButtonClick()
		Network.LobbyAction:FireServer(action, value)
	end)

	-- 9. Skull penalty picker (own skull: pick your card; other's skull: remove one blindly)
	DiscardModal.Create(screenGui, function(pick: { [string]: any })
		AudioController.PlayButtonClick()
		task.spawn(function()
			local success = onSubmitAction(Enums.PlayerAction.DiscardCard, pick)
			if success then
				DiscardModal.Hide()
			else
				DiscardModal.Reset()
			end
		end)
	end)

	-- 10. Leave the table (small corner pill, asks first)
	LeaveTable.Create(screenGui, function()
		AudioController.PlayButtonClick()
		Network.LeaveTable:FireServer()
	end)

	-- 11. Pile outlines on/off (small corner pill next to Leave; off by default)
	PileOutlines.Create(screenGui, function()
		return TableView.GetArena()
	end)

	print("[Skulls & Roses] Fresh SkullsGui built and parented successfully.")
end

-- Initialize UI immediately
buildUI()

-- Seated at the table: the server sets "SeatedAtTable" and removes the Animate script.
-- Stop the looping tracks it already started here (this client plays them for its own
-- character), otherwise the idle sway holds the arms down over the seated pose.
local function watchSeatedPose(character: Model)
	local function stopLoops()
		if character:GetAttribute("SeatedAtTable") ~= true then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Looped then
					track:Stop(0)
				end
			end
		end
	end
	character:GetAttributeChangedSignal("SeatedAtTable"):Connect(stopLoops)
	stopLoops()
end
if localPlayer.Character then
	watchSeatedPose(localPlayer.Character)
end
localPlayer.CharacterAdded:Connect(watchSeatedPose)

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
		AudioController.PlayError()
		if err then
			Toast.Show(err, "warning")
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

		print(string.format("[Client GameStateChanged] State: %s | Active: %s (isMyTurn: %s) | Hand: %d | Stack: %d",
			tostring(payload.gameState), tostring(payload.activePlayerId), tostring(isMyTurn), #myHand, myStackCount))

		-- 1. Camera and per-seat table view
		local seatIndex = myData and tonumber(myData.seatIndex) or nil
		CameraController.SetSeat(seatIndex)
		applySeatView(seatIndex)
		CameraController.SetTurnFocus(isMyTurn)

		-- 2. Update Hand Tray (Remains visible across all phases matching reference)
		local canPlace = (payload.gameState == Enums.GameState.Placement)
		local isNewRound = payload.gameState == Enums.GameState.Placement and previousGameState ~= Enums.GameState.Placement
		HandBar.UpdateHand(myHand, isMyTurn, canPlace, isNewRound, myData and myData.cardSet)
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

		-- 4. Round intro card when a new round's placement begins; spectating pill when eliminated
		if payload.gameState == Enums.GameState.Placement and previousGameState ~= Enums.GameState.Placement then
			PhaseOverlay.ShowRound(payload.roundNumber or 1, activePlayerName, isMyTurn)
			if (payload.roundNumber or 1) == 1 then
				AudioController.PlayMatchStart()
			end
		end

		-- Turn sounds: a cue when your turn starts, ticks over the last seconds of your timer.
		-- The server restarts the timer on every update in a timed phase, so the ticks are
		-- rescheduled on every update too.
		local timedPhase = payload.gameState == Enums.GameState.Placement
			or payload.gameState == Enums.GameState.Bidding
			or payload.gameState == Enums.GameState.Revealing
			or payload.gameState == Enums.GameState.Discarding
		local turnKey = if isMyTurn and timedPhase then payload.gameState .. ":" .. tostring(payload.activePlayerId) else nil
		if turnKey and turnKey ~= lastTurnKey then
			AudioController.PlayYourTurn()
		end
		lastTurnKey = turnKey
		if tickThread then
			task.cancel(tickThread)
			tickThread = nil
		end
		if turnKey then
			tickThread = task.delay(math.max(0, Constants.TURN_TIMEOUT - TICK_SECONDS), function()
				for _ = 1, TICK_SECONDS do
					AudioController.PlayTimerTick()
					task.wait(1)
				end
				tickThread = nil
			end)
		end
		previousGameState = payload.gameState
		local inLobby = payload.gameState == Enums.GameState.Lobby
		local spectateMessage: string? = nil
		if not inLobby and payload.gameState ~= Enums.GameState.MatchEnd then
			if payload.isSeated == false then
				spectateMessage = "👀 Match in progress. You'll get a seat next match"
			elseif myData and myData.isEliminated then
				spectateMessage = "💀 You're out. Watching the rest of the match"
			end
		end
		PhaseOverlay.SetSpectating(spectateMessage)

		-- The lobby panel replaces the in-game controls
		if inLobby then
			HandBar.SetVisible(false)
		end
		local actionRoot = screenGui:FindFirstChild("ActionBarRoot", true)
		if actionRoot and actionRoot:IsA("GuiObject") then
			actionRoot.Visible = not inLobby and payload.isSeated ~= false
		end

		-- 4b. Skull penalty picker (only the chooser gets it)
		local discard = payload.discard
		local isMyDiscard = payload.gameState == Enums.GameState.Discarding
			and discard ~= nil
			and tonumber(discard.chooserId) == localPlayer.UserId
		if isMyDiscard then
			local victimData = lastKnownPlayers[tostring(discard.victimId)]
			DiscardModal.Show(discard, victimData and victimData.name or "the challenger", victimData and victimData.cardSet)
		else
			DiscardModal.Hide()
		end

		-- 5. Status strip: phase, whose turn, the one timer, and one line of context
		local timed = payload.gameState == Enums.GameState.Placement
			or payload.gameState == Enums.GameState.Bidding
			or payload.gameState == Enums.GameState.Revealing
			or payload.gameState == Enums.GameState.Discarding
		if inLobby or payload.gameState == Enums.GameState.MatchEnd then
			StatusBar.Hide()
		else
			local phaseNames = {
				[Enums.GameState.Placement] = "PLACING",
				[Enums.GameState.Bidding] = "BIDDING",
				[Enums.GameState.Revealing] = "CHALLENGE",
				[Enums.GameState.Discarding] = "SKULL PENALTY",
				[Enums.GameState.RoundEnd] = "ROUND OVER",
			}
			local total = payload.totalCardsOnTable or 0
			local info: string? = nil
			if payload.gameState == Enums.GameState.Placement then
				info = if total > 0 then total .. " on the table" else nil
			elseif payload.gameState == Enums.GameState.Bidding then
				local bidder = payload.highestBidderId and lastKnownPlayers[tostring(payload.highestBidderId)]
				local bidderName = if tonumber(payload.highestBidderId) == localPlayer.UserId then "you"
					elseif bidder then bidder.name
					else "?"
				info = "Bid " .. tostring(payload.highestBid or 0) .. " of " .. total .. " (" .. bidderName .. ")"
			elseif payload.gameState == Enums.GameState.Revealing then
				local who = if tonumber(payload.challengerId) == localPlayer.UserId then "You"
					elseif challengerData then challengerData.name
					else "Challenger"
				info = who .. " flipped " .. tostring(payload.cardsFlipped or 0) .. " of " .. tostring(payload.targetCards or 0)
			elseif payload.gameState == Enums.GameState.Discarding and discard then
				local chooserData = lastKnownPlayers[tostring(discard.chooserId)]
				local victimData = lastKnownPlayers[tostring(discard.victimId)]
				local chooserName = chooserData and chooserData.name or "Opponent"
				if isMyDiscard then
					info = if discard.isOwnSkull then "Choose a card to lose" else "Remove one of their cards"
				elseif tonumber(discard.victimId) == localPlayer.UserId then
					info = chooserName .. " is removing one of your cards"
				elseif discard.isOwnSkull then
					info = chooserName .. " is choosing a card to lose"
				else
					info = chooserName .. " is removing a card from " .. (victimData and victimData.name or "the challenger")
				end
			end
			local phase = phaseNames[payload.gameState] or string.upper(tostring(payload.gameState))
			StatusBar.Update({
				phaseText = "ROUND " .. tostring(payload.roundNumber or 1) .. " · " .. phase,
				turnText = if not timed then "" elseif isMyTurn then "YOUR TURN" else activePlayerName,
				isMyTurn = isMyTurn and timed,
				infoText = info,
			})
			if timed then
				StatusBar.StartTimer(Constants.TURN_TIMEOUT)
			else
				StatusBar.StopTimer()
			end
		end
	end)

	if not ok then
		warn("[Skulls & Roses] Error handling GameStateChanged: " .. tostring(err))
	end
end)

-- Server events -> pop-ups. Routine "info" messages (cards placed, round started, rose
-- flips) are already visible in the status strip and on the table, so only passes get a
-- brief pop-up; bids, skulls, timeouts, points and wins always do.
Network.Notification.OnClientEvent:Connect(function(data: { text: string, style: string? })
	local style = data.style or "info"
	if style ~= "info" then
		Toast.Show(data.text, style)
	elseif string.find(data.text, " passed", 1, true) then
		Toast.Show(data.text, "info", 1.4)
	end
	if string.find(data.text, "Point scored", 1, true) then
		AudioController.PlayPointScored()
	end
end)

-- Bids: the server's "raised the bid" notification shows the pop-up; the status strip
-- shows the current bid, so BidUpdated needs no extra UI.

-- Card Played SFX / Alert
Network.CardPlayed.OnClientEvent:Connect(function(_playerId: number, _stackCount: number)
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
	CardRevealModal.ShowCard(data.cardType, targetName, data.cardsFlipped, data.targetCards, targetP and targetP.cardSet)

	if isSkull then
		CameraController.ShakeOnSkull()
	end

end)

-- Private: which card I lost to a skull penalty (only the victim receives this)
Network.CardLost.OnClientEvent:Connect(function(data: any)
	local cardName = data and data.cardType == Enums.CardType.Skull and "your SKULL 💀" or "a ROSE 🌹"
	Toast.Show("You lost " .. cardName .. "!", "alert")
	-- The lost card flies off the top of the screen
	if data and data.cardType then
		local myData = lastKnownPlayers[tostring(localPlayer.UserId)]
		CardAnimation.PlayCardFly(screenGui, HAND_DOCK_POS, UDim2.fromScale(0.5, -0.15), data.cardType, myData and myData.cardSet)
	end
end)

-- Lobby (seats, ready check, countdown, host controls)
Network.LobbyState.OnClientEvent:Connect(function(state: any)
	LobbyPanel.Update(state, localPlayer.UserId)
	local countdown = state and state.inLobby and tonumber(state.countdown) or nil
	if countdown and countdown ~= lastLobbyCountdown then
		AudioController.PlayTimerTick()
	end
	lastLobbyCountdown = countdown
end)

-- Elimination sting for the player who just lost their last card
Network.PlayerEliminated.OnClientEvent:Connect(function(userId: number)
	if userId == localPlayer.UserId then
		AudioController.PlayEliminated()
	end
end)

-- Game Over
Network.GameOver.OnClientEvent:Connect(function(winnerId: number, reason: string?, duration: number?)
	local pData = lastKnownPlayers[tostring(winnerId)]
	local winner = Players:GetPlayerByUserId(winnerId)
	local name = (pData and pData.name) or (winner and winner.DisplayName) or ("Player " .. winnerId)
	AudioController.PlayVictory()
	VictoryModal.Show(name, winnerId == localPlayer.UserId, reason, duration)
end)

-- ============================================================================
-- 5. MAIN MENU, THEN INITIAL STATE SYNC (once the player has picked a table)
-- ============================================================================
if not TableView.GetTableId() then
	MainMenu.Show(playerGui)
end

-- Left the table: forget it, rebuild the game UI fresh (hidden) and show the menu again
TableView.OnLeft(function()
	lastKnownPlayers = {}
	lastTurnKey = nil
	lastLobbyCountdown = nil
	HandBar.UpdateHand({}, false, false)
	CameraController.SetSeat(nil)
	CameraController.SetTurnFocus(false)
	mySeatIndex = nil
	buildUI()
	MainMenu.Show(playerGui)
end)

TableView.OnJoined(function()
	screenGui.Enabled = true
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
