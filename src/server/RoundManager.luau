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

local turnTimerThread: thread? = nil
local isWaitingForAction = false

local function broadcastState()
	for _, p in pairs(PlayerManager.GetAllPlayers()) do
		TableBuilder.UpdateScore(p.seatIndex, p.score)
		TableBuilder.UpdateCardCount(p.seatIndex, #p.hand)
		if not p.isBot then
			RoundManager.SendStateToPlayer(p.userId)
		end
	end

	local activeId = RoundManager.GetActivePlayerId()
	local activePlayer = activeId and PlayerManager.GetPlayer(activeId)
	TableBuilder.HighlightTurn(activePlayer and activePlayer.seatIndex or nil)
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
	if not p or p.isBot then return end
	local playerObj = Players:GetPlayerByUserId(userId)
	if not playerObj then return end

	local payload = {
		gameState = currentGameState,
		roundNumber = currentRoundNumber,
		activePlayerId = RoundManager.GetActivePlayerId(),
		challengerId = challengerId,
		highestBid = highestBid,
		highestBidderId = highestBidderId,
		cardsFlipped = cardsFlippedThisRound,
		targetCards = targetCardsToFlip,
		totalCardsOnTable = PlayerManager.GetTotalCardsOnTable(),
		canStartBid = haveAllPlacedFirstCard(),
		tableState = PlayerManager.GetClientState(userId),
	}
	Network.GameStateChanged:FireClient(playerObj, payload)
end

local function broadcastNotification(text: string, style: string?)
	Network.Notification:FireAllClients({
		text = text,
		style = style or "info", -- "info", "warning", "success", "alert"
	})
end

function RoundManager.GetGameState()
	return currentGameState
end

function RoundManager.GetActivePlayerId(): number?
	local active = PlayerManager.GetActivePlayers()
	if #active == 0 then return nil end
	local p = active[activePlayerIndex]
	return p and p.userId or nil
end

local function advanceToNextActivePlayer()
	local active = PlayerManager.GetActivePlayers()
	if #active == 0 then return end

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
		curIdx = activePlayerIndex
	end

	local oldIdx = curIdx
	activePlayerIndex = (curIdx % #active) + 1
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
end

-- Forward declaration
local runCurrentTurn: () -> ()

local function onTurnTimeout()
	turnTimerThread = nil -- Timer already executed
	local activeId = RoundManager.GetActivePlayerId()
	if not activeId then return end
	local p = PlayerManager.GetPlayer(activeId)
	if not p then return end

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
	if not activeId then return end
	local p = PlayerManager.GetPlayer(activeId)
	if not p or not p.isBot then return end

	-- Fast, snappy bot reaction delay (0.4 to 0.7s) to maintain responsive game pacing
	task.delay(math.random(4, 7) / 10, function()
		if RoundManager.GetActivePlayerId() ~= activeId then return end

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
			end
		elseif currentGameState == Enums.GameState.Revealing then
			local targetId = BotController.DecideCardToReveal(activeId, challengerId or activeId)
			if targetId then
				RoundManager.HandlePlayerAction(activeId, Enums.PlayerAction.RevealCard, { targetUserId = targetId })
			end
		end
	end)
end

runCurrentTurn = function()
	local activeId = RoundManager.GetActivePlayerId()
	if not activeId then return end
	local p = PlayerManager.GetPlayer(activeId)
	if not p then return end

	broadcastState()
	startTurnTimer()
	checkBotTurn()
end

-- TRANSITION: Start a brand-new round
function RoundManager.StartRound(leaderId: number?)
	cancelTurnTimer()
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
		currentGameState = Enums.GameState.Lobby
		broadcastNotification("Waiting for more players to continue...", "info")
		broadcastState()
		return
	end

	-- Determine seat index of starting player
	if leaderId and PlayerManager.GetPlayer(leaderId) and not PlayerManager.GetPlayer(leaderId).isEliminated then
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
	local leader = PlayerManager.GetPlayer(roundLeaderId)
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

-- Resolve Round Success (Challenger flipped target roses)
local function onChallengerSuccess()
	cancelTurnTimer()
	Card3DManager.SetRevealingEnabled(false)
	currentGameState = Enums.GameState.RoundEnd

	if not challengerId then return end
	local challenger = PlayerManager.GetPlayer(challengerId)
	if not challenger then return end

	challenger.score += 1
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
		task.delay(Constants.ROUND_TRANSITION_DELAY, function()
			currentGameState = Enums.GameState.MatchEnd
			broadcastNotification("👑 " .. challenger.name .. " WINS THE MATCH! 👑", "success")
			Network.GameOver:FireAllClients(challengerId)
			broadcastState()

			task.delay(Constants.MATCH_OVER_DELAY, function()
				PlayerManager.ResetMatch()
				RoundManager.StartRound()
			end)
		end)
	else
		-- Next round starts with the victorious challenger
		task.delay(Constants.ROUND_TRANSITION_DELAY, function()
			RoundManager.StartRound(challengerId)
		end)
	end
end

-- Resolve Round Failure (Challenger hit a skull)
local function onChallengerFailed(skullOwnerId: number)
	cancelTurnTimer()
	Card3DManager.SetRevealingEnabled(false)
	currentGameState = Enums.GameState.RoundEnd

	if not challengerId then return end
	local challenger = PlayerManager.GetPlayer(challengerId)
	local skullOwner = PlayerManager.GetPlayer(skullOwnerId)
	if not challenger or not skullOwner then return end

	local isOwnSkull = (challengerId == skullOwnerId)
	local lostCard = PlayerManager.DestroyCard(challengerId, nil) -- Discard 1 card

	if isOwnSkull then
		broadcastNotification("💀 " .. challenger.name .. " hit their OWN Skull! Lost 1 card.", "alert")
	else
		broadcastNotification("💀 " .. challenger.name .. " hit " .. skullOwner.name .. "'s Skull! Lost 1 card.", "alert")
	end

	if challenger.isEliminated then
		broadcastNotification("❌ " .. challenger.name .. " has no cards left and is ELIMINATED!", "alert")
		Network.PlayerEliminated:FireAllClients(challengerId)
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

	-- Next round leader:
	-- If challenger hit own skull -> challenger starts next round (if not eliminated).
	-- If challenger hit someone else's skull -> skull owner starts next round!
	local nextLeader = isOwnSkull and challengerId or skullOwnerId
	local leaderData = PlayerManager.GetPlayer(nextLeader)
	if not leaderData or leaderData.isEliminated then
		nextLeader = nil
	end

	task.delay(Constants.ROUND_TRANSITION_DELAY, function()
		RoundManager.StartRound(nextLeader)
	end)
end

-- Central Action Handler
function RoundManager.HandlePlayerAction(userId: number, action: string, data: any): (boolean, string?)
	local activeId = RoundManager.GetActivePlayerId()
	local p = PlayerManager.GetPlayer(userId)

	print(string.format("[Server RoundManager] Action '%s' from %s (%d) | Active: %s | State: %s",
		tostring(action), p and p.name or "Unknown", userId, tostring(activeId), currentGameState))

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
				Network.CardPlayed:FireAllClients(userId, #p.playedStack)
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
			Network.BidUpdated:FireAllClients(userId, highestBid)
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
			Network.BidUpdated:FireAllClients(userId, highestBid)
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

			advanceToNextActivePlayer()
			-- Skip players who have passed
			local active = PlayerManager.GetActivePlayers()
			local attempts = 0
			while attempts < #active do
				local nextP = active[activePlayerIndex]
				if not nextP.hasPassedBid then
					break
				end
				advanceToNextActivePlayer()
				attempts += 1
			end

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
				advanceToNextActivePlayer()
				local active = PlayerManager.GetActivePlayers()
				local attempts = 0
				while attempts < #active do
					local nextP = active[activePlayerIndex]
					if not nextP.hasPassedBid then
						break
					end
					advanceToNextActivePlayer()
					attempts += 1
				end

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

			Card3DManager.RevealCard3D(targetPlayer.seatIndex, revealedCard)

			Network.CardRevealed:FireAllClients({
				targetUserId = targetUserId,
				cardType = revealedCard,
				stackRemaining = #targetPlayer.playedStack,
				cardsFlipped = cardsFlippedThisRound,
				targetCards = targetCardsToFlip,
			})

			-- Evaluate Revealed Card
			if revealedCard == Enums.CardType.Skull then
				-- SKULL HIT! Challenger fails
				onChallengerFailed(targetUserId)
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

-- Connect 3D table card click detector to RoundManager action arbiter
Card3DManager.SetActionHandler(RoundManager.HandlePlayerAction)

return RoundManager

