--!strict
-- HandBar.luau
-- Tactile 2.5D Hand of Oversized Circular Cards (LOCOfficial style)
-- Raised height, rich textured medallions, spring hover elevation, and direct click placement

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local HandBar = {}

export type CardSelectCallback = (cardType: string, cardIndex: number) -> ()
local onCardClickedCallback: CardSelectCallback? = nil

local dockFrame: Frame? = nil
local cardContainers: { Frame } = {}
local currentHand: { string } = {}
local canCurrentlyPlace = false
local isPlayerTurn = false
local selectedCard: string? = nil

-- Oversized 2.5D Card Geometry
local CARD_DIAMETER = 144       -- Oversized substantial circular card
local CARD_OVERLAP_SPACING = 114 -- Natural horizontal overlap in hand
local RESTING_Y_OFFSET = -75    -- Raised height so full card is visible hovering above screen bottom
local HOVER_LIFT_Y_OFFSET = -135 -- Elevated high into view when hovered

-- Calculated fanned rotation angles (degrees) for natural hand curve
local function getFannedAngle(index: number, totalCards: number): number
	if totalCards <= 1 then return 0 end
	local normalized = (index - 1) / (totalCards - 1) -- 0.0 to 1.0
	local maxAngle = if totalCards == 4 then 7.5 elseif totalCards == 3 then 5.0 else 3.0
	return (normalized - 0.5) * (maxAngle * 2)
end

-- Subtle vertical arch so outer cards rest slightly lower in the palm
local function getArchYOffset(index: number, totalCards: number): number
	if totalCards <= 1 then return 0 end
	local centerDist = math.abs((index - 1) - (totalCards - 1) / 2)
	return centerDist * 4.5
end

