--!strict
-- CameraController.luau
-- 3D Tabletop Over-the-Shoulder Camera framing your avatar, the circular table, and opponents (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraController = {}

-- Camera Framing: Elevated behind Seat 1, framing your avatar in foreground and opponents across table
local LOOK_TARGET = Vector3.new(0, 3.2, 0.8)
local DEFAULT_CAMERA_POS = Vector3.new(0, 7.6, 15.6)
local DEFAULT_FOV = 62

local currentTargetPos = DEFAULT_CAMERA_POS
local currentTargetFOV = DEFAULT_FOV
local isShakeActive = false
local shakeOffset = Vector3.zero
local isInitialized = false

-- ============================================================================
-- 1. SETUP & PER-FRAME CAMERA LOCK
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

		local lookTarget = LOOK_TARGET
		local camPos = currentTargetPos + shakeOffset
		cam.CFrame = CFrame.lookAt(camPos, lookTarget)
		cam.FieldOfView = currentTargetFOV
	end

	-- Run every frame above Camera priority to smoothly lock the view
	RunService:BindToRenderStep("TabletopCameraLock", Enum.RenderPriority.Camera.Value + 20, lockCamera)

	print("[CameraController] Tabletop over-the-shoulder camera initialized.")
end

-- ============================================================================
-- 2. DYNAMIC CAMERA EFFECTS (Turn Focus & Skull Shake)
-- ============================================================================
function CameraController.SetTurnFocus(isMyTurn: boolean)
	local targetPos = isMyTurn and Vector3.new(0, 7.2, 14.8) or DEFAULT_CAMERA_POS
	local targetFOV = isMyTurn and 60 or DEFAULT_FOV

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
