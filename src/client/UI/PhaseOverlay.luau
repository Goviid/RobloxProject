--!strict
-- PhaseOverlay.luau
-- Two lightweight overlays that frame the flow of a match:
--   * Round intro card ("ROUND 3 · ROSE_KING starts") shown briefly when a round begins
--   * Spectating pill shown while the local player is eliminated

local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)

local PhaseOverlay = {}

local roundCard: Frame? = nil
local roundTitle: TextLabel? = nil
local roundSubtitle: TextLabel? = nil
local spectatePill: Frame? = nil
local showToken = 0

local ROUND_CARD_SECONDS = 2.2

function PhaseOverlay.Create(parent: Instance)
	-- Round intro card
	local card = Instance.new("Frame")
	card.Name = "RoundIntroCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.36)
	card.Size = UDim2.fromOffset(320, 92)
	card.BackgroundColor3 = Theme.Colors.PanelBackground
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Visible = false
	card.ZIndex = 55
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = Theme.CornerRadius.Large

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Gold
	stroke.Thickness = 2
	stroke.Parent = card

	local scale = Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Parent = card

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Font = Theme.Fonts.Title
	title.TextSize = 34
	title.TextColor3 = Theme.Colors.TextGold
	title.Text = "ROUND 1"
	title.ZIndex = 56
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(12, 52)
	subtitle.Size = UDim2.new(1, -24, 0, 28)
	subtitle.Font = Theme.Fonts.Body
	subtitle.TextSize = 16
	subtitle.TextColor3 = Theme.Colors.TextSecondary
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle.Text = ""
	subtitle.ZIndex = 56
	subtitle.Parent = card

	-- Spectating pill (top-center, below the notification banner)
	local pill = Instance.new("Frame")
	pill.Name = "SpectatingPill"
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Position = UDim2.new(0.5, 0, 1, -24)
	pill.Size = UDim2.fromOffset(300, 40)
	pill.BackgroundColor3 = Theme.Colors.PanelBackground
	pill.BackgroundTransparency = 0.15
	pill.BorderSizePixel = 0
	pill.Visible = false
	pill.ZIndex = 40
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = Theme.CornerRadius.Circular

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = Theme.Colors.AlertRed
	pillStroke.Thickness = 1.5
	pillStroke.Parent = pill

	local pillText = Instance.new("TextLabel")
	pillText.BackgroundTransparency = 1
	pillText.Size = UDim2.fromScale(1, 1)
	pillText.Font = Theme.Fonts.Header
	pillText.TextSize = 15
	pillText.TextColor3 = Theme.Colors.TextPrimary
	pillText.Text = ""
	pillText.ZIndex = 41
	pillText.Parent = pill

	roundCard = card
	roundTitle = title
	roundSubtitle = subtitle
	spectatePill = pill
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

	local scale = card:FindFirstChild("PopScale") :: UIScale?
	card.Visible = true
	if scale then
		scale.Scale = 0.6
		TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	task.delay(ROUND_CARD_SECONDS, function()
		if showToken ~= token then
			return
		end
		if scale then
			local out = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 })
			out:Play()
			out.Completed:Wait()
		end
		if showToken == token then
			card.Visible = false
		end
	end)
end

-- Show a status pill while not playing (eliminated, or waiting for a seat); nil hides it
function PhaseOverlay.SetSpectating(message: string?)
	local pill = spectatePill
	if not pill then
		return
	end
	pill.Visible = message ~= nil
	local label = pill:FindFirstChildWhichIsA("TextLabel")
	if label and message then
		label.Text = message
	end
end

return PhaseOverlay
