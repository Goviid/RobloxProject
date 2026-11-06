--!strict
-- ActionBar.luau
-- Prominent, Centered, Highly Polished Action Bar (Locofficial Style)
-- Features:
-- 1. Prominent, obvious, centered "⚡ BID" button directly above the circular cards
-- 2. Side-by-side "⚡ RAISE BID" and "✕ PASS" during Bidding phase
-- 3. Sleek frosted glass Bid Picker Modal centered directly above the button
-- 4. Informational status pill for round progress and hints

local TweenService = game:GetService("TweenService")
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local ActionBar = {}

local rootFrame: Frame? = nil
local actionRow: Frame? = nil
local bidButton: TextButton? = nil
local raiseBidButton: TextButton? = nil
local passButton: TextButton? = nil
local statusPill: Frame? = nil
local statusLabel: TextLabel? = nil

-- Bid Number Picker Modal
local bidModal: Frame? = nil
local bidValueLabel: TextLabel? = nil
local bidSubtitleLabel: TextLabel? = nil
local currentBid = 1
local minBid = 1
local maxBid = 1

local onActionCallback: ((action: string, data: any) -> ())? = nil

-- Helper to construct a large glowing neon pill button
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
	btn.TextSize = 20
	btn.TextColor3 = neonColor
	btn.Text = text
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Name = "NeonBorder"
	stroke.Color = neonColor
	stroke.Thickness = 3.0
	stroke.Parent = btn

	local origSize = size

	-- Tactile hover animation
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(origSize.X.Scale, origSize.X.Offset + 10, origSize.Y.Scale, origSize.Y.Offset + 4),
			BackgroundColor3 = Color3.fromRGB(34, 28, 44),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 4.2,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = origSize,
			BackgroundColor3 = Color3.fromRGB(22, 18, 28),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 3.0,
		}):Play()
	end)

	return btn
end

