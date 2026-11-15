--!strict
-- DiscardModal.luau
-- Skull penalty picker shown to whoever chooses the challenger's lost card.
--   Own skull:    the challenger sees their own cards face-up and picks one to lose.
--   Other skull:  the skull owner sees N face-down cards and removes one blindly.
-- The server decides who sees what; this module only renders the payload it is given.

local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)
local Theme = require(script.Parent.Theme)

local DiscardModal = {}

export type DiscardInfo = {
	chooserId: number,
	victimId: number,
	isOwnSkull: boolean,
	cardCount: number,
	cards: { string }?,
}

local root: Frame? = nil
local titleLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local cardRow: Frame? = nil
local pickCallback: ((pick: { [string]: any }) -> ())? = nil
local hasPicked = false

local CARD_W, CARD_H, CARD_GAP = 72, 102, 12

function DiscardModal.Create(parent: Instance, onPick: (pick: { [string]: any }) -> ()): Frame
	pickCallback = onPick

	local frame = Instance.new("Frame")
	frame.Name = "DiscardModal"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.fromOffset(360, 210)
	frame.BackgroundColor3 = Theme.Colors.PanelBackground
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 60
	frame.Parent = parent

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(360, 210)
	sizeLimit.Parent = frame

	Instance.new("UICorner", frame).CornerRadius = Theme.CornerRadius.Large
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.AlertRed
	stroke.Thickness = 2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 10)
	title.Size = UDim2.new(1, -24, 0, 26)
	title.Font = Theme.Fonts.Title
	title.TextSize = 20
	title.TextColor3 = Theme.Colors.TextGold
	title.Text = "SKULL PENALTY"
	title.ZIndex = 61
	title.Parent = frame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(12, 38)
	subtitle.Size = UDim2.new(1, -24, 0, 34)
	subtitle.Font = Theme.Fonts.Body
	subtitle.TextSize = 14
	subtitle.TextWrapped = true
	subtitle.TextColor3 = Theme.Colors.TextSecondary
	subtitle.Text = ""
	subtitle.ZIndex = 61
	subtitle.Parent = frame

	local row = Instance.new("Frame")
	row.Name = "CardRow"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 86)
	row.Size = UDim2.new(1, -24, 0, CARD_H)
	row.ZIndex = 61
	row.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, CARD_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	root = frame
	titleLabel = title
	subtitleLabel = subtitle
	cardRow = row
	return frame
end

local function makeCardButton(row: Frame, order: number, cardType: string?): TextButton
	local isSkull = cardType == Enums.CardType.Skull
	local faceUp = cardType ~= nil

	local button = Instance.new("TextButton")
	button.Name = "DiscardCard" .. order
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(CARD_W, CARD_H)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = Theme.Fonts.Title
	button.TextSize = faceUp and 34 or 30
	button.ZIndex = 62
	if not faceUp then
		button.BackgroundColor3 = Theme.Colors.CardBack
		button.TextColor3 = Theme.Colors.Gold
		button.Text = "?"
	elseif isSkull then
		button.BackgroundColor3 = Theme.Colors.SkullPrimary
		button.TextColor3 = Theme.Colors.SkullAccent
		button.Text = "💀"
	else
		button.BackgroundColor3 = Theme.Colors.RosePrimary
		button.TextColor3 = Theme.Colors.TextPrimary
		button.Text = "🌹"
	end
	button.Parent = row

	Instance.new("UICorner", button).CornerRadius = Theme.CornerRadius.Medium
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = faceUp and (isSkull and Theme.Colors.SkullAccent or Theme.Colors.RoseAccent) or Theme.Colors.CardBorder
	stroke.Thickness = 2
	stroke.Parent = button

	return button
end

-- Show the picker. `victimName` is the challenger who loses the card.
function DiscardModal.Show(info: DiscardInfo, victimName: string)
	local frame, row, title, subtitle = root, cardRow, titleLabel, subtitleLabel
	if not frame or not row or not title or not subtitle then return end

	hasPicked = false
	for _, child in ipairs(row:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	local cards = info.cards
	if info.isOwnSkull and cards then
		title.Text = "YOU HIT YOUR OWN SKULL"
		subtitle.Text = "Choose one of your cards to lose for good."
		for i, cardType in ipairs(cards) do
			local button = makeCardButton(row, i, cardType)
			button.Activated:Connect(function()
				if hasPicked or not pickCallback then return end
				hasPicked = true
				pickCallback({ cardType = cardType })
			end)
		end
	else
		title.Text = "REMOVE A CARD"
		subtitle.Text = "Pick one of " .. victimName .. "'s cards, face-down. Nobody sees what it was."
		for i = 1, math.max(1, info.cardCount) do
			local button = makeCardButton(row, i, nil)
			button.Activated:Connect(function()
				if hasPicked or not pickCallback then return end
				hasPicked = true
				pickCallback({ index = i })
			end)
		end
	end

	frame.Visible = true
end

function DiscardModal.Hide()
	if root then
		root.Visible = false
	end
end

-- Re-enable picking after the server rejected a pick
function DiscardModal.Reset()
	hasPicked = false
end

return DiscardModal