-- ============================================================================
-- 1. CONSTRUCT A RICH TEXTURED 2.5D CIRCULAR CARD
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
	local restingPos = UDim2.new(0.5, xOffset, 1, RESTING_Y_OFFSET + archY)
	local baseZIndex = 20 + index

	-- Outer Container (handles position, rotation & hover)
	local container = Instance.new("Frame")
	container.Name = "CardHolder_" .. index .. "_" .. cardType
	container.Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER)
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = restingPos
	container.Rotation = rotAngle
	container.BackgroundTransparency = 1
	container.ZIndex = baseZIndex

	-- 1. Tactile 2.5D Drop Shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "CardShadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.new(0, 0, 0, 8)
	shadow.BackgroundColor3 = Color3.fromRGB(10, 25, 45)
	shadow.BackgroundTransparency = 0.60
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
	btn.BackgroundColor3 = isRose and Color3.fromRGB(205, 30, 55) or Color3.fromRGB(36, 32, 42)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = baseZIndex + 1
	btn.Parent = container

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(1, 0)
	btnCorner.Parent = btn

	-- 3. Rich Color Gradient Texture (Rose: Radiant Ruby; Skull: Obsidian Slate)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 45
	if isRose then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(240, 45, 75)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(195, 24, 48)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(125, 12, 30)),
		})
	else
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(55, 50, 65)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(32, 28, 38)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(16, 14, 20)),
		})
	end
	gradient.Parent = btn

	-- 4. Outer Beveled Metallic Rim (Tactile 3D Bevel)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "OuterGoldRim"
	stroke.Color = isRose and Color3.fromRGB(250, 205, 75) or Color3.fromRGB(245, 180, 60)
	stroke.Thickness = 4.2
	stroke.Parent = btn

	-- 5. Inner Concentric Filigree Ring
	local innerRing = Instance.new("Frame")
	innerRing.Name = "InnerRing"
	innerRing.Size = UDim2.new(1, -16, 1, -16)
	innerRing.Position = UDim2.new(0, 8, 0, 8)
	innerRing.BackgroundTransparency = 1
	innerRing.ZIndex = baseZIndex + 2
	innerRing.Parent = btn

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = innerRing

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = isRose and Color3.fromRGB(255, 235, 160) or Color3.fromRGB(230, 200, 140)
	innerStroke.Transparency = 0.35
	innerStroke.Thickness = 1.8
	innerStroke.Parent = innerRing

	-- 6. Center Embossed Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "CardIcon"
	icon.Size = UDim2.new(1, 0, 0, 72)
	icon.Position = UDim2.new(0, 0, 0, 22)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 64
	icon.Text = isRose and "🌹" or "💀"
	icon.ZIndex = baseZIndex + 3
	icon.Parent = btn

	-- Icon Drop Shadow for embossed 2.5D appearance
	local iconShadow = Instance.new("TextLabel")
	iconShadow.Name = "IconShadow"
	iconShadow.Size = UDim2.new(1, 0, 0, 72)
	iconShadow.Position = UDim2.new(0, 2, 0, 24)
	iconShadow.BackgroundTransparency = 1
	iconShadow.Font = Theme.Fonts.Title
	iconShadow.TextSize = 64
	iconShadow.TextColor3 = Color3.fromRGB(0, 0, 0)
	iconShadow.TextTransparency = 0.65
	iconShadow.Text = isRose and "🌹" or "💀"
	iconShadow.ZIndex = baseZIndex + 2
	iconShadow.Parent = btn

	-- 7. Bottom Clean Gold Ribbon Label ("ROSE" or "SKULL")
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CardLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 0, 1, -36)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = isRose and Color3.fromRGB(255, 245, 220) or Color3.fromRGB(255, 215, 120)
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.TextStrokeColor3 = Color3.fromRGB(20, 15, 25)
	nameLabel.Text = isRose and "ROSE" or "SKULL"
	nameLabel.ZIndex = baseZIndex + 3
	nameLabel.Parent = btn

	-- Dimmed state if not playable
	if not isPlayable then
		btn.BackgroundTransparency = 0.45
		icon.TextTransparency = 0.45
		nameLabel.TextTransparency = 0.45
		stroke.Transparency = 0.45
		shadow.BackgroundTransparency = 0.85
	end

	-- ========================================================================
	-- 2.5D TACTILE HOVER & ELEVATION
	-- ========================================================================
	btn.MouseEnter:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end

		-- Bring this card to the very front so it overlaps its neighbors
		container.ZIndex = 60
		shadow.ZIndex = 60
		btn.ZIndex = 61
		innerRing.ZIndex = 62
		iconShadow.ZIndex = 62
		icon.ZIndex = 63
		nameLabel.ZIndex = 63

		-- Lift up towards camera, straighten up (0 deg), and scale up slightly
		TweenService:Create(container, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, xOffset, 1, HOVER_LIFT_Y_OFFSET),
			Rotation = 0,
			Size = UDim2.new(0, CARD_DIAMETER + 12, 0, CARD_DIAMETER + 12),
		}):Play()

		-- Drop shadow deepens and moves downward
		TweenService:Create(shadow, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 18),
			BackgroundTransparency = 0.70,
		}):Play()

		-- Glow outline
		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.fromRGB(255, 240, 120),
			Thickness = 5.2,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		-- Reset back to resting fanned position
		container.ZIndex = baseZIndex
		shadow.ZIndex = baseZIndex
		btn.ZIndex = baseZIndex + 1
		innerRing.ZIndex = baseZIndex + 2
		iconShadow.ZIndex = baseZIndex + 2
		icon.ZIndex = baseZIndex + 3
		nameLabel.ZIndex = baseZIndex + 3

		TweenService:Create(container, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = restingPos,
			Rotation = rotAngle,
			Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER),
		}):Play()

		TweenService:Create(shadow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 8),
			BackgroundTransparency = isPlayable and 0.60 or 0.85,
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = isRose and Color3.fromRGB(250, 205, 75) or Color3.fromRGB(245, 180, 60),
			Thickness = 4.2,
		}):Play()
	end)

	-- Direct click to place (immediately consumes card from hand!)
	btn.MouseButton1Click:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end
		isPlayerTurn = false -- Prevent double clicks while server processes turn
		selectedCard = cardType

		local clickedIdx = table.find(cardContainers, container) or index
		HandBar.ConsumeCard(clickedIdx)

		if onCardClickedCallback then
			onCardClickedCallback(cardType, clickedIdx)
		end
	end)

	return container
