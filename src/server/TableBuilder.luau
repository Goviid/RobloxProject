--!strict
-- TableBuilder.luau
-- Builds the 3D Table Arena in Workspace with seats, coasters, and atmospheric lighting (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TableBuilder = {}

-- Arena Configuration
local TABLE_POSITION = Vector3.new(0, 3, 0)
local TABLE_RADIUS = 7.5
local SEAT_DISTANCE = 11.5
local COASTER_DISTANCE = 5.2

local arenaModel: Model? = nil
local seatInstances: { [number]: Seat } = {}
local coasterParts: { [number]: Part } = {}

-- ============================================================================
-- 1. BUILD THE 3D TABLE & ENVIRONMENT
-- ============================================================================
function TableBuilder.Build()
	-- Clean up any previous arena on reload
	local existing = Workspace:FindFirstChild("SkullsArena")
	if existing then existing:Destroy() end

	local arena = Instance.new("Model")
	arena.Name = "SkullsArena"
	arena.Parent = Workspace

	-- Room Floor
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(80, 2, 80)
	floor.Position = Vector3.new(0, -1, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(25, 18, 14)
	floor.Parent = arena

	-- Center Table (Solid Cylinder)
	local tableBase = Instance.new("Part")
	tableBase.Name = "MainTable"
	tableBase.Shape = Enum.PartType.Cylinder
	tableBase.Size = Vector3.new(1.8, TABLE_RADIUS * 2, TABLE_RADIUS * 2)
	tableBase.CFrame = CFrame.new(TABLE_POSITION) * CFrame.Angles(0, 0, math.rad(90))
	tableBase.Anchored = true
	tableBase.CanCollide = true
	tableBase.Material = Enum.Material.Wood
	tableBase.Color = Color3.fromRGB(55, 32, 20)
	tableBase.Parent = arena

	-- Table Center Felt Inset
	local felt = Instance.new("Part")
	felt.Name = "TableFelt"
	felt.Shape = Enum.PartType.Cylinder
	felt.Size = Vector3.new(1.85, (TABLE_RADIUS - 0.8) * 2, (TABLE_RADIUS - 0.8) * 2)
	felt.CFrame = CFrame.new(TABLE_POSITION + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	felt.Anchored = true
	felt.CanCollide = true
	felt.Material = Enum.Material.Fabric
	felt.Color = Color3.fromRGB(32, 20, 16)
	felt.Parent = arena

	-- Ambient Table Overhead Lantern Light
	local lampPost = Instance.new("Part")
	lampPost.Name = "OverheadLamp"
	lampPost.Size = Vector3.new(1, 0.5, 1)
	lampPost.Position = TABLE_POSITION + Vector3.new(0, 14, 0)
	lampPost.Anchored = true
	lampPost.CanCollide = false
	lampPost.Transparency = 1
	lampPost.Parent = arena

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Brightness = 2.5
	light.Range = 36
	light.Shadows = true
	light.Parent = lampPost

	-- ========================================================================
	-- 2. CREATE 6 SEATS & COASTER MATS IN A CIRCLE
	-- ========================================================================
	for seatIdx = 1, 6 do
		local angle = math.rad((seatIdx - 1) * (360 / 6) - 90)
		local dirX = math.cos(angle)
		local dirZ = math.sin(angle)

		-- Coaster Plate on Table Surface
		local coaster = Instance.new("Part")
		coaster.Name = "Coaster_Seat_" .. seatIdx
		coaster.Shape = Enum.PartType.Cylinder
		coaster.Size = Vector3.new(0.08, 2.2, 2.2)
		coaster.CFrame = CFrame.new(TABLE_POSITION.X + dirX * COASTER_DISTANCE, TABLE_POSITION.Y + 0.95, TABLE_POSITION.Z + dirZ * COASTER_DISTANCE)
			* CFrame.Angles(0, 0, math.rad(90))
		coaster.Anchored = true
		coaster.CanCollide = false
		coaster.Material = Enum.Material.SmoothPlastic
		coaster.Color = Color3.fromRGB(70, 48, 30)
		coaster.Parent = arena
		coasterParts[seatIdx] = coaster

		-- Coaster Gold Trim Ring
		local trim = Instance.new("Highlight")
		trim.Name = "GoldTrim"
		trim.FillTransparency = 1
		trim.OutlineColor = Color3.fromRGB(230, 180, 50)
		trim.OutlineTransparency = 0.4
		trim.Adornee = coaster
		trim.Parent = coaster

		-- 3D Chair Seat
		local seatPos = Vector3.new(TABLE_POSITION.X + dirX * SEAT_DISTANCE, TABLE_POSITION.Y - 0.5, TABLE_POSITION.Z + dirZ * SEAT_DISTANCE)
		local lookAtTable = CFrame.lookAt(seatPos, Vector3.new(TABLE_POSITION.X, seatPos.Y, TABLE_POSITION.Z))

		local seat = Instance.new("Seat")
		seat.Name = "Seat_" .. seatIdx
		seat.Size = Vector3.new(2.4, 1.2, 2.4)
		seat.CFrame = lookAtTable
		seat.Anchored = true
		seat.CanCollide = true
		seat.Material = Enum.Material.Wood
		seat.Color = Color3.fromRGB(48, 28, 18)
		seat.Parent = arena
		seatInstances[seatIdx] = seat

		-- Chair Backrest
		local backrest = Instance.new("Part")
		backrest.Name = "Backrest"
		backrest.Size = Vector3.new(2.4, 2.6, 0.4)
		backrest.CFrame = lookAtTable * CFrame.new(0, 1.6, 1.0)
		backrest.Anchored = true
		backrest.CanCollide = true
		backrest.Material = Enum.Material.Wood
		backrest.Color = Color3.fromRGB(48, 28, 18)
		backrest.Parent = arena
	end

	arenaModel = arena
	print("[TableBuilder] 3D Arena created with 6 seats and coasters.")
	return arena
end

-- ============================================================================
-- 3. SEAT PLAYERS & BOTS AT THE TABLE
-- ============================================================================
function TableBuilder.SeatPlayer(player: Player, seatIndex: number)
	local seat = seatInstances[seatIndex]
	if not seat then return end

	local char = player.Character or player.CharacterAdded:Wait()
	local humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid?
	local hrp = char:WaitForChild("HumanoidRootPart", 5) :: Part?

	if humanoid and hrp then
		-- Position character on chair
		hrp.CFrame = seat.CFrame + Vector3.new(0, 1.5, 0)
		task.delay(0.2, function()
			seat:Sit(humanoid)
		end)
	end
end

-- Get Coaster Position in 3D world (used by client to fly cards)
function TableBuilder.GetCoasterCFrame(seatIndex: number): CFrame?
	local coaster = coasterParts[seatIndex]
	return coaster and coaster.CFrame or nil
end

return TableBuilder
