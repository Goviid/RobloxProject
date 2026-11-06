--!strict
-- TableView.luau
-- Minimalist Top Glassmorphism HUD (Matching concept reference image)
-- Features:
-- 1. Left Pill: "1 TURN" with cyan neon border
-- 2. Center Pill: "ROUND 1: BETTING PHASE" with gold/amber border
-- 3. Right Pill: "TURN 2" with crimson neon border

local TweenService = game:GetService("TweenService")
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local TableView = {}

local containerFrame: Frame? = nil
local centerTitleLabel: TextLabel? = nil
local leftTurnLabel: TextLabel? = nil
local rightTurnLabel: TextLabel? = nil
local matchAlertLabel: TextLabel? = nil
local currentRoundNumber = 1

function TableView.Create(parent: GuiObject, _onRevealClick: (targetUserId: number) -> ()): Frame
	local container = Instance.new("Frame")
	container.Name = "TopHudContainer"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Size = UDim2.new(1, 0, 0, 110)
	container.Position = UDim2.new(0.5, 0, 0, 12)
	container.BackgroundTransparency = 1
	container.ZIndex = 20
	container.Parent = parent

	-- ========================================================================
	-- 1. LEFT PILL: "1 TURN" (Cyan Neon `#50E1F5`)
	-- ========================================================================
	local leftPill = Instance.new("Frame")
	leftPill.Name = "LeftTurnPill"
	leftPill.AnchorPoint = Vector2.new(0.5, 0)
	leftPill.Size = UDim2.new(0, 140, 0, 42)
	leftPill.Position = UDim2.new(0.5, -280, 0, 4)
	leftPill.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	leftPill.BackgroundTransparency = 0.20
	leftPill.BorderSizePixel = 0
	leftPill.Parent = container
	Instance.new("UICorner", leftPill).CornerRadius = UDim.new(1, 0)

	local leftStroke = Instance.new("UIStroke")
	leftStroke.Color = Color3.fromRGB(80, 225, 245)
	leftStroke.Thickness = 2.4
	leftStroke.Parent = leftPill

	local leftText = Instance.new("TextLabel")
	leftText.Size = UDim2.new(1, 0, 1, 0)
	leftText.BackgroundTransparency = 1
	leftText.Font = Enum.Font.FredokaOne
	leftText.TextSize = 17
	leftText.TextColor3 = Color3.fromRGB(255, 255, 255)
	leftText.Text = "1 TURN"
	leftText.Parent = leftPill
	leftTurnLabel = leftText

	-- ========================================================================
	-- 2. CENTER PILL: "ROUND 1: PLACEMENT PHASE" (Glowing Gold/Red Border)
	-- ========================================================================
	local centerPill = Instance.new("Frame")
	centerPill.Name = "CenterPhasePill"
	centerPill.AnchorPoint = Vector2.new(0.5, 0)
	centerPill.Size = UDim2.new(0, 390, 0, 48)
	centerPill.Position = UDim2.new(0.5, 0, 0, 0)
	centerPill.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
	centerPill.BackgroundTransparency = 0.15
	centerPill.BorderSizePixel = 0
	centerPill.Parent = container
	Instance.new("UICorner", centerPill).CornerRadius = UDim.new(1, 0)

	local centerStroke = Instance.new("UIStroke")
	centerStroke.Color = Color3.fromRGB(255, 215, 65)
	centerStroke.Thickness = 2.8
	centerStroke.Parent = centerPill

	local strokeGrad = Instance.new("UIGradient")
	strokeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 50, 70)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 75)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 50, 70)),
	})
	strokeGrad.Parent = centerStroke

	local centerLabel = Instance.new("TextLabel")
	centerLabel.Size = UDim2.new(1, 0, 1, 0)
	centerLabel.BackgroundTransparency = 1
	centerLabel.Font = Enum.Font.FredokaOne
	centerLabel.TextSize = 20
	centerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	centerLabel.RichText = true
	centerLabel.Text = `ROUND {currentRoundNumber}: <font color="#FFD23F">PLACEMENT PHASE</font>`
	centerLabel.Parent = centerPill
	centerTitleLabel = centerLabel

	-- ========================================================================
	-- 3. RIGHT PILL: "TURN 2" (Crimson Neon `#FF4757`)
	-- ========================================================================
	local rightPill = Instance.new("Frame")
	rightPill.Name = "RightTurnPill"
	rightPill.AnchorPoint = Vector2.new(0.5, 0)
	rightPill.Size = UDim2.new(0, 140, 0, 42)
	rightPill.Position = UDim2.new(0.5, 280, 0, 4)
	rightPill.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	rightPill.BackgroundTransparency = 0.20
	rightPill.BorderSizePixel = 0
	rightPill.Parent = container
	Instance.new("UICorner", rightPill).CornerRadius = UDim.new(1, 0)

	local rightStroke = Instance.new("UIStroke")
	rightStroke.Color = Color3.fromRGB(255, 75, 95)
	rightStroke.Thickness = 2.4
	rightStroke.Parent = rightPill

	local rightText = Instance.new("TextLabel")
	rightText.Size = UDim2.new(1, 0, 1, 0)
	rightText.BackgroundTransparency = 1
	rightText.Font = Enum.Font.FredokaOne
	rightText.TextSize = 17
	rightText.TextColor3 = Color3.fromRGB(255, 255, 255)
	rightText.Text = "TURN 2"
	rightText.Parent = rightPill
	rightTurnLabel = rightText

	-- ========================================================================
	-- 4. BOLD YELLOW-GOLD ALERT TEXT ("BLUFFER_99 raised the bid to 3!")
	-- ========================================================================
	local alertFrame = Instance.new("Frame")
	alertFrame.Name = "MatchAlertFrame"
	alertFrame.AnchorPoint = Vector2.new(0.5, 0)
	alertFrame.Size = UDim2.new(0, 460, 0, 32)
	alertFrame.Position = UDim2.new(0.5, 0, 0, 54)
	alertFrame.BackgroundTransparency = 1
	alertFrame.Parent = container

	local alertText = Instance.new("TextLabel")
	alertText.Name = "AlertText"
	alertText.Size = UDim2.new(1, 0, 1, 0)
	alertText.BackgroundTransparency = 1
	alertText.Font = Enum.Font.FredokaOne
	alertText.TextSize = 18
	alertText.TextColor3 = Color3.fromRGB(255, 215, 65) -- Bold Yellow-Gold as requested
	alertText.TextStrokeTransparency = 0.35
	alertText.TextStrokeColor3 = Color3.fromRGB(18, 14, 20)
	alertText.Text = "BLUFFER_99 raised the bid to 3!"
	alertText.Parent = alertFrame
	matchAlertLabel = alertText

	containerFrame = container
	return container
