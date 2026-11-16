--!strict
-- DiscardModal.luau
-- Skull penalty picker shown to whoever chooses the challenger's lost card.
--   Own skull:    the challenger sees their own cards face-up and picks one to lose.
--   Other skull:  the skull owner sees N face-down cards and removes one blindly.
-- The server decides who sees what; this module only renders the payload it is given.
-- Built on UIKit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Theme = require(ReplicatedStorage.Shared.Theme)
local UIKit = require(script.Parent.UIKit)

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
local shownKey = "" -- what the open picker shows, so state re-syncs don't rebuild it
local isOpen = false

local CARD_SIZE, CARD_GAP = 76, 12

function DiscardModal.Create(parent: Instance, onPick: (pick: { [string]: any }) -> ()): Frame
	pickCallback = onPick

	local frame = UIKit.Panel(parent, { name = "DiscardModal", width = 380, zIndex = 60, accent = Theme.Colors.AlertRed })
	local title = UIKit.Label(frame, { name = "Title", style = "title", order = 1, text = "SKULL PENALTY" })
	local subtitle = UIKit.Label(frame, { name = "Subtitle", style = "body", order = 2 })
	local row = UIKit.Row(frame, 3, CARD_SIZE + 8, CARD_GAP)
	row.Name = "CardRow"

	root = frame
	titleLabel = title
	subtitleLabel = subtitle
	cardRow = row
	return frame
end

-- A round card: its face for your own cards, its back for a blind pick
local function makeCardButton(row: Frame, order: number, cardType: string?, setId: string?): ImageButton
	local faceUp = cardType ~= nil
	local isSkull = cardType == Enums.CardType.Skull

	local button = Instance.new("ImageButton")
	button.Name = "DiscardCard" .. order
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(CARD_SIZE, CARD_SIZE)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = true
	button.Image = if faceUp then CardArt.Face(setId, cardType) else CardArt.Back(setId)
	button.ScaleType = Enum.ScaleType.Fit
	button.Parent = row
	Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = if not faceUp then Theme.Colors.CardBorder
		elseif isSkull then Theme.Colors.SkullAccent
		else Theme.Colors.RoseAccent
	stroke.Thickness = 2
	stroke.Parent = button

	-- Lift slightly on hover so it's clear what you're about to pick
	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.MouseEnter:Connect(function()
		scale.Scale = 1.08
		stroke.Color = Theme.Colors.GoldGlow
	end)
	button.MouseLeave:Connect(function()
		scale.Scale = 1
		stroke.Color = if not faceUp then Theme.Colors.CardBorder
			elseif isSkull then Theme.Colors.SkullAccent
			else Theme.Colors.RoseAccent
	end)
	return button
end

-- Show the picker. `victimName` is the challenger who loses the card; `setId` their art set.
function DiscardModal.Show(info: DiscardInfo, victimName: string, setId: string?)
	local frame, row, title, subtitle = root, cardRow, titleLabel, subtitleLabel
	if not frame or not row or not title or not subtitle then
		return
	end

	local cards = info.cards
	local ownPick = info.isOwnSkull and cards ~= nil
	local key = (if ownPick and cards then table.concat(cards, ",") else tostring(info.cardCount))
		.. "|" .. tostring(info.victimId) .. "|" .. tostring(setId)
	if isOpen and key == shownKey then
		return -- same picker already open (state re-sync)
	end
	shownKey = key

	hasPicked = false
	for _, child in ipairs(row:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	local function pick(payload: { [string]: any })
		if hasPicked or not pickCallback then
			return
		end
		hasPicked = true
		pickCallback(payload)
	end

	if ownPick and cards then
		title.Text = "YOU HIT YOUR OWN SKULL"
		subtitle.Text = "Choose one of your cards to lose for good."
		for i, cardType in ipairs(cards) do
			makeCardButton(row, i, cardType, setId).Activated:Connect(function()
				pick({ cardType = cardType })
			end)
		end
	else
		title.Text = "REMOVE A CARD"
		subtitle.Text = "Pick one of " .. victimName .. "'s cards, face-down. Nobody sees what it was."
		for i = 1, math.max(1, info.cardCount) do
			makeCardButton(row, i, nil, setId).Activated:Connect(function()
				pick({ index = i })
			end)
		end
	end

	if not isOpen then
		isOpen = true
		UIKit.Pop(frame, true)
	end
end

function DiscardModal.Hide()
	shownKey = ""
	if root and isOpen then
		isOpen = false
		UIKit.Pop(root, false)
	end
end

-- Re-enable picking after the server rejected a pick
function DiscardModal.Reset()
	hasPicked = false
end

return DiscardModal
