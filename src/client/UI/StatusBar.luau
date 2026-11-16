--!strict
-- StatusBar.luau
-- The one place for match status: a small fixed-width card in the bottom-left corner.
--   ROUND 3 · BIDDING        23s
--   YOUR TURN
--   Bid 3 of 9 · ROSE_KING
--   ▬▬▬▬▬▬▬▬▬▬▬▬▬ (turn timer)
-- Fixed width so it never shifts as the text changes. Bottom-left because the top of the
-- screen belongs to the other players' 3D name tags (far, left and right seats), and the
-- bottom centre / right hold the hand and the action panel.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)

local StatusBar = {}

export type Status = {
	phaseText: string, -- "ROUND 3 · BIDDING"
	turnText: string, -- "YOUR TURN" / "ROSE_KING" / "" when nobody is on the clock
	isMyTurn: boolean,
	infoText: string?, -- "Bid 3 of 9 · ROSE_KING" / "Flips 1 of 3" / waiting messages
}

local root: Frame? = nil
local phaseLabel: TextLabel? = nil
local turnLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil
local infoLabel: TextLabel? = nil
local cardStroke: UIStroke? = nil
local timerTrack: Frame? = nil
local timerFill: Frame? = nil
local timerThread: thread? = nil
local myTurnCached = false

local WIDTH = 280
local TIMER_WIDTH = 44

local function makeLabel(parent: Instance, name: string, order: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = ""
	label.Parent = parent
	return label
end

function StatusBar.Create(parent: Instance)
	local card = Instance.new("Frame")
	card.Name = "StatusBar"
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.new(0, 16, 1, -16)
	card.Size = UDim2.fromOffset(WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Theme.Colors.Backing
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Visible = false
	card.ZIndex = 20
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = Theme.CornerRadius.Medium

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.PanelBorder
	stroke.Thickness = 1.5
	stroke.Parent = card

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card

	-- Line 1: phase, with the timer pinned to the right (fixed width, so digits don't shift it)
	local phase = makeLabel(card, "Phase", 1, Theme.Fonts.Title, Theme.TextSize.Body, Theme.Colors.TextGold)
	phase.Size = UDim2.new(1, -TIMER_WIDTH, 0, Theme.TextSize.Body + 4)
	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.new(1, TIMER_WIDTH, 0, 0)
	timer.Size = UDim2.new(0, TIMER_WIDTH, 1, 0)
	timer.BackgroundTransparency = 1
	timer.Font = Theme.Fonts.Title
	timer.TextSize = Theme.TextSize.Label
	timer.TextColor3 = Theme.Colors.TextSecondary
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Text = ""
	timer.Visible = false
	timer.Parent = phase

	-- Line 2: whose turn. Line 3: context
	local turn = makeLabel(card, "Turn", 2, Theme.Fonts.Header, Theme.TextSize.Label, Theme.Colors.TextPrimary)
	local info = makeLabel(card, "Info", 3, Theme.Fonts.Body, Theme.TextSize.Small, Theme.Colors.TextSecondary)
	info.Size = UDim2.fromScale(1, 0) -- longer waiting messages wrap onto a second line
	info.AutomaticSize = Enum.AutomaticSize.Y
	info.TextWrapped = true
	info.TextTruncate = Enum.TextTruncate.None

	-- Line 4: timer drain bar
	local track = Instance.new("Frame")
	track.Name = "TimerTrack"
	track.LayoutOrder = 4
	track.Size = UDim2.new(1, 0, 0, 4)
	track.BackgroundColor3 = Theme.Colors.PanelBorder
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = card
	Instance.new("UICorner", track).CornerRadius = Theme.CornerRadius.Circular
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.Colors.TimerBar
	fill.BorderSizePixel = 0
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = Theme.CornerRadius.Circular

	root = card
	phaseLabel = phase
	turnLabel = turn
	timerLabel = timer
	infoLabel = info
	cardStroke = stroke
	timerTrack = track
	timerFill = fill
end

function StatusBar.Update(status: Status)
	local card, phase, turn, info, stroke = root, phaseLabel, turnLabel, infoLabel, cardStroke
	if not card or not phase or not turn or not info or not stroke then
		return
	end
	card.Visible = true
	phase.Text = status.phaseText
	turn.Text = if status.isMyTurn or status.turnText == "" then status.turnText else (status.turnText .. "'s turn")
	turn.TextColor3 = if status.isMyTurn then Theme.Colors.TextGold else Theme.Colors.TextPrimary
	turn.Visible = status.turnText ~= ""
	stroke.Color = if status.isMyTurn then Theme.Colors.Gold else Theme.Colors.PanelBorder
	stroke.Thickness = if status.isMyTurn then 2 else 1.5
	info.Text = status.infoText or ""
	info.Visible = info.Text ~= ""
	myTurnCached = status.isMyTurn
end

function StatusBar.Hide()
	StatusBar.StopTimer()
	if root then
		root.Visible = false
	end
end

function StatusBar.StopTimer()
	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end
	if timerLabel then
		timerLabel.Text = ""
		timerLabel.Visible = false
	end
	if timerTrack then
		timerTrack.Visible = false
	end
end

function StatusBar.StartTimer(seconds: number)
	StatusBar.StopTimer()
	local label, track, fill = timerLabel, timerTrack, timerFill
	if not label or not track or not fill then
		return
	end
	track.Visible = true
	label.Visible = true
	local started = os.clock()
	timerThread = task.spawn(function()
		while true do
			local left = math.max(0, seconds - (os.clock() - started))
			local urgent = left <= 5
			label.Text = string.format("%ds", math.ceil(left))
			label.TextColor3 = if urgent then Theme.Colors.AlertRed
				elseif myTurnCached then Theme.Colors.TextGold
				else Theme.Colors.TextSecondary
			fill.Size = UDim2.fromScale(left / seconds, 1)
			fill.BackgroundColor3 = if urgent then Theme.Colors.AlertRed else Theme.Colors.TimerBar
			if left <= 0 then
				break
			end
			task.wait(0.1)
		end
		timerThread = nil
	end)
end

return StatusBar
