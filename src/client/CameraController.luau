--!strict
-- CameraController.luau
-- 2.5D Fixed Tabletop Camera framing the 3D table and seated avatars (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local CameraController = {}
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

-- Camera Angles
local TABLE_CENTER = Vector3.new(0, 3.2, 0)
local DEFAULT_CAMERA_POS = Vector3.new(0, 18, 21)
local DEFAULT_FOV = 62

local isInitialized = false

-- ============================================================================
-- 1. SETUP SCRIPTABLE CAMERA
-- ============================================================================
function CameraController.Init()
	if isInitialized then return end
	isInitialized = true

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = DEFAULT_FOV
	camera.CFrame = CFrame.lookAt(DEFAULT_CAMERA_POS, TABLE_CENTER)

	print("[CameraController] 2.5D Tabletop Camera initialized.")
end

-- ============================================================================
-- 2. DYNAMIC CAMERA EFFECTS (LOCOfficial style subtle focus)
-- ============================================================================
-- Subtle punchy focus when it's your turn
function CameraController.SetTurnFocus(isMyTurn: boolean)
	local targetFOV = isMyTurn and 59 or DEFAULT_FOV
	local targetPos = isMyTurn and Vector3.new(0, 17.2, 20) or DEFAULT_CAMERA_POS

	TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = targetFOV,
		CFrame = CFrame.lookAt(targetPos, TABLE_CENTER),
	}):Play()
end

-- Dramatic zoom when skull is hit
function CameraController.ShakeOnSkull()
	task.spawn(function()
		local originalCF = camera.CFrame
		for _ = 1, 6 do
			local offset = Vector3.new(math.random(-6, 6) / 10, math.random(-6, 6) / 10, 0)
			camera.CFrame = originalCF + offset
			task.wait(0.04)
		end
		camera.CFrame = originalCF
	end)
end

return CameraController
