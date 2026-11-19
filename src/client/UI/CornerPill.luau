--!strict
-- CornerPill.luau
-- The small, dim options in the top-right corner (Look, Piles, Leave): an icon and a
-- short word in a rounded pill. To keep the screen clear only a cogwheel shows there;
-- clicking it opens the pills in a row to its left and turns it into an X, which
-- closes them again. Each pill takes its own width; `order` sets the position, left
-- to right.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)

local CornerPill = {}

local ICON_SIZE = 14
local COG_SIZE = 28

local function row(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.fromOffset(0, COG_SIZE)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = frame
	return frame
end

-- The corner row: the (hidden) pills, then the cogwheel that shows and hides them.
-- Returns the frame the pills go in.
local function getPillRow(parent: Instance): Frame
	local existing = parent:FindFirstChild("CornerBar")
	local pills = existing and existing:FindFirstChild("Pills")
	if pills and pills:IsA("Frame") then
		return pills
	end
	local bar = row("CornerBar", parent)
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.Position = UDim2.new(1, -10, 0, 8)

	local pillRow = row("Pills", bar)
	pillRow.LayoutOrder = 1
	pillRow.Visible = false

	local cog = Instance.new("ImageButton")
	cog.Name = "Settings"
	cog.LayoutOrder = 2
	cog.Size = UDim2.fromOffset(COG_SIZE, COG_SIZE)
	cog.BackgroundColor3 = Theme.Colors.Backing
	cog.BackgroundTransparency = 0.45
	cog.BorderSizePixel = 0
	cog.AutoButtonColor = true
	cog.Image = ""
	cog.ZIndex = 5
	cog.Parent = bar
	Instance.new("UICorner", cog).CornerRadius = Theme.CornerRadius.Circular
	local glyph = Instance.new("ImageLabel")
	glyph.Name = "Icon"
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromOffset(16, 16)
	glyph.BackgroundTransparency = 1
	glyph.Image = Theme.Images.IconSettings
	glyph.ImageColor3 = Theme.Colors.TextMuted
	glyph.Parent = cog

	cog.Activated:Connect(function()
		local open = not pillRow.Visible
		pillRow.Visible = open
		glyph.Image = if open then Theme.Images.IconClose else Theme.Images.IconSettings
		glyph.Size = if open then UDim2.fromOffset(12, 12) else UDim2.fromOffset(16, 16)
		glyph.ImageColor3 = if open then Theme.Colors.TextPrimary else Theme.Colors.TextMuted
		cog.BackgroundTransparency = if open then 0.2 else 0.45
	end)
	return pillRow
end

export type Pill = {
	button: TextButton,
	label: TextLabel,
	icon: ImageLabel,
	-- Dim (false) or highlighted (true), e.g. while the setting it toggles is on
	setLit: (lit: boolean) -> (),
}

function CornerPill.Create(parent: Instance, name: string, icon: string, text: string, order: number): Pill
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(0, 24)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = Theme.Colors.Backing
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.ZIndex = 5
	button.Parent = getPillRow(parent)
	Instance.new("UICorner", button).CornerRadius = Theme.CornerRadius.Circular

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 9)
	padding.PaddingRight = UDim.new(0, 11)
	padding.Parent = button
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = button

	local image = Instance.new("ImageLabel")
	image.Name = "Icon"
	image.LayoutOrder = 1
	image.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	image.BackgroundTransparency = 1
	image.Image = icon
	image.ZIndex = 6
	image.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, 24)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.Font = Theme.Fonts.Sub
	label.TextSize = Theme.TextSize.Small
	label.Text = text
	label.ZIndex = 6
	label.Parent = button

	local function setLit(lit: boolean)
		button.BackgroundTransparency = if lit then 0.2 else 0.45
		local color = if lit then Theme.Colors.TextPrimary else Theme.Colors.TextMuted
		local fade = if lit then 0 else 0.2
		label.TextColor3 = color
		label.TextTransparency = fade
		image.ImageColor3 = color
		image.ImageTransparency = fade
	end
	setLit(false)

	return { button = button, label = label, icon = image, setLit = setLit }
end

return CornerPill
