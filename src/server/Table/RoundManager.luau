--!strict
-- RoundManager.luau
-- Core state machine and rule arbiter for Skulls & Roses matches

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerManager = require(script.Parent.PlayerManager)
local BotController = require(script.Parent.BotController)
local Card3DManager = require(script.Parent.Card3DManager)
local TableBuilder = require(script.Parent.TableBuilder)
local TableContext = require(script.Parent.TableContext)

local RoundManager = {}

-- Round State Variables
local currentGameState = Enums.GameState.Lobby
local activePlayerIndex = 1
local challengerId: number? = nil
local highestBid = 0
local highestBidderId: number? = nil
local cardsFlippedThisRound = 0
local targetCardsToFlip = 0
local roundLeaderId: number? = nil -- Starting player for the round
local currentRoundNumber = 1

type PendingDiscard = {
	victimId: number,      -- challenger who hit the skull
	chooserId: number,     -- who picks the card (challenger on own skull, else skull owner)
	skullOwnerId: number,
	isOwnSkull: boolean,
	cards: { string },     -- victim's cards, shuffled; SECRET for blind picks
}
local pendingDiscard: PendingDiscard? = nil

-- Called when a match is over (winner shown) or can't continue; the lobby takes over
local matchOverHandler: (() -> ())? = nil

local turnTimerThread: thread? = nil
local botTurnThread: thread? = nil
local turnLock = false

