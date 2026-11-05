--!strict
-- NotificationBanner.luau
-- Top screen announcement banner and turn timer progress bar

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local NotificationBanner = {}
local bannerFrame: Frame? = nil
local messageLabel: TextLabel? = nil
local timerBar: Frame? = nil
local timerTween: Tween? = nil

-- ============================================================================
-- 1. CREATION & SETUP
-- ============================================================================
function NotificationBanner.Create(parent: GuiObject): Frame
	-- Container frame pinned to top center of screen
	local container = Instance.new("Frame")
	container.Name = "NotificationBanner"
	container.Size = UDim2.new(0, 480, 0, 56)
	container.Position = UDim2.new(0.5, -240, 0, 16)
	container.BackgroundColor3 = Theme.Colors.PanelBackground
	container.BackgroundTransparency = 0.15
	container.BorderSizePixel = 0
	container.Parent = parent

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerRadius.Medium
	corner.Parent = container

	-- Ornate gold border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.GoldMuted
	stroke.Thickness = 1.5
	stroke.Parent = container

	-- Announcement text label
	local label = Instance.new("TextLabel")
	label.Name = "MessageLabel"
	label.Size = UDim2.new(1, -24, 1, -12)
	label.Position = UDim2.new(0, 12, 0, 4)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Header
	label.TextSize = 14
	label.TextColor3 = Theme.Colors.TextPrimary
	label.TextWrapped = true
	label.Text = "Welcome to Skulls & Roses"
	label.Parent = container

	-- Timer bar container (bottom line of the banner)
	local timerTrack = Instance.new("Frame")
	timerTrack.Name = "TimerTrack"
	timerTrack.Size = UDim2.new(1, -8, 0, 4)
	timerTrack.Position = UDim2.new(0, 4, 1, -6)
	timerTrack.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	timerTrack.BackgroundTransparency = 0.5
	timerTrack.BorderSizePixel = 0
	timerTrack.Parent = container

	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.new(1, 0, 1, 0)
	timerFill.BackgroundColor3 = Theme.Colors.TimerBar
	timerFill.BorderSizePixel = 0
	timerFill.Parent = timerTrack

	local timerFillCorner = Instance.new("UICorner")
	timerFillCorner.CornerRadius = UDim.new(1, 0)
	timerFillCorner.Parent = timerFill

	bannerFrame = container
	messageLabel = label
	timerBar = timerFill

	return container
end

-- ============================================================================
-- 2. PUBLIC API: DISPLAY NOTIFICATIONS
-- ============================================================================
function NotificationBanner.Show(text: string, style: string?)
	if not messageLabel or not bannerFrame then return end

	local colorsByStyle = {
		info = Theme.Colors.TextPrimary,
		success = Theme.Colors.SuccessGreen,
		warning = Theme.Colors.WarningAmber,
		alert = Theme.Colors.AlertRed,
	}

	local textColor = colorsByStyle[style or "info"] or Theme.Colors.TextPrimary
	messageLabel.Text = text
	messageLabel.TextColor3 = textColor

	-- Quick bounce scale effect on text update
	bannerFrame.Size = UDim2.new(0, 490, 0, 58)
	bannerFrame.Position = UDim2.new(0.5, -245, 0, 15)

	local tween = TweenService:Create(bannerFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 480, 0, 56),
		Position = UDim2.new(0.5, -240, 0, 16),
	})
	tween:Play()
end

-- ============================================================================
-- 3. PUBLIC API: TURN TIMER ANIMATION
-- ============================================================================
function NotificationBanner.StartTimer(durationSeconds: number)
	if not timerBar then return end

	if timerTween then
		timerTween:Cancel()
	end

	-- Reset bar to 100% full
	timerBar.Size = UDim2.new(1, 0, 1, 0)
	timerBar.BackgroundColor3 = Theme.Colors.TimerBar

	-- Smoothly deplete bar to 0% over turn duration with color transition to AlertRed
	timerTween = TweenService:Create(timerBar, TweenInfo.new(durationSeconds, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Colors.AlertRed,
	})
	timerTween:Play()
end

function NotificationBanner.StopTimer()
	if timerTween then
		timerTween:Cancel()
		timerTween = nil
	end
	if timerBar then
		timerBar.Size = UDim2.new(0, 0, 1, 0)
	end
end

return NotificationBanner