end

-- ============================================================================
-- 2. CONSUME CARD FROM HAND (Smooth fly-off & re-centering animation)
-- ============================================================================
function HandBar.ConsumeCard(cardIndex: number)
	if not dockFrame then return end
	local targetContainer = cardContainers[cardIndex]
	if not targetContainer then return end

	-- Optimistically remove from tracking
	table.remove(cardContainers, cardIndex)
	table.remove(currentHand, cardIndex)

	-- Exit tween for placed card (lifts up and shrinks out)
	local exitTween = TweenService:Create(targetContainer, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = targetContainer.Position + UDim2.new(0, 0, 0, -90),
		Size = UDim2.new(0, 0, 0, 0),
	})
	exitTween:Play()
	exitTween.Completed:Connect(function()
		targetContainer:Destroy()
	end)

	-- Smoothly re-position remaining cards into new centered fan
	local totalRemaining = #currentHand
	if totalRemaining == 0 then
		dockFrame.Visible = false
		return
	end

	local totalWidth = (totalRemaining - 1) * CARD_OVERLAP_SPACING
	local startX = -totalWidth / 2

	for i, container in ipairs(cardContainers) do
		local xOffset = startX + (i - 1) * CARD_OVERLAP_SPACING
		local rotAngle = getFannedAngle(i, totalRemaining)
		local archY = getArchYOffset(i, totalRemaining)
		local newPos = UDim2.new(0.5, xOffset, 1, RESTING_Y_OFFSET + archY)

		container.ZIndex = 20 + i
		TweenService:Create(container, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = newPos,
			Rotation = rotAngle,
		}):Play()
	end
end

-- ============================================================================
-- 3. SETUP FLOATING 2.5D HAND DOCK (Bottom Center)
-- ============================================================================
function HandBar.Create(parent: Instance, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect
	table.clear(cardContainers)

	local dock = Instance.new("Frame")
	dock.Name = "FloatingHandDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Size = UDim2.new(0, 640, 0, 190)
	dock.Position = UDim2.new(0.5, 0, 1, 0)
	dock.BackgroundTransparency = 1 -- Zero black box!
	dock.BorderSizePixel = 0
	dock.ZIndex = 20
	dock.Parent = parent

	dockFrame = dock
	return dock
end

-- ============================================================================
-- 3. RENDER / UPDATE HAND CARDS
-- ============================================================================
function HandBar.UpdateHand(hand: { string }, isTurn: boolean, canPlace: boolean)
	if not dockFrame then return end

	currentHand = hand
	isPlayerTurn = isTurn
	canCurrentlyPlace = canPlace
	dockFrame.Visible = (#hand > 0)

	-- Clear old cards
	for _, c in ipairs(cardContainers) do
		c:Destroy()
	end
	table.clear(cardContainers)

	local totalCards = #hand
	if totalCards == 0 then return end

	-- Calculate horizontal spacing centered around middle
	local totalWidth = (totalCards - 1) * CARD_OVERLAP_SPACING
	local startX = -totalWidth / 2

	for i, cardType in ipairs(hand) do
		local xOffset = startX + (i - 1) * CARD_OVERLAP_SPACING
		local cardHolder = create25DCard(cardType, i, totalCards, xOffset, canPlace and isTurn)
		cardHolder.Parent = dockFrame
		table.insert(cardContainers, cardHolder)
	end
end

-- ============================================================================
-- 4. UTILITY METHODS
-- ============================================================================
function HandBar.SetVisible(visible: boolean)
	if dockFrame then
		dockFrame.Visible = visible
	end
end

function HandBar.GetSelectedCard(): string?
	return selectedCard
end

function HandBar.GetRemainingCardsCount(): number
	return #currentHand
end

return HandBar