local function broadcastState()
	for _, p in pairs(PlayerManager.GetAllPlayers()) do
		TableBuilder.SetSeatCardSet(p.seatIndex, p.cardSet)
		TableBuilder.UpdateScore(p.seatIndex, p.score)
		TableBuilder.UpdateCardCount(p.seatIndex, #p.hand, #p.hand + #p.playedStack + #p.revealedCards)
		TableBuilder.SetEliminated(p.seatIndex, p.isEliminated)
		local emphasis = currentGameState == Enums.GameState.Bidding
			or currentGameState == Enums.GameState.Revealing
			or currentGameState == Enums.GameState.Discarding
		TableBuilder.UpdatePileCount(p.seatIndex, if p.isEliminated then 0 else #p.playedStack, emphasis)
	end
	-- Everyone at this table gets state, including players waiting for the next match
	for _, plr in ipairs(TableContext.GetPlayers()) do
		RoundManager.SendStateToPlayer(plr.UserId)
	end

	local activeId = RoundManager.GetActivePlayerId()
	local activePlayer = activeId and PlayerManager.GetPlayer(activeId)
	local inLobby = currentGameState == Enums.GameState.Lobby
	TableBuilder.HighlightTurn(if not inLobby and activePlayer then activePlayer.seatIndex else nil)
end

-- Check if everyone has played at least 1 card
local function haveAllPlacedFirstCard(): boolean
	for _, p in ipairs(PlayerManager.GetActivePlayers()) do
		if #p.playedStack == 0 then
			return false
		end
	end
	return true
end

function RoundManager.SendStateToPlayer(userId: number)
	local p = PlayerManager.GetPlayer(userId)
	if p and p.isBot then
		return
	end
	local playerObj = Players:GetPlayerByUserId(userId)
	if not playerObj then
		return
	end

	local payload = {
		gameState = currentGameState,
		isSeated = p ~= nil, -- false: waiting for the next match (spectating)
		roundNumber = currentRoundNumber,
		activePlayerId = RoundManager.GetActivePlayerId(),
		challengerId = challengerId,
		highestBid = highestBid,
		highestBidderId = highestBidderId,
		cardsFlipped = cardsFlippedThisRound,
		targetCards = targetCardsToFlip,
		totalCardsOnTable = PlayerManager.GetTotalCardsOnTable(),
		canStartBid = haveAllPlacedFirstCard(),
		discard = RoundManager.GetDiscardInfo(userId),
		tableState = PlayerManager.GetClientState(userId),
	}
	Network.GameStateChanged:FireClient(playerObj, payload)
end

local function broadcastNotification(text: string, style: string?)
	TableContext.FireAll(Network.Notification, {
		text = text,
		style = style or "info", -- "info", "warning", "success", "alert"
	})
end

-- Client-safe view of the pending skull penalty. Card types are only sent to the
-- challenger choosing among their own cards; a blind chooser only gets the count.
function RoundManager.GetDiscardInfo(forUserId: number): any
	local discard = pendingDiscard
	if not discard or currentGameState ~= Enums.GameState.Discarding then
		return nil
	end
	local seesCards = discard.isOwnSkull and forUserId == discard.victimId
	local cards: { string }? = nil
	if seesCards then
		local sorted = table.clone(discard.cards)
		table.sort(sorted, function(a, b)
			return a == Enums.CardType.Rose and b == Enums.CardType.Skull
		end)
		cards = sorted
	end
	return {
		chooserId = discard.chooserId,
		victimId = discard.victimId,
		isOwnSkull = discard.isOwnSkull,
		cardCount = #discard.cards,
		cards = cards,
	}
end

function RoundManager.GetGameState()
	return currentGameState
end

function RoundManager.GetActivePlayerId(): number?
	local active = PlayerManager.GetActivePlayers()
	if #active == 0 then
		return nil
	end
	local p = active[activePlayerIndex]
	return p and p.userId or nil
end

local function advanceToNextActivePlayer(skipPassed: boolean?)
	local active = PlayerManager.GetActivePlayers()
	if #active == 0 then
		return
	end

	local curId = RoundManager.GetActivePlayerId()
	local curIdx = 1
	if curId then
		for idx, p in ipairs(active) do
			if p.userId == curId then
				curIdx = idx
				break
			end
		end
	else
		curIdx = math.clamp(activePlayerIndex, 1, #active)
	end

	local oldIdx = curIdx
	local count = #active
	local nextIdx = (curIdx % count) + 1

	if skipPassed then
		local attempts = 0
		while attempts < count do
			local candidate = active[nextIdx]
			if candidate and not candidate.isEliminated and not candidate.hasPassedBid then
				break
			end
			nextIdx = (nextIdx % count) + 1
			attempts += 1
		end
	else
		local attempts = 0
		while attempts < count do
			local candidate = active[nextIdx]
			if candidate and not candidate.isEliminated then
				break
			end
			nextIdx = (nextIdx % count) + 1
			attempts += 1
		end
	end

	activePlayerIndex = nextIdx
	local nextP = active[activePlayerIndex]
	print(string.format("[Server RoundManager] Advanced turn from index %d (%s) to index %d (%s) [Total active: %d]",
		oldIdx, curId and tostring(curId) or "nil",
		activePlayerIndex, nextP and nextP.name or "nil",
		#active))
end

local function cancelTurnTimer()
	if turnTimerThread then
		local thread = turnTimerThread
		turnTimerThread = nil
		if coroutine.running() ~= thread then
			pcall(task.cancel, thread)
		end
	end
	if botTurnThread then
		local thread = botTurnThread
		botTurnThread = nil
		if coroutine.running() ~= thread then
			pcall(task.cancel, thread)
		end
	end
end

-- Forward declaration
local runCurrentTurn: () -> ()

-- Delayed round/match transitions. Bumping the token (new round, lobby, match end)
-- cancels any transition scheduled before it, so a stale "next round" never fires.
local transitionToken = 0
local function scheduleTransition(fn: () -> ())
	local token = transitionToken
	task.delay(Constants.ROUND_TRANSITION_DELAY, function()
		if token == transitionToken then
			fn()
		end
	end)
end

local function onTurnTimeout()
	turnTimerThread = nil -- Timer already executed

	-- Skull penalty: pick a random card for the chooser (works even if they left)
	local discard = pendingDiscard
	if currentGameState == Enums.GameState.Discarding and discard then
		local chooser = PlayerManager.GetPlayer(discard.chooserId)
		broadcastNotification((chooser and chooser.name or "Player") .. " ran out of time! A random card is removed.", "warning")
		local index = math.random(1, #discard.cards)
		RoundManager.HandlePlayerAction(discard.chooserId, Enums.PlayerAction.DiscardCard, { index = index, cardType = discard.cards[index] })
		return
	end
	local activeId = RoundManager.GetActivePlayerId()
	if not activeId then
		return
	end
	local p = PlayerManager.GetPlayer(activeId)
	if not p then
		return
	end

	broadcastNotification(p.name .. " ran out of time!", "warning")

	-- Auto-action depending on phase
	if currentGameState == Enums.GameState.Placement then
		-- If player has cards, auto-place Rose or Skull
		if #p.hand > 0 then
			local cardToPlace = table.find(p.hand, Enums.CardType.Rose) and Enums.CardType.Rose or Enums.CardType.Skull
			RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.PlaceCard, { cardType = cardToPlace })
		else
			-- No cards left, auto-bid 1
			RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.StartBid, { bid = 1 })
		end
	elseif currentGameState == Enums.GameState.Bidding then
		-- Auto-pass
		RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.Pass, {})
	elseif currentGameState == Enums.GameState.Revealing then
		-- Auto-reveal own card first or random opponent
		local targetId = BotController.DecideCardToReveal(activeId, challengerId or activeId)
		if targetId then
			RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.RevealCard, { targetUserId = targetId })
		end
	end
end

local function startTurnTimer()
	cancelTurnTimer()
	turnTimerThread = task.delay(Constants.TURN_TIMEOUT, onTurnTimeout)
end

-- Execute Bot actions if active player is a Bot
local function checkBotTurn()
	local activeId = RoundManager.GetActivePlayerId()
	if not activeId then
		return
	end
	local p = PlayerManager.GetPlayer(activeId)
	if not p or not p.isBot or p.isEliminated then
		return
	end

	if botTurnThread then
		local thread = botTurnThread
		botTurnThread = nil
		if coroutine.running() ~= thread then
			pcall(task.cancel, thread)
		end
	end

	-- Bots pause before acting so human players can follow what is happening
	botTurnThread = task.delay(Constants.BOT_THINK_DELAY, function()
		botTurnThread = nil
		if RoundManager.GetActivePlayerId() ~= activeId then
			return
		end

		if currentGameState == Enums.GameState.Placement then
			local canBid = haveAllPlacedFirstCard()
			local decision = BotController.DecidePlacementAction(activeId, canBid, PlayerManager.GetTotalCardsOnTable())
			if decision then
				local ok = RoundManager.HandlePlayerAction(activeId, decision.action, decision)
				if not ok and #p.hand > 0 then
					local cardToPlace = table.find(p.hand, Enums.CardType.Rose) and Enums.CardType.Rose or Enums.CardType.Skull
					RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.PlaceCard, { cardType = cardToPlace })
				end
			elseif #p.hand > 0 then
				local cardToPlace = table.find(p.hand, Enums.CardType.Rose) and Enums.CardType.Rose or Enums.CardType.Skull
				RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.PlaceCard, { cardType = cardToPlace })
			end
		elseif currentGameState == Enums.GameState.Bidding then
			local decision = BotController.DecideBiddingAction(activeId, highestBid, PlayerManager.GetTotalCardsOnTable())
			if decision then
				RoundManager.HandlePlayerAction(activeId, decision.action, decision)
			else
				RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.Pass, {})
			end
		elseif currentGameState == Enums.GameState.Revealing then
			local targetId = BotController.DecideCardToReveal(activeId, challengerId or activeId)
			if targetId then
				RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.RevealCard, { targetUserId = targetId })
			end
		elseif currentGameState == Enums.GameState.Discarding then
			local discard = pendingDiscard
			if discard and discard.chooserId == activeId then
				-- Bots only see card types when discarding from their own cards
				local pick = BotController.DecideDiscard(discard.isOwnSkull, discard.isOwnSkull and discard.cards or nil, #discard.cards)
				RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.DiscardCard, pick)
			end
		end
	end)
