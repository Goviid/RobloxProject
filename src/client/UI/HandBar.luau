--!strict
-- HandBar.luau
-- LOCOfficial-Style Handheld Fan of Vertical Playing Cards (Uno-Style)
-- Features authentic vertical rounded playing cards, vibrant pop colors, corner pips,
-- center oval emblems, natural fan geometry, dynamic consumption re-centering, and spring hover elevation

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

-- Authentic Playing Card Dimensions (LOCOfficial Uno Ratio ~1:1.45)
local CARD_WIDTH = 110            -- Width of vertical card
local CARD_HEIGHT = 160           -- Height of vertical card
local CARD_OVERLAP_SPACING = 82   -- Horizontal overlap in hand fan
local RESTING_Y_OFFSET = -30      -- Resting bottom offset above screen edge
local HOVER_LIFT_Y_OFFSET = -95   -- Elevated 65px straight up on hover

-- Natural hand fan angles (degrees)
local function getFannedAngle(index: number, totalCards: number): number
	if totalCards <= 1 then return 0 end
	local normalized = (index - 1) / (totalCards - 1) -- 0.0 to 1.0
	local maxAngle = if totalCards >= 4 then 10.5 elseif totalCards == 3 then 7.0 else 4.0
	return (normalized - 0.5) * (maxAngle * 2)
end

-- Natural vertical arch: outer cards rest slightly lower in the palm
local function getArchYOffset(index: number, totalCards: number): number
	if totalCards <= 1 then return 0 end
	local centerDist = math.abs((index - 1) - (totalCards - 1) / 2)
	return centerDist * 5.0
end

