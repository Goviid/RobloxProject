--!strict
-- NotificationBanner.luau
-- Clean, minimalist floating game status text without bulky black boxes (LOCOfficial style)
-- Displays slightly big, semi-transparent status announcements that gently fade

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local NotificationBanner = {}
local bannerFrame: Frame? = nil
local messageLabel: TextLabel? = nil
local timerTrack: Frame? = nil
local timerBar: Frame? = nil
local timerTween: Tween? = nil
local fadeThread: thread? = nil

-- ============================================================================
-- 1. CREATION & SETUP (Clean floating text, NO black box!)
-- ============================================================================
function NotificationBanner.Create(parent: GuiObject): Frame
	-- Invisible container pinned to top center of screen
	local container = Instance.new("Frame")
	container.Name = "NotificationBanner"
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Size = UDim2.new(0, 580, 0, 48)
	container.Position = UDim2.new(0.5, 0, 0, 20)
	container.BackgroundTransparency = 1 -- Zero black box!
	container.BorderSizePixel = 0
	container.ZIndex = 30
	container.Parent = parent

	-- Slightly big, clean display text (semi-transparent)
	local label = Instance.new("TextLabel")
	label.Name = "MessageLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Title
	label.TextSize = 21
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextTransparency = 0.15 -- Somewhat transparent, pleasant and non-annoying
	label.TextStrokeTransparency = 0.55
	label.TextStrokeColor3 = Color3.fromRGB(15, 35, 65)
	label.TextWrapped = true
	label.Text = "Welcome to Skulls & Roses"
	label.ZIndex = 31
	label.Parent = container

	-- Sleek, thin semi-transparent timer bar (pinned directly below text)
	local track = Instance.new("Frame")
	track.Name = "TimerTrack"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Size = UDim2.new(0, 220, 0, 3)
	track.Position = UDim2.new(0.5, 0, 1, 4)
	track.BackgroundColor3 = Color3.fromRGB(15, 35, 65)
	track.BackgroundTransparency = 0.7
	track.BorderSizePixel = 0
	track.ZIndex = 31
	track.Visible = false
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "TimerFill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 215, 75)
	fill.BackgroundTransparency = 0.2
	fill.BorderSizePixel = 0
	fill.ZIndex = 32
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	bannerFrame = container
	messageLabel = label
	timerTrack = track
	timerBar = fill

	return container
end

-- ============================================================================
-- 2. DISPLAY STATUS ANNOUNCEMENT
-- ============================================================================
function NotificationBanner.Show(text: string, style: string?)
	if not messageLabel or not bannerFrame then return end

	local colorsByStyle = {
		info = Color3.fromRGB(245, 250, 255),
		success = Color3.fromRGB(255, 225, 80),
		warning = Color3.fromRGB(255, 185, 45),
		alert = Color3.fromRGB(255, 75, 75),
	}

	local textColor = colorsByStyle[style or "info"] or Color3.fromRGB(245, 250, 255)
	messageLabel.Text = text
	messageLabel.TextColor3 = textColor
	messageLabel.TextTransparency = 0.10

	-- Soft subtle scale bounce
	messageLabel.TextSize = 23
	TweenService:Create(messageLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextSize = 21,
	}):Play()

	-- Gentle auto-fade so it stays clean and non-annoying
	if fadeThread then
		task.cancel(fadeThread)
		fadeThread = nil
	end

	fadeThread = task.delay(3.5, function()
		if not messageLabel then return end
		TweenService:Create(messageLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0.55,
		}):Play()
	end)
end

-- ============================================================================
-- 3. TURN TIMER ANIMATION
-- ============================================================================
function NotificationBanner.StartTimer(durationSeconds: number)
	if not timerBar or not timerTrack then return end

	if timerTween then
		timerTween:Cancel()
	end

	timerTrack.Visible = true
	timerBar.Size = UDim2.new(1, 0, 1, 0)
	timerBar.BackgroundColor3 = Color3.fromRGB(255, 215, 75)

	timerTween = TweenService:Create(timerBar, TweenInfo.new(durationSeconds, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 70, 70),
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
	if timerTrack then
		timerTrack.Visible = false
	end
end

return NotificationBanner