end

runCurrentTurn = function()
	local activeId = RoundManager.GetActivePlayerId()
	if not activeId then
		return
	end
	local p = PlayerManager.GetPlayer(activeId)
	if not p then
		return
	end

	broadcastState()
	startTurnTimer()
	checkBotTurn()
end

-- TRANSITION: Start a brand-new round
function RoundManager.StartRound(leaderId: number?)
	transitionToken += 1
	cancelTurnTimer()
	pendingDiscard = nil
	PlayerManager.ResetRoundState()
	Card3DManager.ClearAllCards()
	Card3DManager.SetRevealingEnabled(false)

	challengerId = nil
	highestBid = 0
	highestBidderId = nil
	cardsFlippedThisRound = 0
	targetCardsToFlip = 0

	local active = PlayerManager.GetActivePlayers()
	if #active < Constants.MIN_PLAYERS then
		broadcastNotification("Not enough players to continue. Back to the lobby.", "info")
		if matchOverHandler then
			matchOverHandler()
		else
			currentGameState = Enums.GameState.Lobby
			broadcastState()
		end
		return
	end

	-- Determine seat index of starting player
	local leaderData = leaderId and PlayerManager.GetPlayer(leaderId)
	if leaderId and leaderData and not leaderData.isEliminated then
		roundLeaderId = leaderId
		currentRoundNumber += 1
	else
		currentRoundNumber = 1
		-- Prefer human player for round 1 so they can immediately play
		local human = nil
		for _, p in ipairs(active) do
			if not p.isBot then
				human = p
				break
			end
		end
		roundLeaderId = human and human.userId or active[1].userId
	end

	-- Set active index to round leader
	for idx, p in ipairs(active) do
		if p.userId == roundLeaderId then
			activePlayerIndex = idx
			break
		end
	end

	currentGameState = Enums.GameState.Placement
	local leader = PlayerManager.GetPlayer(roundLeaderId or 0)
	broadcastNotification("New Round Started! " .. (leader and leader.name or "Player") .. "'s turn to place.", "info")

	runCurrentTurn()
