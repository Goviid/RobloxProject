--!strict
-- HandBar.luau
-- Oversized 2D Floating Card Hand at bottom of screen with direct-action placement buttons (LOCOfficial style)

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
-- 1. LOCOFFICIAL-STYLE OVERSIZED SQUIRCLE CARD WITH ACTION BUTTON (150 x 205 px)
-- ============================================================================
local function createOversizedCard(cardType: string): ImageButton
	local isRose = (cardType == Enums.CardType.Rose)

	-- Giant floating card button
	local btn = Instance.new("ImageButton")
	btn.Name = "Card_" .. cardType
	btn.Size = UDim2.new(0, 150, 0, 205) -- Oversized LOCOfficial dimensions
	btn.BackgroundColor3 = isRose and Color3.fromRGB(165, 20, 36) or Color3.fromRGB(28, 24, 28)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.AnchorPoint = Vector2.new(0.5, 1)
	btn.ZIndex = 22

	-- Soft squircle corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = btn

	-- Chunky arcade border outline
	local stroke = Instance.new("UIStroke")
	stroke.Name = "BorderStroke"
	stroke.Color = Theme.Colors.GoldMuted
	stroke.Thickness = 4.0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	-- Inner card gold bevel line
	local innerBevel = Instance.new("Frame")
	innerBevel.Name = "InnerBevel"
	innerBevel.Size = UDim2.new(1, -12, 1, -12)
	innerBevel.Position = UDim2.new(0, 6, 0, 6)
	innerBevel.BackgroundTransparency = 1
	innerBevel.ZIndex = 23
	innerBevel.Parent = btn

	local bevelCorner = Instance.new("UICorner")
	bevelCorner.CornerRadius = UDim.new(0, 14)
	bevelCorner.Parent = innerBevel

	local bevelStroke = Instance.new("UIStroke")
	bevelStroke.Color = Color3.fromRGB(240, 200, 100)
	bevelStroke.Transparency = 0.6
	bevelStroke.Thickness = 1.5
	bevelStroke.Parent = innerBevel

	-- Giant Center Card Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 95)
	icon.Position = UDim2.new(0, 0, 0, 18)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 64
	icon.Text = isRose and "🌹" or "💀"
	icon.ZIndex = 24
	icon.Parent = btn

	-- Card Count Pill (Top Right)
	local countPill = Instance.new("Frame")
	countPill.Name = "CountPill"
	countPill.Size = UDim2.new(0, 36, 0, 36)
	countPill.Position = UDim2.new(1, -22, 0, -12)
	countPill.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
	countPill.BorderSizePixel = 0
	countPill.ZIndex = 26
	countPill.Parent = btn

	local countCorner = Instance.new("UICorner")
	countCorner.CornerRadius = Theme.CornerRadius.Circular
	countCorner.Parent = countPill

	local countStroke = Instance.new("UIStroke")
	countStroke.Color = Theme.Colors.Gold
	countStroke.Thickness = 2.0
	countStroke.Parent = countPill

	local countNum = Instance.new("TextLabel")
	countNum.Name = "CountNum"
	countNum.Size = UDim2.new(1, 0, 1, 0)
	countNum.BackgroundTransparency = 1
	countNum.Font = Theme.Fonts.Header
	countNum.TextSize = 16
	countNum.TextColor3 = Theme.Colors.TextPrimary
	countNum.Text = isRose and "3" or "1"
	countNum.ZIndex = 27
	countNum.Parent = countPill

	-- Direct Action Placement Button on Card Bottom
	local actionBadge = Instance.new("TextButton")
	actionBadge.Name = "ActionBadge"
	actionBadge.Size = UDim2.new(1, -16, 0, 36)
	actionBadge.Position = UDim2.new(0, 8, 1, -44)
	actionBadge.BackgroundColor3 = isRose and Color3.fromRGB(36, 125, 230) or Color3.fromRGB(180, 45, 60)
	actionBadge.BorderSizePixel = 0
	actionBadge.AutoButtonColor = true
	actionBadge.Font = Theme.Fonts.Title
	actionBadge.TextSize = 13
	actionBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionBadge.Text = isRose and "🌹 PLACE ROSE" or "💀 PLACE SKULL"
	actionBadge.ZIndex = 25
	actionBadge.Parent = btn

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 8)
	badgeCorner.Parent = actionBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Name = "BadgeStroke"
	badgeStroke.Color = Theme.Colors.Gold
	badgeStroke.Thickness = 1.5
	badgeStroke.Parent = actionBadge

	-- Card click triggers direct placement
	local function triggerClick()
		if btn:GetAttribute("Disabled") == true then return end
		HandBar.SelectCard(cardType)
		if onCardClickedCallback then
			onCardClickedCallback(cardType)
		end
	end

	btn.MouseButton1Click:Connect(triggerClick)
	actionBadge.MouseButton1Click:Connect(triggerClick)

	-- Tactile Spring Hover Interactions
	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("Disabled") == true then return end
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, 1, -26),
		}):Play()
	end)

	btn.MouseLeave:Connect(function()
		local isSel = (selectedCard == cardType)
		TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, 1, isSel and -26 or 0),
		}):Play()
	end)

	return btn
