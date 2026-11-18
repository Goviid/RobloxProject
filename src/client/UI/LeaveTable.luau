--!strict
-- LeaveTable.luau
-- A small, dim "Leave" pill tucked in the top-right corner, deliberately out of the way.
-- Clicking it only asks first ("Leave this table?"); LEAVE confirms, STAY closes the
-- question. Built on UIKit.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local UIKit = require(script.Parent.UIKit)

local LeaveTable = {}

function LeaveTable.Create(parent: Instance, onConfirm: () -> ())
	-- The pill: small, low-contrast, in the corner, away from every other control
	local pill = Instance.new("TextButton")
	pill.Name = "LeaveTablePill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -10, 0, 10)
	pill.Size = UDim2.fromOffset(62, 24)
	pill.BackgroundColor3 = Theme.Colors.Backing
	pill.BackgroundTransparency = 0.45
	pill.BorderSizePixel = 0
	pill.AutoButtonColor = true
	pill.Font = Theme.Fonts.Sub
	pill.TextSize = Theme.TextSize.Small
	pill.TextColor3 = Theme.Colors.TextMuted
	pill.TextTransparency = 0.2
	pill.Text = "Leave"
	pill.ZIndex = 5
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = Theme.CornerRadius.Circular

	-- The question
	local panel = UIKit.Panel(parent, { name = "LeaveTableConfirm", width = 340, accent = Theme.Colors.AlertRed, zIndex = 80 })
	UIKit.Label(panel, { text = "Leave this table?", style = "title", order = 1 })
	UIKit.Label(panel, {
		text = "You'll go back to the main menu. If a match is on, you give up your seat in it.",
		style = "body",
		order = 2,
	})
	local row = UIKit.Row(panel, 3, UIKit.ButtonHeight, 10)
	local stay = UIKit.Button(row, { name = "Stay", text = "STAY", kind = "secondary", order = 1, width = UDim.new(0.5, -5) })
	local leave = UIKit.Button(row, { name = "Leave", text = "LEAVE", kind = "danger", order = 2, width = UDim.new(0.5, -5) })

	pill.Activated:Connect(function()
		UIKit.Pop(panel, true)
	end)
	stay.Activated:Connect(function()
		UIKit.Pop(panel, false)
	end)
	leave.Activated:Connect(function()
		UIKit.Pop(panel, false)
		onConfirm()
	end)
end

return LeaveTable
