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
local timerPill: Frame? = nil
local timerStroke: UIStroke? = nil
local timerLabel: TextLabel? = nil
local timerFillBar: Frame? = nil
local currentTimerThread: thread? = nil
local matchAlertLabel: TextLabel? = nil
local currentRoundNumber = 1
local currentActivePlayerName = "Opponent"
local currentIsMyTurn = false

function TableView.Create(parent: GuiObject, _onRevealClick: (targetUserId: number) -> ()): Frame
	local container = Instance.new("Frame")
	container.Name = "TopHudContainer"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Size = UDim2.new(0, 780, 0, 85)
	container.Position = UDim2.new(0.5, 0, 0, 10)
	container.BackgroundTransparency = 1
	container.ZIndex = 20
	container.Parent = parent

	-- ========================================================================
	-- ========================================================================
	-- TOP ROW: [ 1 TURN ]    [ ROUND 1: PLACEMENT PHASE ]    [ TURN 2 / ⏱️ 15s ]
	-- (Exact 3-pill arcade header matching reference mockup)
	-- ========================================================================
	local topRow = Instance.new("Frame")
	topRow.Name = "HeaderRow"
	topRow.Size = UDim2.new(1, 0, 0, 46)
	topRow.Position = UDim2.new(0, 0, 0, 0)
	topRow.BackgroundTransparency = 1
	topRow.Parent = container

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 16)
	rowLayout.Parent = topRow

	-- 1. LEFT PILL: [ 1 TURN ] (Cyan neon rim with player avatar icon matching mockup)
	local turnPill = Instance.new("Frame")
	turnPill.Name = "TurnPill"
	turnPill.Size = UDim2.new(0, 135, 0, 42)
	turnPill.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
	turnPill.BackgroundTransparency = 0.20
	turnPill.BorderSizePixel = 0
	turnPill.LayoutOrder = 1
	turnPill.Parent = topRow
	Instance.new("UICorner", turnPill).CornerRadius = UDim.new(1, 0)

	local tStroke = Instance.new("UIStroke")
	tStroke.Name = "TurnStroke"
	tStroke.Color = Color3.fromRGB(80, 225, 245)
	tStroke.Thickness = 2.4
	tStroke.Parent = turnPill
	turnPillStroke = tStroke

	local tIcon = Instance.new("TextLabel")
	tIcon.Size = UDim2.new(0, 26, 0, 26)
	tIcon.Position = UDim2.new(0, 10, 0.5, -13)
	tIcon.BackgroundTransparency = 1
	tIcon.Font = Enum.Font.FredokaOne
	tIcon.TextSize = 16
	tIcon.TextColor3 = Color3.fromRGB(80, 225, 245)
	tIcon.Text = "👤"
	tIcon.Parent = turnPill

	local tText = Instance.new("TextLabel")
	tText.Name = "TurnText"
	tText.Size = UDim2.new(1, -44, 1, 0)
	tText.Position = UDim2.new(0, 38, 0, 0)
	tText.BackgroundTransparency = 1
	tText.Font = Enum.Font.FredokaOne
	tText.TextSize = 16
	tText.TextColor3 = Color3.fromRGB(240, 250, 255)
	tText.TextXAlignment = Enum.TextXAlignment.Left
	tText.Text = "1 TURN"
	tText.Parent = turnPill
	turnPillLabel = tText

	-- 2. CENTER PILL: [ ROUND 1: PLACEMENT PHASE ] (Large gold neon banner)
	local centerPill = Instance.new("Frame")
	centerPill.Name = "CenterPhasePill"
	centerPill.Size = UDim2.new(0, 360, 0, 46)
	centerPill.BackgroundColor3 = Color3.fromRGB(16, 13, 22)
	centerPill.BackgroundTransparency = 0.15
	centerPill.BorderSizePixel = 0
	centerPill.LayoutOrder = 2
	centerPill.Parent = topRow
	Instance.new("UICorner", centerPill).CornerRadius = UDim.new(1, 0)

	local centerStroke = Instance.new("UIStroke")
	centerStroke.Color = Color3.fromRGB(255, 215, 65)
	centerStroke.Thickness = 2.8
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
	centerLabel.TextSize = 17
	centerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	centerLabel.RichText = true
	centerLabel.Text = `ROUND {currentRoundNumber}: <font color="#4ECCA3">PLACEMENT PHASE</font>`
	centerLabel.Parent = centerPill
	centerTitleLabel = centerLabel

	-- 3. RIGHT PILL: [ TURN 2 / ⏱️ 15s ] (Crimson neon rim with countdown underline)
	local activePill = Instance.new("Frame")
	activePill.Name = "ActivePlayerPill"
	activePill.Size = UDim2.new(0, 165, 0, 42)
	activePill.BackgroundColor3 = Color3.fromRGB(14, 12, 20)
	activePill.BackgroundTransparency = 0.20
	activePill.BorderSizePixel = 0
	activePill.LayoutOrder = 3
	activePill.Parent = topRow
	Instance.new("UICorner", activePill).CornerRadius = UDim.new(1, 0)

	local aStroke = Instance.new("UIStroke")
	aStroke.Name = "ActiveStroke"
	aStroke.Color = Color3.fromRGB(255, 65, 85)
	aStroke.Thickness = 2.4
	aStroke.Parent = activePill
	activePlayerStroke = aStroke
	timerStroke = aStroke

	local aIcon = Instance.new("TextLabel")
	aIcon.Size = UDim2.new(0, 26, 0, 26)
	aIcon.Position = UDim2.new(0, 10, 0.5, -13)
	aIcon.BackgroundTransparency = 1
	aIcon.Font = Enum.Font.FredokaOne
	aIcon.TextSize = 15
	aIcon.TextColor3 = Color3.fromRGB(255, 85, 105)
	aIcon.Text = "⏱️"
	aIcon.Parent = activePill

	local aText = Instance.new("TextLabel")
	aText.Name = "ActivePlayerText"
	aText.Size = UDim2.new(1, -44, 1, 0)
	aText.Position = UDim2.new(0, 38, 0, 0)
	aText.BackgroundTransparency = 1
	aText.Font = Enum.Font.FredokaOne
	aText.TextSize = 15
	aText.TextColor3 = Color3.fromRGB(255, 225, 85)
	aText.TextXAlignment = Enum.TextXAlignment.Left
	aText.Text = "👤 YOU (15s)"
	aText.Parent = activePill
	activePlayerLabel = aText
	timerLabel = aText

	-- Real-time countdown progress underline
	local fillTrack = Instance.new("Frame")
	fillTrack.Name = "FillTrack"
	fillTrack.AnchorPoint = Vector2.new(0.5, 1)
	fillTrack.Size = UDim2.new(0.82, 0, 0, 3)
	fillTrack.Position = UDim2.new(0.5, 0, 1, -4)
	fillTrack.BackgroundColor3 = Color3.fromRGB(255, 65, 85)
	fillTrack.BorderSizePixel = 0
	fillTrack.Parent = activePill
	Instance.new("UICorner", fillTrack).CornerRadius = UDim.new(1, 0)
	timerFillBar = fillTrack
	timerPill = activePill

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

