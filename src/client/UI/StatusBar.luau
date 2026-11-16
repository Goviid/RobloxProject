--!strict
-- StatusBar.luau
-- The one place for match status: a single pill in the top-right corner
-- (the top centre is left clear for the far player's 3D name tag).
--   ROUND 3 · BIDDING  |  YOUR TURN  23s  |  Bid 3 of 9 on table
-- A thin bar under the pill drains with the turn timer (the only timer on screen).

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)

local StatusBar = {}

export type Status = {
	phaseText: string, -- "ROUND 3 · BIDDING"
	turnText: string, -- "YOUR TURN" / "ROSE_KING"
	isMyTurn: boolean,
	infoText: string?, -- "Bid 3 of 9 on table" / "Flips 1 of 3" / waiting messages
}

local root: Frame? = nil
local phaseLabel: TextLabel? = nil
local turnLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil
local infoLabel: TextLabel? = nil
local infoDivider: Frame? = nil
local pillStroke: UIStroke? = nil
local timerFill: Frame? = nil
local timerThread: thread? = nil
local myTurnCached = false

local HEIGHT = 40

local function makeLabel(parent: Instance, name: string, order: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, HEIGHT)
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = Theme.TextSize.Body
	label.TextColor3 = color
	label.Text = ""
	label.Parent = parent
	return label
end

local function makeDivider(parent: Instance, order: number): Frame
	local divider = Instance.new("Frame")
	divider.Name = "Divider" .. order
	divider.LayoutOrder = order
	divider.Size = UDim2.fromOffset(1, 20)
	divider.BackgroundColor3 = Theme.Colors.PanelBorder
	divider.BorderSizePixel = 0
	divider.Parent = parent
	return divider
end

function StatusBar.Create(parent: Instance)
	-- Wrapper holds the pill (which sizes to its text) and the timer bar under it
	local wrapper = Instance.new("Frame")
	wrapper.Name = "StatusBar"
	wrapper.AnchorPoint = Vector2.new(1, 0)
	wrapper.Position = UDim2.new(1, -16, 0, 8)
	wrapper.AutomaticSize = Enum.AutomaticSize.X
	wrapper.Size = UDim2.fromOffset(0, HEIGHT + 6)
	wrapper.BackgroundTransparency = 1
	wrapper.Visible = false
	wrapper.ZIndex = 20
	wrapper.Parent = parent

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, HEIGHT)
	pill.BackgroundColor3 = Theme.Colors.Backing
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	pill.ZIndex = 20
	pill.Parent = wrapper
	Instance.new("UICorner", pill).CornerRadius = Theme.CornerRadius.Circular

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.PanelBorder
	stroke.Thickness = 1.5
	stroke.Parent = pill

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill

	phaseLabel = makeLabel(pill, "Phase", 1, Theme.Fonts.Title, Theme.Colors.TextGold)
	makeDivider(pill, 2)
	turnLabel = makeLabel(pill, "Turn", 3, Theme.Fonts.Header, Theme.Colors.TextPrimary)
	timerLabel = makeLabel(pill, "Timer", 4, Theme.Fonts.Header, Theme.Colors.TextSecondary)
	infoDivider = makeDivider(pill, 5)
	infoLabel = makeLabel(pill, "Info", 6, Theme.Fonts.Body, Theme.Colors.TextSecondary)

	-- Timer drain bar under the pill
	local track = Instance.new("Frame")
	track.Name = "TimerTrack"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, HEIGHT + 3)
	track.Size = UDim2.new(1, -36, 0, 3)
	track.BackgroundColor3 = Theme.Colors.PanelBorder
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = wrapper
	Instance.new("UICorner", track).CornerRadius = Theme.CornerRadius.Circular
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.Colors.TimerBar
	fill.BorderSizePixel = 0
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = Theme.CornerRadius.Circular

	root = wrapper
	pillStroke = stroke
	timerFill = fill
end

function StatusBar.Update(status: Status)
	local pill, phase, turn, info, divider, stroke = root, phaseLabel, turnLabel, infoLabel, infoDivider, pillStroke
	if not pill or not phase or not turn or not info or not divider or not stroke then
		return
	end
	pill.Visible = true
	phase.Text = status.phaseText
	turn.Text = status.turnText
	turn.TextColor3 = if status.isMyTurn then Theme.Colors.TextGold else Theme.Colors.TextPrimary
	stroke.Color = if status.isMyTurn then Theme.Colors.Gold else Theme.Colors.PanelBorder
	stroke.Thickness = if status.isMyTurn then 2 else 1.5
	info.Text = status.infoText or ""
	info.Visible = status.infoText ~= nil and status.infoText ~= ""
	divider.Visible = info.Visible
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
	local track = timerFill and timerFill.Parent
	if track and track:IsA("Frame") then
		track.Visible = false
	end
end

function StatusBar.StartTimer(seconds: number)
	StatusBar.StopTimer()
	local label, fill = timerLabel, timerFill
	if not label or not fill then
		return
	end
	local track = fill.Parent
	if track and track:IsA("Frame") then
		track.Visible = true
	end
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
