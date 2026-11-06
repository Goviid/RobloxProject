--!strict
-- CameraController.luau
-- First-person eye-level camera framing the ground cards, arena center, and opponents (LOCOfficial style)
-- Completely hides the local player's character model locally while leaving it visible to all other players!

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local CameraController = {}

local localPlayer = Players.LocalPlayer

local function getCameraConfig(): (Vector3, Vector3)
	-- Zoomed out, overhead table view ("from the top") looking down at the circular table
	local lookTarget = Vector3.new(0, 3.0, 0.5)
	local camPos = Vector3.new(0, 9.6, 9.8)
	return lookTarget, camPos
end

local DEFAULT_FOV = 65
local isShakeActive = false
local shakeOffset = Vector3.zero
local isInitialized = false

-- Dynamic target offsets & FOV
local currentTurnOffset = Vector3.zero
local currentTargetFOV = DEFAULT_FOV

-- ============================================================================
-- 1. SETUP & PER-FRAME CAMERA LOCK + LOCAL AVATAR HIDING
-- ============================================================================
function CameraController.Init()
	if isInitialized then return end
	isInitialized = true

	-- Sink mouse panning, wheel zooming, and movement controls so camera is 100% rigidly fixed
	pcall(function()
		ContextActionService:BindActionAtPriority(
			"FreezeCameraAndMovement",
			function() return Enum.ContextActionResult.Sink end,
			false,
			Enum.ContextActionPriority.High.Value + 2000,
			Enum.PlayerActions.CharacterForward,
			Enum.PlayerActions.CharacterBackward,
			Enum.PlayerActions.CharacterLeft,
			Enum.PlayerActions.CharacterRight,
			Enum.PlayerActions.CharacterJump,
			Enum.UserInputType.MouseWheel,
			Enum.UserInputType.MouseButton2
		)
	end)

	-- Per-frame camera lock (Runs at Last priority so Roblox scripts cannot override it)
	local function lockCamera()
		local cam = Workspace.CurrentCamera
		if not cam then return end

		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
		end

		local lookTarget, defaultCamPos = getCameraConfig()
		local camPos = defaultCamPos + currentTurnOffset + shakeOffset
		cam.CFrame = CFrame.lookAt(camPos, lookTarget)
		cam.FieldOfView = currentTargetFOV
	end

	-- Per-frame local character transparency (Locofficial style - completely invisible locally)
	local function hideLocalCharacter()
		local char = localPlayer.Character
		if not char then return end

		for _, item in ipairs(char:GetDescendants()) do
			if item:IsA("BasePart") then
				item.Transparency = 1
				item.LocalTransparencyModifier = 1
				item.CastShadow = false
				item.CanCollide = false
			elseif item:IsA("Decal") then
				item.Transparency = 1
				item.LocalTransparencyModifier = 1
			elseif item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam") then
				item.Enabled = false
			elseif item:IsA("BillboardGui") then
				item.Enabled = false
			end
		end
	end

	-- Run on RenderStep every single frame
	RunService:BindToRenderStep("HideLocalCharacter", Enum.RenderPriority.Camera.Value - 1, hideLocalCharacter)
	RunService:BindToRenderStep("TabletopCameraLock", Enum.RenderPriority.Last.Value, lockCamera)

	-- Handle character respawn
	localPlayer.CharacterAdded:Connect(function(char)
		task.wait(0.1)
		hideLocalCharacter()
	end)

	print("[CameraController] 100% Fixed elevated camera initialized. Local player completely invisible.")
end

-- ============================================================================
-- 2. DYNAMIC CAMERA EFFECTS (Turn Focus & Skull Shake)
-- ============================================================================
function CameraController.SetTurnFocus(isMyTurn: boolean)
	local targetOffset = isMyTurn and Vector3.new(0, -0.6, -0.8) or Vector3.zero
	local targetFOV = isMyTurn and 61 or DEFAULT_FOV

	local tweenObj = Instance.new("NumberValue")
	tweenObj.Value = 0
	local startOffset = currentTurnOffset
	local startFOV = currentTargetFOV

	local tween = TweenService:Create(tweenObj, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = 1,
	})

	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local alpha = tweenObj.Value
		currentTurnOffset = startOffset:Lerp(targetOffset, alpha)
		currentTargetFOV = startFOV + (targetFOV - startFOV) * alpha
	end)

	tween.Completed:Connect(function()
		if conn then conn:Disconnect() end
		currentTurnOffset = targetOffset
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
