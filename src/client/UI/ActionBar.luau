--!strict
-- ActionBar.luau
-- Bottom-right contextual buttons for playing cards, raising bids, and passing (LOCOfficial style)

local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local ActionBar = {}

local containerFrame: Frame? = nil
local placeButton: TextButton? = nil
local bidButton: TextButton? = nil
local passButton: TextButton? = nil
local bidStepperFrame: Frame? = nil
local bidValueLabel: TextLabel? = nil

local currentBidSelected = 1
local currentActiveGameState = Enums.GameState.Placement
local currentCardType = Enums.CardType.Rose
local onActionCallback: ((action: string, data: any) -> ())? = nil

-- ============================================================================
-- 1. BUTTON CREATION HELPER
-- ============================================================================
local function createActionButton(name: string, text: string, bgColor: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(1, 0, 0, 46)
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Theme.Fonts.Title
	btn.TextSize = 15
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Medium
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.GoldMuted
	stroke.Thickness = 1.5
	stroke.Parent = btn

	return btn
end

-- ============================================================================
-- 2. SETUP & CREATION
-- ============================================================================
function ActionBar.Create(parent: GuiObject, callback: (action: string, data: any) -> ()): Frame
	onActionCallback = callback

	local container = Instance.new("Frame")
	container.Name = "ActionBar"
	container.AnchorPoint = Vector2.new(1, 1)
	container.Size = UDim2.new(0, 310, 0, 114)
	container.Position = UDim2.new(1, -20, 1, -16)
	container.BackgroundColor3 = Theme.Colors.PanelBackground
	container.BackgroundTransparency = 0.2
	container.BorderSizePixel = 0
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Large
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.PanelBorder
	stroke.Thickness = 1.5
	stroke.Parent = container

	-- Header label
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 18)
	title.Position = UDim2.new(0, 0, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Header
	title.TextSize = 10
	title.TextColor3 = Theme.Colors.TextSecondary
	title.Text = "YOUR ACTIONS"
	title.Parent = container

	-- Buttons Layout Box
	local buttonsBox = Instance.new("Frame")
	buttonsBox.Name = "ButtonsBox"
	buttonsBox.Size = UDim2.new(1, -20, 0, 80)
	buttonsBox.Position = UDim2.new(0, 10, 0, 26)
	buttonsBox.BackgroundTransparency = 1
	buttonsBox.Parent = container

	-- 1. Prominent Place Card Button (Full Width during Placement)
	local placeBtn = createActionButton("PlaceCardBtn", "🌹 PLACE ROSE", Color3.fromRGB(36, 125, 230))
	placeBtn.Size = UDim2.new(1, 0, 0, 48)
	placeBtn.Position = UDim2.new(0, 0, 0, 0)
	placeBtn.Parent = buttonsBox
	placeBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.PlaceCard, {})
		end
	end)

	-- 2. Pass Button (Used during Bidding)
	local passBtn = createActionButton("PassBtn", "PASS", Color3.fromRGB(120, 40, 40))
	passBtn.Size = UDim2.new(0.48, 0, 0, 42)
	passBtn.Position = UDim2.new(0, 0, 0, 0)
	passBtn.Visible = false
	passBtn.Parent = buttonsBox
	passBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.Pass, {})
		end
	end)

	-- 3. Number Stepper Row (Used during Bidding or to initiate bid during Placement)
	local bidRow = Instance.new("Frame")
	bidRow.Name = "BidRow"
	bidRow.Size = UDim2.new(1, 0, 0, 36)
	bidRow.Position = UDim2.new(0, 0, 0, 44)
	bidRow.BackgroundTransparency = 1
	bidRow.Visible = false
	bidRow.Parent = buttonsBox

	-- Stepper Minus
	local minusBtn = Instance.new("TextButton")
	minusBtn.Name = "MinusBtn"
	minusBtn.Size = UDim2.new(0, 34, 1, 0)
	minusBtn.Position = UDim2.new(0, 0, 0, 0)
	minusBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 35)
	minusBtn.Font = Theme.Fonts.Header
	minusBtn.TextSize = 16
	minusBtn.TextColor3 = Theme.Colors.TextGold
	minusBtn.Text = "-"
	minusBtn.Parent = bidRow
	Instance.new("UICorner", minusBtn).CornerRadius = Theme.CornerRadius.Small

	-- Stepper Value Display
	local bidVal = Instance.new("TextLabel")
	bidVal.Name = "BidValue"
	bidVal.Size = UDim2.new(0, 44, 1, 0)
	bidVal.Position = UDim2.new(0, 36, 0, 0)
	bidVal.BackgroundColor3 = Color3.fromRGB(25, 18, 16)
	bidVal.Font = Theme.Fonts.Title
	bidVal.TextSize = 16
	bidVal.TextColor3 = Theme.Colors.TextGold
	bidVal.Text = "1"
	bidVal.Parent = bidRow
	Instance.new("UICorner", bidVal).CornerRadius = Theme.CornerRadius.Small

	-- Stepper Plus
	local plusBtn = Instance.new("TextButton")
	plusBtn.Name = "PlusBtn"
	plusBtn.Size = UDim2.new(0, 34, 1, 0)
	plusBtn.Position = UDim2.new(0, 82, 0, 0)
	plusBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 35)
	plusBtn.Font = Theme.Fonts.Header
	plusBtn.TextSize = 16
	plusBtn.TextColor3 = Theme.Colors.TextGold
	plusBtn.Text = "+"
	plusBtn.Parent = bidRow
	Instance.new("UICorner", plusBtn).CornerRadius = Theme.CornerRadius.Small

	-- Bid Confirm Button
	local bidConfirmBtn = createActionButton("BidConfirmBtn", "BID 1", Color3.fromRGB(210, 130, 20))
	bidConfirmBtn.Size = UDim2.new(1, -126, 1, 0)
	bidConfirmBtn.Position = UDim2.new(0, 126, 0, 0)
	bidConfirmBtn.Parent = bidRow

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

	containerFrame = container
	placeButton = placeBtn
	passButton = passBtn
	bidButton = bidConfirmBtn
	bidStepperFrame = bidRow
	bidValueLabel = bidVal

	return container
