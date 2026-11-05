--!strict
-- CameraController.luau
-- 2.5D Tabletop Camera framing the 3D table, standing avatars, and 3D card stacks (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local CameraController = {}
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

-- Camera Angles & Framing
local TABLE_CENTER = Vector3.new(0, 3.2, 0)
local DEFAULT_CAMERA_POS = Vector3.new(0, 13.5, 17.5)
local DEFAULT_FOV = 60

local currentTargetPos = DEFAULT_CAMERA_POS
local currentTargetFOV = DEFAULT_FOV
local isShakeActive = false
local shakeOffset = Vector3.zero
local isInitialized = false

-- ============================================================================
-- 1. SETUP & PER-FRAME CAMERA LOCK (Overrides Roblox CameraModule)
-- ============================================================================
function CameraController.Init()
	if isInitialized then return end
	isInitialized = true

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = DEFAULT_FOV
	camera.CFrame = CFrame.lookAt(DEFAULT_CAMERA_POS, TABLE_CENTER)

	-- Bind to RenderStep with priority above standard Camera to prevent Roblox CameraModule hijack
	RunService:BindToRenderStep("TabletopCameraLock", Enum.RenderPriority.Camera.Value + 10, function()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end

		local lookTarget = TABLE_CENTER
		local camPos = currentTargetPos + shakeOffset
		camera.CFrame = CFrame.lookAt(camPos, lookTarget)
		camera.FieldOfView = currentTargetFOV
	end)

	-- Re-assert scriptable on character spawn
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		localPlayer.CharacterAdded:Connect(function()
			task.wait(0.1)
			camera.CameraType = Enum.CameraType.Scriptable
		end)
	end

	print("[CameraController] 2.5D Tabletop Camera locked and initialized.")
end

-- ============================================================================
-- 2. DYNAMIC CAMERA EFFECTS (LOCOfficial Style Focus & Skull Shake)
-- ============================================================================
-- Subtle forward punch when it becomes your turn
function CameraController.SetTurnFocus(isMyTurn: boolean)
	local targetPos = isMyTurn and Vector3.new(0, 13.0, 16.5) or DEFAULT_CAMERA_POS
	local targetFOV = isMyTurn and 58 or DEFAULT_FOV

	local tweenObj = Instance.new("NumberValue")
	tweenObj.Value = 0
	local startPos = currentTargetPos
	local startFOV = currentTargetFOV

	local tween = TweenService:Create(tweenObj, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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

-- Dramatic screen shake when a Skull is flipped
function CameraController.ShakeOnSkull()
	task.spawn(function()
		if isShakeActive then return end
		isShakeActive = true

		local shakes = 8
		for i = 1, shakes do
			local intensity = (shakes - i + 1) / shakes * 0.5
			shakeOffset = Vector3.new(
				(math.random() * 2 - 1) * intensity,
				(math.random() * 2 - 1) * intensity,
				(math.random() * 2 - 1) * intensity * 0.5
			)
			task.wait(0.035)
		end

		shakeOffset = Vector3.zero
		isShakeActive = false
	end)
end

return CameraController
