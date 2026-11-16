--!strict
-- AudioController.luau
-- Client-side sound effects. Every ID below was checked to be a real Audio asset
-- (MarketplaceService:GetProductInfo -> AssetTypeId 3). Sources are Roblox's licensed
-- libraries (Pro Sound Effects, APM Music) or creators publishing original free sounds:
--   card_flip by f4ngy via Freesound (Attribution licence) -> credit "f4ngy (Freesound)"
--   "Daily Sounds" set by DailySoundsFX (original, free)
-- To swap a sound, change its id here; keep it an Audio asset you are allowed to use.

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local AudioController = {}

type SoundConfig = { id: string, volume: number, pitchMin: number, pitchMax: number }

local SOUND_CONFIGS: { [string]: SoundConfig } = {
	CardPlace = { id = "rbxassetid://9118833191", volume = 0.6, pitchMin = 0.95, pitchMax = 1.08 }, -- Scrapbook Close 1 (PSE)
	CardFlip = { id = "rbxassetid://3456145589", volume = 0.7, pitchMin = 0.96, pitchMax = 1.04 }, -- card_flip (f4ngy)
	RoseReveal = { id = "rbxassetid://130378474223829", volume = 0.55, pitchMin = 1.0, pitchMax = 1.06 }, -- Coin Pickup
	SkullReveal = { id = "rbxassetid://130018094603454", volume = 0.8, pitchMin = 0.95, pitchMax = 1.0 }, -- Horror Stinger
	PointScored = { id = "rbxassetid://1840076509", volume = 0.7, pitchMin = 1.0, pitchMax = 1.0 }, -- Through the Roof (sting, APM)
	Victory = { id = "rbxassetid://1836473422", volume = 0.8, pitchMin = 1.0, pitchMax = 1.0 }, -- Victory Fanfare Sting (APM)
	ButtonClick = { id = "rbxassetid://6895079853", volume = 0.4, pitchMin = 0.98, pitchMax = 1.02 }, -- UI Click
	TimerTick = { id = "rbxassetid://6895079853", volume = 0.35, pitchMin = 0.7, pitchMax = 0.7 }, -- UI Click, pitched down
	YourTurn = { id = "rbxassetid://106984966606682", volume = 0.6, pitchMin = 1.0, pitchMax = 1.0 }, -- Cartoon Pop
	Eliminated = { id = "rbxassetid://96795857757261", volume = 0.6, pitchMin = 1.0, pitchMax = 1.0 }, -- Power Down
	MatchStart = { id = "rbxassetid://87058958593472", volume = 0.5, pitchMin = 1.0, pitchMax = 1.0 }, -- Church Bell Toll
	ErrorBuzz = { id = "rbxassetid://91501650514390", volume = 0.35, pitchMin = 1.0, pitchMax = 1.0 }, -- Error Buzz
}

local soundFolder: Folder? = nil
local activeSounds: { [string]: Sound } = {}

-- Play a sound with a little pitch variation so repeats don't sound mechanical
local function playSound(name: string)
	local config = SOUND_CONFIGS[name]
	local sound = activeSounds[name]
	if not config or not sound then
		return
	end
	pcall(function()
		sound.PlaybackSpeed = config.pitchMin + math.random() * (config.pitchMax - config.pitchMin)
		sound.TimePosition = 0
		sound.Volume = config.volume
		sound:Play()
	end)
end

function AudioController.Init()
	if soundFolder then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "SkullsAudioFolder"
	folder.Parent = SoundService

	for name: string, config in pairs(SOUND_CONFIGS) do
		local snd = Instance.new("Sound")
		snd.Name = name .. "SFX"
		snd.SoundId = config.id
		snd.Volume = config.volume
		snd.Parent = folder
		activeSounds[name] = snd
	end

	soundFolder = folder

	task.spawn(function()
		local preloadList = {}
		for _, snd in pairs(activeSounds) do
			table.insert(preloadList, snd)
		end
		pcall(function()
			ContentProvider:PreloadAsync(preloadList)
		end)
	end)
end

-- ============================================================================
-- CONTEXTUAL SOUND ACTIONS
-- ============================================================================
function AudioController.PlayCardPlace()
	playSound("CardPlace")
end

function AudioController.PlayCardFlip()
	playSound("CardFlip")
end

function AudioController.PlayRoseReveal()
	playSound("RoseReveal")
end

function AudioController.PlaySkullReveal()
	playSound("SkullReveal")
end

function AudioController.PlayPointScored()
	playSound("PointScored")
end

function AudioController.PlayVictory()
	playSound("Victory")
end

function AudioController.PlayButtonClick()
	playSound("ButtonClick")
end

function AudioController.PlayTimerTick()
	playSound("TimerTick")
end

function AudioController.PlayYourTurn()
	playSound("YourTurn")
end

function AudioController.PlayEliminated()
	playSound("Eliminated")
end

function AudioController.PlayMatchStart()
	playSound("MatchStart")
end

function AudioController.PlayError()
	playSound("ErrorBuzz")
end

return AudioController
