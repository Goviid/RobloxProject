--!strict
-- HandBar.luau
-- 2.5D Tactile Hand of Circular Cards (LOCOfficial style)
-- Features fanned angles, overlapping hand layout, 2.5D layered depth, drop shadows, and spring hover elevation

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local HandBar = {}

export type CardSelectCallback = (cardType: string, cardIndex: number) -> ()
local onCardClickedCallback: CardSelectCallback? = nil

local dockFrame: Frame? = nil
local cardButtonContainers: { Frame } = {}
local currentHand: { string } = {}
local canCurrentlyPlace = false
local isPlayerTurn = false
local selectedCard: string? = nil

-- 2.5D Card Physical Geometry
local CARD_DIAMETER = 112
local CARD_OVERLAP_SPACING = 88 -- Slight horizontal overlap like physical held cards

-- Calculated fanned rotation angles (degrees) for natural hand curve
local function getFannedAngle(index: number, totalCards: number): number
	if totalCards <= 1 then return 0 end
	local normalized = (index - 1) / (totalCards - 1) -- 0.0 to 1.0
	local maxAngle = if totalCards == 4 then 7.0 elseif totalCards == 3 then 4.5 else 3.0
	return (normalized - 0.5) * (maxAngle * 2)
end

-- Subtle vertical arch so outer cards rest slightly lower in the palm
local function getArchYOffset(index: number, totalCards: number): number
	if totalCards <= 1 then return 0 end
	local centerDist = math.abs((index - 1) - (totalCards - 1) / 2)
	return centerDist * 3.5
end

-- ============================================================================
-- 1. CONSTRUCT A 2.5D CIRCULAR CARD
-- ============================================================================
local function create25DCard(
	cardType: string,
	index: number,
	totalCards: number,
	xOffset: number,
	isPlayable: boolean
): Frame
	local isRose = (cardType == Enums.CardType.Rose)
	local rotAngle = getFannedAngle(index, totalCards)
	local archY = getArchYOffset(index, totalCards)
	local restingPos = UDim2.new(0.5, xOffset, 1, -12 + archY)
	local baseZIndex = 20 + index

	-- Outer Container (handles rotation & placement)
	local container = Instance.new("Frame")
	container.Name = "CardHolder_" .. index .. "_" .. cardType
	container.Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER)
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = restingPos
	container.Rotation = rotAngle
	container.BackgroundTransparency = 1
	container.ZIndex = baseZIndex

	-- 1. 2.5D Dynamic Drop Shadow (Underneath card)
	local shadow = Instance.new("Frame")
	shadow.Name = "CardShadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.new(0, 0, 0, 6)
	shadow.BackgroundColor3 = Color3.fromRGB(10, 30, 55)
	shadow.BackgroundTransparency = 0.65
	shadow.BorderSizePixel = 0
	shadow.ZIndex = baseZIndex
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(1, 0)
	shadowCorner.Parent = shadow

	-- 2. Interactive Circular Card Button
	local btn = Instance.new("ImageButton")
	btn.Name = "CardButton"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.Position = UDim2.new(0, 0, 0, 0)
	btn.BackgroundColor3 = isRose and Color3.fromRGB(175, 24, 42) or Color3.fromRGB(24, 20, 26)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = baseZIndex + 1
	btn.Parent = container

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(1, 0)
	btnCorner.Parent = btn

	-- 3. Outer Ornate Gold Rim (Tactile physical bevel)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "GoldBevelRim"
	stroke.Color = isRose and Color3.fromRGB(245, 195, 60) or Color3.fromRGB(250, 180, 50)
	stroke.Thickness = 3.6
	stroke.Parent = btn

	-- 4. 2.5D Top-Light Bevel Accent Ring
	local bevelRing = Instance.new("Frame")
	bevelRing.Name = "BevelHighlightRing"
	bevelRing.Size = UDim2.new(1, -12, 1, -12)
	bevelRing.Position = UDim2.new(0, 6, 0, 6)
	bevelRing.BackgroundTransparency = 1
	bevelRing.ZIndex = baseZIndex + 2
	bevelRing.Parent = btn

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = bevelRing

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.fromRGB(255, 245, 200)
	ringStroke.Transparency = 0.45
	ringStroke.Thickness = 1.4
	ringStroke.Parent = bevelRing

	-- 5. Center Embossed Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "CardIcon"
	icon.Size = UDim2.new(1, 0, 0, 56)
	icon.Position = UDim2.new(0, 0, 0, 16)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 52
	icon.Text = isRose and "🌹" or "💀"
	icon.ZIndex = baseZIndex + 3
	icon.Parent = btn

	-- 6. Bottom Clean Curved Name ("ROSE" or "SKULL")
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CardLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.Position = UDim2.new(0, 0, 1, -30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Theme.Fonts.Title
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = isRose and Color3.fromRGB(255, 245, 235) or Color3.fromRGB(255, 210, 130)
	nameLabel.Text = isRose and "ROSE" or "SKULL"
	nameLabel.ZIndex = baseZIndex + 3
	nameLabel.Parent = btn

	-- Disabled / Dimmed State
	if not isPlayable then
		btn.BackgroundTransparency = 0.4
		icon.TextTransparency = 0.4
		nameLabel.TextTransparency = 0.4
		stroke.Transparency = 0.4
		shadow.BackgroundTransparency = 0.85
	end

	-- ========================================================================
	-- 2.5D TACTILE HOVER & ELEVATION (LOCOfficial Feeling)
	-- ========================================================================
	btn.MouseEnter:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end

		-- Bring this card to the very front so it overlaps its neighbors
		container.ZIndex = 50
		shadow.ZIndex = 50
		btn.ZIndex = 51
		bevelRing.ZIndex = 52
		icon.ZIndex = 53
		nameLabel.ZIndex = 53

		-- Lift up toward camera, straighten up (0 deg), and scale up slightly
		TweenService:Create(container, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, xOffset, 1, -44),
			Rotation = 0,
			Size = UDim2.new(0, CARD_DIAMETER + 8, 0, CARD_DIAMETER + 8),
		}):Play()

		-- Drop shadow deepens and moves downward
		TweenService:Create(shadow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 14),
			BackgroundTransparency = 0.75,
		}):Play()

		-- Glow outline
		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Theme.Colors.GoldGlow,
			Thickness = 4.4,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		-- Reset back to fanned resting position
		container.ZIndex = baseZIndex
		shadow.ZIndex = baseZIndex
		btn.ZIndex = baseZIndex + 1
		bevelRing.ZIndex = baseZIndex + 2
		icon.ZIndex = baseZIndex + 3
		nameLabel.ZIndex = baseZIndex + 3

		TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = restingPos,
			Rotation = rotAngle,
			Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER),
		}):Play()

		TweenService:Create(shadow, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 6),
			BackgroundTransparency = isPlayable and 0.65 or 0.85,
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = isRose and Color3.fromRGB(245, 195, 60) or Color3.fromRGB(250, 180, 50),
			Thickness = 3.6,
		}):Play()
	end)

	-- Direct click to place
	btn.MouseButton1Click:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end
		selectedCard = cardType

		if onCardClickedCallback then
			onCardClickedCallback(cardType, index)
		end
	end)

	return container