end

-- ============================================================================
-- 2. SETUP FLOATING OVERSIZED DOCK (360 x 225 px)
-- ============================================================================
function HandBar.Create(parent: Instance, onSelect: CardSelectCallback?): Frame
	onCardClickedCallback = onSelect
	table.clear(cardButtons)

	-- Floating oversized dock pinned cleanly at bottom center of screen
	local dock = Instance.new("Frame")
	dock.Name = "FloatingHandDock"
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Size = UDim2.new(0, 360, 0, 225)
	dock.Position = UDim2.new(0.5, 0, 1, -25) -- Safe bottom padding
	dock.BackgroundTransparency = 1
	dock.ZIndex = 20
	dock.Parent = parent

	-- Rose Card (Left)
	local roseBtn = createOversizedCard(Enums.CardType.Rose)
	roseBtn.Position = UDim2.new(0, 85, 1, 0)
	roseBtn.Parent = dock
	cardButtons[Enums.CardType.Rose] = roseBtn

	-- Skull Card (Right)
	local skullBtn = createOversizedCard(Enums.CardType.Skull)
	skullBtn.Position = UDim2.new(0, 275, 1, 0)
	skullBtn.Parent = dock
	cardButtons[Enums.CardType.Skull] = skullBtn

	dockFrame = dock

	-- Default select Rose on startup
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
			stroke.Thickness = isSel and 5.0 or 4.0
		end
		TweenService:Create(btn, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(btn.Position.X.Scale, btn.Position.X.Offset, 1, isSel and -26 or 0),
			Size = isSel and UDim2.new(0, 156, 0, 215) or UDim2.new(0, 150, 0, 205),
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
		local countPill = roseBtn:FindFirstChild("CountPill")
		local countNum = if countPill then countPill:FindFirstChild("CountNum") :: TextLabel? else nil
		if countNum then countNum.Text = tostring(roseCount) end
		local hasRoses = (roseCount > 0)
		local isEnabled = hasRoses and isMyTurn and canPlace
		roseBtn:SetAttribute("Disabled", not isEnabled)
		roseBtn.BackgroundTransparency = hasRoses and 0 or 0.65

		local actionBadge = roseBtn:FindFirstChild("ActionBadge") :: TextButton?
		if actionBadge then
			actionBadge.AutoButtonColor = isEnabled
			actionBadge.BackgroundTransparency = isEnabled and 0 or 0.5
			actionBadge.Text = if not hasRoses then "NO ROSES LEFT" elseif isEnabled then "🌹 PLACE ROSE" else "ROSE"
		end

		local icon = roseBtn:FindFirstChild("Icon") :: TextLabel?
		if icon then
			icon.TextTransparency = hasRoses and 0 or 0.5
		end
	end

	-- Skull update
	local skullBtn = cardButtons[Enums.CardType.Skull]
	if skullBtn then
		local countPill = skullBtn:FindFirstChild("CountPill")
		local countNum = if countPill then countPill:FindFirstChild("CountNum") :: TextLabel? else nil
		if countNum then countNum.Text = tostring(skullCount) end
		local hasSkulls = (skullCount > 0)
		local isEnabled = hasSkulls and isMyTurn and canPlace
		skullBtn:SetAttribute("Disabled", not isEnabled)
		skullBtn.BackgroundTransparency = hasSkulls and 0 or 0.65

		local actionBadge = skullBtn:FindFirstChild("ActionBadge") :: TextButton?
		if actionBadge then
			actionBadge.AutoButtonColor = isEnabled
			actionBadge.BackgroundTransparency = isEnabled and 0 or 0.5
			actionBadge.Text = if not hasSkulls then "NO SKULL LEFT" elseif isEnabled then "💀 PLACE SKULL" else "SKULL"
		end

		local icon = skullBtn:FindFirstChild("Icon") :: TextLabel?
		if icon then
			icon.TextTransparency = hasSkulls and 0 or 0.5
		end
	end

	-- Maintain valid selection
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
