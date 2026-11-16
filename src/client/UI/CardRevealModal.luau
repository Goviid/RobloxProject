--!strict
-- CardRevealModal.luau
-- Centre-screen reveal: the flipped card's face in its owner's art set, flipping in
-- like a coin, with who it came from and the challenge progress.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Theme = require(script.Parent.Theme)

local CardRevealModal = {}

local CARD_SIZE = 180

local modalContainer: Frame? = nil
local cardFace: ImageLabel? = nil
local cardStroke: UIStroke? = nil
local typeLabel: TextLabel? = nil
local sourceLabel: TextLabel? = nil
local showToken = 0

function CardRevealModal.Create(parent: Instance): Frame
	local container = Instance.new("Frame")
	container.Name = "CardRevealModal"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Size = UDim2.fromOffset(260, 260)
	container.Position = UDim2.fromScale(0.5, 0.44)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Visible = false
	container.ZIndex = 50
	container.Parent = parent

	-- Whose pile it came from, and challenge progress
	local source = Instance.new("TextLabel")
	source.Name = "SourceLabel"
	source.Size = UDim2.new(1, 0, 0, 24)
	source.BackgroundTransparency = 1
	source.Font = Theme.Fonts.Title
	source.TextSize = 15
	source.TextColor3 = Theme.Colors.TextPrimary
	source.TextStrokeTransparency = 0.4
	source.TextStrokeColor3 = Theme.Colors.PanelBackground
	source.Text = ""
	source.ZIndex = 51
	source.Parent = container

	-- The round card face
	local face = Instance.new("ImageLabel")
	face.Name = "CardFace"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE)
	face.Position = UDim2.new(0.5, 0, 0.5, -4)
	face.BackgroundTransparency = 1
	face.ScaleType = Enum.ScaleType.Fit
	face.ZIndex = 51
	face.Parent = container
	Instance.new("UICorner", face).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Name = "CardStroke"
	stroke.Color = Theme.Colors.Gold
	stroke.Thickness = 3
	stroke.Parent = face

	-- "ROSE REVEALED" / "SKULL REVEALED!"
	local typeText = Instance.new("TextLabel")
	typeText.Name = "TypeLabel"
	typeText.Size = UDim2.new(1, 0, 0, 30)
	typeText.Position = UDim2.new(0, 0, 1, -30)
	typeText.BackgroundTransparency = 1
	typeText.Font = Theme.Fonts.Title
	typeText.TextSize = 22
	typeText.TextStrokeTransparency = 0.35
	typeText.TextStrokeColor3 = Theme.Colors.PanelBackground
	typeText.Text = ""
	typeText.ZIndex = 51
	typeText.Parent = container

	modalContainer = container
	cardFace = face
	cardStroke = stroke
	typeLabel = typeText
	sourceLabel = source
	return container
end

-- `setId`: the card owner's CardArt set
function CardRevealModal.ShowCard(cardType: string, playerName: string, flippedCount: number, targetCount: number, setId: string?)
	local container, face, stroke, typeText, source = modalContainer, cardFace, cardStroke, typeLabel, sourceLabel
	if not container or not face or not stroke or not typeText or not source then
		return
	end
	showToken += 1
	local token = showToken

	local isSkull = cardType == Enums.CardType.Skull
	source.Text = playerName .. "'s pile (" .. flippedCount .. "/" .. targetCount .. ")"
	face.Image = CardArt.Face(setId, cardType)
	stroke.Color = if isSkull then Theme.Colors.AlertRed else CardArt.Get(setId).accent
	typeText.Text = if isSkull then "SKULL REVEALED!" else "ROSE REVEALED"
	typeText.TextColor3 = if isSkull then Theme.Colors.AlertRed else Theme.Colors.TextGold

	container.Visible = true

	-- Coin flip: squash to a sliver, then open up
	face.Size = UDim2.fromOffset(8, CARD_SIZE)
	TweenService:Create(face, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE),
	}):Play()

	task.delay(2.2, function()
		if token ~= showToken then
			return
		end
		local shrink = TweenService:Create(face, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(0, 0),
		})
		shrink:Play()
		shrink.Completed:Connect(function()
			if token == showToken then
				container.Visible = false
			end
		end)
	end)
end

return CardRevealModal