-- ============================================================================
-- 1. CONSTRUCT A VERTICAL ROUNDED PLAYING CARD (LOCOfficial Style)
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
	local restingY = RESTING_Y_OFFSET + archY
	local restingPos = UDim2.new(0.5, xOffset, 1, restingY)
	local baseZIndex = 20 + index

	-- Outer Container (handles fan position, rotation & hover)
	local container = Instance.new("Frame")
	container.Name = "CardHolder_" .. index .. "_" .. cardType
	container.Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT)
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = restingPos
	container.Rotation = rotAngle
	container.BackgroundTransparency = 1
	container.ZIndex = baseZIndex

	-- Store dynamic resting state on container attributes so adjustments update hover targets
	container:SetAttribute("RestingX", xOffset)
	container:SetAttribute("RestingY", restingY)
	container:SetAttribute("RestingRot", rotAngle)
	container:SetAttribute("BaseZIndex", baseZIndex)

	-- 1. Tactile 2.5D Drop Shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "CardShadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.new(0, 0, 0, 7)
	shadow.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	shadow.BackgroundTransparency = 0.65
	shadow.BorderSizePixel = 0
	shadow.ZIndex = baseZIndex
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 14)
	shadowCorner.Parent = shadow

	-- 2. Interactive Vertical Playing Card Body
	local btn = Instance.new("ImageButton")
	btn.Name = "CardButton"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.Position = UDim2.new(0, 0, 0, 0)
	btn.BackgroundColor3 = isRose and Color3.fromRGB(235, 42, 75) or Color3.fromRGB(26, 26, 32)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = baseZIndex + 1
	btn.Parent = container

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 14)
	btnCorner.Parent = btn

	-- 3. Thick Crisp White Playing Card Border (Signature LOCOfficial outline)
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardWhiteBorder"
	cardStroke.Color = Color3.fromRGB(255, 255, 255)
	cardStroke.Thickness = 3.5
	cardStroke.Parent = btn

	-- 4. Subtle Rich Vertical Gradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	if isRose then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(252, 60, 95)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(205, 28, 58)),
		})
	else
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(48, 48, 58)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(18, 18, 22)),
		})
	end
	gradient.Parent = btn

	-- 5. Top-Left Corner Pip (White Pill with mini symbol)
	local topLeftPip = Instance.new("Frame")
	topLeftPip.Name = "TopLeftPip"
	topLeftPip.Size = UDim2.new(0, 24, 0, 26)
	topLeftPip.Position = UDim2.new(0, 7, 0, 7)
	topLeftPip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	topLeftPip.BorderSizePixel = 0
	topLeftPip.ZIndex = baseZIndex + 2
	topLeftPip.Parent = btn
	Instance.new("UICorner", topLeftPip).CornerRadius = UDim.new(0, 6)

	local tlIcon = Instance.new("TextLabel")
	tlIcon.Size = UDim2.new(1, 0, 1, 0)
	tlIcon.BackgroundTransparency = 1
	tlIcon.Font = Theme.Fonts.Title
	tlIcon.TextSize = 14
	tlIcon.Text = isRose and "🌹" or "💀"
	tlIcon.ZIndex = baseZIndex + 3
	tlIcon.Parent = topLeftPip

	-- 6. Bottom-Right Corner Pip (White Pill with mini symbol)
	local bottomRightPip = Instance.new("Frame")
	bottomRightPip.Name = "BottomRightPip"
	bottomRightPip.Size = UDim2.new(0, 24, 0, 26)
	bottomRightPip.Position = UDim2.new(1, -31, 1, -33)
	bottomRightPip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bottomRightPip.BorderSizePixel = 0
	bottomRightPip.ZIndex = baseZIndex + 2
	bottomRightPip.Parent = btn
	Instance.new("UICorner", bottomRightPip).CornerRadius = UDim.new(0, 6)

	local brIcon = Instance.new("TextLabel")
	brIcon.Size = UDim2.new(1, 0, 1, 0)
	brIcon.BackgroundTransparency = 1
	brIcon.Font = Theme.Fonts.Title
	brIcon.TextSize = 14
	brIcon.Text = isRose and "🌹" or "💀"
	brIcon.ZIndex = baseZIndex + 3
	brIcon.Parent = bottomRightPip

	-- 7. Center White Oval Emblem (Signature LOCOfficial Graphic Badge)
	local centerOval = Instance.new("Frame")
	centerOval.Name = "CenterOval"
	centerOval.Size = UDim2.new(0, 74, 0, 84)
	centerOval.Position = UDim2.new(0.5, -37, 0.5, -42)
	centerOval.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	centerOval.BorderSizePixel = 0
	centerOval.ZIndex = baseZIndex + 2
	centerOval.Parent = btn

	local ovalCorner = Instance.new("UICorner")
	ovalCorner.CornerRadius = UDim.new(0, 20)
	ovalCorner.Parent = centerOval

	local ovalStroke = Instance.new("UIStroke")
	ovalStroke.Color = isRose and Color3.fromRGB(255, 220, 228) or Color3.fromRGB(220, 220, 230)
	ovalStroke.Thickness = 1.5
	ovalStroke.Parent = centerOval

	-- 8. Large Centered Icon inside Oval (🌹 or 💀)
	local centerIcon = Instance.new("TextLabel")
	centerIcon.Name = "CenterIcon"
	centerIcon.Size = UDim2.new(1, 0, 0, 48)
	centerIcon.Position = UDim2.new(0, 0, 0, 8)
	centerIcon.BackgroundTransparency = 1
	centerIcon.Font = Theme.Fonts.Title
	centerIcon.TextSize = 46
	centerIcon.Text = isRose and "🌹" or "💀"
	centerIcon.ZIndex = baseZIndex + 3
	centerIcon.Parent = centerOval

	-- 9. Crisp Card Name Label inside Oval
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CardLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.Position = UDim2.new(0, 0, 1, -24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = isRose and Color3.fromRGB(205, 30, 55) or Color3.fromRGB(24, 24, 30)
	nameLabel.Text = isRose and "ROSE" or "SKULL"
	nameLabel.ZIndex = baseZIndex + 3
	nameLabel.Parent = centerOval

	-- Dimmed state if not playable
	if not isPlayable then
		btn.BackgroundTransparency = 0.45
		cardStroke.Transparency = 0.45
		centerOval.BackgroundTransparency = 0.45
		centerIcon.TextTransparency = 0.45
		nameLabel.TextTransparency = 0.45
		topLeftPip.BackgroundTransparency = 0.45
		bottomRightPip.BackgroundTransparency = 0.45
		tlIcon.TextTransparency = 0.45
		brIcon.TextTransparency = 0.45
		shadow.BackgroundTransparency = 0.85
	end

	-- ========================================================================
	-- 2.5D TACTILE HOVER & ELEVATION (Pops UP smoothly into focus)
	-- ========================================================================
	btn.MouseEnter:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end

		-- Bring this card to the very front so it pops over neighbors
		container.ZIndex = 60
		shadow.ZIndex = 60
		btn.ZIndex = 61
		topLeftPip.ZIndex = 62
		bottomRightPip.ZIndex = 62
		tlIcon.ZIndex = 63
		brIcon.ZIndex = 63
		centerOval.ZIndex = 62
		centerIcon.ZIndex = 63
		nameLabel.ZIndex = 63

		local curX = container:GetAttribute("RestingX") or xOffset

		-- Lift up towards player, straighten rotation to 0, and expand slightly
		TweenService:Create(container, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, curX, 1, HOVER_LIFT_Y_OFFSET),
			Rotation = 0,
			Size = UDim2.new(0, CARD_WIDTH + 6, 0, CARD_HEIGHT + 8),
		}):Play()

		TweenService:Create(shadow, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 16),
			BackgroundTransparency = 0.70,
		}):Play()

		TweenService:Create(cardStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.fromRGB(255, 250, 180),
			Thickness = 4.5,
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		-- Read current dynamic attributes so it returns to the adjusted fan slot!
		local curX = container:GetAttribute("RestingX") or xOffset
		local curY = container:GetAttribute("RestingY") or restingY
		local curRot = container:GetAttribute("RestingRot") or rotAngle
		local curZIndex = container:GetAttribute("BaseZIndex") or baseZIndex

		container.ZIndex = curZIndex
		shadow.ZIndex = curZIndex
		btn.ZIndex = curZIndex + 1
		topLeftPip.ZIndex = curZIndex + 2
		bottomRightPip.ZIndex = curZIndex + 2
		tlIcon.ZIndex = curZIndex + 3
		brIcon.ZIndex = curZIndex + 3
		centerOval.ZIndex = curZIndex + 2
		centerIcon.ZIndex = curZIndex + 3
		nameLabel.ZIndex = curZIndex + 3

		TweenService:Create(container, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, curX, 1, curY),
			Rotation = curRot,
			Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT),
		}):Play()

		TweenService:Create(shadow, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 7),
			BackgroundTransparency = isPlayable and 0.65 or 0.85,
		}):Play()

		TweenService:Create(cardStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = 3.5,
		}):Play()
	end)

	-- Direct click to place (immediately consumes card and triggers fan re-adjustment!)
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
-- 2. CONSUME CARD FROM HAND (Smooth fly-off & dynamic fan re-adjustment!)
-- ============================================================================
function HandBar.ConsumeCard(cardIndex: number)
	if not dockFrame then return end
	local targetContainer = cardContainers[cardIndex]
	if not targetContainer then return end

	-- Optimistically remove from tracking
	table.remove(cardContainers, cardIndex)
	table.remove(currentHand, cardIndex)

	local localBadge = dockFrame:FindFirstChild("LocalCardBadge") :: Frame?
	if localBadge then
		local num = localBadge:FindFirstChild("CountNum") :: TextLabel?
		if num then num.Text = tostring(#currentHand) end
	end

	-- Exit tween for placed card (lifts up and shrinks out)
	local exitTween = TweenService:Create(targetContainer, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Position = targetContainer.Position + UDim2.new(0, 0, 0, -90),
		Size = UDim2.new(0, 0, 0, 0),
	})
	exitTween:Play()
	exitTween.Completed:Connect(function()
		targetContainer:Destroy()
	end)

	-- Smoothly re-position & re-fan remaining cards into their new centered formation!
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
		local newY = RESTING_Y_OFFSET + archY
		local newZIndex = 20 + i

		-- Update dynamic attributes so subsequent hovers return to the adjusted position
		container:SetAttribute("RestingX", xOffset)
		container:SetAttribute("RestingY", newY)
		container:SetAttribute("RestingRot", rotAngle)
		container:SetAttribute("BaseZIndex", newZIndex)

		container.ZIndex = newZIndex
		local s = container:FindFirstChild("CardShadow") :: Frame?
		if s then s.ZIndex = newZIndex end
		local b = container:FindFirstChild("CardButton") :: ImageButton?
		if b then
			b.ZIndex = newZIndex + 1
			local tl = b:FindFirstChild("TopLeftPip") :: Frame?
			if tl then
				tl.ZIndex = newZIndex + 2
				local ic = tl:FindFirstChildWhichIsA("TextLabel")
				if ic then ic.ZIndex = newZIndex + 3 end
			end
			local br = b:FindFirstChild("BottomRightPip") :: Frame?
			if br then
				br.ZIndex = newZIndex + 2
				local ic = br:FindFirstChildWhichIsA("TextLabel")
				if ic then ic.ZIndex = newZIndex + 3 end
			end
			local co = b:FindFirstChild("CenterOval") :: Frame?
			if co then
				co.ZIndex = newZIndex + 2
				local ci = co:FindFirstChild("CenterIcon") :: TextLabel?
				if ci then ci.ZIndex = newZIndex + 3 end
				local cl = co:FindFirstChild("CardLabel") :: TextLabel?
				if cl then cl.ZIndex = newZIndex + 3 end
			end
		end

		-- Smoothly glide into adjusted fan position and angle
		TweenService:Create(container, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, xOffset, 1, newY),
			Rotation = rotAngle,
			Size = UDim2.new(0, CARD_WIDTH, 0, CARD_HEIGHT),
		}):Play()
	end
