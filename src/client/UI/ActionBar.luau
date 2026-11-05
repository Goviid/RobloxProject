--!strict
-- ActionBar.luau
-- Bottom-right contextual buttons for playing cards, raising bids, and passing

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
local onActionCallback: ((action: string, data: any) -> ())? = nil

-- ============================================================================
-- 1. BUTTON CREATION HELPER
-- ============================================================================
local function createActionButton(name: string, text: string, bgColor: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 160, 0, 42)
	btn.BackgroundColor3 = bgColor
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Font = Theme.Fonts.Header
	btn.TextSize = 13
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Medium
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.GoldMuted
	stroke.Thickness = 1
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
	container.Size = UDim2.new(0, 360, 0, 110)
	container.Position = UDim2.new(1, -380, 1, -126)
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
	title.Text = "ACTIONS"
	title.Parent = container

	-- Buttons Layout Box
	local buttonsBox = Instance.new("Frame")
	buttonsBox.Name = "ButtonsBox"
	buttonsBox.Size = UDim2.new(1, -20, 0, 76)
	buttonsBox.Position = UDim2.new(0, 10, 0, 26)
	buttonsBox.BackgroundTransparency = 1
	buttonsBox.Parent = container

	-- 1. Place Card Button
	local placeBtn = createActionButton("PlaceCardBtn", "Place Card", Color3.fromRGB(40, 120, 220))
	placeBtn.Size = UDim2.new(0.48, 0, 0, 38)
	placeBtn.Position = UDim2.new(0, 0, 0, 0)
	placeBtn.Parent = buttonsBox
	placeBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.PlaceCard, {})
		end
	end)

	-- 2. Pass Button
	local passBtn = createActionButton("PassBtn", "Pass", Color3.fromRGB(90, 80, 80))
	passBtn.Size = UDim2.new(0.48, 0, 0, 38)
	passBtn.Position = UDim2.new(0.52, 0, 0, 0)
	passBtn.Parent = buttonsBox
	passBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.Pass, {})
		end
	end)

	-- 3. Bid Stepper & Challenge Button Row (Bottom Row)
	local bidRow = Instance.new("Frame")
	bidRow.Name = "BidRow"
	bidRow.Size = UDim2.new(1, 0, 0, 34)
	bidRow.Position = UDim2.new(0, 0, 0, 42)
	bidRow.BackgroundTransparency = 1
	bidRow.Parent = buttonsBox

	-- Stepper Minus
	local minusBtn = Instance.new("TextButton")
	minusBtn.Name = "MinusBtn"
	minusBtn.Size = UDim2.new(0, 32, 1, 0)
	minusBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 35)
	minusBtn.Font = Theme.Fonts.Header
	minusBtn.TextSize = 14
	minusBtn.TextColor3 = Theme.Colors.TextGold
	minusBtn.Text = "-"
	minusBtn.Parent = bidRow
	Instance.new("UICorner", minusBtn).CornerRadius = Theme.CornerRadius.Small

	-- Stepper Label
	local bidVal = Instance.new("TextLabel")
	bidVal.Name = "BidVal"
	bidVal.Size = UDim2.new(0, 40, 1, 0)
	bidVal.Position = UDim2.new(0, 36, 0, 0)
	bidVal.BackgroundTransparency = 1
	bidVal.Font = Theme.Fonts.Title
	bidVal.TextSize = 16
	bidVal.TextColor3 = Theme.Colors.TextGold
	bidVal.Text = "1"
	bidVal.Parent = bidRow

	-- Stepper Plus
	local plusBtn = Instance.new("TextButton")
	plusBtn.Name = "PlusBtn"
	plusBtn.Size = UDim2.new(0, 32, 1, 0)
	plusBtn.Position = UDim2.new(0, 80, 0, 0)
	plusBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 35)
	plusBtn.Font = Theme.Fonts.Header
	plusBtn.TextSize = 14
	plusBtn.TextColor3 = Theme.Colors.TextGold
	plusBtn.Text = "+"
	plusBtn.Parent = bidRow
	Instance.new("UICorner", plusBtn).CornerRadius = Theme.CornerRadius.Small

	-- Bid Confirm Button
	local bidConfirmBtn = createActionButton("BidConfirmBtn", "Bid 1", Color3.fromRGB(200, 120, 20))
	bidConfirmBtn.Size = UDim2.new(1, -120, 1, 0)
	bidConfirmBtn.Position = UDim2.new(0, 120, 0, 0)
	bidConfirmBtn.Parent = bidRow

	bidConfirmBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.RaiseBid, { bid = currentBidSelected })
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
-- 3. DYNAMIC STATE & VALIDATION
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
		bidButton.Text = "Bid " .. currentBidSelected
	end
end

function ActionBar.UpdateState(
	isMyTurn: boolean,
	gameState: string,
	currentHighestBid: number,
	totalCardsOnTable: number,
	hasCardsInHand: boolean,
	hasPlacedFirstCard: boolean
)
	if not containerFrame or not placeButton or not passButton or not bidButton then return end

	-- 1. Placement Phase
	if gameState == Enums.GameState.Placement then
		placeButton.Visible = true
		passButton.Visible = false
		bidStepperFrame.Visible = hasPlacedFirstCard

		local canPlace = isMyTurn and hasCardsInHand
		placeButton.AutoButtonColor = canPlace
		placeButton.BackgroundTransparency = canPlace and 0 or 0.6
		placeButton.Text = "Place Card"

		-- Can start bid if mandatory 1st card placed by all
		minAllowedBid = 1
		maxAllowedBid = math.max(1, totalCardsOnTable)
		if currentBidSelected < minAllowedBid then
			currentBidSelected = minAllowedBid
		end
		ActionBar.AdjustBid(0)
		bidButton.Text = "Start Bid " .. currentBidSelected
		bidButton.AutoButtonColor = isMyTurn and hasPlacedFirstCard
		bidButton.BackgroundTransparency = (isMyTurn and hasPlacedFirstCard) and 0 or 0.6

	-- 2. Bidding Phase
	elseif gameState == Enums.GameState.Bidding then
		placeButton.Visible = false
		passButton.Visible = true
		bidStepperFrame.Visible = true

		minAllowedBid = currentHighestBid + 1
		maxAllowedBid = math.max(minAllowedBid, totalCardsOnTable)
		currentBidSelected = minAllowedBid
		ActionBar.AdjustBid(0)

		local canRaise = isMyTurn and (minAllowedBid <= totalCardsOnTable)
		bidButton.Text = "Raise Bid " .. currentBidSelected
		bidButton.AutoButtonColor = canRaise
		bidButton.BackgroundTransparency = canRaise and 0 or 0.6

		passButton.AutoButtonColor = isMyTurn
		passButton.BackgroundTransparency = isMyTurn and 0 or 0.6

	-- 3. Revealing or End Phases
	else
		placeButton.Visible = false
		passButton.Visible = false
		bidStepperFrame.Visible = false
	end
end

return ActionBar