function TableView.UpdateTurn(turnNumber: number, activePlayerName: string, isMyTurn: boolean, pillOverrideText: string?)
	currentActivePlayerName = activePlayerName
	currentIsMyTurn = isMyTurn

	if turnPillLabel then
		if pillOverrideText then
			turnPillLabel.Text = pillOverrideText
		else
			turnPillLabel.Text = "TURN " .. turnNumber
		end
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

function TableView.UpdateCenter(gameState: string, highestBid: number, challengerName: string?, totalCards: number, roundNumber: number?)
	if not centerTitleLabel then return end
	if roundNumber then
		currentRoundNumber = roundNumber
	end

	local phaseNames: { [string]: { name: string, color: string } } = {
		[Enums.GameState.Lobby] = { name = "WAITING FOR PLAYERS", color = "#50E1F5" },
		[Enums.GameState.Placement] = { name = "PLACEMENT PHASE", color = "#4ECCA3" },
		[Enums.GameState.Bidding] = { name = "BIDDING PHASE", color = "#FFD23F" },
		[Enums.GameState.Revealing] = { name = "CHALLENGE PHASE", color = "#FF6B6B" },
		[Enums.GameState.RoundEnd] = { name = "ROUND COMPLETE", color = "#FFD23F" },
		[Enums.GameState.MatchEnd] = { name = "MATCH OVER", color = "#FFD23F" },
	}

	local pInfo = phaseNames[gameState] or { name = string.upper(gameState), color = "#FFD23F" }
	centerTitleLabel.Text = `ROUND {currentRoundNumber}: <font color="{pInfo.color}">{pInfo.name}</font>`
