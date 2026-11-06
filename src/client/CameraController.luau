--!strict
-- CameraController.luau
-- First-person eye-level camera framing the ground cards, arena center, and opponents (LOCOfficial style)
-- Completely hides the local player's character model locally while leaving it visible to all other players!

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CameraController = {}

local localPlayer = Players.LocalPlayer

local function getCameraConfig(): (Vector3, Vector3)
	local isTable = (Workspace:GetAttribute("ArenaMode") == "Table")
	if isTable then
		-- Classic Parlor Table eye-level framing
		return Vector3.new(0, 3.4, 0.0), Vector3.new(0, 5.2, 9.4)
	else
		-- LOCOfficial elevated void perspective (frames full circular table, all opponents, and center pile)
		return Vector3.new(0, 1.0, 0.5), Vector3.new(0, 7.2, 14.8)
	end
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

	-- Per-frame camera lock
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

	-- Per-frame local character transparency (Hides model for YOU, friends still see you!)
	local function hideLocalCharacter()
		local char = localPlayer.Character
		if not char then return end

		for _, item in ipairs(char:GetDescendants()) do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = 1
				item.CastShadow = false
			elseif item:IsA("Decal") then
				item.LocalTransparencyModifier = 1
			elseif item:IsA("ParticleEmitter") or item:IsA("Trail") then
				item.Enabled = false
			end
		end

		-- Also hide your own overhead nametag so it doesn't float in front of your eyes
		local head = char:FindFirstChild("Head")
		if head then
			local tag = head:FindFirstChild("PlayerInfoTag") :: BillboardGui?
			if tag then
				tag.Enabled = false
			end
		end
	end

	-- Run hideLocalCharacter before Camera, and lockCamera at Camera priority
	RunService:BindToRenderStep("HideLocalCharacter", Enum.RenderPriority.Camera.Value - 1, hideLocalCharacter)
	RunService:BindToRenderStep("TabletopCameraLock", Enum.RenderPriority.Camera.Value + 20, lockCamera)

	print("[CameraController] First-person LOCOfficial camera initialized. Local character hidden from self.")
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
