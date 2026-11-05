--!strict
-- HandBar.luau
-- LOCOfficial-style circular cards hovering at the bottom center of the screen
-- Displays individual cards (Roses and Skull randomly ordered) with tactile spring hover and direct 1-click placement

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local HandBar = {}

export type CardSelectCallback = (cardType: string, cardIndex: number) -> ()
local onCardClickedCallback: CardSelectCallback? = nil

local dockFrame: Frame? = nil
local cardButtons: { ImageButton } = {}
local currentHand: { string } = {}
local canCurrentlyPlace = false
local isPlayerTurn = false
local selectedCard: string? = nil

-- Circular Card Dimensions (LOCOfficial style)
local CARD_DIAMETER = 112
local CARD_SPACING = 124

-- ============================================================================
-- 1. CONSTRUCT A CIRCULAR CARD BUTTON
-- ============================================================================
local function createCircularCard(cardType: string, index: number, restingPos: UDim2, isPlayable: boolean): ImageButton
	local isRose = (cardType == Enums.CardType.Rose)

	local btn = Instance.new("ImageButton")
	btn.Name = "Card_" .. index .. "_" .. cardType
	btn.Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER)
	btn.AnchorPoint = Vector2.new(0.5, 1)
	btn.Position = restingPos
	btn.BackgroundColor3 = isRose and Color3.fromRGB(160, 24, 40) or Color3.fromRGB(26, 22, 26)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = 22 + index
	btn:SetAttribute("CardType", cardType)
	btn:SetAttribute("CardIndex", index)
	btn:SetAttribute("IsPlayable", isPlayable)

	-- 1. Perfect Circle Shape
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	-- 2. Outer Ornate Gold Rim
	local stroke = Instance.new("UIStroke")
	stroke.Name = "CardBorder"
	stroke.Color = isRose and Color3.fromRGB(240, 190, 60) or Color3.fromRGB(245, 175, 45)
	stroke.Thickness = 3.5
	stroke.Parent = btn

	-- 3. Inner Filigree Circle Ring
	local innerRing = Instance.new("Frame")
	innerRing.Name = "InnerRing"
	innerRing.Size = UDim2.new(1, -14, 1, -14)
	innerRing.Position = UDim2.new(0, 7, 0, 7)
	innerRing.BackgroundTransparency = 1
	innerRing.ZIndex = btn.ZIndex + 1
	innerRing.Parent = btn

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = innerRing

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(255, 235, 170)
	innerStroke.Transparency = 0.5
	innerStroke.Thickness = 1.2
	innerStroke.Parent = innerRing

	-- 4. Large Center Card Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 56)
	icon.Position = UDim2.new(0, 0, 0, 16)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 50
	icon.Text = isRose and "🌹" or "💀"
	icon.ZIndex = btn.ZIndex + 2
	icon.Parent = btn

	-- 5. Bottom Card Label ("ROSE" or "SKULL")
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.Position = UDim2.new(0, 0, 1, -30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Theme.Fonts.Header
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = isRose and Color3.fromRGB(255, 240, 230) or Color3.fromRGB(255, 195, 110)
	nameLabel.Text = isRose and "ROSE" or "SKULL"
	nameLabel.ZIndex = btn.ZIndex + 2
	nameLabel.Parent = btn

	-- Apply disabled transparency if not playable
	if not isPlayable then
		btn.BackgroundTransparency = 0.45
		icon.TextTransparency = 0.45
		nameLabel.TextTransparency = 0.45
		stroke.Transparency = 0.45
	end

	-- ========================================================================
	-- LOCOFFICIAL TACTILE HOVER INTERACTION
	-- ========================================================================
	local hoverYOffset = -28
	local isHovered = false

	btn.MouseEnter:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end
		isHovered = true

		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(restingPos.X.Scale, restingPos.X.Offset, 1, hoverYOffset),
			Size = UDim2.new(0, CARD_DIAMETER + 6, 0, CARD_DIAMETER + 6),
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Theme.Colors.GoldGlow,
			Thickness = 4.5,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		isHovered = false

		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = restingPos,
			Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER),
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = isRose and Color3.fromRGB(240, 190, 60) or Color3.fromRGB(245, 175, 45),
			Thickness = 3.5,
		}):Play()
	end)

	-- Direct click-to-place
	btn.MouseButton1Click:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end
		selectedCard = cardType

		if onCardClickedCallback then
			onCardClickedCallback(cardType, index)
		end
	end)

	return btn
end

-- ============================================================================
-- 2. SETUP FLOATING HAND DOCK (Bottom Center)
-- ============================================================================
function HandBar.Create(parent: Instance, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect
	table.clear(cardButtons)

	local dock = Instance.new("Frame")
	dock.Name = "FloatingHandDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Size = UDim2.new(0, 560, 0, 140)
	dock.Position = UDim2.new(0.5, 0, 1, -16)
	dock.BackgroundTransparency = 1
	dock.ZIndex = 20
	dock.Parent = parent

	dockFrame = dock
	return dock
end

-- ============================================================================
-- 3. RE-RENDER CIRCULAR CARDS IN HAND
-- ============================================================================
function HandBar.UpdateHand(handCards: { string }, isMyTurn: boolean, canPlace: boolean)
	if not dockFrame then return end

	currentHand = handCards
	isPlayerTurn = isMyTurn
	canCurrentlyPlace = canPlace

	-- Clear old card buttons
	for _, btn in ipairs(cardButtons) do
		btn:Destroy()
	end
	table.clear(cardButtons)

	local cardCount = #handCards
	if cardCount == 0 then
		dockFrame.Visible = false
		return
	end

	dockFrame.Visible = true
	local isPlayable = isMyTurn and canPlace

	-- Calculate horizontal centering offset for all circular cards
	-- E.g. 4 cards: centered evenly around 0.5
	local totalSpan = (cardCount - 1) * CARD_SPACING
	local startXOffset = -totalSpan / 2

	for i, cardType in ipairs(handCards) do
		local xOffset = startXOffset + (i - 1) * CARD_SPACING
		local restingPos = UDim2.new(0.5, xOffset, 1, 0)

		local cardBtn = createCircularCard(cardType, i, restingPos, isPlayable)
		cardBtn.Parent = dockFrame
		table.insert(cardButtons, cardBtn)
	end
end

-- ============================================================================
-- 4. ACCESSORS
-- ============================================================================
function HandBar.GetSelectedCard(): string?
	return selectedCard or (currentHand[1] or nil)
end

function HandBar.SelectCard(cardType: string)
	selectedCard = cardType
end

function HandBar.SetVisible(visible: boolean)
	if dockFrame then
		dockFrame.Visible = visible
	end
end

return HandBar
