--!strict
-- HandBar.luau
-- Bottom tray displaying the local player's cards (Roses & Skull) with selection and hover states

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local HandBar = {}

local containerFrame: Frame? = nil
local cardsContainer: Frame? = nil
local selectedCard: string? = nil
local cardButtons: { [string]: ImageButton } = {}

-- Callback when player clicks a card
export type CardSelectCallback = (cardType: string) -> ()
local onCardClickedCallback: CardSelectCallback? = nil

-- ============================================================================
-- 1. CARD VISUAL CREATION HELPER
-- ============================================================================
local function createCardElement(cardType: string): ImageButton
	local isRose = (cardType == Enums.CardType.Rose)

	local btn = Instance.new("ImageButton")
	btn.Name = "Card_" .. cardType
	btn.Size = UDim2.new(0, 84, 0, 84)
	btn.BackgroundColor3 = isRose and Theme.Colors.RosePrimary or Theme.Colors.SkullPrimary
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false

	-- Circle corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Circular
	corner.Parent = btn

	-- Ornate gold rim
	local stroke = Instance.new("UIStroke")
	stroke.Name = "BorderStroke"
	stroke.Color = Theme.Colors.GoldMuted
	stroke.Thickness = 2.5
	stroke.Parent = btn

	-- Inner decorative ring
	local innerRing = Instance.new("Frame")
	innerRing.Name = "InnerRing"
	innerRing.Size = UDim2.new(1, -12, 1, -12)
	innerRing.Position = UDim2.new(0, 6, 0, 6)
	innerRing.BackgroundTransparency = 1
	innerRing.Parent = btn

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = Theme.CornerRadius.Circular
	ringCorner.Parent = innerRing

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = isRose and Theme.Colors.RoseAccent or Theme.Colors.SkullAccent
	ringStroke.Thickness = 1
	ringStroke.Parent = innerRing

	-- Center Icon / Art
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 1, -20)
	icon.Position = UDim2.new(0, 0, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 34
	icon.Text = isRose and "🌹" or "💀"
	icon.Parent = btn

	-- Card label below icon ("ROSE" or "SKULL")
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Position = UDim2.new(0, 0, 1, -22)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Header
	label.TextSize = 10
	label.TextColor3 = isRose and Color3.fromRGB(255, 220, 225) or Color3.fromRGB(255, 170, 170)
	label.Text = isRose and "ROSE" or "SKULL"
	label.Parent = btn

	-- Count badge (top right)
	local badge = Instance.new("Frame")
	badge.Name = "CountBadge"
	badge.Size = UDim2.new(0, 22, 0, 22)
	badge.Position = UDim2.new(1, -16, 0, -4)
	badge.BackgroundColor3 = Color3.fromRGB(15, 10, 10)
	badge.BorderSizePixel = 0
	badge.Parent = btn

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = Theme.CornerRadius.Circular
	badgeCorner.Parent = badge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Theme.Colors.Gold
	badgeStroke.Thickness = 1
	badgeStroke.Parent = badge

	local countText = Instance.new("TextLabel")
	countText.Name = "CountText"
	countText.Size = UDim2.new(1, 0, 1, 0)
	countText.BackgroundTransparency = 1
	countText.Font = Theme.Fonts.Header
	countText.TextSize = 11
	countText.TextColor3 = Theme.Colors.TextGold
	countText.Text = "1"
	countText.Parent = badge

	-- Hover & Click Interactions
	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("Disabled") == true then return end
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0, btn.Position.X.Offset, 0, -10),
		}):Play()
		stroke.Color = Theme.Colors.GoldGlow
		stroke.Thickness = 3.5
	end)

	btn.MouseLeave:Connect(function()
		local isSel = (selectedCard == cardType)
		local targetY = isSel and -12 or 0
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0, btn.Position.X.Offset, 0, targetY),
		}):Play()
		stroke.Color = isSel and Theme.Colors.GoldGlow or Theme.Colors.GoldMuted
		stroke.Thickness = isSel and 3.5 or 2.5
	end)

	btn.MouseButton1Click:Connect(function()
		if btn:GetAttribute("Disabled") == true then return end
		HandBar.SelectCard(cardType)
		if onCardClickedCallback then
			onCardClickedCallback(cardType)
		end
	end)

	return btn
end