end

-- ============================================================================
-- 3. DYNAMIC CARD SELECTION UPDATE
-- ============================================================================
function ActionBar.SetSelectedCard(cardType: string)
	currentCardType = cardType
	if placeButton then
		if cardType == Enums.CardType.Rose then
			placeButton.Text = "🌹 PLACE ROSE"
			placeButton.BackgroundColor3 = Color3.fromRGB(36, 125, 230)
		else
			placeButton.Text = "💀 PLACE SKULL"
			placeButton.BackgroundColor3 = Color3.fromRGB(180, 45, 60)
		end
	end
end

-- ============================================================================
-- 4. DYNAMIC STATE & VALIDATION
-- ============================================================================
local minAllowedBid = 1
local maxAllowedBid = 1

function ActionBar.AdjustBid(delta: number)
	local nextVal = math.clamp(currentBidSelected + delta, minAllowedBid, maxAllowedBid)
	currentBidSelected = nextVal
	if bidValueLabel then
		bidValueLabel.Text = tostring(currentBidSelected)
	end
	if bidButton then
		bidButton.Text = "BID " .. currentBidSelected
	end
end

function ActionBar.UpdateState(
	isMyTurn: boolean,
	gameState: string,
	currentHighestBid: number?,
	totalCardsOnTable: number?,
	hasCardsInHand: boolean?,
	hasPlacedFirstCard: boolean?
)
	if not containerFrame or not placeButton or not passButton or not bidButton or not bidStepperFrame then return end
	currentActiveGameState = gameState

	local cardsOnTable = totalCardsOnTable or 0
	local highestBidVal = currentHighestBid or 0
	local cardsInHand = (hasCardsInHand == true)
	local placedFirst = (hasPlacedFirstCard == true)

	-- 1. Placement Phase
	if gameState == Enums.GameState.Placement then
		placeButton.Visible = true
		passButton.Visible = false

		-- If player has already placed a card, split the layout to allow starting a bid
		if placedFirst and cardsOnTable >= 1 then
			placeButton.Size = UDim2.new(0.48, 0, 0, 40)
			bidStepperFrame.Visible = true
			bidStepperFrame.Size = UDim2.new(1, 0, 0, 34)
			bidStepperFrame.Position = UDim2.new(0, 0, 0, 44)
		else
			placeButton.Size = UDim2.new(1, 0, 0, 50)
			bidStepperFrame.Visible = false
		end

		local canPlace = isMyTurn and cardsInHand
		placeButton.AutoButtonColor = canPlace
		placeButton.BackgroundTransparency = canPlace and 0 or 0.5
		ActionBar.SetSelectedCard(currentCardType)

		-- Stepper limits
		minAllowedBid = 1
		maxAllowedBid = math.max(1, cardsOnTable)
		if currentBidSelected < minAllowedBid then
			currentBidSelected = minAllowedBid
		end
		ActionBar.AdjustBid(0)
		bidButton.Text = "START BID " .. currentBidSelected
		bidButton.AutoButtonColor = isMyTurn and placedFirst
		bidButton.BackgroundTransparency = (isMyTurn and placedFirst) and 0 or 0.5

	-- 2. Bidding Phase
	elseif gameState == Enums.GameState.Bidding then
		placeButton.Visible = false
		passButton.Visible = true
		passButton.Size = UDim2.new(0.48, 0, 0, 40)
		passButton.Position = UDim2.new(0, 0, 0, 0)

		bidStepperFrame.Visible = true
		bidStepperFrame.Position = UDim2.new(0, 0, 0, 44)

		minAllowedBid = highestBidVal + 1
		maxAllowedBid = math.max(minAllowedBid, cardsOnTable)
		currentBidSelected = minAllowedBid
		ActionBar.AdjustBid(0)

		local canRaise = isMyTurn and (minAllowedBid <= cardsOnTable)
		bidButton.Text = "RAISE " .. currentBidSelected
		bidButton.AutoButtonColor = canRaise
		bidButton.BackgroundTransparency = canRaise and 0 or 0.5

		passButton.AutoButtonColor = isMyTurn
		passButton.BackgroundTransparency = isMyTurn and 0 or 0.5

	-- 3. Revealing or End Phases
	else
		placeButton.Visible = false
		passButton.Visible = false
		bidStepperFrame.Visible = false
	end
end

return ActionBar
