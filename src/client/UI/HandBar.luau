--!strict
-- HandBar.luau
-- Circular Cards / Tokens Hand Fan (Matching the exact concept reference image)
-- Features:
-- 1. Cream circular Rose tokens with crimson roses & gold rims
-- 2. Dark circular Skull token with stylized skull & glowing neon crimson rim
-- 3. Floating "PLACE CARD" prompts above each token
-- 4. Smooth hover elevation with glowing neon highlights
-- 5. Tactile card placement into "YOUR PILE" with dynamic re-centering

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

-- Circular Token Dimensions (Clean circular tokens docked at bottom center)
local CARD_DIAMETER = 150
local CARD_SPACING = 88
local RESTING_Y = -55
local HOVER_LIFT_Y = -105

-- Natural fan angles
local function getFannedAngle(index: number, total: number): number
	if total <= 1 then return 0 end
	local norm = (index - 1) / (total - 1) -- 0.0 to 1.0
	local maxDeg = if total >= 4 then 12.0 elseif total == 3 then 8.0 else 5.0
	return (norm - 0.5) * (maxDeg * 2)
end

local function getArchY(index: number, total: number): number
	if total <= 1 then return 0 end
	local centerDist = math.abs((index - 1) - (total - 1) / 2)
	return centerDist * 8.0
end

