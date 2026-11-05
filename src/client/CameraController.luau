--!strict
-- CameraController.luau
-- First-person tabletop camera locked at Seat 1 facing the table and opponents (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local CameraController = {}

-- Camera Framing: Positioned at Seat 1 eye-level, looking across the table at opponents
local TABLE_CENTER = Vector3.new(0, 3.2, 0)
local EYE_CAMERA_POS = Vector3.new(0, 5.4, 8.6) -- Seat 1 eye-level facing table
local DEFAULT_FOV = 68

local currentTargetPos = EYE_CAMERA_POS
local currentTargetFOV = DEFAULT_FOV
local isShakeActive = false
local shakeOffset = Vector3.zero
local isInitialized = false

-- ============================================================================
-- 1. SETUP & PER-FRAME CAMERA LOCK (Guaranteed live camera sync)
-- ============================================================================
function CameraController.Init()
	if isInitialized then return end
	isInitialized = true

	local function lockCamera()
		local cam = Workspace.CurrentCamera
		if not cam then return end

		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
		end

		local lookTarget = TABLE_CENTER
		local camPos = currentTargetPos + shakeOffset
		cam.CFrame = CFrame.lookAt(camPos, lookTarget)
		cam.FieldOfView = currentTargetFOV
	end

	-- Run every frame above Camera priority to override Roblox default CameraModule
	RunService:BindToRenderStep("TabletopCameraLock", Enum.RenderPriority.Camera.Value + 20, lockCamera)

	-- Also handle character spawning / respawning
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		localPlayer.CharacterAdded:Connect(function(char)
			-- Hide local player's character head/torso locally so it doesn't clip into your own first-person camera
			task.spawn(function()
				task.wait(0.1)
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 1
					end
				end
			end)
		end)
	end

	print("[CameraController] LOCOfficial Seat 1 tabletop camera locked.")
end

-- ============================================================================
-- 2. DYNAMIC CAMERA EFFECTS (Turn Focus & Skull Shake)
-- ============================================================================
function CameraController.SetTurnFocus(isMyTurn: boolean)
	local targetPos = isMyTurn and Vector3.new(0, 5.2, 8.2) or EYE_CAMERA_POS
	local targetFOV = isMyTurn and 66 or DEFAULT_FOV

	local tweenObj = Instance.new("NumberValue")
	tweenObj.Value = 0
	local startPos = currentTargetPos
	local startFOV = currentTargetFOV

	local tween = TweenService:Create(tweenObj, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = 1,
	})

	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local alpha = tweenObj.Value
		currentTargetPos = startPos:Lerp(targetPos, alpha)
		currentTargetFOV = startFOV + (targetFOV - startFOV) * alpha
	end)

	tween.Completed:Connect(function()
		if conn then conn:Disconnect() end
		currentTargetPos = targetPos
		currentTargetFOV = targetFOV
		tweenObj:Destroy()
	end)

	tween:Play()
end

function CameraController.ShakeOnSkull()
	task.spawn(function()
		if isShakeActive then return end
		isShakeActive = true

		local shakes = 8
		for i = 1, shakes do
			local intensity = (shakes - i + 1) / shakes * 0.6
			shakeOffset = Vector3.new(
				(math.random() * 2 - 1) * intensity,
				(math.random() * 2 - 1) * intensity,
				(math.random() * 2 - 1) * intensity * 0.4
			)
			task.wait(0.035)
		end

		shakeOffset = Vector3.zero
		isShakeActive = false
	end)
end

return CameraController
