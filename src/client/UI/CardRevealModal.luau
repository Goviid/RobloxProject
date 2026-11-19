--!strict
-- CardRevealModal.luau
-- Centre-screen reveal: the flipped card's face in its owner's art set, flipping in
-- like a coin, with who it came from and the challenge progress. Built on UIKit.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Theme = require(ReplicatedStorage.Shared.Theme)
local UIKit = require(script.Parent.UIKit)

local CardRevealModal = {}

local CARD_SIZE = 150
local SHOW_SECONDS = 2.2

local panel: Frame? = nil
local cardFace: ImageLabel? = nil
local cardStroke: UIStroke? = nil
local typeLabel: TextLabel? = nil
local sourceLabel: TextLabel? = nil
local showToken = 0

function CardRevealModal.Create(parent: Instance): Frame
	local frame = UIKit.Panel(parent, { name = "CardRevealModal", width = 280, zIndex = 50, gap = 8 })
	frame.Position = UDim2.fromScale(0.5, 0.42)

	-- "ROSE REVEALED" / "SKULL!"
	local typeText = UIKit.Label(frame, { name = "TypeLabel", style = "title", order = 1 })

	-- Fixed-size holder so the coin-flip squash doesn't move the layout
	local holder = Instance.new("Frame")
	holder.Name = "CardHolder"
	holder.LayoutOrder = 2
	holder.Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE)
	holder.BackgroundTransparency = 1
	holder.Parent = frame

	local face = Instance.new("ImageLabel")
	face.Name = "CardFace"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE)
	face.BackgroundTransparency = 1
	face.ScaleType = Enum.ScaleType.Fit
	face.Parent = holder
	Instance.new("UICorner", face).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Name = "CardStroke"
	stroke.Color = Theme.Colors.Gold
	stroke.Thickness = 3
	stroke.Parent = face

	-- Whose pile it came from, and challenge progress
	local source = UIKit.Label(frame, { name = "SourceLabel", style = "body", order = 3 })

	panel = frame
	cardFace = face
	cardStroke = stroke
	typeLabel = typeText
	sourceLabel = source
	return frame
end

-- `setId`: the card owner's CardArt set
function CardRevealModal.ShowCard(cardType: string, playerName: string, flippedCount: number, targetCount: number, setId: string?)
	local frame, face, stroke, typeText, source = panel, cardFace, cardStroke, typeLabel, sourceLabel
	if not frame or not face or not stroke or not typeText or not source then
		return
	end
	showToken += 1
	local token = showToken

	local isSkull = cardType == Enums.CardType.Skull
	local accent = if isSkull then Theme.Colors.AlertRed else CardArt.Get(setId).accent
	typeText.Text = if isSkull then "SKULL!" else "ROSE REVEALED"
	typeText.TextColor3 = if isSkull then Theme.Colors.AlertRed else Theme.Colors.TextGold
	source.Text = playerName .. "'s pile  ·  flip " .. flippedCount .. " of " .. targetCount
	stroke.Color = accent
	UIKit.SetAccent(frame, if isSkull then Theme.Colors.AlertRed else Theme.Colors.Gold)

	UIKit.Pop(frame, true)

	-- Coin flip: the back narrows to edge-on, the face opens out from edge-on
	face.Image = CardArt.Back(setId)
	face.Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE)
	local close = TweenService:Create(face, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(0, CARD_SIZE),
	})
	close.Completed:Connect(function()
		if token ~= showToken then
			return
		end
		face.Image = CardArt.Face(setId, cardType)
		TweenService:Create(face, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE),
		}):Play()
	end)
	close:Play()

	task.delay(SHOW_SECONDS, function()
		if token == showToken then
			UIKit.Pop(frame, false)
		end
	end)
end

return CardRevealModal
