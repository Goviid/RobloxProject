--!strict
-- CardAnimation.luau
-- Flying card transitions from player hand onto table coaster (LOCOfficial style)

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local CardAnimation = {}

-- Fly a card from the hand dock into the center table stack
function CardAnimation.PlayCardFly(parentGui: Instance, startPos: UDim2, endPos: UDim2, cardType: string)
	local isRose = (cardType == Enums.CardType.Rose)

	-- Temp flying card element
	local flying = Instance.new("Frame")
	flying.Name = "FlyingCard"
	flying.Size = UDim2.new(0, 72, 0, 72)
	flying.Position = startPos
	flying.AnchorPoint = Vector2.new(0.5, 0.5)
	flying.BackgroundColor3 = isRose and Theme.Colors.RosePrimary or Theme.Colors.SkullPrimary
	flying.BorderSizePixel = 0
	flying.ZIndex = 50
	flying.Parent = parentGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Circular
	corner.Parent = flying

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.GoldGlow
	stroke.Thickness = 2.5
	stroke.Parent = flying

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Font = Theme.Fonts.Title
	icon.TextSize = 32
	icon.Text = isRose and "🌹" or "💀"
	icon.Parent = flying

	-- Arc trajectory tween
	local tween = TweenService:Create(flying, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = endPos,
		Size = UDim2.new(0, 48, 0, 48),
		Rotation = math.random(-25, 25),
	})
	tween:Play()

	tween.Completed:Connect(function()
		task.wait(0.1)
		flying:Destroy()
	end)
end

return CardAnimation

