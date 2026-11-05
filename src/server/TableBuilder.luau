--!strict
-- TableBuilder.luau
-- Constructs the 3D tabletop environment, enclosed room, chandelier lighting, standing pods, and avatar dummies (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableBuilder = {}

-- Arena Spatial Configuration
local TABLE_POSITION = Vector3.new(0, 3.0, 0)
local TABLE_RADIUS = 7.5
local STAND_DISTANCE = 9.8        -- Distance from table center to player standing pod
local COASTER_DISTANCE = 5.2      -- Distance from table center to card coaster on table surface

local arenaModel: Model? = nil
local standingCFrames: { [number]: CFrame } = {}
local coasterParts: { [number]: Part } = {}
local botDummies: { [number]: Model } = {}
local playerBillboards: { [number]: BillboardGui } = {}

-- ============================================================================
-- 1. CONSTRUCT ENCLOSED ROOM & ATMOSPHERIC LIGHTING (LOCOfficial Aesthetic)
-- ============================================================================
function TableBuilder.Build()
	-- Clean up any previous arena instance on live reload
	local existing = Workspace:FindFirstChild("SkullsArena")
	if existing then existing:Destroy() end

	local arena = Instance.new("Model")
	arena.Name = "SkullsArena"
	arena.Parent = Workspace

	-- ------------------------------------------------------------------------
	-- A. Room Enclosure (Blocks all harsh outdoor daylight)
	-- ------------------------------------------------------------------------
	local ROOM_WIDTH = 70
	local ROOM_HEIGHT = 22

	-- Floor: Dark polished mahogany planks
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(ROOM_WIDTH, 2, ROOM_WIDTH)
	floor.Position = Vector3.new(0, -1, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(26, 18, 14)
	floor.Parent = arena

	-- Ceiling: Dark acoustic wood coffering
	local ceiling = Instance.new("Part")
	ceiling.Name = "ArenaCeiling"
	ceiling.Size = Vector3.new(ROOM_WIDTH, 1.5, ROOM_WIDTH)
	ceiling.Position = Vector3.new(0, ROOM_HEIGHT, 0)
	ceiling.Anchored = true
	ceiling.CanCollide = true
	ceiling.Material = Enum.Material.Wood
	ceiling.Color = Color3.fromRGB(18, 14, 12)
	ceiling.Parent = arena

	-- 4 Enclosing Walls to completely block outdoor sunlight
	local wallConfigs = {
		{ name = "Wall_North", size = Vector3.new(ROOM_WIDTH, ROOM_HEIGHT, 2), pos = Vector3.new(0, ROOM_HEIGHT / 2, -ROOM_WIDTH / 2) },
		{ name = "Wall_South", size = Vector3.new(ROOM_WIDTH, ROOM_HEIGHT, 2), pos = Vector3.new(0, ROOM_HEIGHT / 2, ROOM_WIDTH / 2) },
		{ name = "Wall_East",  size = Vector3.new(2, ROOM_HEIGHT, ROOM_WIDTH), pos = Vector3.new(ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0) },
		{ name = "Wall_West",  size = Vector3.new(2, ROOM_HEIGHT, ROOM_WIDTH), pos = Vector3.new(-ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0) },
	}

	for _, cfg in ipairs(wallConfigs) do
		local wall = Instance.new("Part")
		wall.Name = cfg.name
		wall.Size = cfg.size
		wall.Position = cfg.pos
		wall.Anchored = true
		wall.CanCollide = true
		wall.Material = Enum.Material.WoodPlanks
		wall.Color = Color3.fromRGB(22, 16, 14)
		wall.Parent = arena

		-- Subtle warm decorative wainscot trim along bottom of each wall
		local trim = Instance.new("Part")
		trim.Name = cfg.name .. "_Trim"
		trim.Size = (cfg.size.X > cfg.size.Z) and Vector3.new(cfg.size.X, 4, 2.4) or Vector3.new(2.4, 4, cfg.size.Z)
		trim.Position = Vector3.new(cfg.pos.X, 2, cfg.pos.Z)
		trim.Anchored = true
		trim.CanCollide = true
		trim.Material = Enum.Material.Wood
		trim.Color = Color3.fromRGB(38, 26, 20)
		trim.Parent = arena
	end

	-- ------------------------------------------------------------------------
	-- B. Center Circular Table & Felt Inset
	-- ------------------------------------------------------------------------
	-- Outer table rim (Dark polished oak)
	local tableBase = Instance.new("Part")
	tableBase.Name = "MainTable"
	tableBase.Shape = Enum.PartType.Cylinder
	tableBase.Size = Vector3.new(1.8, TABLE_RADIUS * 2, TABLE_RADIUS * 2)
	tableBase.CFrame = CFrame.new(TABLE_POSITION) * CFrame.Angles(0, 0, math.rad(90))
	tableBase.Anchored = true
	tableBase.CanCollide = true
	tableBase.Material = Enum.Material.Wood
	tableBase.Color = Color3.fromRGB(48, 28, 18)
	tableBase.Parent = arena

	-- Center Felt Inset (Rich burgundy fabric surface)
	local felt = Instance.new("Part")
	felt.Name = "TableFelt"
	felt.Shape = Enum.PartType.Cylinder
	felt.Size = Vector3.new(1.85, (TABLE_RADIUS - 0.7) * 2, (TABLE_RADIUS - 0.7) * 2)
	felt.CFrame = CFrame.new(TABLE_POSITION + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	felt.Anchored = true
	felt.CanCollide = true
	felt.Material = Enum.Material.Fabric
	felt.Color = Color3.fromRGB(32, 16, 14)
	felt.Parent = arena

	-- Table Pedestal Leg
	local leg = Instance.new("Part")
	leg.Name = "TablePedestal"
	leg.Shape = Enum.PartType.Cylinder
	leg.Size = Vector3.new(3.0, 3.6, 3.6)
	leg.CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	leg.Anchored = true
	leg.CanCollide = true
	leg.Material = Enum.Material.Wood
	leg.Color = Color3.fromRGB(36, 20, 14)
	leg.Parent = arena

	-- ------------------------------------------------------------------------
	-- C. Chandelier & Atmospheric Light Setup
	-- ------------------------------------------------------------------------
	-- Hanging Chandelier Stem
	local stem = Instance.new("Part")
	stem.Name = "ChandelierStem"
	stem.Size = Vector3.new(0.3, 7, 0.3)
	stem.Position = Vector3.new(0, 17.5, 0)
	stem.Anchored = true
	stem.CanCollide = false
	stem.Material = Enum.Material.Metal
	stem.Color = Color3.fromRGB(60, 48, 25)
	stem.Parent = arena

	-- Chandelier Hood & Frosted Glow Fixture
	local hood = Instance.new("Part")
	hood.Name = "ChandelierHood"
	hood.Shape = Enum.PartType.Cylinder
	hood.Size = Vector3.new(0.8, 3.6, 3.6)
	hood.CFrame = CFrame.new(0, 14.0, 0) * CFrame.Angles(0, 0, math.rad(90))
	hood.Anchored = true
	hood.CanCollide = false
	hood.Material = Enum.Material.Metal
	hood.Color = Color3.fromRGB(45, 35, 20)
	hood.Parent = arena

	local glowRing = Instance.new("Part")
	glowRing.Name = "ChandelierGlow"
	glowRing.Shape = Enum.PartType.Cylinder
	glowRing.Size = Vector3.new(0.3, 3.2, 3.2)
	glowRing.CFrame = CFrame.new(0, 13.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	glowRing.Anchored = true
	glowRing.CanCollide = false
	glowRing.Material = Enum.Material.Neon
	glowRing.Color = Color3.fromRGB(255, 235, 190)
	glowRing.Parent = arena

	-- Central Pool Light: Warm, diffused, non-shadow to avoid voxel/shadow acne
	local centerLight = Instance.new("PointLight")
	centerLight.Color = Color3.fromRGB(255, 225, 175)
	centerLight.Brightness = 1.3
	centerLight.Range = 26
	centerLight.Shadows = false -- Eliminates harsh flickering shadow artifacts
	centerLight.Parent = glowRing

	-- 4 Perimeter Wall Sconces for warm ambient fill
	local sconcePositions = {
		Vector3.new(0, 11, -33.8),
		Vector3.new(0, 11, 33.8),
		Vector3.new(33.8, 11, 0),
		Vector3.new(-33.8, 11, 0),
	}
	for i, pos in ipairs(sconcePositions) do
		local sconcePart = Instance.new("Part")
		sconcePart.Name = "Sconce_" .. i
		sconcePart.Size = Vector3.new(0.8, 1.2, 0.8)
		sconcePart.Position = pos
		sconcePart.Anchored = true
		sconcePart.CanCollide = false
		sconcePart.Material = Enum.Material.Neon
		sconcePart.Color = Color3.fromRGB(255, 215, 150)
		sconcePart.Parent = arena

		local sconceLight = Instance.new("PointLight")
		sconceLight.Color = Color3.fromRGB(255, 205, 140)
		sconceLight.Brightness = 0.5
		sconceLight.Range = 16
		sconceLight.Shadows = false
		sconceLight.Parent = sconcePart
	end

	-- Configure Lighting Post-Processing
	local cc = Lighting:FindFirstChild("SkullsColorCorrection") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "SkullsColorCorrection"
		cc.Parent = Lighting
	end
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(255, 246, 236)

	local bloom = Lighting:FindFirstChild("SkullsBloom") :: BloomEffect?
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "SkullsBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.35
	bloom.Size = 16
	bloom.Threshold = 0.9

	-- Container for 3D card stacks
	local stacksFolder = Instance.new("Folder")
	stacksFolder.Name = "TableCardStacks"
	stacksFolder.Parent = arena

	-- ------------------------------------------------------------------------
	-- D. 6 Standing Pods, Coasters, and Spawn Location
	-- ------------------------------------------------------------------------
	for seatIdx = 1, 6 do
		-- Seat 1 starts at angle 90 deg (positive Z axis, facing center)
		local angle = math.rad((seatIdx - 1) * (360 / 6) + 90)
		local dirX = math.cos(angle)
		local dirZ = math.sin(angle)

		-- 3D Card Coaster on Table Surface (Y = 3.96)
		local coasterPos = Vector3.new(TABLE_POSITION.X + dirX * COASTER_DISTANCE, 3.96, TABLE_POSITION.Z + dirZ * COASTER_DISTANCE)
		local coaster = Instance.new("Part")
		coaster.Name = "Coaster_" .. seatIdx
		coaster.Shape = Enum.PartType.Cylinder
		coaster.Size = Vector3.new(0.08, 2.7, 2.7)
		coaster.CFrame = CFrame.new(coasterPos) * CFrame.Angles(0, 0, math.rad(90))
		coaster.Anchored = true
		coaster.CanCollide = false
		coaster.Material = Enum.Material.SmoothPlastic
		coaster.Color = Color3.fromRGB(60, 38, 24)
		coaster.Parent = arena
		coasterParts[seatIdx] = coaster

		-- Gold Trim Ring on Coaster
		local trim = Instance.new("Highlight")
		trim.Name = "GoldTrim"
		trim.FillTransparency = 1
		trim.OutlineColor = Color3.fromRGB(230, 180, 50)
		trim.OutlineTransparency = 0.3
		trim.Adornee = coaster
		trim.Parent = coaster

		-- Standing Floor Pad (Brass ring on floor)
		local standPos = Vector3.new(TABLE_POSITION.X + dirX * STAND_DISTANCE, 0.05, TABLE_POSITION.Z + dirZ * STAND_DISTANCE)
		local standPad = Instance.new("Part")
		standPad.Name = "StandPad_" .. seatIdx
		standPad.Shape = Enum.PartType.Cylinder
		standPad.Size = Vector3.new(0.1, 3.4, 3.4)
		standPad.CFrame = CFrame.new(standPos) * CFrame.Angles(0, 0, math.rad(90))
		standPad.Anchored = true
		standPad.CanCollide = false
		standPad.Material = Enum.Material.Metal
		standPad.Color = Color3.fromRGB(55, 42, 28)
		standPad.Parent = arena

		-- Standing CFrame: Standing on the pad, facing directly at the table center
		local lookTarget = Vector3.new(TABLE_POSITION.X, 3.0, TABLE_POSITION.Z)
		local charStandPos = Vector3.new(standPos.X, 3.0, standPos.Z)
		standingCFrames[seatIdx] = CFrame.lookAt(charStandPos, lookTarget)

		-- Seat 1 Default Spawn Location: Engine places the joining player right on Pad 1
		if seatIdx == 1 then
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = "Seat1_SpawnLocation"
			spawn.Size = Vector3.new(3.0, 0.2, 3.0)
			spawn.CFrame = CFrame.lookAt(Vector3.new(standPos.X, 0.2, standPos.Z), lookTarget)
			spawn.Anchored = true
			spawn.CanCollide = false
			spawn.Transparency = 1
			spawn.Neutral = true
			spawn.Duration = 0 -- Eliminates the white glowing forcefield ball
			spawn.Parent = arena
		end
	end

	arenaModel = arena
	print("[TableBuilder] 3D Enclosed Arena, atmospheric lighting, and 6 pods built.")
	return arena
end

-- ============================================================================
-- 2. HELPER: CREATE OVERHEAD BILLBOARD GUI (LOCOfficial Style)
-- ============================================================================
local function createOverheadBillboard(adorneePart: BasePart, displayName: string, isBot: boolean): BillboardGui
	local bill = Instance.new("BillboardGui")
	bill.Name = "PlayerInfoTag"
	bill.Size = UDim2.new(0, 140, 0, 48)
	bill.StudsOffset = Vector3.new(0, 2.5, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = adorneePart
	bill.Parent = adorneePart

	local frame = Instance.new("Frame")
	frame.Name = "Container"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(18, 12, 10)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = bill

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "BorderStroke"
	stroke.Color = Color3.fromRGB(180, 140, 60)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	-- Player Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 0, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = Color3.fromRGB(250, 235, 205)
	nameLabel.Text = displayName .. (isBot and " [BOT]" or "")
	nameLabel.Parent = frame

	-- Score Gems Display (Two gems for 2 points to win)
	local scoreFrame = Instance.new("Frame")
	scoreFrame.Name = "ScoreRow"
	scoreFrame.Size = UDim2.new(1, 0, 0, 18)
	scoreFrame.Position = UDim2.new(0, 0, 0, 24)
	scoreFrame.BackgroundTransparency = 1
	scoreFrame.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scoreFrame

	for i = 1, 2 do
		local gem = Instance.new("TextLabel")
		gem.Name = "Gem_" .. i
		gem.Size = UDim2.new(0, 16, 0, 16)
		gem.BackgroundTransparency = 1
		gem.Font = Enum.Font.GothamBold
		gem.TextSize = 13
		gem.Text = "◇"
		gem.TextColor3 = Color3.fromRGB(120, 100, 80)
		gem.LayoutOrder = i
		gem.Parent = scoreFrame
	end

	return bill
end

-- ============================================================================
-- 3. POSITION HUMAN PLAYERS (STANDING AT POD, FACING TABLE)
-- ============================================================================
function TableBuilder.StandPlayer(player: Player, seatIndex: number)
	local targetCF = standingCFrames[seatIndex]
	if not targetCF then return end

	local function setupPlayerCharacter(char: Model)
		-- Wait for HumanoidRootPart and Humanoid to replicate
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: Part?
		local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hrp or not humanoid then return end

		-- Allow character physics and appearance loading to settle
		task.wait(0.2)

		-- Position standing directly on pad facing the table
		char:PivotTo(targetCF)
		hrp.CFrame = targetCF

		-- Anchor HumanoidRootPart so physics engine does not override position or slide character
		hrp.Anchored = true

		-- Disable locomotion for seated/standing tabletop immersion
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false

		-- Add Overhead Billboard Tag for human player
		local head = char:WaitForChild("Head", 5) :: BasePart?
		if head then
			playerBillboards[player.UserId] = createOverheadBillboard(head, player.DisplayName, false)
		end
	end

	task.spawn(function()
		if player.Character then
			setupPlayerCharacter(player.Character)
		end
		player.CharacterAdded:Connect(setupPlayerCharacter)
	end)
end

-- ============================================================================
-- 4. SPAWN STYLIZED STANDING BOT AVATARS (LOCOfficial Character Style)
-- ============================================================================
function TableBuilder.SpawnStandingBot(botName: string, seatIndex: number)
	local targetCF = standingCFrames[seatIndex]
	if not targetCF or not arenaModel then return end

	-- Clean up previous bot model at this seat if re-spawning
	if botDummies[seatIndex] then
		botDummies[seatIndex]:Destroy()
		botDummies[seatIndex] = nil
	end

	-- Personality Suit Palette per character
	local botColorThemes: { [string]: { suit: Color3, trim: Color3 } } = {
		["Doña Flor"]    = { suit = Color3.fromRGB(140, 24, 34),  trim = Color3.fromRGB(240, 200, 70) },
		["El Bandido"]   = { suit = Color3.fromRGB(38, 38, 42),   trim = Color3.fromRGB(180, 130, 60) },
		["Don Diego"]    = { suit = Color3.fromRGB(22, 44, 82),   trim = Color3.fromRGB(210, 210, 220) },
		["La Catrina"]   = { suit = Color3.fromRGB(75, 25, 88),   trim = Color3.fromRGB(245, 195, 65) },
		["Señor Hueso"]  = { suit = Color3.fromRGB(210, 205, 195), trim = Color3.fromRGB(25, 20, 22) },
	}
	local theme = botColorThemes[botName] or { suit = Color3.fromRGB(45, 32, 26), trim = Color3.fromRGB(210, 180, 60) }

	local botModel = Instance.new("Model")
	botModel.Name = "Bot_" .. botName
	botModel.Parent = arenaModel

	-- Stylized Torso (Standing upright)
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.0, 2.4, 1.2)
	torso.CFrame = targetCF
	torso.Anchored = true
	torso.CanCollide = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = theme.suit
	torso.Parent = botModel

	-- Stylized Suit Lapel Accent
	local lapel = Instance.new("Part")
	lapel.Name = "Lapel"
	lapel.Size = Vector3.new(1.0, 1.6, 0.2)
	lapel.CFrame = targetCF * CFrame.new(0, 0.3, -0.6)
	lapel.Anchored = true
	lapel.CanCollide = false
	lapel.Material = Enum.Material.SmoothPlastic
	lapel.Color = theme.trim
	lapel.Parent = botModel

	-- Stylized Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.CFrame = targetCF * CFrame.new(0, 1.9, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.Color = Color3.fromRGB(225, 190, 160)
	head.Parent = botModel

	-- Arms (Resting neatly at side)
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = Vector3.new(0.8, 2.2, 0.8)
	leftArm.CFrame = targetCF * CFrame.new(-1.4, -0.1, 0)
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Color = theme.suit
	leftArm.Parent = botModel

	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Size = Vector3.new(0.8, 2.2, 0.8)
	rightArm.CFrame = targetCF * CFrame.new(1.4, -0.1, 0)
	rightArm.Anchored = true
	rightArm.CanCollide = false
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Color = theme.suit
	rightArm.Parent = botModel

	-- Legs
	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(1.8, 2.0, 1.0)
	legs.CFrame = targetCF * CFrame.new(0, -2.1, 0)
	legs.Anchored = true
	legs.CanCollide = false
	legs.Material = Enum.Material.SmoothPlastic
	legs.Color = Color3.fromRGB(20, 18, 20)
	legs.Parent = botModel

	-- Overhead Billboard Tag for Bot
	createOverheadBillboard(head, botName, true)

	botDummies[seatIndex] = botModel
end

-- ============================================================================
-- 5. ACCESSORS & GETTERS
-- ============================================================================
function TableBuilder.GetCoasterCFrame(seatIndex: number): CFrame?
	local coaster = coasterParts[seatIndex]
	return coaster and coaster.CFrame or nil
end

function TableBuilder.GetCoasterPart(seatIndex: number): Part?
	return coasterParts[seatIndex]
end

function TableBuilder.GetStandingCFrame(seatIndex: number): CFrame?
	return standingCFrames[seatIndex]
end

return TableBuilder
