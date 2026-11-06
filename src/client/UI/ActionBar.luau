--!strict
-- ActionBar.luau
-- Prominent, Clean, Non-overlapping Action Controls (Locofficial Style)
-- Features:
-- 1. "⚡ BID" button always visible floating clearly above the card dock
-- 2. Side-by-side "⚡ RAISE BID" and "✕ PASS" during Bidding phase
-- 3. Sleek frosted glass Bid Picker Modal centered directly above the button
-- 4. Compact boundary box so it never intercepts clicks on player cards

local TweenService = game:GetService("TweenService")
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local ActionBar = {}

local rootFrame: Frame? = nil
local actionRow: Frame? = nil
local bidButton: TextButton? = nil
local raiseBidButton: TextButton? = nil
local passButton: TextButton? = nil

-- Bid Number Picker Modal
local bidModal: Frame? = nil
local bidValueLabel: TextLabel? = nil
local bidSubtitleLabel: TextLabel? = nil
local currentBid = 1
local minBid = 1
local maxBid = 1
local isBidUnlocked = false
local currentPhase: string = ""
local isMyTurnCached = false

local onActionCallback: ((action: string, data: any) -> ())? = nil

-- Helper to construct a glowing neon pill button
local function makeActionPill(
	name: string,
	text: string,
	neonColor: Color3,
	size: UDim2,
	parent: GuiObject
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = size
	btn.BackgroundColor3 = Color3.fromRGB(22, 18, 28)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 18
	btn.TextColor3 = neonColor
	btn.Text = text
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Name = "NeonBorder"
	stroke.Color = neonColor
	stroke.Thickness = 2.6
	stroke.Parent = btn

	local origSize = size

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(origSize.X.Scale, origSize.X.Offset + 8, origSize.Y.Scale, origSize.Y.Offset + 2),
			BackgroundColor3 = Color3.fromRGB(34, 28, 44),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 3.6,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = origSize,
			BackgroundColor3 = Color3.fromRGB(22, 18, 28),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 2.6,
		}):Play()
	end)

	return btn
end

