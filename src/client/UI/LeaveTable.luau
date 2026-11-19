--!strict
-- LeaveTable.luau
-- A small, dim "Leave" pill tucked in the top-right corner, deliberately out of the way.
-- Clicking it only asks first ("Leave this table?"); LEAVE confirms, STAY closes the
-- question. Built on UIKit.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local UIKit = require(script.Parent.UIKit)
local CornerPill = require(script.Parent.CornerPill)

local LeaveTable = {}

function LeaveTable.Create(parent: Instance, onConfirm: () -> ())
	-- The pill: small, low-contrast, rightmost in the corner, away from every other control
	local pill = CornerPill.Create(parent, "LeaveTablePill", Theme.Images.IconLeave, "Leave", 3).button

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
