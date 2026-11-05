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

	-- Circular Medallion Card Face
	local card = Instance.new("Frame")
	card.Name = "CardFace"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.new(0, 150, 0, 150)
	card.Position = UDim2.new(0.5, 0, 0.5, -6)
	card.BackgroundColor3 = Color3.fromRGB(205, 30, 55)
	card.BorderSizePixel = 0
	card.ZIndex = 51
	card.Parent = container

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(1, 0)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardStroke"
	cardStroke.Color = Color3.fromRGB(255, 225, 80)
	cardStroke.Thickness = 4
	cardStroke.Parent = card

	-- Inner Ring
	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(1, -16, 1, -16)
	inner.Position = UDim2.new(0, 8, 0, 8)
	inner.BackgroundTransparency = 1
	inner.ZIndex = 52
	inner.Parent = card
	Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(255, 240, 160)
	innerStroke.Transparency = 0.4
	innerStroke.Thickness = 2
	innerStroke.Parent = inner

	-- Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.FredokaOne
	icon.TextSize = 82
	icon.Text = "🌹"
	icon.ZIndex = 53
	icon.Parent = card

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
		cardBadge.BackgroundColor3 = Color3.fromRGB(30, 24, 34)
		typeLabel.Text = "💀 SKULL REVEALED!"
		typeLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
		local stroke = cardBadge:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then stroke.Color = Color3.fromRGB(255, 80, 80) end
	else
		cardBadge.BackgroundColor3 = Color3.fromRGB(205, 30, 55)
		typeLabel.Text = "🌹 ROSE REVEALED"
		typeLabel.TextColor3 = Color3.fromRGB(255, 230, 90)
		local stroke = cardBadge:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then stroke.Color = Color3.fromRGB(255, 225, 80) end
	end

	modalContainer.Visible = true

	-- Flip scale animation
	cardBadge.Size = UDim2.new(0, 10, 0, 150)
	TweenService:Create(cardBadge, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 150, 0, 150),
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
