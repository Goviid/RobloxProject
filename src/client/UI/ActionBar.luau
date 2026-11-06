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
-- 1. SETUP ACTION BAR
-- ============================================================================
function ActionBar.Create(parent: GuiObject, callback: (action: string, data: any) -> ()): Frame
	onActionCallback = callback

	-- Root container strictly bounded directly above cards (never covers the hand!)
	local root = Instance.new("Frame")
	root.Name = "ActionBarRoot"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Size = UDim2.new(0, 420, 0, 48)
	root.Position = UDim2.new(0.5, 0, 1, -195) -- Floats cleanly above the resting & hovered cards
	root.BackgroundTransparency = 1
	root.Active = false
	root.ZIndex = 35
	root.Parent = parent
	rootFrame = root

	local row = Instance.new("Frame")
	row.Name = "ActionRow"
	row.Size = UDim2.new(1, 0, 1, 0)
	row.BackgroundTransparency = 1
	row.Active = false
	row.Parent = root
	actionRow = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 12)
	layout.Parent = row

	-- 1. Prominent BID Button (Always visible in placement phase!)
	bidButton = makeActionPill(
		"BidBtn",
		"⚡ START BID",
		Color3.fromRGB(255, 215, 65),
		UDim2.new(0, 190, 0, 44),
		row
	)
	bidButton.LayoutOrder = 1
	bidButton.Visible = true

	-- 2. RAISE BID Button (Bidding Phase)
	raiseBidButton = makeActionPill(
		"RaiseBidBtn",
		"⚡ RAISE BID",
		Color3.fromRGB(255, 215, 65),
		UDim2.new(0, 170, 0, 44),
		row
	)
	raiseBidButton.LayoutOrder = 2
	raiseBidButton.Visible = false

	-- 3. PASS Button (Bidding Phase)
	passButton = makeActionPill(
		"PassBtn",
		"✕ PASS",
		Color3.fromRGB(255, 95, 115),
		UDim2.new(0, 120, 0, 44),
		row
	)
	passButton.LayoutOrder = 3
	passButton.Visible = false

	-- ========================================================================
	-- 2. BID NUMBER PICKER POPUP MODAL (Floats cleanly above the action bar)
	-- ========================================================================
	local modal = Instance.new("Frame")
	modal.Name = "BidPickerModal"
	modal.AnchorPoint = Vector2.new(0.5, 1)
	modal.Size = UDim2.new(0, 260, 0, 142)
	modal.Position = UDim2.new(0.5, 0, 1, -250)
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
			onActionCallback(Enums.PlayerAction.StartBid, { bid = currentBid })
		end
	end)

	bidModal = modal

	-- Click Handlers
	bidButton.MouseButton1Click:Connect(function()
		if not isBidUnlocked then
			-- Show informational feedback if clicked on Turn 1
			local NotificationBanner = require(script.Parent.NotificationBanner)
			NotificationBanner.Show("👉 Place your 1st card before starting a bid!", "info")
			return
		end
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

	local inPlacement = (gameState == Enums.GameState.Placement)
	local inBidding = (gameState == Enums.GameState.Bidding)

	if inPlacement then
		-- In Placement Phase: BID button is ALWAYS visible so player sees the option!
		bidButton.Visible = true
		raiseBidButton.Visible = false
		passButton.Visible = false

		local canBidNow = (canStartBid == true or totalCards >= 4)
		isBidUnlocked = canBidNow and isMyTurn

		local stroke = bidButton:FindFirstChildWhichIsA("UIStroke")
		if isBidUnlocked then
			bidButton.Text = "⚡ START BID"
			bidButton.TextColor3 = Color3.fromRGB(255, 215, 65)
			if stroke then stroke.Color = Color3.fromRGB(255, 215, 65) end
		else
			-- Clearly visible but indicates turn requirement
			bidButton.Text = (totalCards >= 4) and "⚡ BID (Wait for turn)" or "⚡ BID (Turn 2+)"
			bidButton.TextColor3 = Color3.fromRGB(170, 160, 130)
			if stroke then stroke.Color = Color3.fromRGB(110, 100, 70) end
		end
	elseif inBidding then
		bidButton.Visible = false
		if isMyTurn then
			raiseBidButton.Visible = (highestBid < totalCards)
			passButton.Visible = true
		else
			raiseBidButton.Visible = false
			passButton.Visible = false
		end
	else
		bidButton.Visible = false
		raiseBidButton.Visible = false
		passButton.Visible = false
	end

	if not isMyTurn and bidModal then
		bidModal.Visible = false
	end
end

return ActionBar