-- ============================================================================
-- 1. SETUP ACTION BAR (Bottom-Right stacked pills matching reference mockup)
-- ============================================================================
function ActionBar.Create(parent: GuiObject, callback: (action: string, data: any) -> ()): Frame
	onActionCallback = callback

	-- Root container strictly anchored in the bottom-right corner (never touches cards or center table!)
	local root = Instance.new("Frame")
	root.Name = "ActionBarRoot"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Size = UDim2.new(0, 150, 0, 150)
	root.Position = UDim2.new(1, -25, 1, -25)
	root.BackgroundTransparency = 1
	root.Active = false
	root.ZIndex = 35
	root.Parent = parent
	rootFrame = root

	local col = Instance.new("Frame")
	col.Name = "ActionColumn"
	col.Size = UDim2.new(1, 0, 1, 0)
	col.BackgroundTransparency = 1
	col.Active = false
	col.Parent = root
	actionRow = col

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = col

	-- 1. Prominent BET Button (Gold/Amber)
	bidButton = makeActionPill(
		"BidBtn",
		"BET",
		Color3.fromRGB(255, 215, 65),
		UDim2.new(1, 0, 0, 42),
		col
	)
	bidButton.LayoutOrder = 1
	bidButton.Visible = true

	-- 2. RAISE BID / CHALLENGE Button (Coral/Salmon Pink)
	raiseBidButton = makeActionPill(
		"RaiseBidBtn",
		"CHALLENGE",
		Color3.fromRGB(255, 115, 130),
		UDim2.new(1, 0, 0, 42),
		col
	)
	raiseBidButton.LayoutOrder = 2
	raiseBidButton.Visible = false

	-- 3. PASS Button (Mint Green)
	passButton = makeActionPill(
		"PassBtn",
		"PASS",
		Color3.fromRGB(78, 204, 163),
		UDim2.new(1, 0, 0, 42),
		col
	)
	passButton.LayoutOrder = 3
	passButton.Visible = false

	-- ========================================================================
	-- 2. BID NUMBER PICKER POPUP MODAL (Floats neatly to the left of the action buttons)
	-- ========================================================================
	local modal = Instance.new("Frame")
	modal.Name = "BidPickerModal"
	modal.AnchorPoint = Vector2.new(1, 1)
	modal.Size = UDim2.new(0, 260, 0, 142)
	modal.Position = UDim2.new(1, -185, 1, -25)
	modal.BackgroundColor3 = Color3.fromRGB(18, 15, 25)
	modal.BackgroundTransparency = 0.10
	modal.BorderSizePixel = 0
	modal.ZIndex = 50
	modal.Visible = false
	modal.Parent = parent
	Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 14)

	local mStroke = Instance.new("UIStroke")
	mStroke.Color = Color3.fromRGB(255, 215, 65)
	mStroke.Thickness = 2.4
	mStroke.Parent = modal

	-- Modal Title
	local mTitle = Instance.new("TextLabel")
	mTitle.Size = UDim2.new(1, 0, 0, 26)
	mTitle.Position = UDim2.new(0, 0, 0, 6)
	mTitle.BackgroundTransparency = 1
	mTitle.Font = Enum.Font.FredokaOne
	mTitle.TextSize = 15
	mTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	mTitle.Text = "CHOOSE YOUR BID"
	mTitle.Parent = modal

	-- Close 'X' Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -28, 0, 6)
	closeBtn.BackgroundColor3 = Color3.fromRGB(30, 24, 38)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 13
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 215)
	closeBtn.Text = "✕"
	closeBtn.Parent = modal
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Value Controls: [-]  [ VALUE ]  [+]
	local minusBtn = Instance.new("TextButton")
	minusBtn.Size = UDim2.new(0, 38, 0, 38)
	minusBtn.Position = UDim2.new(0, 18, 0, 36)
	minusBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 42)
	minusBtn.Font = Enum.Font.FredokaOne
	minusBtn.TextSize = 22
	minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	minusBtn.Text = "-"
	minusBtn.Parent = modal
	Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(1, 0)

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, -120, 0, 38)
	valLabel.Position = UDim2.new(0, 60, 0, 36)
	valLabel.BackgroundTransparency = 1
	valLabel.Font = Enum.Font.FredokaOne
	valLabel.TextSize = 30
	valLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	valLabel.Text = "1"
	valLabel.Parent = modal
	bidValueLabel = valLabel

	local plusBtn = Instance.new("TextButton")
	plusBtn.Size = UDim2.new(0, 38, 0, 38)
	plusBtn.Position = UDim2.new(1, -56, 0, 36)
	plusBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 42)
	plusBtn.Font = Enum.Font.FredokaOne
	plusBtn.TextSize = 22
	plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	plusBtn.Text = "+"
	plusBtn.Parent = modal
	Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(1, 0)

	-- Subtitle: "Cards on Table: X"
	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0, 16)
	subLabel.Position = UDim2.new(0, 0, 0, 78)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.FredokaOne
	subLabel.TextSize = 11
	subLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
	subLabel.Text = "Cards on Table: 4"
	subLabel.Parent = modal
	bidSubtitleLabel = subLabel

	-- Confirm Bid Button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(1, -36, 0, 32)
	confirmBtn.Position = UDim2.new(0, 18, 1, -40)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(235, 155, 30)
	confirmBtn.Font = Enum.Font.FredokaOne
	confirmBtn.TextSize = 15
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.Text = "CONFIRM BID"
	confirmBtn.Parent = modal
	Instance.new("UICorner", confirmBtn).CornerRadius = UDim.new(1, 0)

	minusBtn.MouseButton1Click:Connect(function()
		if currentBid > minBid then
			currentBid -= 1
			valLabel.Text = tostring(currentBid)
		end
	end)

	plusBtn.MouseButton1Click:Connect(function()
		if currentBid < maxBid then
			currentBid += 1
			valLabel.Text = tostring(currentBid)
		end
	end)

	confirmBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
		if onActionCallback then
			local actionToFire = (currentPhase == Enums.GameState.Bidding)
				and Enums.PlayerAction.RaiseBid
				or Enums.PlayerAction.StartBid
			onActionCallback(actionToFire, { bid = currentBid })
		end
	end)

	bidModal = modal

	-- Click Handlers
	bidButton.MouseButton1Click:Connect(function()
		if currentPhase == Enums.GameState.Revealing and isMyTurnCached then
			if onActionCallback then
				local Players = game:GetService("Players")
				onActionCallback(Enums.PlayerAction.RevealCard, { targetUserId = Players.LocalPlayer.UserId })
			end
			return
		end

		if not isBidUnlocked then
			local NotificationBanner = require(script.Parent.NotificationBanner)
			NotificationBanner.Show("👉 Place your 1st card before starting a bid!", "info")
			return
		end
		modal.Visible = not modal.Visible
	end)

	raiseBidButton.MouseButton1Click:Connect(function()
		local inBidding = (currentPhase == Enums.GameState.Bidding)
		if inBidding and isMyTurnCached then
			modal.Visible = not modal.Visible
		elseif not inBidding then
			local NotificationBanner = require(script.Parent.NotificationBanner)
			NotificationBanner.Show("⚡ Challenge/Raise can only be called during betting phase!", "info")
		else
			local NotificationBanner = require(script.Parent.NotificationBanner)
			NotificationBanner.Show("⏳ Please wait for your turn to raise or challenge!", "info")
		end
	end)

	passButton.MouseButton1Click:Connect(function()
		local inBidding = (currentPhase == Enums.GameState.Bidding)
		if inBidding and isMyTurnCached then
			if onActionCallback then
				onActionCallback(Enums.PlayerAction.Pass, {})
			end
		elseif not inBidding then
			local NotificationBanner = require(script.Parent.NotificationBanner)
			NotificationBanner.Show("✕ You cannot pass during placement phase!", "info")
		else
			local NotificationBanner = require(script.Parent.NotificationBanner)
			NotificationBanner.Show("⏳ Please wait for your turn to pass!", "info")
		end
	end)

	return root
