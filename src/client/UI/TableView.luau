--!strict
-- TableView.luau
-- Clean, Unified Top Glassmorphism HUD (Locofficial Style)
-- Features:
-- 1. Left Pill: "TURN 1" (dynamically updates to Turn 2, Turn 3, etc. - NEVER duplicates!)
-- 2. Center Pill: "ROUND 1: PLACEMENT PHASE" with gold/amber border
-- 3. Right Pill: "👤 YOUR TURN" (Gold) or "🤖 {NAME}'S TURN" (Cyan)
-- 4. Clean, non-overlapping alert line below

local TweenService = game:GetService("TweenService")
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local TableView = {}

local containerFrame: Frame? = nil
local turnPillLabel: TextLabel? = nil
local turnPillStroke: UIStroke? = nil
local centerTitleLabel: TextLabel? = nil
local activePlayerLabel: TextLabel? = nil
local activePlayerStroke: UIStroke? = nil
local matchAlertLabel: TextLabel? = nil
local currentRoundNumber = 1

function TableView.Create(parent: GuiObject, _onRevealClick: (targetUserId: number) -> ()): Frame
	local container = Instance.new("Frame")
	container.Name = "TopHudContainer"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Size = UDim2.new(0, 720, 0, 85)
	container.Position = UDim2.new(0.5, 0, 0, 10)
	container.BackgroundTransparency = 1
	container.ZIndex = 20
	container.Parent = parent

	-- ========================================================================
	-- TOP ROW: [ TURN 1 ]  [ ROUND 1: PLACEMENT PHASE ]  [ YOUR TURN ]
	-- ========================================================================
	local topRow = Instance.new("Frame")
	topRow.Name = "HeaderRow"
	topRow.Size = UDim2.new(1, 0, 0, 44)
	topRow.Position = UDim2.new(0, 0, 0, 0)
	topRow.BackgroundTransparency = 1
	topRow.Parent = container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 12)
	rowLayout.Parent = topRow

	-- 1. LEFT PILL: Current Turn Number ("TURN 1")
	local turnPill = Instance.new("Frame")
	turnPill.Name = "TurnPill"
	turnPill.Size = UDim2.new(0, 130, 0, 40)
	turnPill.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	turnPill.BackgroundTransparency = 0.20
	turnPill.BorderSizePixel = 0
	turnPill.LayoutOrder = 1
	turnPill.Parent = topRow
	Instance.new("UICorner", turnPill).CornerRadius = UDim.new(1, 0)

	local tStroke = Instance.new("UIStroke")
	tStroke.Name = "TurnStroke"
	tStroke.Color = Color3.fromRGB(80, 225, 245)
	tStroke.Thickness = 2.2
	tStroke.Parent = turnPill
	turnPillStroke = tStroke

	local tText = Instance.new("TextLabel")
	tText.Name = "TurnText"
	tText.Size = UDim2.new(1, 0, 1, 0)
	tText.BackgroundTransparency = 1
	tText.Font = Enum.Font.FredokaOne
	tText.TextSize = 16
	tText.TextColor3 = Color3.fromRGB(240, 250, 255)
	tText.Text = "TURN 1"
	tText.Parent = turnPill
	turnPillLabel = tText

	-- 2. CENTER PILL: "ROUND 1: PLACEMENT PHASE"
	local centerPill = Instance.new("Frame")
	centerPill.Name = "CenterPhasePill"
	centerPill.Size = UDim2.new(0, 340, 0, 44)
	centerPill.BackgroundColor3 = Color3.fromRGB(18, 14, 24)
	centerPill.BackgroundTransparency = 0.15
	centerPill.BorderSizePixel = 0
	centerPill.LayoutOrder = 2
	centerPill.Parent = topRow
	Instance.new("UICorner", centerPill).CornerRadius = UDim.new(1, 0)

	local centerStroke = Instance.new("UIStroke")
	centerStroke.Color = Color3.fromRGB(255, 215, 65)
	centerStroke.Thickness = 2.6
	centerStroke.Parent = centerPill

	local strokeGrad = Instance.new("UIGradient")
	strokeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 65, 85)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 225, 80)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 65, 85)),
	})
	strokeGrad.Parent = centerStroke

	local centerLabel = Instance.new("TextLabel")
	centerLabel.Name = "PhaseLabel"
	centerLabel.Size = UDim2.new(1, 0, 1, 0)
	centerLabel.BackgroundTransparency = 1
	centerLabel.Font = Enum.Font.FredokaOne
	centerLabel.TextSize = 18
	centerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	centerLabel.RichText = true
	centerLabel.Text = `ROUND {currentRoundNumber}: <font color="#4ECCA3">PLACEMENT PHASE</font>`
	centerLabel.Parent = centerPill
	centerTitleLabel = centerLabel

	-- 3. RIGHT PILL: Active Player Badge ("YOUR TURN" / "BLUFFER_99'S TURN")
	local activePill = Instance.new("Frame")
	activePill.Name = "ActivePlayerPill"
	activePill.Size = UDim2.new(0, 160, 0, 40)
	activePill.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	activePill.BackgroundTransparency = 0.20
	activePill.BorderSizePixel = 0
	activePill.LayoutOrder = 3
	activePill.Parent = topRow
	Instance.new("UICorner", activePill).CornerRadius = UDim.new(1, 0)

	local aStroke = Instance.new("UIStroke")
	aStroke.Name = "ActiveStroke"
	aStroke.Color = Color3.fromRGB(255, 215, 65)
	aStroke.Thickness = 2.4
	aStroke.Parent = activePill
	activePlayerStroke = aStroke

	local aText = Instance.new("TextLabel")
	aText.Name = "ActivePlayerText"
	aText.Size = UDim2.new(1, 0, 1, 0)
	aText.BackgroundTransparency = 1
	aText.Font = Enum.Font.FredokaOne
	aText.TextSize = 15
	aText.TextColor3 = Color3.fromRGB(255, 225, 80)
	aText.Text = "👤 YOUR TURN"
	aText.Parent = activePill
	activePlayerLabel = aText

	-- ========================================================================
	-- BOTTOM ROW: Non-overlapping Alert Announcement Line
	-- ========================================================================
	local alertFrame = Instance.new("Frame")
	alertFrame.Name = "MatchAlertFrame"
	alertFrame.AnchorPoint = Vector2.new(0.5, 0)
	alertFrame.Size = UDim2.new(1, 0, 0, 28)
	alertFrame.Position = UDim2.new(0.5, 0, 0, 50)
	alertFrame.BackgroundTransparency = 1
	alertFrame.Parent = container

	local alertText = Instance.new("TextLabel")
	alertText.Name = "AlertText"
	alertText.Size = UDim2.new(1, 0, 1, 0)
	alertText.BackgroundTransparency = 1
	alertText.Font = Enum.Font.FredokaOne
	alertText.TextSize = 16
	alertText.TextColor3 = Color3.fromRGB(255, 220, 85)
	alertText.TextStrokeTransparency = 0.4
	alertText.TextStrokeColor3 = Color3.fromRGB(15, 12, 18)
	alertText.Text = ""
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

