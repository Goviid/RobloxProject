--!strict
-- VictoryModal.luau
-- Winner screen: crown, who won, and a countdown back to the lobby, with a confetti
-- burst. Built on UIKit.

local TweenService = game:GetService("TweenService")
local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local UIKit = require(script.Parent.UIKit)

local VictoryModal = {}

local panel: Frame? = nil
local confettiLayer: Frame? = nil
local winnerLabel: TextLabel? = nil
local reasonLabel: TextLabel? = nil
local countdownLabel: TextLabel? = nil
local showToken = 0

local CONFETTI_COLORS = {
	Theme.Colors.Gold,
	Theme.Colors.RosePrimary,
	Theme.Colors.TextPrimary,
	Theme.Colors.SuccessGreen,
	Color3.fromRGB(80, 150, 235),
}

-- Confetti flies out from the panel's centre on a layer of its own (the panel's
-- list layout would otherwise line the flakes up)
local function spawnConfettiBurst(layer: Frame)
	for _ = 1, 35 do
		local flake = Instance.new("Frame")
		flake.Name = "ConfettiFlake"
		flake.AnchorPoint = Vector2.new(0.5, 0.5)
		flake.Size = UDim2.fromOffset(math.random(8, 14), math.random(8, 14))
		flake.Position = UDim2.fromScale(0.5 + math.random(-12, 12) / 100, 0.45)
		flake.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		flake.BorderSizePixel = 0
		flake.Rotation = math.random(0, 360)
		flake.Parent = layer
		Instance.new("UICorner", flake).CornerRadius = UDim.new(0, 3)

		local tween = TweenService:Create(flake, TweenInfo.new(math.random(12, 22) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(flake.Position.X.Scale + math.random(-30, 30) / 100, 0.45 + math.random(-35, 35) / 100),
			Rotation = flake.Rotation + math.random(-180, 180),
			BackgroundTransparency = 1,
		})
		tween.Completed:Connect(function()
			flake:Destroy()
		end)
		tween:Play()
	end
end

function VictoryModal.Create(parent: Instance): Frame
	local frame = UIKit.Panel(parent, { name = "VictoryModal", width = 420, zIndex = 50, padding = 22, gap = 8 })

	UIKit.Label(frame, { name = "Crown", style = "display", order = 1, text = "👑" }).TextSize = 52
	UIKit.Label(frame, { name = "Title", style = "title", order = 2, text = "MATCH OVER" })
	local winner = UIKit.Label(frame, { name = "WinnerName", style = "display", order = 3 })
	local reason = UIKit.Label(frame, { name = "Reason", style = "body", order = 4 })
	local countdown = UIKit.Label(frame, { name = "Countdown", style = "muted", order = 5 })

	local layer = Instance.new("Frame")
	layer.Name = "Confetti"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.ZIndex = 51
	layer.Parent = parent

	panel = frame
	confettiLayer = layer
	winnerLabel = winner
	reasonLabel = reason
	countdownLabel = countdown
	return frame
end

-- Shows the winner for `duration` seconds with a countdown to the lobby.
function VictoryModal.Show(winnerName: string, isLocalPlayer: boolean, reason: string?, duration: number?)
	local frame, layer, winner, reasonText, countdown = panel, confettiLayer, winnerLabel, reasonLabel, countdownLabel
	if not frame or not layer or not winner or not reasonText or not countdown then
		return
	end
	showToken += 1
	local token = showToken
	local holdSeconds = math.max(3, duration or 6)

	winner.Text = if isLocalPlayer then "YOU WIN!" else (winnerName .. " wins")
	winner.TextColor3 = if isLocalPlayer then Theme.Colors.GoldGlow else Theme.Colors.TextPrimary
	reasonText.Text = reason or ""
	reasonText.Visible = reason ~= nil and reason ~= ""

	task.spawn(function()
		local secondsLeft = math.ceil(holdSeconds)
		while secondsLeft > 0 and showToken == token do
			countdown.Text = "Back to the lobby in " .. secondsLeft .. "s"
			task.wait(1)
			secondsLeft -= 1
		end
	end)

	UIKit.Pop(frame, true)
	spawnConfettiBurst(layer)

	-- Auto-dismiss just before the lobby comes back
	task.delay(holdSeconds - 0.5, function()
		if showToken == token then
			UIKit.Pop(frame, false)
		end
	end)
end

return VictoryModal
