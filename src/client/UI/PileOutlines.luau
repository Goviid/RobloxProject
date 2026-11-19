--!strict
-- PileOutlines.luau
-- A small, dim "Piles" pill in the top-right corner (left of "Leave") that turns the
-- round pile-mat outlines on the table on or off. Off by default; local to this player.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)

local PileOutlines = {}

local shown = false

function PileOutlines.IsShown(): boolean
	return shown
end

-- Shows or hides every pile mat outline in the given table arena (this client only)
function PileOutlines.Apply(arena: Instance?)
	if not arena then
		return
	end
	for _, d in ipairs(arena:GetDescendants()) do
		if d:IsA("SurfaceGui") and d.Name == "MatGui" then
			d.Enabled = shown
		end
	end
end

function PileOutlines.Create(parent: Instance, getArena: () -> Instance?)
	local pill = Instance.new("TextButton")
	pill.Name = "PileOutlinesPill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -78, 0, 10) -- just left of the Leave pill
	pill.Size = UDim2.fromOffset(62, 24)
	pill.BackgroundColor3 = Theme.Colors.Backing
	pill.BorderSizePixel = 0
	pill.AutoButtonColor = true
	pill.Font = Theme.Fonts.Sub
	pill.TextSize = Theme.TextSize.Small
	pill.Text = "Piles"
	pill.ZIndex = 5
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = Theme.CornerRadius.Circular

	local function style()
		pill.BackgroundTransparency = if shown then 0.2 else 0.45
		pill.TextColor3 = if shown then Theme.Colors.TextPrimary else Theme.Colors.TextMuted
		pill.TextTransparency = if shown then 0 else 0.2
	end
	style()

	pill.Activated:Connect(function()
		shown = not shown
		style()
		PileOutlines.Apply(getArena())
	end)
end

return PileOutlines