function TableView.UpdateTurn(turnNumber: number, activePlayerName: string, isMyTurn: boolean)
	if turnPillLabel then
		turnPillLabel.Text = "TURN " .. turnNumber
	end
	if activePlayerLabel and activePlayerStroke then
		if isMyTurn then
			activePlayerLabel.Text = "👤 YOUR TURN"
			activePlayerLabel.TextColor3 = Color3.fromRGB(255, 225, 80)
			activePlayerStroke.Color = Color3.fromRGB(255, 215, 65)
		else
			activePlayerLabel.Text = "🤖 " .. activePlayerName .. "'S TURN"
			activePlayerLabel.TextColor3 = Color3.fromRGB(160, 235, 255)
			activePlayerStroke.Color = Color3.fromRGB(80, 220, 245)
		end
	end
end

function TableView.UpdateCenter(gameState: string, highestBid: number, challengerName: string?, totalCards: number)
	if not centerTitleLabel then return end

	local phaseNames: { [string]: { name: string, color: string } } = {
		[Enums.GameState.Lobby] = { name = "WAITING FOR PLAYERS", color = "#50E1F5" },
		[Enums.GameState.Placement] = { name = "PLACEMENT PHASE", color = "#4ECCA3" },
		[Enums.GameState.Bidding] = { name = "BIDDING PHASE", color = "#FFD23F" },
		[Enums.GameState.Revealing] = { name = "CHALLENGE PHASE", color = "#FF6B6B" },
		[Enums.GameState.RoundEnd] = { name = "ROUND COMPLETE", color = "#FFD23F" },
		[Enums.GameState.GameOver] = { name = "MATCH OVER", color = "#FFD23F" },
	}

	local pInfo = phaseNames[gameState] or { name = string.upper(gameState), color = "#FFD23F" }
	centerTitleLabel.Text = `ROUND {currentRoundNumber}: <font color="{pInfo.color}">{pInfo.name}</font>`
end

function TableView.UpdateLayout(_players: any, _activeId: number?, _challengerId: number?)
	-- 3D Table layout handles avatars in world
end

return TableView