end

-- Check how many bidders remain active
local function getActiveBidderCount(): number
	local count = 0
	for _, p in ipairs(PlayerManager.GetActivePlayers()) do
		if not p.hasPassedBid then
			count += 1
		end
	end
	return count
end

-- End the match: show the winner on every client for MATCH_OVER_DELAY, then start a fresh match
local function declareMatchWinner(winnerId: number, reason: string)
	transitionToken += 1
	local token = transitionToken
	cancelTurnTimer()
	pendingDiscard = nil
	currentGameState = Enums.GameState.MatchEnd
	local winner = PlayerManager.GetPlayer(winnerId)
	broadcastNotification("👑 " .. (winner and winner.name or "Player") .. " WINS THE MATCH! 👑", "success")
	if winner then
		TableBuilder.PlayReaction(winner.seatIndex, "Dance", Constants.MATCH_OVER_DELAY - 1)
	end
	TableContext.FireAll(Network.GameOver, winnerId, reason, Constants.MATCH_OVER_DELAY)
	broadcastState()

	task.delay(Constants.MATCH_OVER_DELAY, function()
		if token ~= transitionToken then
			return
		end
		if matchOverHandler then
			matchOverHandler()
		else
			PlayerManager.ResetMatch()
			RoundManager.StartRound()
		end
	end)
end

-- ============================================================================
-- MATCH LIFECYCLE (driven by LobbyManager)
-- ============================================================================
function RoundManager.SetMatchOverHandler(handler: () -> ())
	matchOverHandler = handler
end

function RoundManager.StartMatch()
	PlayerManager.ResetMatch()
	PlayerManager.AssignCardSets()
	RoundManager.StartRound()
end

-- Stop any match in progress and sit in the Lobby state
function RoundManager.EnterLobby()
	transitionToken += 1
	cancelTurnTimer()
	pendingDiscard = nil
	challengerId = nil
	highestBid = 0
	highestBidderId = nil
	cardsFlippedThisRound = 0
	targetCardsToFlip = 0
	currentRoundNumber = 1
	Card3DManager.ClearAllCards()
	Card3DManager.SetRevealingEnabled(false)
	currentGameState = Enums.GameState.Lobby
	broadcastState()
end