end

-- ============================================================================
-- 3. UPDATE STATE
-- ============================================================================
function ActionBar.UpdateState(
	isMyTurn: boolean,
	gameState: string,
	highestBid: number,
	totalCards: number,
	hasCardsInHand: boolean,
	hasCardsInStack: boolean,
	canStartBid: boolean?
)
	if not rootFrame or not bidButton or not raiseBidButton or not passButton then
		return
	end

	minBid = math.max(1, highestBid + 1)
	maxBid = math.max(minBid, totalCards)
	currentBid = minBid
	if bidValueLabel then
		bidValueLabel.Text = tostring(currentBid)
	end
	if bidSubtitleLabel then
		bidSubtitleLabel.Text = "Total Cards on Table: " .. totalCards
	end

	currentPhase = gameState
	isMyTurnCached = isMyTurn

	local inPlacement = (gameState == Enums.GameState.Placement)
	local inBidding = (gameState == Enums.GameState.Bidding)

	-- All 3 action pills are permanently present in bottom-right matching reference mockup
	bidButton.Visible = true
	raiseBidButton.Visible = true
	passButton.Visible = true

	local bStroke = bidButton:FindFirstChildWhichIsA("UIStroke")
	local rStroke = raiseBidButton:FindFirstChildWhichIsA("UIStroke")
	local pStroke = passButton:FindFirstChildWhichIsA("UIStroke")

	if inPlacement then
		local canBidNow = (canStartBid == true or totalCards >= 4)
		isBidUnlocked = canBidNow and isMyTurn

		bidButton.Text = isBidUnlocked and "BET" or (totalCards >= 4 and "BET (Turn)" or "BET (Turn 2+)")
		bidButton.TextColor3 = isBidUnlocked and Color3.fromRGB(255, 215, 65) or Color3.fromRGB(160, 150, 110)
		bidButton.TextTransparency = isBidUnlocked and 0 or 0.35
		if bStroke then
			bStroke.Color = isBidUnlocked and Color3.fromRGB(255, 215, 65) or Color3.fromRGB(120, 110, 60)
			bStroke.Transparency = isBidUnlocked and 0 or 0.4
		end

		-- Dim CHALLENGE & PASS during placement
		raiseBidButton.Text = "CHALLENGE"
		raiseBidButton.TextColor3 = Color3.fromRGB(255, 115, 130)
		raiseBidButton.TextTransparency = 0.55
		if rStroke then
			rStroke.Color = Color3.fromRGB(160, 65, 75)
			rStroke.Transparency = 0.60
		end

		passButton.Text = "PASS"
		passButton.TextColor3 = Color3.fromRGB(78, 204, 163)
		passButton.TextTransparency = 0.55
		if pStroke then
			pStroke.Color = Color3.fromRGB(45, 120, 95)
			pStroke.Transparency = 0.60
		end

	elseif inBidding then
		-- Dim BET or switch to RAISE
		isBidUnlocked = false
		bidButton.Text = "BET"
		bidButton.TextColor3 = Color3.fromRGB(160, 150, 110)
		bidButton.TextTransparency = 0.55
		if bStroke then
			bStroke.Color = Color3.fromRGB(110, 100, 60)
			bStroke.Transparency = 0.60
		end

		-- Active CHALLENGE / RAISE BID
		local canChallenge = isMyTurn and (highestBid < totalCards)
		raiseBidButton.Text = (highestBid + 1 >= totalCards) and "CHALLENGE" or "RAISE BID"
		raiseBidButton.TextColor3 = Color3.fromRGB(255, 115, 130)
		raiseBidButton.TextTransparency = canChallenge and 0 or 0.45
		if rStroke then
			rStroke.Color = canChallenge and Color3.fromRGB(255, 115, 130) or Color3.fromRGB(160, 65, 75)
			rStroke.Transparency = canChallenge and 0 or 0.50
		end

		-- Active PASS
		passButton.Text = "PASS"
		passButton.TextColor3 = Color3.fromRGB(78, 204, 163)
		passButton.TextTransparency = isMyTurn and 0 or 0.45
		if pStroke then
			pStroke.Color = isMyTurn and Color3.fromRGB(78, 204, 163) or Color3.fromRGB(45, 120, 95)
			pStroke.Transparency = isMyTurn and 0 or 0.50
		end

	elseif gameState == Enums.GameState.Revealing then
		-- Challenge / Revealing Phase
		isBidUnlocked = isMyTurn and hasCardsInStack
		if isMyTurn and hasCardsInStack then
			bidButton.Text = "FLIP OWN PILE"
			bidButton.TextColor3 = Color3.fromRGB(255, 80, 100)
			bidButton.TextTransparency = 0
			if bStroke then
				bStroke.Color = Color3.fromRGB(255, 65, 85)
				bStroke.Transparency = 0
			end
		elseif isMyTurn then
			bidButton.Text = "FLIP OPPONENT"
			bidButton.TextColor3 = Color3.fromRGB(255, 215, 65)
			bidButton.TextTransparency = 0.2
			if bStroke then
				bStroke.Color = Color3.fromRGB(255, 215, 65)
				bStroke.Transparency = 0.2
			end
		else
			bidButton.Text = "REVEALING"
			bidButton.TextTransparency = 0.6
			if bStroke then bStroke.Transparency = 0.6 end
		end

		raiseBidButton.Text = "CHALLENGE"
		raiseBidButton.TextTransparency = 0.6
		passButton.Text = "PASS"
		passButton.TextTransparency = 0.6
		if rStroke then rStroke.Transparency = 0.6 end
		if pStroke then pStroke.Transparency = 0.6 end

	else
		-- RoundEnd / Lobby: keep stacked layout in quiet mode
		isBidUnlocked = false
		bidButton.Text = "BET"
		bidButton.TextTransparency = 0.6
		raiseBidButton.Text = "CHALLENGE"
		raiseBidButton.TextTransparency = 0.6
		passButton.Text = "PASS"
		passButton.TextTransparency = 0.6
		if bStroke then bStroke.Transparency = 0.6 end
		if rStroke then rStroke.Transparency = 0.6 end
		if pStroke then pStroke.Transparency = 0.6 end
	end

	if not isMyTurn and bidModal then
		bidModal.Visible = false
	end
end

return ActionBar
