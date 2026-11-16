--!strict
-- PhaseOverlay.luau
-- Two lightweight overlays that frame the flow of a match:
--   * Round intro card ("ROUND 3 · ROSE_KING starts") shown briefly when a round begins
--   * Spectating pill (bottom centre) shown while the local player isn't playing
-- Built on UIKit.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local UIKit = require(script.Parent.UIKit)

local PhaseOverlay = {}

local roundCard: Frame? = nil
local roundTitle: TextLabel? = nil
local roundSubtitle: TextLabel? = nil
local spectatePill: Frame? = nil
local spectateText: TextLabel? = nil
local showToken = 0

local ROUND_CARD_SECONDS = 2.2

function PhaseOverlay.Create(parent: Instance)
	-- Round intro card
	local card = UIKit.Panel(parent, { name = "RoundIntroCard", width = 320, zIndex = 55, gap = 4 })
	card.Position = UDim2.fromScale(0.5, 0.36)
	local title = UIKit.Label(card, { name = "Title", style = "display", order = 1, text = "ROUND 1" })
	local subtitle = UIKit.Label(card, { name = "Subtitle", style = "body", order = 2 })

	-- Spectating pill, same look as the status strip and toasts
	local pill = Instance.new("Frame")
	pill.Name = "SpectatingPill"
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.new(0.5, 0, 1, -24)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 40)
	pill.BackgroundColor3 = Theme.Colors.Backing
	pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0
	pill.Visible = false
	pill.ZIndex = 40
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = Theme.CornerRadius.Circular

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = Theme.Colors.AlertRed
	pillStroke.Thickness = 1.5
	pillStroke.Parent = pill

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = pill

	local pillText = Instance.new("TextLabel")
	pillText.AutomaticSize = Enum.AutomaticSize.X
	pillText.Size = UDim2.fromScale(0, 1)
	pillText.BackgroundTransparency = 1
	pillText.Font = Theme.Fonts.Header
	pillText.TextSize = Theme.TextSize.Body
	pillText.TextColor3 = Theme.Colors.TextPrimary
	pillText.Text = ""
	pillText.Parent = pill

	roundCard = card
	roundTitle = title
	roundSubtitle = subtitle
	spectatePill = pill
	spectateText = pillText
end

function PhaseOverlay.ShowRound(roundNumber: number, starterName: string, isMe: boolean)
	local card, title, subtitle = roundCard, roundTitle, roundSubtitle
	if not card or not title or not subtitle then
		return
	end
	showToken += 1
	local token = showToken

	title.Text = "ROUND " .. roundNumber
	subtitle.Text = if isMe then "You start. Place a card!" else (starterName .. " starts")
	UIKit.Pop(card, true)

	task.delay(ROUND_CARD_SECONDS, function()
		if showToken == token then
			UIKit.Pop(card, false)
		end
	end)
end

-- Show a status pill while not playing (eliminated, or waiting for a seat); nil hides it
function PhaseOverlay.SetSpectating(message: string?)
	local pill, text = spectatePill, spectateText
	if not pill or not text then
		return
	end
	pill.Visible = message ~= nil
	if message then
		text.Text = message
	end
end

return PhaseOverlay