-- ============================================================================
-- 1. CONSTRUCT A CIRCULAR TOKEN
-- ============================================================================
local function createCircularToken(
	cardType: string,
	index: number,
	totalCards: number,
	xOffset: number,
	isPlayable: boolean
): Frame
	local isRose = (cardType == Enums.CardType.Rose)
	local rotAngle = getFannedAngle(index, totalCards)
	local archY = getArchY(index, totalCards)
	local restingYPos = RESTING_Y + archY
	local baseZIndex = 20 + index

	local container = Instance.new("Frame")
	container.Name = "TokenHolder_" .. index .. "_" .. cardType
	container.Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER + 36)
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.new(0.5, xOffset, 1, restingYPos)
	container.Rotation = rotAngle
	container.BackgroundTransparency = 1
	container.ZIndex = baseZIndex

	-- Dynamic attributes for smooth re-centering & return
	container:SetAttribute("RestingX", xOffset)
	container:SetAttribute("RestingY", restingYPos)
	container:SetAttribute("RestingRot", rotAngle)
	container:SetAttribute("BaseZIndex", baseZIndex)

	-- Tiny Floating Prompt Label above token ("PLACE CARD")
	local promptLabel = Instance.new("TextLabel")
	promptLabel.Name = "PromptLabel"
	promptLabel.Size = UDim2.new(1, 0, 0, 18)
	promptLabel.Position = UDim2.new(0, 0, 0, 4)
	promptLabel.BackgroundTransparency = 1
	promptLabel.Font = Enum.Font.FredokaOne
	promptLabel.TextSize = 11 -- Tiny text as requested
	promptLabel.TextColor3 = isRose and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 110, 130)
	promptLabel.TextStrokeTransparency = 0.35
	promptLabel.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
	promptLabel.Text = ""
	promptLabel.ZIndex = baseZIndex + 4
	promptLabel.Parent = container

	-- Circular Shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "TokenShadow"
	shadow.Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER)
	shadow.Position = UDim2.new(0, 0, 0, 36)
	shadow.BackgroundColor3 = Color3.fromRGB(12, 10, 16)
	shadow.BackgroundTransparency = 0.65
	shadow.BorderSizePixel = 0
	shadow.ZIndex = baseZIndex
	shadow.Parent = container
	Instance.new("UICorner", shadow).CornerRadius = UDim.new(1, 0)

	-- Circular Button Body
	local btn = Instance.new("ImageButton")
	btn.Name = "TokenButton"
	btn.Size = UDim2.new(0, CARD_DIAMETER, 0, CARD_DIAMETER)
	btn.Position = UDim2.new(0, 0, 0, 28)
	btn.BackgroundColor3 = isRose and Color3.fromRGB(240, 226, 202) or Color3.fromRGB(28, 24, 32)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = baseZIndex + 1
	btn.Parent = container
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

	-- Outer Stroke: Rose = Crisp Gold Rim; Skull = Glowing Neon Crimson Rim
	local tokenStroke = Instance.new("UIStroke")
	tokenStroke.Name = "TokenStroke"
	tokenStroke.Color = isRose and Color3.fromRGB(255, 215, 75) or Color3.fromRGB(255, 45, 65)
	tokenStroke.Thickness = isRose and 4.6 or 5.2
	tokenStroke.Parent = btn

	-- Subtle Color Gradient
	local grad = Instance.new("UIGradient")
	grad.Rotation = 45
	if isRose then
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(248, 236, 216)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(222, 206, 178)),
		})
	else
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(42, 36, 48)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(18, 15, 22)),
		})
	end
	grad.Parent = btn

	-- Inner Concentric Ring
	local inner = Instance.new("Frame")
	inner.Name = "InnerRing"
	inner.Size = UDim2.new(1, -18, 1, -18)
	inner.Position = UDim2.new(0, 9, 0, 9)
	inner.BackgroundTransparency = 1
	inner.ZIndex = baseZIndex + 2
	inner.Parent = btn
	Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = isRose and Color3.fromRGB(205, 175, 115) or Color3.fromRGB(255, 75, 105)
	innerStroke.Transparency = 0.45
	innerStroke.Thickness = 1.6
	innerStroke.Parent = inner

	-- Center Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "CenterIcon"
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.Position = UDim2.new(0, 0, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 74
	icon.Text = isRose and "🌹" or "💀"
	icon.TextColor3 = isRose and Color3.fromRGB(215, 30, 50) or Color3.fromRGB(245, 235, 250)
	icon.ZIndex = baseZIndex + 3
	icon.Parent = btn

	-- Hover & Elevation (Tactile Locofficial-style hover response)
	btn.MouseEnter:Connect(function()
		container.ZIndex = 60
		shadow.ZIndex = 60
		btn.ZIndex = 61
		inner.ZIndex = 62
		icon.ZIndex = 63
		promptLabel.ZIndex = 64

		local curX = container:GetAttribute("RestingX") or xOffset

		TweenService:Create(container, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, curX, 1, HOVER_LIFT_Y),
			Rotation = 0,
		}):Play()

		TweenService:Create(tokenStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 6.0,
			Color = isRose and Color3.fromRGB(255, 245, 180) or Color3.fromRGB(255, 70, 100),
		}):Play()

		if isPlayerTurn and canCurrentlyPlace then
			promptLabel.Text = isRose and "PLACE ROSE" or "PLACE SKULL"
			promptLabel.TextColor3 = isRose and Color3.fromRGB(255, 235, 150) or Color3.fromRGB(255, 80, 110)
		else
			promptLabel.Text = isRose and "ROSE" or "SKULL"
			promptLabel.TextColor3 = isRose and Color3.fromRGB(255, 235, 150) or Color3.fromRGB(255, 80, 110)
		end
	end)

	btn.MouseLeave:Connect(function()
		local curX = container:GetAttribute("RestingX") or xOffset
		local curY = container:GetAttribute("RestingY") or restingYPos
		local curRot = container:GetAttribute("RestingRot") or rotAngle
		local curZ = container:GetAttribute("BaseZIndex") or baseZIndex

		container.ZIndex = curZ
		shadow.ZIndex = curZ
		btn.ZIndex = curZ + 1
		inner.ZIndex = curZ + 2
		icon.ZIndex = curZ + 3
		promptLabel.ZIndex = curZ + 4

		TweenService:Create(container, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, curX, 1, curY),
			Rotation = curRot,
		}):Play()

		TweenService:Create(tokenStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = isRose and 4.0 or 4.5,
			Color = isRose and Color3.fromRGB(255, 225, 130) or Color3.fromRGB(255, 45, 75),
		}):Play()

		promptLabel.Text = ""
		promptLabel.TextColor3 = isRose and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 100, 120)
	end)

	btn.MouseButton1Click:Connect(function()
		if not isPlayerTurn or not canCurrentlyPlace then return end
		isPlayerTurn = false
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
-- 2. CONSUME CARD & RE-FAN REMAINING
-- ============================================================================
function HandBar.ConsumeCard(cardIndex: number)
	if not dockFrame then return end
	local targetContainer = cardContainers[cardIndex]
	if not targetContainer then return end

	table.remove(cardContainers, cardIndex)
	table.remove(currentHand, cardIndex)

	local btn = targetContainer:FindFirstChild("TokenButton") :: ImageButton?
	local promptLabel = targetContainer:FindFirstChild("PromptLabel") :: TextLabel?
	local shadow = targetContainer:FindFirstChild("TokenShadow") :: Frame?
	local icon = btn and btn:FindFirstChild("CenterIcon") :: TextLabel?
	local stroke = btn and btn:FindFirstChild("TokenStroke") :: UIStroke?
	local inner = btn and btn:FindFirstChild("InnerRing") :: Frame?
	local innerStroke = inner and inner:FindFirstChildWhichIsA("UIStroke") :: UIStroke?

	local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	if btn then
		TweenService:Create(btn, tweenInfo, { BackgroundTransparency = 1 }):Play()
	end
	if shadow then
		TweenService:Create(shadow, tweenInfo, { BackgroundTransparency = 1 }):Play()
	end
	if icon then
		TweenService:Create(icon, tweenInfo, { TextTransparency = 1 }):Play()
	end
	if promptLabel then
		TweenService:Create(promptLabel, tweenInfo, { TextTransparency = 1 }):Play()
	end
	if stroke then
		TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()
	end
	if innerStroke then
		TweenService:Create(innerStroke, tweenInfo, { Transparency = 1 }):Play()
	end

	local exitTween = TweenService:Create(targetContainer, tweenInfo, {
		Position = targetContainer.Position + UDim2.new(0, 0, 0, 60),
	})
	exitTween:Play()
	exitTween.Completed:Connect(function()
		targetContainer:Destroy()
	end)

	local totalRemaining = #currentHand
	if totalRemaining == 0 then
		dockFrame.Visible = false
		return
	end

	local totalWidth = (totalRemaining - 1) * CARD_SPACING
	local startX = -totalWidth / 2

	for i, container in ipairs(cardContainers) do
		local xOffset = startX + (i - 1) * CARD_SPACING
		local rotAngle = getFannedAngle(i, totalRemaining)
		local archY = getArchY(i, totalRemaining)
		local newY = RESTING_Y + archY
		local newZ = 20 + i

		container:SetAttribute("RestingX", xOffset)
		container:SetAttribute("RestingY", newY)
		container:SetAttribute("RestingRot", rotAngle)
		container:SetAttribute("BaseZIndex", newZ)
		container.ZIndex = newZ

		TweenService:Create(container, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, xOffset, 1, newY),
			Rotation = rotAngle,
		}):Play()
	end
