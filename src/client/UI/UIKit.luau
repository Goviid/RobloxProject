--!strict
-- UIKit.luau
-- Shared building blocks so every pop-up looks the same: one panel style, one set of
-- text styles, one button style, one pop animation. Build screens from these instead of
-- hand-styling Instances.
--
--   local panel = UIKit.Panel(parent, { name = "X", width = 360, zIndex = 60 })
--   UIKit.Label(panel, { text = "TITLE", style = "title", order = 1 })
--   UIKit.Button(panel, { text = "OK", kind = "primary", order = 2 })
--   UIKit.Pop(panel, true)
--
-- The ScreenGui uses ZIndexBehavior.Sibling, so children always draw above their panel;
-- only the panel's own zIndex matters.

local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)

local UIKit = {}

export type PanelOptions = {
	name: string,
	width: number, -- max width; shrinks to fit narrow screens
	zIndex: number?,
	accent: Color3?, -- border colour (gold by default)
	padding: number?,
	gap: number?,
}

export type LabelStyle = "display" | "title" | "heading" | "body" | "muted"
export type LabelOptions = {
	name: string?,
	text: string?,
	style: LabelStyle?,
	order: number?,
	color: Color3?,
	richText: boolean?,
}

export type ButtonKind = "primary" | "success" | "danger" | "secondary"
export type ButtonOptions = {
	name: string?,
	text: string?,
	kind: ButtonKind?,
	order: number?,
	width: UDim?, -- default: full width
	height: number?,
}

local BUTTON_COLORS: { [string]: Color3 } = {
	primary = Theme.Colors.WarningAmber,
	success = Theme.Colors.SuccessGreen,
	danger = Theme.Colors.AlertRed,
	secondary = Theme.Colors.PanelBorder,
}

type TextStyle = { font: Enum.Font, size: number, color: Color3 }
local LABEL_STYLES: { [string]: TextStyle } = {
	display = { font = Theme.Fonts.Title, size = Theme.TextSize.Display, color = Theme.Colors.TextGold },
	title = { font = Theme.Fonts.Title, size = Theme.TextSize.Heading, color = Theme.Colors.TextGold },
	heading = { font = Theme.Fonts.Header, size = Theme.TextSize.Label, color = Theme.Colors.TextPrimary },
	body = { font = Theme.Fonts.Body, size = Theme.TextSize.Body, color = Theme.Colors.TextSecondary },
	muted = { font = Theme.Fonts.Sub, size = Theme.TextSize.Small, color = Theme.Colors.TextMuted },
}

UIKit.ButtonHeight = 44

-- Centred, auto-height panel with a vertical layout. Hidden until shown.
function UIKit.Panel(parent: Instance, options: PanelOptions): Frame
	local frame = Instance.new("Frame")
	frame.Name = options.name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.45)
	frame.Size = UDim2.new(1, -32, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Theme.Colors.Backing
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = options.zIndex or 50
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = Theme.CornerRadius.Large

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(options.width, math.huge)
	limit.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = options.accent or Theme.Colors.Gold
	stroke.Thickness = 2
	stroke.Parent = frame

	local padding = options.padding or 18
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, padding)
	pad.PaddingBottom = UDim.new(0, padding)
	pad.PaddingLeft = UDim.new(0, padding)
	pad.PaddingRight = UDim.new(0, padding)
	pad.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, options.gap or 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = frame

	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = frame

	return frame
end

-- Recolour a panel's border (e.g. red for skull events)
function UIKit.SetAccent(panel: Frame, color: Color3)
	local stroke = panel:FindFirstChild("Border")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = color
	end
end

-- Full-width, wrapping, auto-height text in one of the shared styles
function UIKit.Label(parent: Instance, options: LabelOptions): TextLabel
	local style = LABEL_STYLES[options.style or "body"]
	local label = Instance.new("TextLabel")
	label.Name = options.name or "Label"
	label.LayoutOrder = options.order or 0
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = style.font
	label.TextSize = style.size
	label.TextColor3 = options.color or style.color
	label.TextWrapped = true
	label.RichText = options.richText == true
	label.Text = options.text or ""
	label.Parent = parent
	return label
end

function UIKit.Button(parent: Instance, options: ButtonOptions): TextButton
	local button = Instance.new("TextButton")
	button.Name = options.name or "Button"
	button.LayoutOrder = options.order or 0
	button.Size = UDim2.new(options.width or UDim.new(1, 0), UDim.new(0, options.height or UIKit.ButtonHeight))
	button.BackgroundColor3 = BUTTON_COLORS[options.kind or "primary"]
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = Theme.Fonts.Title
	button.TextSize = Theme.TextSize.Label
	button.TextColor3 = Theme.Colors.TextPrimary
	button.Text = options.text or ""
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = Theme.CornerRadius.Circular
	Theme.Outline(button, 0.5)
	return button
end

function UIKit.SetButtonKind(button: TextButton, kind: ButtonKind)
	button.BackgroundColor3 = BUTTON_COLORS[kind]
end

-- Greyed out and unclickable when disabled
function UIKit.SetEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.6
	button.TextTransparency = if enabled then 0 else 0.4
end

-- Invisible horizontal row (for buttons or cards side by side)
function UIKit.Row(parent: Instance, order: number, height: number, gap: number?): Frame
	local row = Instance.new("Frame")
	row.Name = "Row" .. order
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, gap or 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

-- Show with a springy pop, or hide with a quick shrink (then Visible = false).
-- Re-showing during a hide cancels the hide.
function UIKit.Pop(frame: GuiObject, show: boolean, onHidden: (() -> ())?)
	local scale = frame:FindFirstChild("Pop") :: UIScale?
	local previous = frame:GetAttribute("PopToken")
	local token = (if typeof(previous) == "number" then previous else 0) + 1
	frame:SetAttribute("PopToken", token)
	if show then
		frame.Visible = true
		if scale then
			scale.Scale = 0.85
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		return
	end
	if not frame.Visible then
		if onHidden then
			onHidden()
		end
		return
	end
	if not scale then
		frame.Visible = false
		if onHidden then
			onHidden()
		end
		return
	end
	local tween = TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
	tween.Completed:Connect(function()
		if frame:GetAttribute("PopToken") == token then
			frame.Visible = false
			scale.Scale = 1
			if onHidden then
				onHidden()
			end
		end
	end)
	tween:Play()
end

return UIKit