end

-- ============================================================================
-- 2. SETUP FLOATING 2.5D HAND DOCK (Bottom Center)
-- ============================================================================
function HandBar.Create(parent: Instance, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect
	table.clear(cardButtonContainers)

	local dock = Instance.new("Frame")
	dock.Name = "FloatingHandDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Size = UDim2.new(0, 580, 0, 150)
	dock.Position = UDim2.new(0.5, 0, 1, -12)
	dock.BackgroundTransparency = 1
	dock.ZIndex = 20
	dock.Parent = parent

	dockFrame = dock
	return dock
end

-- ============================================================================
-- 3. RE-RENDER 2.5D FANNED CARDS IN HAND
-- ============================================================================
function HandBar.UpdateHand(handCards: { string }, isMyTurn: boolean, canPlace: boolean)
	if not dockFrame then return end

	currentHand = handCards
	isPlayerTurn = isMyTurn
	canCurrentlyPlace = canPlace

	-- Destroy old card containers
	for _, cardHolder in ipairs(cardButtonContainers) do
		cardHolder:Destroy()
	end
	table.clear(cardButtonContainers)

	local cardCount = #handCards
	if cardCount == 0 then
		dockFrame.Visible = false
		return
	end

	dockFrame.Visible = true
	local isPlayable = isMyTurn and canPlace

	-- Calculate horizontal spacing with subtle overlap
	local totalSpan = (cardCount - 1) * CARD_OVERLAP_SPACING
	local startXOffset = -totalSpan / 2

	for i, cardType in ipairs(handCards) do
		local xOffset = startXOffset + (i - 1) * CARD_OVERLAP_SPACING
		local cardHolder = create25DCard(cardType, i, cardCount, xOffset, isPlayable)
		cardHolder.Parent = dockFrame
		table.insert(cardButtonContainers, cardHolder)
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