-- A seated player left (already removed from PlayerManager). Keep the match playable.
function RoundManager.OnPlayerLeft(name: string)
	if currentGameState == Enums.GameState.Lobby or currentGameState == Enums.GameState.MatchEnd then
		broadcastState()
		return
	end
	local active = PlayerManager.GetActivePlayers()
	if #active == 1 then
		declareMatchWinner(active[1].userId, "Everyone else left!")
		return
	end
	if #active == 0 then
		if matchOverHandler then
			matchOverHandler()
		end
		return
	end
	-- Restart the round without them (cards go back to hands), next player in seat order leads
	broadcastNotification(name .. " left the game. Restarting the round.", "warning")
	local leader = active[math.clamp(activePlayerIndex, 1, #active)]
	RoundManager.StartRound(leader.userId)
end

-- Resolve Round Success (Challenger flipped target roses)
local function onChallengerSuccess()
	cancelTurnTimer()
	Card3DManager.SetRevealingEnabled(false)
	currentGameState = Enums.GameState.RoundEnd

	if not challengerId then
		return
	end
	local challenger = PlayerManager.GetPlayer(challengerId)
	if not challenger then
		return
	end

	challenger.score += 1
	TableBuilder.PlayReaction(challenger.seatIndex, "Cheer")
	broadcastNotification("🎉 " .. challenger.name .. " successfully flipped " .. targetCardsToFlip .. " Roses! Point scored!", "success")
	if challenger.isBot then
		pcall(function()
			TableBuilder.SetBotEmote(challenger.seatIndex, "🎉")
		end)
		task.delay(3.0, function()
			pcall(function()
				TableBuilder.SetBotEmote(challenger.seatIndex, "🤠")
			end)
		end)
	end
	broadcastState()

	-- Check Victory
	if challenger.score >= Constants.POINTS_TO_WIN then
		local winnerId = challenger.userId
		scheduleTransition(function()
			declareMatchWinner(winnerId, "First to " .. Constants.POINTS_TO_WIN .. " points!")
		end)
	else
		-- Next round starts with the victorious challenger
		local nextLeaderId = challengerId
		scheduleTransition(function()
			RoundManager.StartRound(nextLeaderId)
		end)
	end
end

-- Skull penalty (classic rules):
--   own skull       -> the challenger picks which of their own cards to lose (sees them)
--   another's skull -> the skull owner removes one of the challenger's cards blindly
-- `cards` is the challenger's full card set (hand + stack + revealed), shuffled once so a
-- blind index maps to a fixed hidden card. It never leaves the server for a blind pick.
local function setActivePlayer(userId: number)
	for idx, player in ipairs(PlayerManager.GetActivePlayers()) do
		if player.userId == userId then
			activePlayerIndex = idx
			return
		end
	end
end

local function finishChallengerFailed(lostCard: string?)
	local discard = pendingDiscard
	if not discard then
		return
	end
	pendingDiscard = nil
	cancelTurnTimer()
	currentGameState = Enums.GameState.RoundEnd

	local victimId = discard.victimId
	local challenger = PlayerManager.GetPlayer(victimId)
	if not challenger then
		-- Challenger left mid-penalty: just move on
		scheduleTransition(function()
			RoundManager.StartRound(discard.skullOwnerId)
		end)
		return
	end

	Card3DManager.BurnCard(challenger.seatIndex)

	local chooser = PlayerManager.GetPlayer(discard.chooserId)
	if discard.isOwnSkull then
		broadcastNotification("💀 " .. challenger.name .. " discarded a card.", "alert")
	else
		broadcastNotification("💀 " .. (chooser and chooser.name or "Skull owner") .. " removed one of " .. challenger.name .. "'s cards.", "alert")
	end

	-- Only the victim learns which card they lost
	local victimPlayer = Players:GetPlayerByUserId(victimId)
	if victimPlayer and lostCard then
		Network.CardLost:FireClient(victimPlayer, { cardType = lostCard })
	end

	if challenger.isEliminated then
		broadcastNotification("❌ " .. challenger.name .. " has no cards left and is ELIMINATED!", "alert")
		TableContext.FireAll(Network.PlayerEliminated, victimId)
	end

	if challenger.isBot then
		pcall(function()
			TableBuilder.SetBotEmote(challenger.seatIndex, "😱")
		end)
		task.delay(3.0, function()
			pcall(function()
				TableBuilder.SetBotEmote(challenger.seatIndex, "🤠")
			end)
		end)
	end

	broadcastState()

	-- Classic rule: the last player with cards left wins the match
	local remaining = PlayerManager.GetActivePlayers()
	if challenger.isEliminated and #remaining == 1 then
		local lastId = remaining[1].userId
		scheduleTransition(function()
			declareMatchWinner(lastId, "Last player standing!")
		end)
		return
	end

	-- Next round leader:
	-- If challenger hit own skull -> challenger starts next round (if not eliminated).
	-- If challenger hit someone else's skull -> skull owner starts next round!
	local nextLeader: number? = discard.isOwnSkull and victimId or discard.skullOwnerId
	local leaderData = PlayerManager.GetPlayer(nextLeader or 0)
	if not leaderData or leaderData.isEliminated then
		nextLeader = nil
	end

	scheduleTransition(function()
		RoundManager.StartRound(nextLeader)
	end)
end

-- Validate and apply a discard pick. `pick` is { cardType = ... } (own skull) or { index = n } (blind).
local function resolveDiscard(pick: any): (boolean, string?)
	local discard = pendingDiscard
	if not discard then
		return false, "No card to discard right now."
	end

	local cardType: string?
	if discard.isOwnSkull then
		local wanted = type(pick) == "table" and pick.cardType or nil
		if type(wanted) ~= "string" or not table.find(discard.cards, wanted) then
			return false, "Pick one of your cards."
		end
		cardType = wanted
	else
		local index = type(pick) == "table" and tonumber(pick.index) or nil
		if not index or index ~= math.floor(index) or index < 1 or index > #discard.cards then
			return false, "Pick one of the face-down cards."
		end
		cardType = discard.cards[index]
	end

	local lostCard = PlayerManager.DestroyCard(discard.victimId, cardType)
	finishChallengerFailed(lostCard)
	return true
end

local function randomDiscardPick(): any
	local discard = pendingDiscard
	if not discard then
		return {}
	end
	local index = math.random(1, #discard.cards)
	return { index = index, cardType = discard.cards[index] }
end

-- Resolve Round Failure (Challenger hit a skull): enter the discard phase
local function onChallengerFailed(skullOwnerId: number)
	cancelTurnTimer()
	Card3DManager.SetRevealingEnabled(false)

	if not challengerId then
		return
	end
	local challenger = PlayerManager.GetPlayer(challengerId)
	local skullOwner = PlayerManager.GetPlayer(skullOwnerId)
	if not challenger or not skullOwner then
		return
	end

	local isOwnSkull = (challengerId == skullOwnerId)

	-- Reactions: the challenger flinches; whoever owned the skull laughs
	TableBuilder.PlayReaction(challenger.seatIndex, "Shock", 1.4)
	if not isOwnSkull then
		TableBuilder.PlayReaction(skullOwner.seatIndex, "Laugh")
	end

	local cards = {}
	for _, c in ipairs(challenger.hand) do
		table.insert(cards, c)
	end
	for _, c in ipairs(challenger.playedStack) do
		table.insert(cards, c)
	end
	for _, c in ipairs(challenger.revealedCards) do
		table.insert(cards, c)
	end
	for i = #cards, 2, -1 do
		local j = math.random(1, i)
		cards[i], cards[j] = cards[j], cards[i]
	end

	currentGameState = Enums.GameState.Discarding
	pendingDiscard = {
		victimId = challengerId,
		chooserId = skullOwnerId, -- own skull: the challenger themselves
		skullOwnerId = skullOwnerId,
		isOwnSkull = isOwnSkull,
		cards = cards,
	}

	if challenger.isBot then
		pcall(function()
			TableBuilder.SetBotEmote(challenger.seatIndex, "😱")
		end)
	end

	-- Nothing to choose with a single card left
	if #cards <= 1 then
		if isOwnSkull then
			broadcastNotification("💀 " .. challenger.name .. " hit their OWN Skull!", "alert")
		else
			broadcastNotification("💀 " .. challenger.name .. " hit " .. skullOwner.name .. "'s Skull!", "alert")
		end
		local pick = randomDiscardPick()
		task.delay(Constants.REVEAL_ANIMATION_DELAY, function()
			if pendingDiscard then
				RoundManager.HandlePlayerAction(skullOwnerId, Enums.PlayerAction.DiscardCard, pick)
			end
		end)
		return
	end

	if isOwnSkull then
		broadcastNotification("💀 " .. challenger.name .. " hit their OWN Skull! They choose a card to lose.", "alert")
	else
		broadcastNotification("💀 " .. challenger.name .. " hit " .. skullOwner.name .. "'s Skull! " .. skullOwner.name .. " removes one of their cards blindly.", "alert")
	end

	-- The chooser takes the turn (timer, bot logic, turn highlight); let the reveal animation play first
	setActivePlayer(skullOwnerId)
	task.delay(Constants.REVEAL_ANIMATION_DELAY, function()
		if currentGameState == Enums.GameState.Discarding then
			runCurrentTurn()
		end
	end)
end

-- Central Action Handler (Internal)
function RoundManager._ProcessPlayerAction(userId: number, action: string, data: any): (boolean, string?)
	local activeId = RoundManager.GetActivePlayerId()
	local p = PlayerManager.GetPlayer(userId)

	print(string.format("[Server RoundManager] Action '%s' from %s (%d) | Active: %s | State: %s",
		tostring(action), p and p.name or "Unknown", userId, tostring(activeId), currentGameState))

	-- 0. SKULL PENALTY: only the designated chooser may act (they may not be the active player
	--    if they left mid-pick and the timeout resolves on their behalf)
	if currentGameState == Enums.GameState.Discarding then
		local discard = pendingDiscard
		if action ~= Enums.PlayerAction.DiscardCard or not discard or userId ~= discard.chooserId then
			return false, "Waiting for a card to be discarded."
		end
		return resolveDiscard(data)
	end

	if userId ~= activeId then
		warn(string.format("[Server RoundManager] Rejected '%s' from %d: Not your turn (active: %s)",
			action, userId, tostring(activeId)))
		return false, "Not your turn."
	end

	if not p or p.isEliminated then
		return false, "Invalid player."
	end

	-- 1. PLACEMENT PHASE
	if currentGameState == Enums.GameState.Placement then
		if action == Enums.PlayerAction.PlaceCard then
			local cardType = data.cardType
			if not cardType or not table.find(p.hand, cardType) then
				return false, "You do not have that card in hand."
			end

			local success = PlayerManager.PlayCard(userId, cardType)
			if success then
				cancelTurnTimer()
				Card3DManager.PlaceCard3D(p.seatIndex, #p.playedStack)
				TableContext.FireAll(Network.CardPlayed, userId, #p.playedStack)
				broadcastNotification(p.name .. " placed a card face-down.", "info")

				advanceToNextActivePlayer()
				runCurrentTurn()
				return true
			end
		elseif action == Enums.PlayerAction.StartBid or action == Enums.PlayerAction.RaiseBid then
			-- Can only start a bid if all players have placed their mandatory 1st card
			if not haveAllPlacedFirstCard() then
				return false, "All players must place at least 1 card before bidding can start."
			end

			local bid = tonumber(data.bid) or 1
			local totalCards = PlayerManager.GetTotalCardsOnTable()
			if bid < 1 or bid > totalCards then
				return false, "Bid must be between 1 and " .. totalCards .. "."
			end

			cancelTurnTimer()
			currentGameState = Enums.GameState.Bidding
			highestBid = bid
			highestBidderId = userId
			TableContext.FireAll(Network.BidUpdated, userId, highestBid)
			broadcastNotification(p.name .. " opened the bid at " .. highestBid .. " cards!", "warning")

			-- Check if max possible bid immediately reached
			if highestBid == totalCards then
				-- Instant Challenger!
				challengerId = userId
				targetCardsToFlip = highestBid
				cardsFlippedThisRound = 0
				currentGameState = Enums.GameState.Revealing
				Card3DManager.SetRevealingEnabled(true)
				broadcastNotification(p.name .. " bid the MAXIMUM (" .. highestBid .. ") and is the CHALLENGER!", "warning")
				runCurrentTurn()
				return true
			end

			advanceToNextActivePlayer()
			runCurrentTurn()
			return true
		end

	-- 2. BIDDING PHASE
	elseif currentGameState == Enums.GameState.Bidding then
		if action == Enums.PlayerAction.RaiseBid or action == Enums.PlayerAction.StartBid then
			local bid = tonumber(data.bid)
			local totalCards = PlayerManager.GetTotalCardsOnTable()
			if not bid or bid <= highestBid or bid > totalCards then
				return false, "Bid must be greater than " .. highestBid .. " and up to " .. totalCards .. "."
			end

			cancelTurnTimer()
			highestBid = bid
			highestBidderId = userId
			TableContext.FireAll(Network.BidUpdated, userId, highestBid)
			broadcastNotification(p.name .. " raised the bid to " .. highestBid .. "!", "warning")

			-- If bid equals total cards on the table, bidding ends immediately
			if highestBid == totalCards then
				challengerId = userId
				targetCardsToFlip = highestBid
				cardsFlippedThisRound = 0
				currentGameState = Enums.GameState.Revealing
				Card3DManager.SetRevealingEnabled(true)
				broadcastNotification(p.name .. " bid the MAXIMUM and is the CHALLENGER!", "warning")
				runCurrentTurn()
				return true
			end

			advanceToNextActivePlayer(true)
			runCurrentTurn()
			return true

		elseif action == Enums.PlayerAction.Pass then
			cancelTurnTimer()
			p.hasPassedBid = true
			broadcastNotification(p.name .. " passed.", "info")

			-- Check if only 1 active bidder remains
			if getActiveBidderCount() <= 1 then
				challengerId = highestBidderId
				targetCardsToFlip = highestBid
				cardsFlippedThisRound = 0
				currentGameState = Enums.GameState.Revealing
				Card3DManager.SetRevealingEnabled(true)

				local chal = PlayerManager.GetPlayer(challengerId or 0)
				broadcastNotification("Bidding closed! " .. (chal and chal.name or "Player") .. " is the CHALLENGER (" .. targetCardsToFlip .. " cards)!", "warning")

				-- Set active index directly to the challenger
				local active = PlayerManager.GetActivePlayers()
				for idx, player in ipairs(active) do
					if player.userId == challengerId then
						activePlayerIndex = idx
						break
					end
				end

				runCurrentTurn()
				return true
			else
				-- Pass to next non-passed player
				advanceToNextActivePlayer(true)
				runCurrentTurn()
				return true
			end
		end

	-- 3. REVEALING PHASE
	elseif currentGameState == Enums.GameState.Revealing then
		if action == Enums.PlayerAction.RevealCard then
			local targetUserId = tonumber(data.targetUserId)
			local targetPlayer = PlayerManager.GetPlayer(targetUserId or 0)

			-- If challenger's own pile is already empty, and target player has no cards or was own pile:
			-- Fallback to finding an opponent with cards in stack (supports the GUI "FLIP OPPONENT" button)
			if challengerId and #p.playedStack == 0 then
				if not targetPlayer or #targetPlayer.playedStack == 0 or targetUserId == challengerId then
					for _, candidate in ipairs(PlayerManager.GetActivePlayers()) do
						if candidate.userId ~= challengerId and #candidate.playedStack > 0 then
							targetUserId = candidate.userId
							targetPlayer = candidate
							break
						end
					end
				end
			end

			if not targetPlayer or #targetPlayer.playedStack == 0 then
				return false, "Target player has no cards to flip."
			end

			-- MANDATORY RULE: Challenger MUST flip all cards in their own stack first!
			if challengerId and #p.playedStack > 0 and targetUserId ~= challengerId then
				return false, "You MUST flip all of your own cards first before flipping opponents' cards!"
			end

			cancelTurnTimer()

			-- Pop top card from target's played stack
			local revealedCard = table.remove(targetPlayer.playedStack)
			if not revealedCard then
				return false, "No cards left in this player's stack."
			end
			table.insert(targetPlayer.revealedCards, revealedCard)
			cardsFlippedThisRound += 1

			local flipId = Card3DManager.RevealCard3D(targetPlayer.seatIndex, revealedCard)

			TableContext.FireAll(Network.CardRevealed, {
				targetUserId = targetUserId,
				flipId = flipId, -- clients animate this card's flip (client/CardFlip3D)
				cardType = revealedCard,
				stackRemaining = #targetPlayer.playedStack,
				cardsFlipped = cardsFlippedThisRound,
				targetCards = targetCardsToFlip,
			})

			-- Evaluate Revealed Card
			if revealedCard == Enums.CardType.Skull then
				-- SKULL HIT! Challenger fails
				onChallengerFailed(targetPlayer.userId)
				return true
			else
				-- ROSE FLIPPED!
				broadcastNotification(p.name .. " revealed a ROSE from " .. targetPlayer.name .. "! (" .. cardsFlippedThisRound .. "/" .. targetCardsToFlip .. ")", "info")

				if cardsFlippedThisRound >= targetCardsToFlip then
					-- TARGET REACHED! Challenger wins round
					onChallengerSuccess()
					return true
				else
					-- More cards needed, continue challenger's turn
					task.delay(Constants.REVEAL_ANIMATION_DELAY, function()
						runCurrentTurn()
					end)
					return true
				end
			end
		end
	end

	return false, "Invalid action for current game state."
end

-- Public Action Handler with Turn Lock & Resync Protection
function RoundManager.HandlePlayerAction(userId: number, action: string, data: any): (boolean, string?)
	local p = PlayerManager.GetPlayer(userId)

	if turnLock then
		warn(string.format("[Server RoundManager] Rejected '%s' from %d: Action locked/in-progress", action, userId))
		if p and not p.isBot then
			RoundManager.SendStateToPlayer(userId)
		end
		return false, "Action in progress, please wait."
	end

	turnLock = true
	local success, ok, errMsg = pcall(function()
		return RoundManager._ProcessPlayerAction(userId, action, data)
	end)
	turnLock = false

	if not success then
		warn(string.format("[Server RoundManager] Error processing '%s' from %d: %s", action, userId, tostring(ok)))
		if p and not p.isBot then
			RoundManager.SendStateToPlayer(userId)
		end
		return false, "An internal error occurred."
	end

	-- If action failed/rejected, ensure player gets state resynced so hand is restored
	if not ok then
		if p and not p.isBot then
			RoundManager.SendStateToPlayer(userId)
		end
	end

	return ok, errMsg
end

-- Connect 3D table card click detector to RoundManager action arbiter
Card3DManager.SetActionHandler(RoundManager.HandlePlayerAction)

return RoundManager

