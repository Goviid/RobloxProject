--!strict
-- CardRevealModal.luau
-- Clean LOCOfficial-style Card Flip Announcement (Zero black boxes!)
-- Displays a floating 3D circular medallion in the center of the screen with smooth flip animation

local TweenService = game:GetService("TweenService")
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local CardRevealModal = {}

local modalContainer: Frame? = nil
local cardBadge: Frame? = nil
local iconLabel: TextLabel? = nil
local typeLabel: TextLabel? = nil
local sourceLabel: TextLabel? = nil

-- ============================================================================
-- 1. SETUP (Clean Floating Medallion, No Dark Box!)
-- ============================================================================
function CardRevealModal.Create(parent: GuiObject): Frame
	local container = Instance.new("Frame")
	container.Name = "CardRevealModal"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Size = UDim2.new(0, 260, 0, 260)
	container.Position = UDim2.new(0.5, 0, 0.44, 0)
	container.BackgroundTransparency = 1 -- Zero black box!
	container.BorderSizePixel = 0
	container.Visible = false
	container.ZIndex = 50
	container.Parent = parent

	-- Who was flipped from (e.g. "Doña Flor's Stack")
	local source = Instance.new("TextLabel")
	source.Name = "SourceLabel"
	source.Size = UDim2.new(1, 0, 0, 24)
	source.Position = UDim2.new(0, 0, 0, 0)
	source.BackgroundTransparency = 1
	source.Font = Enum.Font.FredokaOne
	source.TextSize = 15
	source.TextColor3 = Color3.fromRGB(240, 248, 255)
	source.TextStrokeTransparency = 0.4
	source.TextStrokeColor3 = Color3.fromRGB(15, 30, 55)
	source.Text = "Revealed from Stack"
	source.ZIndex = 51
	source.Parent = container

	-- Vertical Playing Card Face (LOCOfficial Uno Style)
	local card = Instance.new("Frame")
	card.Name = "CardFace"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.new(0, 130, 0, 185)
	card.Position = UDim2.new(0.5, 0, 0.5, -4)
	card.BackgroundColor3 = Color3.fromRGB(235, 42, 75)
	card.BorderSizePixel = 0
	card.ZIndex = 51
	card.Parent = container

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardStroke"
	cardStroke.Color = Color3.fromRGB(255, 255, 255)
	cardStroke.Thickness = 3.5
	cardStroke.Parent = card

	-- Top-Left Mini Pip
	local tlPip = Instance.new("Frame")
	tlPip.Name = "TLPip"
	tlPip.Size = UDim2.new(0, 24, 0, 26)
	tlPip.Position = UDim2.new(0, 7, 0, 7)
	tlPip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tlPip.BorderSizePixel = 0
	tlPip.ZIndex = 52
	tlPip.Parent = card
	Instance.new("UICorner", tlPip).CornerRadius = UDim.new(0, 6)

	local tlIcon = Instance.new("TextLabel")
	tlIcon.Name = "TLIcon"
	tlIcon.Size = UDim2.new(1, 0, 1, 0)
	tlIcon.BackgroundTransparency = 1
	tlIcon.Font = Enum.Font.FredokaOne
	tlIcon.TextSize = 14
	tlIcon.Text = "🌹"
	tlIcon.ZIndex = 53
	tlIcon.Parent = tlPip

	-- Bottom-Right Mini Pip
	local brPip = Instance.new("Frame")
	brPip.Name = "BRPip"
	brPip.Size = UDim2.new(0, 24, 0, 26)
	brPip.Position = UDim2.new(1, -31, 1, -33)
	brPip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	brPip.BorderSizePixel = 0
	brPip.ZIndex = 52
	brPip.Parent = card
	Instance.new("UICorner", brPip).CornerRadius = UDim.new(0, 6)

	local brIcon = Instance.new("TextLabel")
	brIcon.Name = "BRIcon"
	brIcon.Size = UDim2.new(1, 0, 1, 0)
	brIcon.BackgroundTransparency = 1
	brIcon.Font = Enum.Font.FredokaOne
	brIcon.TextSize = 14
	brIcon.Text = "🌹"
	brIcon.ZIndex = 53
	brIcon.Parent = brPip

	-- Center White Oval Graphic
	local centerOval = Instance.new("Frame")
	centerOval.Name = "CenterOval"
	centerOval.Size = UDim2.new(0, 84, 0, 96)
	centerOval.Position = UDim2.new(0.5, -42, 0.5, -48)
	centerOval.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	centerOval.BorderSizePixel = 0
	centerOval.ZIndex = 52
	centerOval.Parent = card
	Instance.new("UICorner", centerOval).CornerRadius = UDim.new(0, 22)

	-- Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 56)
	icon.Position = UDim2.new(0, 0, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.FredokaOne
	icon.TextSize = 56
	icon.Text = "🌹"
	icon.ZIndex = 53
	icon.Parent = centerOval

	local nameSub = Instance.new("TextLabel")
	nameSub.Name = "NameSub"
	nameSub.Size = UDim2.new(1, 0, 0, 18)
	nameSub.Position = UDim2.new(0, 0, 1, -26)
	nameSub.BackgroundTransparency = 1
	nameSub.Font = Enum.Font.FredokaOne
	nameSub.TextSize = 13
	nameSub.TextColor3 = Color3.fromRGB(205, 30, 55)
	nameSub.Text = "ROSE"
	nameSub.ZIndex = 53
	nameSub.Parent = centerOval

	-- Card Type Announcement ("ROSE REVEALED" or "SKULL REVEALED!")
	local typeText = Instance.new("TextLabel")
	typeText.Name = "TypeLabel"
	typeText.Size = UDim2.new(1, 0, 0, 30)
	typeText.Position = UDim2.new(0, 0, 1, -30)
	typeText.BackgroundTransparency = 1
	typeText.Font = Enum.Font.FredokaOne
	typeText.TextSize = 22
	typeText.TextColor3 = Color3.fromRGB(255, 225, 80)
	typeText.TextStrokeTransparency = 0.35
	typeText.TextStrokeColor3 = Color3.fromRGB(20, 15, 30)
	typeText.Text = "ROSE REVEALED"
	typeText.ZIndex = 51
	typeText.Parent = container

	modalContainer = container
	cardBadge = card
	iconLabel = icon
	typeLabel = typeText
	sourceLabel = source

	return container
end

-- ============================================================================
-- 2. TRIGGER REVEAL POPUP ANIMATION
-- ============================================================================
function CardRevealModal.ShowCard(cardType: string, playerName: string, flippedCount: number, targetCount: number)
	if not modalContainer or not cardBadge or not iconLabel or not typeLabel or not sourceLabel then return end

	local isSkull = (cardType == Enums.CardType.Skull)

	sourceLabel.Text = playerName .. "'s Stack (" .. flippedCount .. "/" .. targetCount .. ")"
	iconLabel.Text = isSkull and "💀" or "🌹"

	if isSkull then
		cardBadge.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
		typeLabel.Text = "💀 SKULL REVEALED!"
		typeLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
		local stroke = cardBadge:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then stroke.Color = Color3.fromRGB(255, 255, 255) end

		local co = cardBadge:FindFirstChild("CenterOval")
		if co then
			local ns = co:FindFirstChild("NameSub") :: TextLabel?
			if ns then
				ns.Text = "SKULL"
				ns.TextColor3 = Color3.fromRGB(25, 25, 30)
			end
		end
		local tl = cardBadge:FindFirstChild("TLPip")
		if tl then
			local ic = tl:FindFirstChild("TLIcon") :: TextLabel?
			if ic then ic.Text = "💀" end
		end
		local br = cardBadge:FindFirstChild("BRPip")
		if br then
			local ic = br:FindFirstChild("BRIcon") :: TextLabel?
			if ic then ic.Text = "💀" end
		end
	else
		cardBadge.BackgroundColor3 = Color3.fromRGB(235, 42, 75)
		typeLabel.Text = "🌹 ROSE REVEALED"
		typeLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
		local stroke = cardBadge:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then stroke.Color = Color3.fromRGB(255, 255, 255) end

		local co = cardBadge:FindFirstChild("CenterOval")
		if co then
			local ns = co:FindFirstChild("NameSub") :: TextLabel?
			if ns then
				ns.Text = "ROSE"
				ns.TextColor3 = Color3.fromRGB(205, 30, 55)
			end
		end
		local tl = cardBadge:FindFirstChild("TLPip")
		if tl then
			local ic = tl:FindFirstChild("TLIcon") :: TextLabel?
			if ic then ic.Text = "🌹" end
		end
		local br = cardBadge:FindFirstChild("BRPip")
		if br then
			local ic = br:FindFirstChild("BRIcon") :: TextLabel?
			if ic then ic.Text = "🌹" end
		end
	end

	modalContainer.Visible = true

	-- Flip scale animation (horizontal flip effect)
	cardBadge.Size = UDim2.new(0, 10, 0, 185)
	TweenService:Create(cardBadge, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 130, 0, 185),
	}):Play()

	-- Auto-dismiss after 2.2 seconds
	task.delay(2.2, function()
		if not modalContainer then return end
		local fade = TweenService:Create(cardBadge, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
		})
		fade:Play()
		fade.Completed:Connect(function()
			if modalContainer then
				modalContainer.Visible = false
			end
		end)
	end)
end

return CardRevealModal
