--!strict
-- CardAnimation.luau
-- Flying card transitions from player hand onto table coaster (LOCOfficial style)

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local CardArt = require(game:GetService("ReplicatedStorage").Shared.CardArt)

local CardAnimation = {}

-- Fly a card from the hand dock into the center table stack
function CardAnimation.PlayCardFly(parentGui: Instance, startPos: UDim2, endPos: UDim2, cardType: string, setId: string?)

	-- Temp flying card element
	local flying = Instance.new("Frame")
	flying.Name = "FlyingCard"
	flying.Size = UDim2.fromOffset(72, 72)
	flying.Position = startPos
	flying.AnchorPoint = Vector2.new(0.5, 0.5)
	flying.BackgroundTransparency = 1
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

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Image = CardArt.Face(setId, cardType)
	icon.ZIndex = 51
	icon.Parent = flying
	Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

	-- Arc trajectory tween
	local tween = TweenService:Create(flying, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = endPos,
		Size = UDim2.fromOffset(48, 48),
		Rotation = math.random(-25, 25),
	})
	tween:Play()

	tween.Completed:Connect(function()
		task.wait(0.1)
		flying:Destroy()
	end)
end

return CardAnimation

