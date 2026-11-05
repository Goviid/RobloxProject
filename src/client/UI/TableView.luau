--!strict
-- TableView.luau
-- Clean LOCOfficial-style Match Announcements (100% unobstructed 3D arena view)
-- Player info and card counts are rendered overhead in 3D; this module displays phase transition banners

local TweenService = game:GetService("TweenService")
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local TableView = {}

local containerFrame: Frame? = nil
local announcementLabel: TextLabel? = nil
local subAnnouncementLabel: TextLabel? = nil
local fadeThread: thread? = nil

-- ============================================================================
-- 1. SETUP & CREATION (Floating Ethereal Display)
-- ============================================================================
function TableView.Create(parent: GuiObject, _onRevealClick: (targetUserId: number) -> ()): Frame
	local container = Instance.new("Frame")
	container.Name = "AnnouncementContainer"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Size = UDim2.new(0, 500, 0, 70)
	container.Position = UDim2.new(0.5, 0, 0, 70) -- Upper screen, completely unobstructed
	container.BackgroundTransparency = 1 -- Zero black box!
	container.BorderSizePixel = 0
	container.ZIndex = 20
	container.Parent = parent

	-- Big bold LOCOfficial-style announcement text
	local label = Instance.new("TextLabel")
	label.Name = "AnnouncementLabel"
	label.Size = UDim2.new(1, 0, 0, 34)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.TextColor3 = Color3.fromRGB(255, 245, 230)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(15, 30, 55)
	label.Text = ""
	label.ZIndex = 21
	label.Parent = container

	-- Secondary info (e.g. "Highest Bid: 2 by Carmel")
	local sub = Instance.new("TextLabel")
	sub.Name = "SubAnnouncementLabel"
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.Position = UDim2.new(0, 0, 0, 36)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.FredokaOne
	sub.TextSize = 16
	sub.TextColor3 = Color3.fromRGB(255, 215, 75)
	sub.TextStrokeTransparency = 0.45
	sub.TextStrokeColor3 = Color3.fromRGB(15, 30, 55)
	sub.Text = ""
	sub.ZIndex = 21
	sub.Parent = container

	containerFrame = container
	announcementLabel = label
	subAnnouncementLabel = sub

	return container
end

-- ============================================================================
-- 2. UPDATE CENTER ANNOUNCEMENT (With Gentle Auto-Fade)
-- ============================================================================
function TableView.UpdateCenter(gameState: string, highestBid: number, challengerName: string?, totalCards: number)
	if not announcementLabel or not subAnnouncementLabel then return end

	local phaseTitles: { [string]: string } = {
		[Enums.GameState.Lobby] = "WAITING FOR PLAYERS",
		[Enums.GameState.Placement] = "CARD PLACEMENT PHASE",
		[Enums.GameState.Bidding] = "BIDDING PHASE",
		[Enums.GameState.Revealing] = "CARD REVEAL CHALLENGE",
		[Enums.GameState.RoundEnd] = "ROUND COMPLETE",
		[Enums.GameState.GameOver] = "MATCH OVER",
	}

	local title = phaseTitles[gameState] or string.upper(gameState)
	announcementLabel.Text = title

	if gameState == Enums.GameState.Placement then
		subAnnouncementLabel.Text = (totalCards > 0) and (totalCards .. " Cards on Ground") or "Place your first card"
	elseif gameState == Enums.GameState.Bidding then
		if highestBid > 0 and challengerName then
			subAnnouncementLabel.Text = "Highest Bid: " .. highestBid .. " by " .. challengerName
		else
			subAnnouncementLabel.Text = "Total Cards in Play: " .. totalCards
		end
	elseif gameState == Enums.GameState.Revealing then
		subAnnouncementLabel.Text = "Target to Reveal: " .. highestBid .. " by " .. (challengerName or "Challenger")
	else
		subAnnouncementLabel.Text = ""
	end

	-- Reveal bounce and soft auto-fade
	announcementLabel.TextTransparency = 0.05
	subAnnouncementLabel.TextTransparency = 0.10

	if fadeThread then
		task.cancel(fadeThread)
		fadeThread = nil
	end

	fadeThread = task.delay(4.0, function()
		if not announcementLabel or not subAnnouncementLabel then return end
		TweenService:Create(announcementLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0.65,
		}):Play()
		TweenService:Create(subAnnouncementLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0.70,
		}):Play()
	end)
end

function TableView.UpdateLayout(_playersData: any, _activePlayerId: any, _challengerId: any)
	-- No-op: 3D Billboards overhead handle seat rendering cleanly
end

return TableView