-- ============================================================================
-- 1. SETUP ACTION BAR
-- ============================================================================
function ActionBar.Create(parent: GuiObject, callback: (action: string, data: any) -> ()): Frame
	onActionCallback = callback

	local root = Instance.new("Frame")
	root.Name = "ActionBarRoot"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.ZIndex = 25
	root.Parent = parent
	rootFrame = root

	-- Prominent Centered Row directly above the circular cards dock
	local row = Instance.new("Frame")
	row.Name = "CenteredActionRow"
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Size = UDim2.new(0, 440, 0, 54)
	row.Position = UDim2.new(0.5, 0, 1, -210) -- Prominently floating in center view
	row.BackgroundTransparency = 1
	row.ZIndex = 26
	row.Parent = root
	actionRow = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 14)
	layout.Parent = row

	-- 1. Prominent OBVIOUS BID Button (Placement Phase)
	bidButton = makeActionPill(
		"BidBtn",
		"⚡ START BID",
		Color3.fromRGB(255, 215, 65),
		UDim2.new(0, 200, 0, 48),
		row
	)
	bidButton.LayoutOrder = 1
	bidButton.Visible = false

	-- 2. RAISE BID Button (Bidding Phase)
	raiseBidButton = makeActionPill(
		"RaiseBidBtn",
		"⚡ RAISE BID",
		Color3.fromRGB(255, 215, 65),
		UDim2.new(0, 180, 0, 48),
		row
	)
	raiseBidButton.LayoutOrder = 2
	raiseBidButton.Visible = false

	-- 3. PASS Button (Bidding Phase)
	passButton = makeActionPill(
		"PassBtn",
		"✕ PASS",
		Color3.fromRGB(255, 95, 115),
		UDim2.new(0, 130, 0, 48),
		row
	)
	passButton.LayoutOrder = 3
	passButton.Visible = false

	-- 4. Sleek Status Pill (Hints / Turn Info)
	local pill = Instance.new("Frame")
	pill.Name = "StatusPill"
	pill.Size = UDim2.new(0, 360, 0, 40)
	pill.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	pill.BackgroundTransparency = 0.25
	pill.BorderSizePixel = 0
	pill.LayoutOrder = 4
	pill.Visible = false
	pill.Parent = row
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

	local pStroke = Instance.new("UIStroke")
	pStroke.Color = Color3.fromRGB(80, 225, 245)
	pStroke.Transparency = 0.4
	pStroke.Thickness = 1.8
	pStroke.Parent = pill

	local pLabel = Instance.new("TextLabel")
	pLabel.Name = "StatusText"
	pLabel.Size = UDim2.new(1, -20, 1, 0)
	pLabel.Position = UDim2.new(0, 10, 0, 0)
	pLabel.BackgroundTransparency = 1
	pLabel.Font = Enum.Font.FredokaOne
	pLabel.TextSize = 15
	pLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	pLabel.Text = "Waiting for game..."
	pLabel.Parent = pill

	statusPill = pill
	statusLabel = pLabel

	-- ========================================================================
	-- 2. BID NUMBER PICKER POPUP MODAL (Centered directly above Bid Button)
	-- ========================================================================
	local modal = Instance.new("Frame")
	modal.Name = "BidPickerModal"
	modal.AnchorPoint = Vector2.new(0.5, 1)
	modal.Size = UDim2.new(0, 270, 0, 150)
	modal.Position = UDim2.new(0.5, 0, 1, -270)
	modal.BackgroundColor3 = Color3.fromRGB(18, 15, 25)
	modal.BackgroundTransparency = 0.12
	modal.BorderSizePixel = 0
	modal.ZIndex = 40
	modal.Visible = false
	modal.Parent = root
	Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)

	local mStroke = Instance.new("UIStroke")
	mStroke.Color = Color3.fromRGB(255, 215, 65)
	mStroke.Thickness = 2.6
	mStroke.Parent = modal

	-- Modal Title
	local mTitle = Instance.new("TextLabel")
	mTitle.Size = UDim2.new(1, 0, 0, 28)
	mTitle.Position = UDim2.new(0, 0, 0, 8)
	mTitle.BackgroundTransparency = 1
	mTitle.Font = Enum.Font.FredokaOne
	mTitle.TextSize = 16
	mTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	mTitle.Text = "CHOOSE YOUR BID"
	mTitle.Parent = modal

	-- Close 'X' Button in Top-Right
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26)
	closeBtn.Position = UDim2.new(1, -32, 0, 8)
	closeBtn.BackgroundColor3 = Color3.fromRGB(30, 24, 38)
	closeBtn.Font = Enum.Font.FredokaOne
	closeBtn.TextSize = 14
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 215)
	closeBtn.Text = "✕"
	closeBtn.Parent = modal
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
	closeBtn.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)

	-- Value Controls: [-]  [ VALUE ]  [+]
	local minusBtn = Instance.new("TextButton")
	minusBtn.Size = UDim2.new(0, 42, 0, 42)
	minusBtn.Position = UDim2.new(0, 20, 0, 40)
	minusBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 42)
	minusBtn.Font = Enum.Font.FredokaOne
	minusBtn.TextSize = 24
	minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	minusBtn.Text = "-"
	minusBtn.Parent = modal
	Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(1, 0)

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, -132, 0, 42)
	valLabel.Position = UDim2.new(0, 66, 0, 40)
	valLabel.BackgroundTransparency = 1
	valLabel.Font = Enum.Font.FredokaOne
	valLabel.TextSize = 34
	valLabel.TextColor3 = Color3.fromRGB(255, 225, 90)
	valLabel.Text = "1"
	valLabel.Parent = modal
	bidValueLabel = valLabel

	local plusBtn = Instance.new("TextButton")
	plusBtn.Size = UDim2.new(0, 42, 0, 42)
	plusBtn.Position = UDim2.new(1, -62, 0, 40)
	plusBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 42)
	plusBtn.Font = Enum.Font.FredokaOne
	plusBtn.TextSize = 24
	plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	plusBtn.Text = "+"
	plusBtn.Parent = modal
	Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(1, 0)

	-- Subtitle: "Total Cards on Table: X"
	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, 0, 0, 16)
	subLabel.Position = UDim2.new(0, 0, 0, 84)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.FredokaOne
	subLabel.TextSize = 12
	subLabel.TextColor3 = Color3.fromRGB(180, 185, 200)
	subLabel.Text = "Total Cards on Table: 4"
	subLabel.Parent = modal
	bidSubtitleLabel = subLabel

	-- Confirm Bid Button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(1, -40, 0, 36)
	confirmBtn.Position = UDim2.new(0, 20, 1, -44)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(235, 155, 30)
	confirmBtn.Font = Enum.Font.FredokaOne
	confirmBtn.TextSize = 16
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
			onActionCallback(Enums.PlayerAction.StartBid, { bid = currentBid })
		end
	end)

	bidModal = modal

	-- Click Handlers
	bidButton.MouseButton1Click:Connect(function()
		modal.Visible = not modal.Visible
	end)

	raiseBidButton.MouseButton1Click:Connect(function()
		modal.Visible = not modal.Visible
	end)

	passButton.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.Pass, {})
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
	if not rootFrame or not bidButton or not raiseBidButton or not passButton or not statusPill or not statusLabel then
		return
	end

	minBid = math.max(1, highestBid + 1)
	maxBid = math.max(minBid, totalCards)
	currentBid = minBid
	if bidValueLabel then
		bidValueLabel.Text = tostring(currentBid)
	end
	if bidSubtitleLabel then
		bidSubtitleLabel.Text = "Cards on Table: " .. totalCards
	end

	local inPlacement = (gameState == Enums.GameState.Placement)
	local inBidding = (gameState == Enums.GameState.Bidding)
	local inRevealing = (gameState == Enums.GameState.Revealing)

	if inPlacement then
		if isMyTurn then
			if canStartBid == true or totalCards >= 4 then
				bidButton.Visible = true
				bidButton.Text = "⚡ START BID"
				raiseBidButton.Visible = false
				passButton.Visible = false
				statusPill.Visible = false
			else
				bidButton.Visible = false
				raiseBidButton.Visible = false
				passButton.Visible = false
				statusPill.Visible = true
				statusLabel.Text = "👉 YOUR TURN: Choose a card from hand to place!"
			end
		else
			bidButton.Visible = false
			raiseBidButton.Visible = false
			passButton.Visible = false
			statusPill.Visible = true
			statusLabel.Text = "Waiting for other players to place..."
		end
	elseif inBidding then
		if isMyTurn then
			bidButton.Visible = false
			raiseBidButton.Visible = (highestBid < totalCards)
			passButton.Visible = true
			statusPill.Visible = false
		else
			bidButton.Visible = false
			raiseBidButton.Visible = false
			passButton.Visible = false
			statusPill.Visible = true
			statusLabel.Text = "Bidding Phase: Current bid is " .. highestBid .. " cards"
		end
	elseif inRevealing then
		bidButton.Visible = false
		raiseBidButton.Visible = false
		passButton.Visible = false
		statusPill.Visible = true
		statusLabel.Text = "🔍 Click card stacks on the table to reveal them!"
	else
		bidButton.Visible = false
		raiseBidButton.Visible = false
		passButton.Visible = false
		statusPill.Visible = false
	end

	if not isMyTurn and bidModal then
		bidModal.Visible = false
	end
end

return ActionBar
