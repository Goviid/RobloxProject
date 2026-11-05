--!strict
-- HandBar.luau
-- Floating 2D Card Dock at bottom center of screen with spring hover and arcade polish (LOCOfficial style)

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local HandBar = {}

local dockFrame: Frame? = nil
local cardButtons: { [string]: ImageButton } = {}
local selectedCard: string? = Enums.CardType.Rose

export type CardSelectCallback = (cardType: string) -> ()
local onCardClickedCallback: CardSelectCallback? = nil

-- ============================================================================
-- 1. LOCOFFICIAL-STYLE FLOATING SQUIRCLE CARD
-- ============================================================================
local function createFloatingCard(cardType: string): ImageButton
	local isRose = (cardType == Enums.CardType.Rose)

	-- Main floating card button (squircle card)
	local btn = Instance.new("ImageButton")
	btn.Name = "Card_" .. cardType
	btn.Size = UDim2.new(0, 96, 0, 120)
	btn.BackgroundColor3 = isRose and Theme.Colors.RosePrimary or Theme.Colors.SkullPrimary
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.AnchorPoint = Vector2.new(0.5, 1) -- Anchored at bottom for natural lift

	-- Soft squircle corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = btn

	-- Chunky border outline (arcade style)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "BorderStroke"
	stroke.Color = Theme.Colors.GoldMuted
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	-- Inner card white bevel line
	local innerBevel = Instance.new("Frame")
	innerBevel.Name = "InnerBevel"
	innerBevel.Size = UDim2.new(1, -8, 1, -8)
	innerBevel.Position = UDim2.new(0, 4, 0, 4)
	innerBevel.BackgroundTransparency = 1
	innerBevel.Parent = btn

	local bevelCorner = Instance.new("UICorner")
	bevelCorner.CornerRadius = UDim.new(0, 10)
	bevelCorner.Parent = innerBevel

	local bevelStroke = Instance.new("UIStroke")
	bevelStroke.Color = Color3.fromRGB(255, 255, 255)
	bevelStroke.Transparency = 0.8
	bevelStroke.Thickness = 1
	bevelStroke.Parent = innerBevel

	-- Giant Center Card Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 64)
	icon.Position = UDim2.new(0, 0, 0, 12)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 44
	icon.Text = isRose and "🌹" or "💀"
	icon.Parent = btn

	-- Bottom Card Banner Name ("ROSE" or "SKULL")
	local nameBadge = Instance.new("TextLabel")
	nameBadge.Name = "NameBadge"
	nameBadge.Size = UDim2.new(1, -12, 0, 22)
	nameBadge.Position = UDim2.new(0, 6, 1, -28)
	nameBadge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	nameBadge.BackgroundTransparency = 0.4
	nameBadge.Font = Theme.Fonts.Title
	nameBadge.TextSize = 12
	nameBadge.TextColor3 = isRose and Theme.Colors.TextPrimary or Theme.Colors.TextGold
	nameBadge.Text = isRose and "ROSE" or "SKULL"
	nameBadge.Parent = btn

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 6)
	badgeCorner.Parent = nameBadge

	-- Card Count Pill (Top Right)
	local countPill = Instance.new("Frame")
	countPill.Name = "CountPill"
	countPill.Size = UDim2.new(0, 26, 0, 26)
	countPill.Position = UDim2.new(1, -16, 0, -8)
	countPill.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
	countPill.BorderSizePixel = 0
	countPill.Parent = btn

	local countCorner = Instance.new("UICorner")
	countCorner.CornerRadius = Theme.CornerRadius.Circular
	countCorner.Parent = countPill

	local countStroke = Instance.new("UIStroke")
	countStroke.Color = Theme.Colors.Gold
	countStroke.Thickness = 1.5
	countStroke.Parent = countPill

	local countNum = Instance.new("TextLabel")
	countNum.Name = "CountNum"
	countNum.Size = UDim2.new(1, 0, 1, 0)
	countNum.BackgroundTransparency = 1
	countNum.Font = Theme.Fonts.Header
	countNum.TextSize = 12
	countNum.TextColor3 = Theme.Colors.TextPrimary
	countNum.Text = isRose and "3" or "1"
	countNum.Parent = countPill

	-- Spring Hover and Click Interactions
	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("Disabled") == true then return end
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, 1, -14),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		local isSel = (selectedCard == cardType)
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, 1, isSel and -14 or 0),
		}):Play()
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
-- 2. SETUP FLOATING DOCK AT BOTTOM OF SCREEN
-- ============================================================================
function HandBar.Create(parent: GuiObject, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect

	-- Floating invisible dock pinned cleanly at bottom center of screen
	local dock = Instance.new("Frame")
	dock.Name = "FloatingHandDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Size = UDim2.new(0, 260, 0, 134)
	dock.Position = UDim2.new(0.5, 0, 1, -14)
	dock.BackgroundTransparency = 1
	dock.Parent = parent

	-- Rose Card
	local roseBtn = createFloatingCard(Enums.CardType.Rose)
	roseBtn.Position = UDim2.new(0, 60, 1, 0)
	roseBtn.Parent = dock
	cardButtons[Enums.CardType.Rose] = roseBtn

	-- Skull Card
	local skullBtn = createFloatingCard(Enums.CardType.Skull)
	skullBtn.Position = UDim2.new(0, 196, 1, 0)
	skullBtn.Parent = dock
	cardButtons[Enums.CardType.Skull] = skullBtn

	dockFrame = dock

	-- Default select Rose
	HandBar.SelectCard(Enums.CardType.Rose)

	return dock
end

function HandBar.SelectCard(cardType: string)
	selectedCard = cardType

	for cType, btn in pairs(cardButtons) do
		local isSel = (cType == cardType)
		local stroke = btn:FindFirstChild("BorderStroke") :: UIStroke?
		if stroke then
			stroke.Color = isSel and Theme.Colors.GoldGlow or Theme.Colors.GoldMuted
			stroke.Thickness = isSel and 4 or 3
		end
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, 1, isSel and -14 or 0),
			Size = isSel and UDim2.new(0, 100, 0, 126) or UDim2.new(0, 96, 0, 120),
		}):Play()
	end
end

function HandBar.GetSelectedCard(): string?
	return selectedCard
end

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

	-- Rose update
	local roseBtn = cardButtons[Enums.CardType.Rose]
	if roseBtn then
		local countNum = roseBtn:FindFirstChild("CountPill") and roseBtn.CountPill:FindFirstChild("CountNum") :: TextLabel?
		if countNum then countNum.Text = tostring(roseCount) end
		roseBtn.Visible = (roseCount > 0)
		local isEnabled = (isMyTurn and canPlace and roseCount > 0)
		roseBtn:SetAttribute("Disabled", not isEnabled)
		roseBtn.ImageTransparency = isEnabled and 0 or 0.4
	end

	-- Skull update
	local skullBtn = cardButtons[Enums.CardType.Skull]
	if skullBtn then
		local countNum = skullBtn:FindFirstChild("CountPill") and skullBtn.CountPill:FindFirstChild("CountNum") :: TextLabel?
		if countNum then countNum.Text = tostring(skullCount) end
		skullBtn.Visible = (skullCount > 0)
		local isEnabled = (isMyTurn and canPlace and skullCount > 0)
		skullBtn:SetAttribute("Disabled", not isEnabled)
		skullBtn.ImageTransparency = isEnabled and 0 or 0.4
	end

	-- Keep valid selection
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
