--!strict
-- CardArt.luau
-- The 8 card art sets (back / skull / rose), uploaded 2026-11-16 from
-- "Artwork assets/Cards" (cropped to round 512x512 PNGs in Artwork assets/Cards/cropped).
-- Each player gets a random, unique set per match (PlayerManager.AssignCardSets).
-- Which set a player uses is public; which card they hold never leaves the server.

local Enums = require(script.Parent.Enums)

export type CardSet = {
	id: string,
	name: string,
	accent: Color3, -- rim / highlight colour matching the art
	back: string,
	rose: string,
	skull: string,
}

local function set(id: string, name: string, accent: Color3, back: number, skull: number, rose: number): CardSet
	return {
		id = id,
		name = name,
		accent = accent,
		back = "rbxassetid://" .. back,
		skull = "rbxassetid://" .. skull,
		rose = "rbxassetid://" .. rose,
	}
end

local SETS: { [string]: CardSet } = {
	scarlet = set("scarlet", "Scarlet", Color3.fromRGB(205, 35, 50), 87334318012900, 119702310157142, 125505443153830),
	blue_diamond = set("blue_diamond", "Blue Diamond", Color3.fromRGB(80, 150, 235), 127413325960769, 87043108671935, 128194131564673),
	forest_green = set("forest_green", "Forest Green", Color3.fromRGB(70, 150, 80), 111252390997045, 71985640537026, 92951018340221),
	sunset_orange = set("sunset_orange", "Sunset Orange", Color3.fromRGB(240, 135, 45), 70823296227511, 96214502886073, 106739792006211),
	amethyst = set("amethyst", "Amethyst", Color3.fromRGB(155, 85, 205), 96321050050053, 98945749485976, 111067433629778),
	obsidian_cyan = set("obsidian_cyan", "Obsidian Cyan", Color3.fromRGB(45, 205, 215), 80132308594232, 95851496099854, 138919229652247),
	obsidian_gold = set("obsidian_gold", "Obsidian Gold", Color3.fromRGB(230, 185, 60), 129599376214072, 120705604618399, 78597648607092),
	deep_emerald = set("deep_emerald", "Deep Emerald", Color3.fromRGB(25, 130, 90), 85323079661350, 101846509964646, 122826995712035),
}

local CardArt = {}

-- Fixed order, used for shuffling and as a stable fallback
CardArt.SetIds = {
	"scarlet",
	"blue_diamond",
	"forest_green",
	"sunset_orange",
	"amethyst",
	"obsidian_cyan",
	"obsidian_gold",
	"deep_emerald",
}

CardArt.DefaultSetId = "scarlet"

function CardArt.Get(setId: string?): CardSet
	return (setId and SETS[setId]) or SETS[CardArt.DefaultSetId]
end

function CardArt.Back(setId: string?): string
	return CardArt.Get(setId).back
end

-- Face image for a revealed card; anything that isn't a Rose or Skull shows the back
function CardArt.Face(setId: string?, cardType: string?): string
	local cardSet = CardArt.Get(setId)
	if cardType == Enums.CardType.Rose then
		return cardSet.rose
	elseif cardType == Enums.CardType.Skull then
		return cardSet.skull
	end
	return cardSet.back
end

-- Every image, for ContentProvider preloading on the client
function CardArt.AllImages(): { string }
	local list = {}
	for _, id in ipairs(CardArt.SetIds) do
		local s = SETS[id]
		table.insert(list, s.back)
		table.insert(list, s.rose)
		table.insert(list, s.skull)
	end
	return list
end

return table.freeze(CardArt)
