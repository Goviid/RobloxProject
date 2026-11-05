--!strict
-- PlayerManager.luau
-- Manages player state, secret hands, played stacks, seats, and bot players.

local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)
local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)

export type PlayerData = {
	userId: number,
	name: string,
	isBot: boolean,
	seatIndex: number,
	score: number,
	isEliminated: boolean,
	hasPassedBid: boolean,
	-- SECRET DATA (Never replicate to other clients!)
	hand: { string },        -- Available cards in hand
	playedStack: { string }, -- Cards placed on table face-down (1st placed is index 1, top is #playedStack)
}

local PlayerManager = {}
local players: { [number]: PlayerData } = {}
local seatOrder: { number } = {} -- Ordered list of userIds by seat (1..6)
local nextBotId = -100

-- Helper: create standard starting hand
local function createDefaultHand(): { string }
	local hand = {}
	for _ = 1, Constants.ROSES_PER_PLAYER do
		table.insert(hand, Enums.CardType.Rose)
	end
	for _ = 1, Constants.SKULLS_PER_PLAYER do
		table.insert(hand, Enums.CardType.Skull)
	end
	return hand
end

-- Find next open seat 1..MAX_PLAYERS (Reserves Seat 1 for human players)
local function findOpenSeat(isBot: boolean): number?
	local taken = {}
	for _, p in pairs(players) do
		taken[p.seatIndex] = true
	end
	if isBot then
		-- Bots start at seat 2 so seat 1 is reserved for the local human player
		for i = 2, Constants.MAX_PLAYERS do
			if not taken[i] then
				return i
			end
		end
		if not taken[1] then return 1 end
	else
		-- Humans prefer seat 1 for direct alignment with the over-the-shoulder camera
		if not taken[1] then return 1 end
		for i = 2, Constants.MAX_PLAYERS do
			if not taken[i] then
				return i
			end
		end
	end
	return nil
end

function PlayerManager.AddPlayer(player: Player): PlayerData?
	if players[player.UserId] then
		return players[player.UserId]
	end

	local seat = findOpenSeat(false)
	if not seat then
		return nil
	end

	local data: PlayerData = {
		userId = player.UserId,
		name = player.DisplayName or player.Name,
		isBot = false,
		seatIndex = seat,
		score = 0,
		isEliminated = false,
		hasPassedBid = false,
		hand = createDefaultHand(),
		playedStack = {},
	}

	players[player.UserId] = data
	table.insert(seatOrder, player.UserId)
	return data
end

function PlayerManager.AddBot(name: string): PlayerData?
	local seat = findOpenSeat(true)
	if not seat then
		return nil
	end

	local botId = nextBotId
	nextBotId -= 1

	local data: PlayerData = {
		userId = botId,
		name = name,
		isBot = true,
		seatIndex = seat,
		score = 0,
		isEliminated = false,
		hasPassedBid = false,
		hand = createDefaultHand(),
		playedStack = {},
	}

	players[botId] = data
	table.insert(seatOrder, botId)
	return data
end

function PlayerManager.RemovePlayer(userId: number)
	players[userId] = nil
	for i, id in ipairs(seatOrder) do
		if id == userId then
			table.remove(seatOrder, i)
			break
		end
	end
end

function PlayerManager.GetPlayer(userId: number): PlayerData?
	return players[userId]
end

function PlayerManager.GetPlayerBySeat(seatIndex: number): PlayerData?
	for _, p in pairs(players) do
		if p.seatIndex == seatIndex then
			return p
		end
	end
	return nil
end

function PlayerManager.GetAllPlayers(): { [number]: PlayerData }
	return players
end

function PlayerManager.GetActivePlayers(): { PlayerData }
	local active = {}
	-- Sort by seat index for consistent clockwise turns
	local sortedIds = table.clone(seatOrder)
	table.sort(sortedIds, function(a, b)
		local pa = players[a]
		local pb = players[b]
		if not pa or not pb then return false end
		return pa.seatIndex < pb.seatIndex
	end)

	for _, id in ipairs(sortedIds) do
		local p = players[id]
		if p and not p.isEliminated then
			table.insert(active, p)
		end
	end
	return active
end

function PlayerManager.GetTotalCardsOnTable(): number
	local count = 0
	for _, p in pairs(players) do
		if not p.isEliminated then
			count += #p.playedStack
		end
	end
	return count
end

function PlayerManager.ResetRoundState()
	for _, p in pairs(players) do
		if not p.isEliminated then
			-- Return played cards back to hand
			for _, card in ipairs(p.playedStack) do
				table.insert(p.hand, card)
			end
			table.clear(p.playedStack)
			p.hasPassedBid = false
		end
	end
end

function PlayerManager.ResetMatch()
	for _, p in pairs(players) do
		p.score = 0
		p.isEliminated = false
		p.hasPassedBid = false
		p.hand = createDefaultHand()
		p.playedStack = {}
	end
end

-- Play a card from hand to the top of player's playedStack
function PlayerManager.PlayCard(userId: number, cardType: string): boolean
	local p = players[userId]
	if not p or p.isEliminated then
		return false
	end

	-- Find and remove card from hand
	local cardIndex = table.find(p.hand, cardType)
	if not cardIndex then
		return false
	end

	table.remove(p.hand, cardIndex)
	table.insert(p.playedStack, cardType)
	return true
end

-- Permanently discard a card from hand or stack (e.g. after hitting a skull)
function PlayerManager.DestroyCard(userId: number, cardType: string?): string?
	local p = players[userId]
	if not p then return nil end

	-- Combine all remaining cards to pick from
	local allRemaining = {}
	for _, c in ipairs(p.hand) do table.insert(allRemaining, c) end
	for _, c in ipairs(p.playedStack) do table.insert(allRemaining, c) end

	if #allRemaining == 0 then
		p.isEliminated = true
		return nil
	end

	local targetCard = cardType
	if not targetCard or not table.find(allRemaining, targetCard) then
		-- Pick random
		local randIdx = math.random(1, #allRemaining)
		targetCard = allRemaining[randIdx]
	end

	-- Remove from hand first, or from playedStack
	local inHand = table.find(p.hand, targetCard)
	if inHand then
		table.remove(p.hand, inHand)
	else
		local inStack = table.find(p.playedStack, targetCard)
		if inStack then
			table.remove(p.playedStack, inStack)
		end
	end

	-- If player now has 0 total cards, they are eliminated
	if #p.hand + #p.playedStack == 0 then
		p.isEliminated = true
	end

	return targetCard
end

-- SANITIZED REPLICATION DATA
-- Converts internal game state into client-safe payload where opponent cards are hidden
function PlayerManager.GetClientState(forUserId: number?)
	local sanitizedPlayers = {}
	for id, p in pairs(players) do
		local isSelf = (forUserId and forUserId == id)
		sanitizedPlayers[tostring(id)] = {
			userId = p.userId,
			name = p.name,
			isBot = p.isBot,
			seatIndex = p.seatIndex,
			score = p.score,
			isEliminated = p.isEliminated,
			hasPassedBid = p.hasPassedBid,
			handCount = #p.hand,
			stackCount = #p.playedStack,
			-- Only the player themselves gets to see the true cards in their hand
			hand = isSelf and p.hand or nil,
		}
	end
	return {
		players = sanitizedPlayers,
		seatCount = #seatOrder,
	}
end

return PlayerManager

