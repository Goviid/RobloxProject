--!strict
-- Enums.luau
-- Shared enumerations for Skulls & Roses

local Enums = {}

Enums.CardType = {
	Rose = "Rose",
	Skull = "Skull",
	Unknown = "Unknown", -- Client-side placeholder for hidden opponent cards
}

Enums.GameState = {
	Lobby = "Lobby",
	Placement = "Placement",
	Bidding = "Bidding",
	Revealing = "Revealing",
	RoundEnd = "RoundEnd",
	MatchEnd = "MatchEnd",
}

Enums.TurnType = {
	MandatoryPlacement = "MandatoryPlacement", -- Must play 1st card
	PlacementOrBid = "PlacementOrBid",         -- Can add card or start bid
	Bidding = "Bidding",                       -- Raise bid or pass
	Revealing = "Revealing",                   -- Challenger picks cards to flip
	DiscardSelection = "DiscardSelection",     -- Pick a card to lose on skull hit
}

Enums.PlayerAction = {
	PlaceCard = "PlaceCard",
	StartBid = "StartBid",
	RaiseBid = "RaiseBid",
	Pass = "Pass",
	RevealCard = "RevealCard",
	DiscardCard = "DiscardCard",
}

Enums.RoundResolution = {
	ChallengerWon = "ChallengerWon",           -- Successfully flipped target roses
	HitOwnSkull = "HitOwnSkull",               -- Challenger flipped their own skull
	HitOpponentSkull = "HitOpponentSkull",     -- Challenger flipped someone else's skull
}

return table.freeze(Enums)