end

-- ============================================================================
-- 3. SETUP FLOATING HAND DOCK (Bottom Center)
-- ============================================================================
function HandBar.Create(parent: Instance, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect
	table.clear(cardContainers)

	local dock = Instance.new("Frame")
	dock.Name = "FloatingHandDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Size = UDim2.new(0, 640, 0, 240)
	dock.Position = UDim2.new(0.5, 0, 1, 0)
	dock.BackgroundTransparency = 1 -- Zero black box!
	dock.BorderSizePixel = 0
	dock.ZIndex = 20
	dock.Parent = parent

	-- LOCOfficial Local Player Card Count Badge (pinned directly below hand at bottom center)
	local localBadge = Instance.new("Frame")
	localBadge.Name = "LocalCardBadge"
	localBadge.AnchorPoint = Vector2.new(0.5, 1)
	localBadge.Size = UDim2.new(0, 26, 0, 32)
	localBadge.Position = UDim2.new(0.5, 0, 1, -4)
	localBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	localBadge.BorderSizePixel = 0
	localBadge.ZIndex = 40
	localBadge.Parent = dock

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 6)
	badgeCorner.Parent = localBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Name = "BadgeStroke"
	badgeStroke.Color = Color3.fromRGB(180, 205, 235)
	badgeStroke.Thickness = 1.5
	badgeStroke.Parent = localBadge

	local badgeNum = Instance.new("TextLabel")
	badgeNum.Name = "CountNum"
	badgeNum.Size = UDim2.new(1, 0, 1, 0)
	badgeNum.BackgroundTransparency = 1
	badgeNum.Font = Enum.Font.GothamBold
	badgeNum.TextSize = 14
	badgeNum.TextColor3 = Color3.fromRGB(30, 35, 45)
	badgeNum.Text = "4"
	badgeNum.ZIndex = 41
	badgeNum.Parent = localBadge

	dockFrame = dock
	return dock
