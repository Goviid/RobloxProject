--!strict
-- PileOutlines.luau
-- A small, dim "Piles" pill in the top-right corner (left of "Leave") that turns the
-- round pile-mat outlines on the table on or off. Off by default; local to this player.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local CornerPill = require(script.Parent.CornerPill)

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
	local pill = CornerPill.Create(parent, "PileOutlinesPill", Theme.Images.IconPiles, "Piles", 2) -- left of Leave
	pill.setLit(shown)

	pill.button.Activated:Connect(function()
		shown = not shown
		pill.setLit(shown)
		PileOutlines.Apply(getArena())
	end)
end

return PileOutlines
