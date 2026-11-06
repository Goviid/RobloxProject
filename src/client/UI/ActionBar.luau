--!strict
-- ActionBar.luau
-- Clean 3-Button Action Stack on Bottom-Right (Matching concept reference image)
-- Features:
-- 1. BET (Golden neon border)
-- 2. CHALLENGE (Coral/Crimson neon border)
-- 3. PASS (Mint green neon border)
-- 4. Sleek popup modal for selecting bid quantity

local TweenService = game:GetService("TweenService")
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local ActionBar = {}

local rootFrame: Frame? = nil
local betButton: TextButton? = nil
local challengeButton: TextButton? = nil
local passButton: TextButton? = nil

-- Bid Number Picker Modal
local bidModal: Frame? = nil
local bidValueLabel: TextLabel? = nil
local currentBid = 1
local minBid = 1
local maxBid = 1

local onActionCallback: ((action: string, data: any) -> ())? = nil

-- Helper to construct a neon pill button
local function makeActionPill(
	name: string,
	text: string,
	neonColor: Color3,
	order: number,
	parent: GuiObject
): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 145, 0, 42)
	btn.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 19
	btn.TextColor3 = neonColor
	btn.Text = text
	btn.LayoutOrder = order
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Name = "NeonBorder"
	stroke.Color = neonColor
	stroke.Thickness = 2.4
	stroke.Parent = btn

	-- Hover animation
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 155, 0, 45),
			BackgroundColor3 = Color3.fromRGB(30, 26, 36),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 3.6,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 145, 0, 42),
			BackgroundColor3 = Color3.fromRGB(20, 18, 24),
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 2.4,
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

	-- Vertical Column Container at Bottom-Right
	local col = Instance.new("Frame")
	col.Name = "ButtonColumn"
	col.AnchorPoint = Vector2.new(1, 1)
	col.Size = UDim2.new(0, 160, 0, 160)
	col.Position = UDim2.new(1, -28, 1, -25) -- Pinned bottom-right matching reference
	col.BackgroundTransparency = 1
	col.ZIndex = 26
	col.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = col

	-- 1. BET (Golden Neon `#FFD23F`)
	betButton = makeActionPill("BetBtn", "BET", Color3.fromRGB(255, 210, 65), 1, col)

	-- 2. CHALLENGE (Coral/Crimson Neon `#FF6B6B`)
	challengeButton = makeActionPill("ChallengeBtn", "CHALLENGE", Color3.fromRGB(255, 105, 105), 2, col)

	-- 3. PASS (Mint Green Neon `#4ECCA3`)
	passButton = makeActionPill("PassBtn", "PASS", Color3.fromRGB(78, 204, 163), 3, col)

	-- ========================================================================
	-- 2. BID NUMBER PICKER POPUP MODAL
	-- ========================================================================
	local modal = Instance.new("Frame")
	modal.Name = "BidPickerModal"
	modal.AnchorPoint = Vector2.new(1, 1)
	modal.Size = UDim2.new(0, 240, 0, 130)
	modal.Position = UDim2.new(1, -195, 1, -25)
	modal.BackgroundColor3 = Color3.fromRGB(18, 16, 22)
	modal.BackgroundTransparency = 0.15
	modal.BorderSizePixel = 0
	modal.ZIndex = 40
	modal.Visible = false
	modal.Parent = root
	Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)

	local mStroke = Instance.new("UIStroke")
	mStroke.Color = Color3.fromRGB(255, 210, 65)
	mStroke.Thickness = 2.5
	mStroke.Parent = modal

	local mTitle = Instance.new("TextLabel")
	mTitle.Size = UDim2.new(1, 0, 0, 28)
	mTitle.Position = UDim2.new(0, 0, 0, 6)
	mTitle.BackgroundTransparency = 1
	mTitle.Font = Enum.Font.FredokaOne
	mTitle.TextSize = 15
	mTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	mTitle.Text = "SELECT YOUR BID"
	mTitle.Parent = modal

	-- Value Controls: [-] [ VALUE ] [+]
	local minusBtn = Instance.new("TextButton")
	minusBtn.Size = UDim2.new(0, 36, 0, 36)
	minusBtn.Position = UDim2.new(0, 16, 0, 38)
	minusBtn.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	minusBtn.Font = Enum.Font.FredokaOne
	minusBtn.TextSize = 22
	minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	minusBtn.Text = "-"
	minusBtn.Parent = modal
	Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(1, 0)

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, -112, 0, 36)
	valLabel.Position = UDim2.new(0, 56, 0, 38)
	valLabel.BackgroundTransparency = 1
	valLabel.Font = Enum.Font.FredokaOne
	valLabel.TextSize = 26
	valLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valLabel.Text = "1"
	valLabel.Parent = modal
	bidValueLabel = valLabel

	local plusBtn = Instance.new("TextButton")
	plusBtn.Size = UDim2.new(0, 36, 0, 36)
	plusBtn.Position = UDim2.new(1, -52, 0, 38)
	plusBtn.BackgroundColor3 = Color3.fromRGB(30, 26, 36)
	plusBtn.Font = Enum.Font.FredokaOne
	plusBtn.TextSize = 22
	plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	plusBtn.Text = "+"
	plusBtn.Parent = modal
	Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(1, 0)

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size = UDim2.new(1, -32, 0, 34)
	confirmBtn.Position = UDim2.new(0, 16, 1, -42)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(225, 140, 25)
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
	betButton.MouseButton1Click:Connect(function()
		modal.Visible = not modal.Visible
	end)

	challengeButton.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.StartBid, { bid = currentBid })
		end
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
	if not rootFrame or not betButton or not challengeButton or not passButton then return end

	minBid = math.max(1, highestBid + 1)
	maxBid = math.max(minBid, totalCards)
	currentBid = minBid
	if bidValueLabel then
		bidValueLabel.Text = tostring(currentBid)
	end

	local inPlacement = (gameState == Enums.GameState.Placement)
	local inBidding = (gameState == Enums.GameState.Bidding)
	local inRevealing = (gameState == Enums.GameState.Revealing)

	-- BET visibility & availability
	if inPlacement then
		betButton.Visible = (canStartBid == true or totalCards >= 4)
		challengeButton.Visible = false
		passButton.Visible = false
	elseif inBidding then
		betButton.Visible = isMyTurn and (highestBid < totalCards)
		challengeButton.Visible = isMyTurn and (highestBid < totalCards)
		passButton.Visible = isMyTurn
	elseif inRevealing then
		betButton.Visible = false
		challengeButton.Visible = false
		passButton.Visible = false
	else
		betButton.Visible = false
		challengeButton.Visible = false
		passButton.Visible = false
	end

	if not isMyTurn and bidModal then
		bidModal.Visible = false
	end
end

return ActionBar
