--!strict
-- Toast.luau
-- Short event pop-ups just above the hand ("ROSE_KING raised the bid to 4!").
-- One at a time, queued; a backed-up queue plays faster and drops the oldest
-- so it never lags behind the game.

local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)

local Toast = {}

type Item = { text: string, style: string, duration: number }

local root: Frame? = nil
local label: TextLabel? = nil
local stroke: UIStroke? = nil
local queue: { Item } = {}
local running = false

local DEFAULT_SECONDS = 2.5
local MAX_QUEUE = 3

local STYLE_COLORS: { [string]: Color3 } = {
	info = Theme.Colors.PanelBorder,
	warning = Theme.Colors.WarningAmber,
	alert = Theme.Colors.AlertRed,
	success = Theme.Colors.SuccessGreen,
}

function Toast.Create(parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	-- Bottom centre, above the hand (cards top out ~175px up when hovered); the top
	-- of the screen is left clear for the 3D name tags
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -200)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.fromOffset(0, 36)
	frame.BackgroundColor3 = Theme.Colors.Backing
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 45
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = Theme.CornerRadius.Circular

	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = frame

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(560, 36)
	sizeLimit.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromScale(0, 1)
	text.BackgroundTransparency = 1
	text.Font = Theme.Fonts.Header
	text.TextSize = Theme.TextSize.Body
	text.TextColor3 = Theme.Colors.TextPrimary
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.ZIndex = 46
	text.Parent = frame

	local popScale = Instance.new("UIScale")
	popScale.Name = "Pop"
	popScale.Parent = frame

	root = frame
	label = text
	stroke = s
end

local function runQueue()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1)
			local frame, text, s = root, label, stroke
			if not item or not frame or not text or not s then
				break
			end
			text.Text = item.text
			s.Color = STYLE_COLORS[item.style] or STYLE_COLORS.info
			local pop = frame:FindFirstChild("Pop")
			frame.Visible = true
			if pop and pop:IsA("UIScale") then
				pop.Scale = 0.85
				TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
			-- Play faster while more are waiting
			task.wait(if #queue > 0 then math.min(item.duration, 1.2) else item.duration)
			frame.Visible = false
			task.wait(0.08)
		end
		running = false
	end)
end

-- style: "info" | "warning" | "alert" | "success"
function Toast.Show(text: string, style: string?, duration: number?)
	table.insert(queue, { text = text, style = style or "info", duration = duration or DEFAULT_SECONDS })
	while #queue > MAX_QUEUE do
		table.remove(queue, 1)
	end
	runQueue()
end

return Toast