end

function TableView.SetAlertText(text: string)
	if matchAlertLabel then
		matchAlertLabel.Text = text
	end
end

function TableView.UpdateCenter(gameState: string, highestBid: number, challengerName: string?, totalCards: number)
	if not centerTitleLabel then return end

	local phaseNames: { [string]: { name: string, color: string } } = {
		[Enums.GameState.Lobby] = { name = "WAITING FOR PLAYERS", color = "#50E1F5" },
		[Enums.GameState.Placement] = { name = "PLACEMENT PHASE", color = "#4ECCA3" },
		[Enums.GameState.Bidding] = { name = "BETTING PHASE", color = "#FFD23F" },
		[Enums.GameState.Revealing] = { name = "CHALLENGE PHASE", color = "#FF6B6B" },
		[Enums.GameState.RoundEnd] = { name = "ROUND COMPLETE", color = "#FFD23F" },
		[Enums.GameState.GameOver] = { name = "MATCH OVER", color = "#FFD23F" },
	}

	local pInfo = phaseNames[gameState] or { name = string.upper(gameState), color = "#FFD23F" }
	centerTitleLabel.Text = `ROUND {currentRoundNumber}: <font color="{pInfo.color}">{pInfo.name}</font>`
end

function TableView.UpdateLayout(_players: any, _activeId: number?, _challengerId: number?)
	-- Layout is statically in 3D table matching concept reference
end

return TableView