end

function TableView.StartTurnTimer(durationSeconds: number)
	if currentTimerThread then
		task.cancel(currentTimerThread)
		currentTimerThread = nil
	end

	if not timerLabel or not timerStroke or not timerFillBar or not timerPill then
		return
	end

	timerPill.Visible = true
	local timeLeft = durationSeconds
	local isMe = currentIsMyTurn
	local initialText = isMe and string.format("👤 YOU (%ds)", math.ceil(timeLeft)) or string.format("🤖 %s (%ds)", currentActivePlayerName, math.ceil(timeLeft))

	timerLabel.Text = initialText
	timerLabel.TextColor3 = isMe and Color3.fromRGB(255, 225, 85) or Color3.fromRGB(160, 235, 255)
	timerStroke.Color = isMe and Color3.fromRGB(255, 215, 65) or Color3.fromRGB(80, 225, 245)
	timerFillBar.Size = UDim2.new(0.75, 0, 0, 3)
	timerFillBar.BackgroundColor3 = isMe and Color3.fromRGB(255, 215, 65) or Color3.fromRGB(80, 225, 245)

	currentTimerThread = task.spawn(function()
		local startTime = os.clock()
		while true do
			local elapsed = os.clock() - startTime
			local rem = math.max(0, durationSeconds - elapsed)
			local ceilRem = math.ceil(rem)

			if timerLabel then
				if currentIsMyTurn then
					timerLabel.Text = string.format("👤 YOU (%ds)", ceilRem)
				else
					timerLabel.Text = string.format("🤖 %s (%ds)", currentActivePlayerName, ceilRem)
				end
			end

			local alpha = math.clamp(rem / durationSeconds, 0, 1)
			if timerFillBar then
				timerFillBar.Size = UDim2.new(0.75 * alpha, 0, 0, 3)
			end

			if rem <= 5 then
				-- Urgency glow (Coral Red)
				if timerStroke then
					timerStroke.Color = Color3.fromRGB(255, 65, 85)
				end
				if timerLabel then
					timerLabel.TextColor3 = Color3.fromRGB(255, 95, 115)
				end
				if timerFillBar then
					timerFillBar.BackgroundColor3 = Color3.fromRGB(255, 65, 85)
				end
			end

			if rem <= 0 then
				break
			end
			task.wait(0.1)
		end
	end)
end

function TableView.StopTurnTimer()
	if currentTimerThread then
		task.cancel(currentTimerThread)
		currentTimerThread = nil
	end
	if timerLabel then
		if currentIsMyTurn then
			timerLabel.Text = "👤 YOUR TURN"
		else
			timerLabel.Text = "🤖 " .. currentActivePlayerName .. "'S TURN"
		end
	end
	if timerStroke then
		timerStroke.Color = currentIsMyTurn and Color3.fromRGB(255, 215, 65) or Color3.fromRGB(80, 225, 245)
	end
	if timerFillBar then
		timerFillBar.Size = UDim2.new(0, 0, 0, 3)
	end
end

function TableView.UpdateLayout(_players: any, _activeId: number?, _challengerId: number?)
	-- 3D Table layout handles avatars in world
end

return TableView