-- ============================================================================
-- 2. PUBLIC API: SETUP & RENDER
-- ============================================================================
function HandBar.Create(parent: GuiObject, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect

	-- Bottom drawer tray
	local tray = Instance.new("Frame")
	tray.Name = "HandBar"
	tray.Size = UDim2.new(0, 320, 0, 110)
	tray.Position = UDim2.new(0.5, -160, 1, -126)
	tray.BackgroundColor3 = Theme.Colors.PanelBackground
	tray.BackgroundTransparency = 0.2
	tray.BorderSizePixel = 0
	tray.Parent = parent

	local trayCorner = Instance.new("UICorner")
	trayCorner.CornerRadius = Theme.CornerRadius.Large
	trayCorner.Parent = tray

	local trayStroke = Instance.new("UIStroke")
	trayStroke.Color = Theme.Colors.PanelBorder
	trayStroke.Thickness = 1.5
	trayStroke.Parent = tray

	-- Header label ("YOUR HAND")
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 18)
	title.Position = UDim2.new(0, 0, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Header
	title.TextSize = 10
	title.TextColor3 = Theme.Colors.TextSecondary
	title.Text = "YOUR HAND"
	title.Parent = tray

	-- Cards container (horizontal layout)
	local cardsBox = Instance.new("Frame")
	cardsBox.Name = "CardsBox"
	cardsBox.Size = UDim2.new(1, -24, 0, 84)
	cardsBox.Position = UDim2.new(0, 12, 0, 22)
	cardsBox.BackgroundTransparency = 1
	cardsBox.Parent = tray

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 24)
	layout.Parent = cardsBox

	-- Pre-create Rose and Skull buttons
	local roseBtn = createCardElement(Enums.CardType.Rose)
	roseBtn.Parent = cardsBox
	cardButtons[Enums.CardType.Rose] = roseBtn

	local skullBtn = createCardElement(Enums.CardType.Skull)
	skullBtn.Parent = cardsBox
	cardButtons[Enums.CardType.Skull] = skullBtn

	containerFrame = tray
	cardsContainer = cardsBox

	return tray
end

-- Select a card to prepare for placement
function HandBar.SelectCard(cardType: string)
	selectedCard = cardType

	for cType, btn in pairs(cardButtons) do
		local isSel = (cType == cardType)
		local stroke = btn:FindFirstChild("BorderStroke") :: UIStroke?
		if stroke then
			stroke.Color = isSel and Theme.Colors.GoldGlow or Theme.Colors.GoldMuted
			stroke.Thickness = isSel and 3.5 or 2.5
		end
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0, btn.Position.X.Offset, 0, isSel and -12 or 0),
		}):Play()
	end
end

function HandBar.GetSelectedCard(): string?
	return selectedCard
end

-- Refresh hand counts and enable/disable states based on current turn
function HandBar.UpdateHand(handCards: { string }, isMyTurn: boolean, canPlace: boolean)
	local roseCount = 0
	local skullCount = 0

	for _, c in ipairs(handCards) do
		if c == Enums.CardType.Rose then
			roseCount += 1
		elseif c == Enums.CardType.Skull then
			skullCount += 1
		end
	end

	-- Update Rose card
	local roseBtn = cardButtons[Enums.CardType.Rose]
	if roseBtn then
		local countText = roseBtn:FindFirstChild("CountBadge") and roseBtn.CountBadge:FindFirstChild("CountText") :: TextLabel?
		if countText then countText.Text = tostring(roseCount) end
		roseBtn.Visible = (roseCount > 0)

		local isEnabled = (isMyTurn and canPlace and roseCount > 0)
		roseBtn:SetAttribute("Disabled", not isEnabled)
		roseBtn.BackgroundTransparency = isEnabled and 0 or 0.5
	end

	-- Update Skull card
	local skullBtn = cardButtons[Enums.CardType.Skull]
	if skullBtn then
		local countText = skullBtn:FindFirstChild("CountBadge") and skullBtn.CountBadge:FindFirstChild("CountText") :: TextLabel?
		if countText then countText.Text = tostring(skullCount) end
		skullBtn.Visible = (skullCount > 0)

		local isEnabled = (isMyTurn and canPlace and skullCount > 0)
		skullBtn:SetAttribute("Disabled", not isEnabled)
		skullBtn.BackgroundTransparency = isEnabled and 0 or 0.5
	end

	-- Auto-select first available card if selection became invalid
	if selectedCard == Enums.CardType.Rose and roseCount == 0 then
		selectedCard = (skullCount > 0) and Enums.CardType.Skull or nil
	elseif selectedCard == Enums.CardType.Skull and skullCount == 0 then
		selectedCard = (roseCount > 0) and Enums.CardType.Rose or nil
	elseif not selectedCard then
		selectedCard = (roseCount > 0) and Enums.CardType.Rose or ((skullCount > 0) and Enums.CardType.Skull or nil)
	end

	if selectedCard then
		HandBar.SelectCard(selectedCard)
	end
end

return HandBar