end

-- ============================================================================
-- 4. RENDER / UPDATE HAND CARDS
-- ============================================================================
function HandBar.UpdateHand(hand: { string }, isTurn: boolean, canPlace: boolean)
	if not dockFrame then return end

	currentHand = hand
	isPlayerTurn = isTurn
	canCurrentlyPlace = canPlace
	dockFrame.Visible = (#hand > 0)

	-- Update LOCOfficial turn color on local player's card count badge
	local localBadge = dockFrame:FindFirstChild("LocalCardBadge") :: Frame?
	if localBadge then
		local num = localBadge:FindFirstChild("CountNum") :: TextLabel?
		local bStroke = localBadge:FindFirstChild("BadgeStroke") :: UIStroke?
		if num then num.Text = tostring(#hand) end
		if isTurn then
			localBadge.BackgroundColor3 = Color3.fromRGB(245, 140, 20)
			if num then num.TextColor3 = Color3.fromRGB(255, 255, 255) end
			if bStroke then bStroke.Color = Color3.fromRGB(255, 220, 100) end
		else
			localBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			if num then num.TextColor3 = Color3.fromRGB(30, 35, 45) end
			if bStroke then bStroke.Color = Color3.fromRGB(180, 205, 235) end
		end
	end

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
-- 5. UTILITY METHODS
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

-- ============================================================================
-- 5. UTILITY METHODS
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