end

-- ============================================================================
-- 3. SETUP FLOATING HAND DOCK (Locofficial style - cards only, clean fan)
-- ============================================================================
function HandBar.Create(parent: Instance, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect
	table.clear(cardContainers)

	local dock = Instance.new("Frame")
	dock.Name = "FloatingHandDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Size = UDim2.new(0, 600, 0, 240)
	dock.Position = UDim2.new(0.5, 0, 1, 0)
	dock.BackgroundTransparency = 1
	dock.BorderSizePixel = 0
	dock.ZIndex = 15
	dock.Parent = parent

	dockFrame = dock
	return dock
end

function HandBar.UpdateHand(hand: { string }, isTurn: boolean, canPlace: boolean)
	if not dockFrame then return end

	currentHand = hand
	isPlayerTurn = isTurn
	canCurrentlyPlace = canPlace
	dockFrame.Visible = (#hand > 0)

	-- If the visual cards count already matches, just reset prompt texts
	if #cardContainers == #hand and #hand > 0 then
		for _, c in ipairs(cardContainers) do
			local pLabel = c:FindFirstChild("PromptLabel") :: TextLabel?
			if pLabel then
				pLabel.Text = ""
			end
		end
		return
	end

	for _, c in ipairs(cardContainers) do
		c:Destroy()
	end
	table.clear(cardContainers)

	local total = #hand
	if total == 0 then return end

	local totalWidth = (total - 1) * CARD_SPACING
	local startX = -totalWidth / 2

	for i, cardType in ipairs(hand) do
		local xOffset = startX + (i - 1) * CARD_SPACING
		local tokenHolder = createCircularToken(cardType, i, total, xOffset, canPlace and isTurn)
		tokenHolder.Parent = dockFrame
		table.insert(cardContainers, tokenHolder)
	end
end

function HandBar.SetVisible(visible: boolean)
	if dockFrame then dockFrame.Visible = visible end
end

function HandBar.GetSelectedCard(): string?
	return selectedCard
end

function HandBar.GetRemainingCardsCount(): number
	return #currentHand
end

return HandBar
