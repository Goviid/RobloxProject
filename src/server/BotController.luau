--!strict
-- BotController.luau
-- AI decision engine for automated bot players during testing and solo play

local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)
local PlayerManager = require(script.Parent.PlayerManager)

local BotController = {}

-- Decide an action during Placement Phase
function BotController.DecidePlacementAction(botId: number, canBid: boolean, totalCardsOnTable: number)
	local p = PlayerManager.GetPlayer(botId)
	if not p or p.isEliminated then return nil end

	-- Count cards in bot's hand
	local hasRose = table.find(p.hand, Enums.CardType.Rose) ~= nil
	local hasSkull = table.find(p.hand, Enums.CardType.Skull) ~= nil

	-- If canBid is true, bot has played at least 1 card. Should they start a bid?
	if canBid and #p.playedStack >= 2 and totalCardsOnTable >= 3 then
		-- Count how many roses the bot placed on its own stack
		local ownRoses = 0
		for _, card in ipairs(p.playedStack) do
			if card == Enums.CardType.Rose then
				ownRoses += 1
			end
		end

		-- If bot has 2+ roses and no skull in their own pile, 40% chance to start a bid
		local ownSkullInPile = table.find(p.playedStack, Enums.CardType.Skull) ~= nil
		if not ownSkullInPile and ownRoses >= 2 and math.random() < 0.40 then
			local startBid = math.min(ownRoses + 1, totalCardsOnTable)
			return {
				action = Enums.PlayerAction.StartBid,
				bid = startBid,
			}
		elseif ownSkullInPile and math.random() < 0.35 then
			-- Bot bluffed with a skull, 35% chance to start a bluff-bid of 1 or 2
			local bluffBid = math.min(2, totalCardsOnTable)
			return {
				action = Enums.PlayerAction.StartBid,
				bid = bluffBid,
			}
		end
	end

	-- Otherwise, place a card if cards remain in hand
	if #p.hand > 0 then
		local cardToPlay = Enums.CardType.Rose
		if hasSkull and hasRose then
			-- 75% Rose, 25% Skull (bluff)
			cardToPlay = (math.random() < 0.25) and Enums.CardType.Skull or Enums.CardType.Rose
		elseif hasSkull then
			cardToPlay = Enums.CardType.Skull
		end

		return {
			action = Enums.PlayerAction.PlaceCard,
			cardType = cardToPlay,
		}
	elseif canBid then
		-- No cards left in hand, must start a bid!
		return {
			action = Enums.PlayerAction.StartBid,
			bid = 1,
		}
	end

	return nil
end

-- Decide an action during Bidding Phase
function BotController.DecideBiddingAction(botId: number, currentBid: number, totalCardsOnTable: number)
	local p = PlayerManager.GetPlayer(botId)
	if not p or p.isEliminated or p.hasPassedBid then return nil end

	-- Calculate bot's confidence:
	-- Count own roses placed
	local ownRoses = 0
	local ownSkull = false
	for _, card in ipairs(p.playedStack) do
		if card == Enums.CardType.Rose then
			ownRoses += 1
		else
			ownSkull = true
		end
	end

	-- If bot put a skull in their own pile, they CANNOT bid unless bluffing lightly and planning to pass early
	local maxSafeBid = ownRoses
	if not ownSkull then
		-- Opponents typically have ~60% roses in stacks
		local opponentCards = totalCardsOnTable - #p.playedStack
		maxSafeBid += math.floor(opponentCards * 0.55)
	else
		-- Bot bluffed with a skull, bid conservatively or pass immediately
		maxSafeBid = 1
	end

	local nextBid = currentBid + 1
	if nextBid <= maxSafeBid and nextBid <= totalCardsOnTable then
		return {
			action = Enums.PlayerAction.RaiseBid,
			bid = nextBid,
		}
	else
		return {
			action = Enums.PlayerAction.Pass,
		}
	end
end

-- Decide which player's stack to flip during Revealing Phase
function BotController.DecideCardToReveal(botId: number, challengerId: number): number?
	local challenger = PlayerManager.GetPlayer(challengerId)
	if not challenger then return nil end

	-- 1. RULE: Challenger MUST flip all of their own stack first!
	if #challenger.playedStack > 0 then
		return challengerId
	end

	-- 2. Once own stack is cleared, choose an opponent's stack
	local candidates = {}
	for _, p in pairs(PlayerManager.GetAllPlayers()) do
		if p.userId ~= challengerId and not p.isEliminated and #p.playedStack > 0 then
			table.insert(candidates, p.userId)
		end
	end

	if #candidates > 0 then
		-- Pick random opponent with cards remaining
		local choice = candidates[math.random(1, #candidates)]
		return choice
	end

	return nil
end

return BotController

