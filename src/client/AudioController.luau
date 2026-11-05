--!strict
-- AudioController.luau
-- Manages sound effects for card placement, card flips, skull stingers, and victory fanfares (LOCOfficial style)

local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local AudioController = {}

-- Sound asset definitions with primary IDs and fallbacks
local SOUND_CONFIGS = {
	CardPlace = {
		id = "rbxassetid://9114223170",
		fallbackId = "rbxassetid://6026987857",
		volume = 0.65,
		pitchRange = { min = 0.94, max = 1.06 },
	},
	CardFlip = {
		id = "rbxassetid://9114223321",
		fallbackId = "rbxassetid://6895079853",
		volume = 0.70,
		pitchRange = { min = 0.96, max = 1.04 },
	},
	RoseReveal = {
		id = "rbxassetid://9114223789",
		fallbackId = "rbxassetid://5153734608",
		volume = 0.85,
		pitchRange = { min = 1.0, max = 1.05 },
	},
	SkullReveal = {
		id = "rbxassetid://9114387214",
		fallbackId = "rbxassetid://8601662498",
		volume = 1.0,
		pitchRange = { min = 0.90, max = 0.95 },
	},
	PointScored = {
		id = "rbxassetid://9114223961",
		fallbackId = "rbxassetid://5153734608",
		volume = 0.90,
		pitchRange = { min = 1.0, max = 1.0 },
	},
	Victory = {
		id = "rbxassetid://9114224120",
		fallbackId = "rbxassetid://9114223961",
		volume = 1.0,
		pitchRange = { min = 1.0, max = 1.0 },
	},
	ButtonClick = {
		id = "rbxassetid://6895079853",
		fallbackId = "rbxasset://sounds/uiclick.wav",
		volume = 0.45,
		pitchRange = { min = 0.98, max = 1.02 },
	},
	TimerTick = {
		id = "rbxassetid://9114222851",
		fallbackId = "rbxassetid://6895079853",
		volume = 0.40,
		pitchRange = { min = 1.0, max = 1.0 },
	},
}

local soundFolder: Folder? = nil
local activeSounds: { [string]: Sound } = {}

-- Safely plays a sound with volume and slight organic pitch variation
local function playSound(name: string)
	local config = SOUND_CONFIGS[name]
	if not config then return end

	local sound = activeSounds[name]
	if not sound then return end

	pcall(function()
		-- Subtle pitch variation for organic tabletop feel
		if config.pitchRange then
			sound.PlaybackSpeed = config.pitchRange.min + math.random() * (config.pitchRange.max - config.pitchRange.min)
		else
			sound.PlaybackSpeed = 1.0
		end
		sound.TimePosition = 0
		sound.Volume = config.volume
		sound:Play()
	end)
end

function AudioController.Init()
	if soundFolder then return end

	local folder = Instance.new("Folder")
	folder.Name = "SkullsAudioFolder"
	folder.Parent = SoundService

	for name, config in pairs(SOUND_CONFIGS) do
		local snd = Instance.new("Sound")
		snd.Name = name .. "SFX"
		snd.SoundId = config.id
		snd.Volume = config.volume
		snd.RollOffMaxDistance = 100
		snd.Parent = folder
		activeSounds[name] = snd
	end

	soundFolder = folder

	-- Asynchronously preload sound assets
	task.spawn(function()
		local preloadList = {}
		for _, snd in pairs(activeSounds) do
			table.insert(preloadList, snd)
		end
		pcall(function()
			ContentProvider:PreloadAsync(preloadList)
		end)
	end)

	print("[AudioController] Sound effects initialized and preloaded.")
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

return AudioController

