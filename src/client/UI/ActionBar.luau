--!strict
-- ActionBar.luau
-- Clean, centered Bidding controls at the bottom center of the screen (LOCOfficial style)

local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local ActionBar = {}

local containerFrame: Frame? = nil
local passButton: TextButton? = nil
local bidConfirmButton: TextButton? = nil
local startBidButton: TextButton? = nil
local bidStepperFrame: Frame? = nil
local bidValueLabel: TextLabel? = nil
local statusHintLabel: TextLabel? = nil

local currentBidSelected = 1
local minAllowedBid = 1
local maxAllowedBid = 1
local currentActiveGameState = Enums.GameState.Placement
local onActionCallback: ((action: string, data: any) -> ())? = nil

-- ============================================================================
-- 1. BUTTON CREATION HELPER
-- ============================================================================
local function createActionButton(name: string, text: string, bgColor: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 140, 0, 46)
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Theme.Fonts.Title
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.ZIndex = 26

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Medium
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.GoldMuted
	stroke.Thickness = 1.8
	stroke.Parent = btn

	return btn
end

-- ============================================================================
-- 2. SETUP & CREATION (Pinned to Bottom Center)
-- ============================================================================
function ActionBar.Create(parent: GuiObject, callback: (action: string, data: any) -> ()): Frame
	onActionCallback = callback

	-- Centered bottom panel
	local container = Instance.new("Frame")
	container.Name = "ActionBar"
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Size = UDim2.new(0, 480, 0, 68)
	container.Position = UDim2.new(0.5, 0, 1, -16)
	container.BackgroundColor3 = Theme.Colors.PanelBackground
	container.BackgroundTransparency = 0.15
	container.BorderSizePixel = 0
	container.ZIndex = 25
	container.Visible = false
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Large
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Name = "BorderStroke"
	stroke.Color = Theme.Colors.PanelBorder
	stroke.Thickness = 2.0
	stroke.Parent = container

	-- Turn Status / Hint Label (when not your turn)
	local hint = Instance.new("TextLabel")
	hint.Name = "StatusHint"
	hint.Size = UDim2.new(1, -20, 1, 0)
	hint.Position = UDim2.new(0, 10, 0, 0)
	hint.BackgroundTransparency = 1
	hint.Font = Theme.Fonts.Header
	hint.TextSize = 14
	hint.TextColor3 = Theme.Colors.TextSecondary
	hint.Text = "Waiting for other players to bid..."
	hint.Visible = false
	hint.ZIndex = 26
	hint.Parent = container

	-- Controls Layout Row (Centered horizontally)
	local controlsRow = Instance.new("Frame")
	controlsRow.Name = "ControlsRow"
	controlsRow.Size = UDim2.new(1, -24, 0, 48)
	controlsRow.Position = UDim2.new(0, 12, 0.5, -24)
	controlsRow.BackgroundTransparency = 1
	controlsRow.ZIndex = 26
	controlsRow.Parent = container

	-- 1. Pass Button (Left)
	local passBtn = createActionButton("PassBtn", "❌ PASS", Color3.fromRGB(130, 32, 40))
	passBtn.Size = UDim2.new(0, 110, 1, 0)
	passBtn.Position = UDim2.new(0, 0, 0, 0)
	passBtn.Parent = controlsRow

	passBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.Pass, {})
		end
	end)

	-- 2. Stepper Frame (Center)
	local bidRow = Instance.new("Frame")
	bidRow.Name = "BidStepperRow"
	bidRow.Size = UDim2.new(0, 136, 1, 0)
	bidRow.Position = UDim2.new(0.5, -68, 0, 0)
	bidRow.BackgroundTransparency = 1
	bidRow.ZIndex = 26
	bidRow.Parent = controlsRow

	-- Minus Button
	local minusBtn = Instance.new("TextButton")
	minusBtn.Name = "MinusBtn"
	minusBtn.Size = UDim2.new(0, 38, 1, 0)
	minusBtn.Position = UDim2.new(0, 0, 0, 0)
	minusBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 30)
	minusBtn.Font = Theme.Fonts.Title
	minusBtn.TextSize = 18
	minusBtn.TextColor3 = Theme.Colors.TextGold
	minusBtn.Text = "-"
	minusBtn.ZIndex = 27
	minusBtn.Parent = bidRow
	Instance.new("UICorner", minusBtn).CornerRadius = Theme.CornerRadius.Small

	-- Current Bid Display
	local bidVal = Instance.new("TextLabel")
	bidVal.Name = "BidValue"
	bidVal.Size = UDim2.new(0, 52, 1, 0)
	bidVal.Position = UDim2.new(0, 42, 0, 0)
	bidVal.BackgroundColor3 = Color3.fromRGB(22, 16, 14)
	bidVal.Font = Theme.Fonts.Title
	bidVal.TextSize = 18
	bidVal.TextColor3 = Theme.Colors.TextGold
	bidVal.Text = "1"
	bidVal.ZIndex = 27
	bidVal.Parent = bidRow
	Instance.new("UICorner", bidVal).CornerRadius = Theme.CornerRadius.Small

	-- Plus Button
	local plusBtn = Instance.new("TextButton")
	plusBtn.Name = "PlusBtn"
	plusBtn.Size = UDim2.new(0, 38, 1, 0)
	plusBtn.Position = UDim2.new(0, 98, 0, 0)
	plusBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 30)
	plusBtn.Font = Theme.Fonts.Title
	plusBtn.TextSize = 18
	plusBtn.TextColor3 = Theme.Colors.TextGold
	plusBtn.Text = "+"
	plusBtn.ZIndex = 27
	plusBtn.Parent = bidRow
	Instance.new("UICorner", plusBtn).CornerRadius = Theme.CornerRadius.Small

	-- 3. Confirm / Raise Button (Right)
	local bidConfirmBtn = createActionButton("BidConfirmBtn", "⚡ RAISE TO 1", Color3.fromRGB(215, 135, 25))
	bidConfirmBtn.Size = UDim2.new(1, -270, 1, 0)
	bidConfirmBtn.Position = UDim2.new(0, 270, 0, 0)
	bidConfirmBtn.Parent = controlsRow

	bidConfirmBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			local action = (currentActiveGameState == Enums.GameState.Placement) and Enums.PlayerAction.StartBid or Enums.PlayerAction.RaiseBid
			onActionCallback(action, { bid = currentBidSelected })
		end
	end)

	minusBtn.MouseButton1Click:Connect(function()
		ActionBar.AdjustBid(-1)
	end)

	plusBtn.MouseButton1Click:Connect(function()
		ActionBar.AdjustBid(1)
	end)

	-- ========================================================================
	-- 4. START BID PILL (Used during Placement Phase right above hand)
	-- ========================================================================
	local startBidPill = Instance.new("TextButton")
	startBidPill.Name = "StartBidPill"
	startBidPill.AnchorPoint = Vector2.new(0.5, 1)
	startBidPill.Size = UDim2.new(0, 210, 0, 38)
	startBidPill.Position = UDim2.new(0.5, 0, 1, -145) -- Pinned cleanly above circular hand
	startBidPill.BackgroundColor3 = Color3.fromRGB(200, 125, 20)
	startBidPill.BorderSizePixel = 0
	startBidPill.AutoButtonColor = true
	startBidPill.Font = Theme.Fonts.Title
	startBidPill.TextSize = 13
	startBidPill.TextColor3 = Color3.fromRGB(255, 255, 255)
	startBidPill.Text = "⚡ OPEN BID (1)"
	startBidPill.ZIndex = 25
	startBidPill.Visible = false
	startBidPill.Parent = parent

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(1, 0)
	pillCorner.Parent = startBidPill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = Theme.Colors.GoldGlow
	pillStroke.Thickness = 2.0
	pillStroke.Parent = startBidPill

	startBidPill.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.StartBid, { bid = currentBidSelected })
		end
	end)

	containerFrame = container
	passButton = passBtn
	bidConfirmButton = bidConfirmBtn
	startBidButton = startBidPill
	bidStepperFrame = bidRow
	bidValueLabel = bidVal
	statusHintLabel = hint

	return container
