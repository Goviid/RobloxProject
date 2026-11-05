--!strict
-- CardRevealModal.luau
-- Center screen card flip popup showing the revealed card (Rose vs Skull)

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local CardRevealModal = {}

local modalContainer: Frame? = nil
local cardBadge: Frame? = nil
local iconLabel: TextLabel? = nil
local typeLabel: TextLabel? = nil
local sourceLabel: TextLabel? = nil

-- ============================================================================
-- 1. SETUP
-- ============================================================================
function CardRevealModal.Create(parent: GuiObject): Frame
	local container = Instance.new("Frame")
	container.Name = "CardRevealModal"
	container.Size = UDim2.new(0, 240, 0, 260)
	container.Position = UDim2.new(0.5, -120, 0.45, -130)
	container.BackgroundColor3 = Theme.Colors.PanelBackground
	container.BackgroundTransparency = 0.1
	container.BorderSizePixel = 0
	container.Visible = false
	container.ZIndex = 20
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Large
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Gold
	stroke.Thickness = 2.5
	stroke.Parent = container

	-- Who was flipped from
	local source = Instance.new("TextLabel")
	source.Name = "SourceLabel"
	source.Size = UDim2.new(1, -20, 0, 24)
	source.Position = UDim2.new(0, 10, 0, 14)
	source.BackgroundTransparency = 1
	source.Font = Theme.Fonts.Header
	source.TextSize = 13
	source.TextColor3 = Theme.Colors.TextSecondary
	source.Text = "Revealed from Stack"
	source.Parent = container

	-- Circular Card Face
	local card = Instance.new("Frame")
	card.Name = "CardFace"
	card.Size = UDim2.new(0, 130, 0, 130)
	card.Position = UDim2.new(0.5, -65, 0, 48)
	card.BackgroundColor3 = Theme.Colors.RosePrimary
	card.BorderSizePixel = 0
	card.Parent = container

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = Theme.CornerRadius.Circular
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardStroke"
	cardStroke.Color = Theme.Colors.GoldGlow
	cardStroke.Thickness = 3
	cardStroke.Parent = card

	-- Icon (🌹 or 💀)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 64
	icon.Text = "🌹"
	icon.Parent = card

	-- Card Type Announcement ("ROSE" or "SKULL!")
	local typeText = Instance.new("TextLabel")
	typeText.Name = "TypeLabel"
	typeText.Size = UDim2.new(1, -20, 0, 32)
	typeText.Position = UDim2.new(0, 10, 1, -54)
	typeText.BackgroundTransparency = 1
	typeText.Font = Theme.Fonts.Title
	typeText.TextSize = 20
	typeText.TextColor3 = Theme.Colors.TextGold
	typeText.Text = "ROSE REVEALED"
	typeText.Parent = container

	-- Progress subtext (e.g. "2 of 4 Roses Flipped")
	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressLabel"
	progressText.Size = UDim2.new(1, -20, 0, 18)
	progressText.Position = UDim2.new(0, 10, 1, -26)
	progressText.BackgroundTransparency = 1
	progressText.Font = Theme.Fonts.Body
	progressText.TextSize = 11
	progressText.TextColor3 = Theme.Colors.TextSecondary
	progressText.Text = "Progress: 1/3"
	progressText.Parent = container

	modalContainer = container
	cardBadge = card
	iconLabel = icon
	typeLabel = typeText
	sourceLabel = source

	return container
end

-- ============================================================================
-- 2. ANIMATED SHOW & HIDE
-- ============================================================================
function CardRevealModal.ShowCard(cardType: string, fromPlayerName: string, flippedCount: number, targetCount: number)
	if not modalContainer or not cardBadge or not iconLabel or not typeLabel or not sourceLabel then return end

	local isSkull = (cardType == Enums.CardType.Skull)
	sourceLabel.Text = "Revealed from " .. fromPlayerName .. "'s Stack"
	iconLabel.Text = isSkull and "💀" or "🌹"

	if isSkull then
		cardBadge.BackgroundColor3 = Theme.Colors.SkullPrimary
		typeLabel.Text = "💥 SKULL HIT! 💥"
		typeLabel.TextColor3 = Theme.Colors.AlertRed
	else
		cardBadge.BackgroundColor3 = Theme.Colors.RosePrimary
		typeLabel.Text = "🌹 ROSE REVEALED!"
		typeLabel.TextColor3 = Theme.Colors.Gold
	end

	local progress = modalContainer:FindFirstChild("ProgressLabel") :: TextLabel?
	if progress then
		progress.Text = isSkull and "Challenger failed the bet!" or ("Progress: " .. flippedCount .. " of " .. targetCount .. " Roses")
	end

	-- Pop-in animation
	modalContainer.Visible = true
	modalContainer.Size = UDim2.new(0, 200, 0, 220)
	modalContainer.Position = UDim2.new(0.5, -100, 0.45, -110)

	TweenService:Create(modalContainer, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 240, 0, 260),
		Position = UDim2.new(0.5, -120, 0.45, -130),
	}):Play()

	-- Auto-hide after 1.4 seconds
	task.delay(1.4, function()
		if not modalContainer then return end
		local tween = TweenService:Create(modalContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 180, 0, 200),
			Position = UDim2.new(0.5, -90, 0.45, -100),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if modalContainer then
				modalContainer.Visible = false
			end
		end)
	end)
end

return CardRevealModal

