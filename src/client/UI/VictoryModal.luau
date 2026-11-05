--!strict
-- VictoryModal.luau
-- Match celebration popup honoring the winner with animated particles, crown, and score banner (LOCOfficial style)

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Theme = require(script.Parent.Theme)

local VictoryModal = {}
local modalFrame: Frame? = nil
local winnerLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local gemContainer: Frame? = nil

-- Create floating confetti flakes
local function spawnConfettiBurst(parent: Instance)
	local colors = {
		Color3.fromRGB(245, 205, 60),  -- Gold
		Color3.fromRGB(235, 45, 65),   -- Crimson Rose
		Color3.fromRGB(255, 255, 255), -- White
		Color3.fromRGB(60, 190, 100),  -- Emerald
		Color3.fromRGB(50, 140, 240),  -- Azure
	}

	for _ = 1, 35 do
		local flake = Instance.new("Frame")
		flake.Name = "ConfettiFlake"
		flake.Size = UDim2.new(0, math.random(8, 14), 0, math.random(8, 14))
		flake.Position = UDim2.new(math.random(15, 85) / 100, 0, 0.45, 0)
		flake.BackgroundColor3 = colors[math.random(1, #colors)]
		flake.BorderSizePixel = 0
		flake.Rotation = math.random(0, 360)
		flake.ZIndex = 60
		flake.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = flake

		local targetX = flake.Position.X.Scale + (math.random(-25, 25) / 100)
		local targetY = flake.Position.Y.Scale + (math.random(-35, 35) / 100)

		local tween = TweenService:Create(flake, TweenInfo.new(math.random(12, 22) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(targetX, 0, targetY, 0),
			Rotation = flake.Rotation + math.random(-180, 180),
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			flake:Destroy()
		end)
	end
end

function VictoryModal.Create(parent: Instance): Frame
	local container = Instance.new("Frame")
	container.Name = "VictoryModal"
	container.Size = UDim2.new(0, 440, 0, 260)
	container.Position = UDim2.new(0.5, -220, 0.45, -130)
	container.BackgroundColor3 = Theme.Colors.PanelBackground
	container.BackgroundTransparency = 0.08
	container.BorderSizePixel = 0
	container.Visible = false
	container.ZIndex = 50
	container.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Large
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.GoldGlow
	stroke.Thickness = 3
	stroke.Parent = container

	-- Top Crown Trophy Banner
	local crownIcon = Instance.new("TextLabel")
	crownIcon.Name = "CrownIcon"
	crownIcon.Size = UDim2.new(1, 0, 0, 60)
	crownIcon.Position = UDim2.new(0, 0, 0, 12)
	crownIcon.BackgroundTransparency = 1
	crownIcon.Font = Theme.Fonts.Title
	crownIcon.TextSize = 52
	crownIcon.Text = "👑"
	crownIcon.ZIndex = 52
	crownIcon.Parent = container

	-- Victory Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 72)
	title.BackgroundTransparency = 1
	title.Font = Theme.Fonts.Title
	title.TextSize = 22
	title.TextColor3 = Theme.Colors.Gold
	title.Text = "MATCH VICTORY"
	title.ZIndex = 52
	title.Parent = container

	-- Winner Name
	local winner = Instance.new("TextLabel")
	winner.Name = "WinnerName"
	winner.Size = UDim2.new(1, -20, 0, 34)
	winner.Position = UDim2.new(0, 10, 0, 104)
	winner.BackgroundTransparency = 1
	winner.Font = Theme.Fonts.Header
	winner.TextSize = 20
	winner.TextColor3 = Theme.Colors.TextPrimary
	winner.Text = "DON DIEGO"
	winner.ZIndex = 52
	winner.Parent = container

	-- Winning Score Gems (2 golden diamonds)
	local gemBox = Instance.new("Frame")
	gemBox.Name = "GemBox"
	gemBox.Size = UDim2.new(1, 0, 0, 32)
	gemBox.Position = UDim2.new(0, 0, 0, 146)
	gemBox.BackgroundTransparency = 1
	gemBox.ZIndex = 52
	gemBox.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = gemBox

	for i = 1, 2 do
		local gem = Instance.new("TextLabel")
		gem.Name = "Gem_" .. i
		gem.Size = UDim2.new(0, 28, 0, 28)
		gem.BackgroundTransparency = 1
		gem.Font = Theme.Fonts.Title
		gem.TextSize = 26
		gem.TextColor3 = Theme.Colors.Gold
		gem.Text = "◆"
		gem.ZIndex = 53
		gem.Parent = gemBox
	end

	-- Subtitle (Round transition message)
	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.Size = UDim2.new(1, -20, 0, 24)
	sub.Position = UDim2.new(0, 10, 1, -38)
	sub.BackgroundTransparency = 1
	sub.Font = Theme.Fonts.Body
	sub.TextSize = 13
	sub.TextColor3 = Theme.Colors.TextSecondary
	sub.Text = "Preparing the next match..."
	sub.ZIndex = 52
	sub.Parent = container

	modalFrame = container
	winnerLabel = winner
	subtitleLabel = sub
	gemContainer = gemBox

	return container
end

function VictoryModal.Show(winnerName: string, isLocalPlayer: boolean)
	if not modalFrame or not winnerLabel or not subtitleLabel then return end

	winnerLabel.Text = if isLocalPlayer then "🎉 YOU WON THE MATCH! 🎉" else (winnerName .. " WINS THE MATCH!")
	winnerLabel.TextColor3 = if isLocalPlayer then Theme.Colors.GoldGlow else Theme.Colors.TextPrimary
	subtitleLabel.Text = "First to 2 Points! Preparing the next game..."

	modalFrame.Visible = true
	modalFrame.Size = UDim2.new(0, 360, 0, 210)
	modalFrame.Position = UDim2.new(0.5, -180, 0.45, -105)

	TweenService:Create(modalFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 440, 0, 260),
		Position = UDim2.new(0.5, -220, 0.45, -130),
	}):Play()

	spawnConfettiBurst(modalFrame)

	-- Auto-dismiss after 6 seconds
	task.delay(6.0, function()
		if not modalFrame then return end
		local tween = TweenService:Create(modalFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 340, 0, 200),
			Position = UDim2.new(0.5, -170, 0.45, -100),
		})
		tween:Play()
		tween.Completed:Connect(function()
			if modalFrame then
				modalFrame.Visible = false
			end
		end)
	end)
end

return VictoryModal