end

-- ============================================================================
-- 3. ADJUST CURRENT BID VALUE
-- ============================================================================
function ActionBar.AdjustBid(delta: number)
	local nextVal = math.clamp(currentBidSelected + delta, minAllowedBid, maxAllowedBid)
	currentBidSelected = nextVal

	if bidValueLabel then
		bidValueLabel.Text = tostring(currentBidSelected)
	end

	if bidConfirmButton then
		if currentActiveGameState == Enums.GameState.Placement then
			bidConfirmButton.Text = "⚡ START BID " .. currentBidSelected
		else
			bidConfirmButton.Text = "⚡ RAISE TO " .. currentBidSelected
		end
	end

	if startBidButton then
		startBidButton.Text = "⚡ OPEN BID (" .. currentBidSelected .. ")"
	end
end

-- No-op compatibility hook
function ActionBar.SetSelectedCard(_cardType: string)
	-- Circular cards in HandBar are now directly clicked
end

-- ============================================================================
-- 4. DYNAMIC STATE & PHASE UPDATE
-- ============================================================================
function ActionBar.UpdateState(
	isMyTurn: boolean,
	gameState: string,
	currentHighestBid: number?,
	totalCardsOnTable: number?,
	hasCardsInHand: boolean?,
	hasPlacedFirstCard: boolean?
)
	if not containerFrame or not passButton or not bidConfirmButton or not startBidButton or not bidStepperFrame or not statusHintLabel then return end

	currentActiveGameState = gameState
	local cardsOnTable = totalCardsOnTable or 0
	local highestBidVal = currentHighestBid or 0
	local placedFirst = (hasPlacedFirstCard == true)

	-- 1. Placement Phase
	if gameState == Enums.GameState.Placement then
		containerFrame.Visible = false

		-- Show centered "OPEN BID" pill above hand if player has placed their 1st card
		if placedFirst and cardsOnTable >= 1 then
			startBidButton.Visible = true
			minAllowedBid = 1
			maxAllowedBid = math.max(1, cardsOnTable)
			currentBidSelected = 1
			ActionBar.AdjustBid(0)

			startBidButton.AutoButtonColor = isMyTurn
			startBidButton.BackgroundTransparency = isMyTurn and 0 or 0.5
		else
			startBidButton.Visible = false
		end

	-- 2. Bidding Phase (Clean centered bar at bottom)
	elseif gameState == Enums.GameState.Bidding then
		startBidButton.Visible = false
		containerFrame.Visible = true

		minAllowedBid = highestBidVal + 1
		maxAllowedBid = math.max(minAllowedBid, cardsOnTable)
		currentBidSelected = minAllowedBid
		ActionBar.AdjustBid(0)

		local canRaise = isMyTurn and (minAllowedBid <= cardsOnTable)
		local controlsRow = containerFrame:FindFirstChild("ControlsRow") :: Frame?

		if isMyTurn then
			statusHintLabel.Visible = false
			if controlsRow then controlsRow.Visible = true end

			passButton.AutoButtonColor = true
			passButton.BackgroundTransparency = 0

			bidConfirmButton.AutoButtonColor = canRaise
			bidConfirmButton.BackgroundTransparency = canRaise and 0 or 0.5

			-- Glow outline when it's your turn to bid
			local stroke = containerFrame:FindFirstChild("BorderStroke") :: UIStroke?
			if stroke then stroke.Color = Theme.Colors.GoldGlow end
		else
			-- Other player's turn to bid
			statusHintLabel.Visible = true
			statusHintLabel.Text = "Waiting for other players to bid..."
			if controlsRow then controlsRow.Visible = false end

			local stroke = containerFrame:FindFirstChild("BorderStroke") :: UIStroke?
			if stroke then stroke.Color = Theme.Colors.PanelBorder end
		end

	-- 3. Revealing / RoundEnd / Other Phases
	else
		containerFrame.Visible = false
		startBidButton.Visible = false
	end
end

return ActionBar
