--!strict
-- TableBuilder.luau
-- Constructs the High-End Competitive Table Parlor environment (Matching the exact concept reference)
-- Features:
-- 1. Dark-wood & felt poker table with beveled leather trim & center glowing pile
-- 2. Indoor atmospheric parlor room (dark wood walls, floor neon strips, warm point lights, zero skybox)
-- 3. Individual "YOUR PILE" and "PILE" player mats with subtle glowing neon borders
-- 4. Sleek dark silhouette opponent avatars seated in black armchairs
-- 5. Floating glassmorphism gradient nametags & standing fanned circular hand displays

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)

local TableBuilder = {}

-- Spatial State
local arenaModel: Model? = nil
local standingCFrames: { [number]: CFrame } = {}
local pileMats: { [number]: Part } = {}
local botDummies: { [number]: Model } = {}
local seatBillboards: { [number]: BillboardGui } = {}
local opponentHands: { [number]: Model } = {}
local cardCountLabels: { [number]: TextLabel } = {}

-- Table Seat Coordinates (4-Player Layout: 1=Front/You, 2=Left, 3=Back, 4=Right)
local SEAT_CONFIGS = {
	[1] = { -- You (Front) - Centered directly in front
		standPos = Vector3.new(0, 3.4, 7.8),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(0, 3.06, 4.4),
		isLocal = true,
		label = "YOUR PILE",
	},
	[2] = { -- Left (BLUFFER_99) - Centered directly in front
		standPos = Vector3.new(-7.8, 3.4, 0),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(-4.4, 3.06, 0),
		handPos = Vector3.new(-5.8, 3.3, 0),
		handRotY = math.rad(90),
		isLocal = false,
		label = "PILE",
	},
	[3] = { -- Back (BLUFFE_99) - Centered directly in front
		standPos = Vector3.new(0, 3.4, -7.8),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(0, 3.06, -4.4),
		handPos = Vector3.new(0, 3.3, -5.8),
		handRotY = math.rad(180),
		isLocal = false,
		label = "PILE",
	},
	[4] = { -- Right (ROSE_KING) - Centered directly in front
		standPos = Vector3.new(7.8, 3.4, 0),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(4.4, 3.06, 0),
		handPos = Vector3.new(5.8, 3.3, 0),
		handRotY = math.rad(-90),
		isLocal = false,
		label = "PILE",
	},
}

-- ============================================================================
-- 1. BUILD THE COMPLETE PARLOR ROOM & TABLE
-- ============================================================================
function TableBuilder.Build()
	local existing = Workspace:FindFirstChild("SkullsArena")
	if existing then existing:Destroy() end

	table.clear(standingCFrames)
	table.clear(pileMats)
	table.clear(botDummies)
	table.clear(seatBillboards)
	table.clear(opponentHands)
	table.clear(cardCountLabels)

	local arena = Instance.new("Model")
	arena.Name = "SkullsArena"
	arena.Parent = Workspace
	arenaModel = arena

	-- Relocate baseplate so it never interferes
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Position = Vector3.new(0, -500, 0)
		baseplate.Transparency = 1
		baseplate.CanCollide = false
	end

	-- 1. Atmosphere & Lighting: Warm vibrant game-room lighting (High contrast, bright table)
	pcall(function()
		Lighting.GlobalShadows = false
		Lighting.Brightness = 2.2
		Lighting.ClockTime = 0.0 -- Midnight indoor
		Lighting.Ambient = Color3.fromRGB(115, 95, 90)
		Lighting.OutdoorAmbient = Color3.fromRGB(55, 45, 50)
		Lighting.FogEnd = 1000

		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then sky:Destroy() end
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then atmosphere:Destroy() end
	end)

	-- 2. Complete Enclosed Room (No sky visible anywhere)
	local ROOM_SIZE = 48
	local ROOM_HEIGHT = 20
	local wallColor = Color3.fromRGB(36, 22, 18) -- Warm dark mahogany wood
	local floorColor = Color3.fromRGB(22, 18, 18) -- Dark floor

	local roomFolder = Instance.new("Folder")
	roomFolder.Name = "RoomEnclosure"
	roomFolder.Parent = arena

	local function makeWall(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = true
		p.CastShadow = false
		p.Color = color
		p.Material = mat
		p.Parent = roomFolder
		return p
	end

	-- Floor & Ceiling
	makeWall("Floor", Vector3.new(ROOM_SIZE, 2, ROOM_SIZE), CFrame.new(0, -1, 0), floorColor, Enum.Material.WoodPlanks)
	makeWall("Ceiling", Vector3.new(ROOM_SIZE, 2, ROOM_SIZE), CFrame.new(0, ROOM_HEIGHT, 0), Color3.fromRGB(25, 20, 20), Enum.Material.SmoothPlastic)

	-- 4 Walls
	makeWall("Wall_North", Vector3.new(ROOM_SIZE, ROOM_HEIGHT, 2), CFrame.new(0, ROOM_HEIGHT / 2, -ROOM_SIZE / 2), wallColor, Enum.Material.WoodPlanks)
	makeWall("Wall_South", Vector3.new(ROOM_SIZE, ROOM_HEIGHT, 2), CFrame.new(0, ROOM_HEIGHT / 2, ROOM_SIZE / 2), wallColor, Enum.Material.WoodPlanks)
	makeWall("Wall_East", Vector3.new(2, ROOM_HEIGHT, ROOM_SIZE), CFrame.new(ROOM_SIZE / 2, ROOM_HEIGHT / 2, 0), wallColor, Enum.Material.WoodPlanks)
	makeWall("Wall_West", Vector3.new(2, ROOM_HEIGHT, ROOM_SIZE), CFrame.new(-ROOM_SIZE / 2, ROOM_HEIGHT / 2, 0), wallColor, Enum.Material.WoodPlanks)

	-- Floor Crimson Neon Accent Strips (Matching the concept reference)
	local neonFloor1 = Instance.new("Part")
	neonFloor1.Name = "NeonFloorStrip_Left"
	neonFloor1.Size = Vector3.new(1.2, 0.05, 18)
	neonFloor1.CFrame = CFrame.new(-8.8, 0.03, 0) * CFrame.Angles(0, math.rad(25), 0)
	neonFloor1.Anchored = true
	neonFloor1.CanCollide = false
	neonFloor1.Material = Enum.Material.Neon
	neonFloor1.Color = Color3.fromRGB(255, 35, 50)
	neonFloor1.Parent = roomFolder

	local neonFloor2 = Instance.new("Part")
	neonFloor2.Name = "NeonFloorStrip_Right"
	neonFloor2.Size = Vector3.new(1.2, 0.05, 18)
	neonFloor2.CFrame = CFrame.new(8.8, 0.03, 0) * CFrame.Angles(0, math.rad(-25), 0)
	neonFloor2.Anchored = true
	neonFloor2.CanCollide = false
	neonFloor2.Material = Enum.Material.Neon
	neonFloor2.Color = Color3.fromRGB(255, 35, 50)
	neonFloor2.Parent = roomFolder

	-- Ceiling Amber PointLight over Table
	local lightPart = Instance.new("Part")
	lightPart.Name = "CeilingChandelier"
	lightPart.Size = Vector3.new(4, 0.5, 4)
	lightPart.CFrame = CFrame.new(0, ROOM_HEIGHT - 2, 0)
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.Transparency = 1
	lightPart.Parent = arena

	local tableLight = Instance.new("PointLight")
	tableLight.Color = Color3.fromRGB(255, 230, 200)
	tableLight.Brightness = 2.4
	tableLight.Range = 36
	tableLight.Shadows = false
	tableLight.Parent = lightPart

	-- Additional warm fill light directly over table felt
	local centerLightPart = Instance.new("Part")
	centerLightPart.Name = "TableCenterLight"
	centerLightPart.Size = Vector3.new(1, 1, 1)
	centerLightPart.CFrame = CFrame.new(0, 5.2, 0.4)
	centerLightPart.Anchored = true
	centerLightPart.CanCollide = false
	centerLightPart.Transparency = 1
	centerLightPart.Parent = arena

	local feltFillLight = Instance.new("PointLight")
	feltFillLight.Color = Color3.fromRGB(255, 235, 210)
	feltFillLight.Brightness = 2.2
	feltFillLight.Range = 26
	feltFillLight.Shadows = false
	feltFillLight.Parent = centerLightPart

	-- Dedicated Spotlight brightly illuminating Seat 1's "YOUR PILE" (Centered in front)
	local pileSpotPart = Instance.new("Part")
	pileSpotPart.Name = "YourPileSpotlight"
	pileSpotPart.Size = Vector3.new(1, 1, 1)
	pileSpotPart.CFrame = CFrame.new(0, 7.0, 4.4)
	pileSpotPart.Anchored = true
	pileSpotPart.CanCollide = false
	pileSpotPart.Transparency = 1
	pileSpotPart.Parent = arena

	local yourPileSpot = Instance.new("SpotLight")
	yourPileSpot.Color = Color3.fromRGB(255, 235, 185)
	yourPileSpot.Brightness = 3.0
	yourPileSpot.Range = 12
	yourPileSpot.Angle = 70
	yourPileSpot.Face = Enum.NormalId.Bottom
	yourPileSpot.Parent = pileSpotPart

	-- 3. The Brightened Wood & Felt Table with Glowing Neon Red & Gold LED Highlights
	local tableModel = Instance.new("Model")
	tableModel.Name = "PokerTable"
	tableModel.Parent = arena

	-- Table Base Pedestal
	local pedestal = Instance.new("Part")
	pedestal.Name = "Pedestal"
	pedestal.Size = Vector3.new(8, 2.6, 8)
	pedestal.CFrame = CFrame.new(0, 1.3, 0)
	pedestal.Anchored = true
	pedestal.CanCollide = true
	pedestal.Material = Enum.Material.Wood
	pedestal.Color = Color3.fromRGB(24, 18, 18)
	pedestal.Parent = tableModel

	-- Warm Velvet Main Felt Surface (18-stud diameter cylinder)
	local feltTop = Instance.new("Part")
	feltTop.Name = "FeltSurface"
	feltTop.Shape = Enum.PartType.Cylinder
	feltTop.Size = Vector3.new(0.4, 18, 18)
	feltTop.CFrame = CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	feltTop.Anchored = true
	feltTop.CanCollide = true
	feltTop.Material = Enum.Material.SmoothPlastic
	feltTop.Color = Color3.fromRGB(36, 30, 40) -- Rich warm velvet felt
	feltTop.Parent = tableModel

	-- Elevated Polished Mahogany Outer Armrest / Rim
	local tableRim = Instance.new("Part")
	tableRim.Name = "TableRim"
	tableRim.Shape = Enum.PartType.Cylinder
	tableRim.Size = Vector3.new(0.5, 19.4, 19.4)
	tableRim.CFrame = CFrame.new(0, 2.85, 0) * CFrame.Angles(0, 0, math.rad(90))
	tableRim.Anchored = true
	tableRim.CanCollide = false
	tableRim.Material = Enum.Material.WoodPlanks
	tableRim.Color = Color3.fromRGB(48, 26, 20) -- Polished warm mahogany wood
	tableRim.Parent = tableModel

	-- Glowing Neon Crimson LED Ring around Outer Perimeter
	local outerNeonLed = Instance.new("Part")
	outerNeonLed.Name = "OuterNeonLed"
	outerNeonLed.Shape = Enum.PartType.Cylinder
	outerNeonLed.Size = Vector3.new(0.08, 19.65, 19.65)
	outerNeonLed.CFrame = CFrame.new(0, 2.88, 0) * CFrame.Angles(0, 0, math.rad(90))
	outerNeonLed.Anchored = true
	outerNeonLed.CanCollide = false
	outerNeonLed.Material = Enum.Material.Neon
	outerNeonLed.Color = Color3.fromRGB(255, 35, 50)
	outerNeonLed.Parent = tableModel

	-- Glowing Neon Gold LED Ring around Felt Border
	local innerNeonLed = Instance.new("Part")
	innerNeonLed.Name = "InnerNeonLed"
	innerNeonLed.Shape = Enum.PartType.Cylinder
	innerNeonLed.Size = Vector3.new(0.06, 17.6, 17.6)
	innerNeonLed.CFrame = CFrame.new(0, 2.84, 0) * CFrame.Angles(0, 0, math.rad(90))
	innerNeonLed.Anchored = true
	innerNeonLed.CanCollide = false
	innerNeonLed.Material = Enum.Material.Neon
	innerNeonLed.Color = Color3.fromRGB(255, 215, 65)
	innerNeonLed.Parent = tableModel

	-- 4. Center Glowing Circular Pile (Piled with cards & sparkling embers)
	local centerPile = Instance.new("Part")
	centerPile.Name = "CenterGlowingPile"
	centerPile.Shape = Enum.PartType.Cylinder
	centerPile.Size = Vector3.new(0.04, 5.2, 5.2)
	centerPile.CFrame = CFrame.new(0, 3.02, 0) * CFrame.Angles(0, 0, math.rad(90))
	centerPile.Anchored = true
	centerPile.CanCollide = false
	centerPile.Material = Enum.Material.Neon
	centerPile.Color = Color3.fromRGB(255, 235, 210)
	centerPile.Transparency = 0.25
	centerPile.Parent = tableModel

	-- Floating spark/ember particles rising from center glowing circle
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "CenterEmbers"
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 160))
	particles.LightEmission = 0.85
	particles.Size = NumberSequence.new(0.14, 0.04)
	particles.Transparency = NumberSequence.new(0.1, 1.0)
	particles.Lifetime = NumberRange.new(1.2, 2.2)
	particles.Rate = 18
	particles.Speed = NumberRange.new(0.8, 1.6)
	particles.SpreadAngle = Vector2.new(35, 35)
	particles.EmissionDirection = Enum.NormalId.Right
	particles.Parent = centerPile

	-- 5. Individual Player Mats ("YOUR PILE" and "PILE")
	for seatIdx, cfg in pairs(SEAT_CONFIGS) do
		standingCFrames[seatIdx] = CFrame.lookAt(cfg.standPos, cfg.lookAt)

		-- Rounded Square Mat Part on Table
		local mat = Instance.new("Part")
		mat.Name = "PlayerMat_" .. seatIdx
		mat.Size = Vector3.new(3.4, 0.04, 3.4)
		mat.CFrame = CFrame.new(cfg.pilePos.X, 3.03, cfg.pilePos.Z)
		mat.Anchored = true
		mat.CanCollide = false
		mat.Material = Enum.Material.SmoothPlastic
		mat.Color = Color3.fromRGB(22, 20, 25)
		mat.Parent = tableModel
		pileMats[seatIdx] = mat

		-- Energetic spark particle emitter for active turns
		local turnSparks = Instance.new("ParticleEmitter")
		turnSparks.Name = "TurnSparks"
		turnSparks.Color = ColorSequence.new(Color3.fromRGB(255, 225, 110))
		turnSparks.LightEmission = 0.95
		turnSparks.Size = NumberSequence.new(0.14, 0.02)
		turnSparks.Transparency = NumberSequence.new(0.1, 1.0)
		turnSparks.Lifetime = NumberRange.new(0.8, 1.4)
		turnSparks.Rate = 18
		turnSparks.Speed = NumberRange.new(1.0, 2.0)
		turnSparks.SpreadAngle = Vector2.new(45, 45)
		turnSparks.EmissionDirection = Enum.NormalId.Top
		turnSparks.Enabled = (seatIdx == 1) -- initially active for placement
		turnSparks.Parent = mat

		-- SurfaceGui on Mat
		local matSg = Instance.new("SurfaceGui")
		matSg.Name = "MatGui"
		matSg.Face = Enum.NormalId.Top
		matSg.CanvasSize = Vector2.new(256, 256)
		matSg.Adornee = mat
		matSg.Parent = mat

		local matFrame = Instance.new("Frame")
		matFrame.Size = UDim2.new(1, -8, 1, -8)
		matFrame.Position = UDim2.new(0, 4, 0, 4)
		matFrame.BackgroundColor3 = Color3.fromRGB(20, 18, 24)
		matFrame.BorderSizePixel = 0
		matFrame.Parent = matSg
		Instance.new("UICorner", matFrame).CornerRadius = UDim.new(0, 16)

		local matStroke = Instance.new("UIStroke")
		matStroke.Name = "MatBorder"
		matStroke.Color = cfg.isLocal and Color3.fromRGB(255, 235, 180) or Color3.fromRGB(200, 200, 215)
		matStroke.Transparency = 0.35
		matStroke.Thickness = 2.8
		matStroke.Parent = matFrame

		-- Glowing Neon Ring Drop Zone in center of mat
		local ring = Instance.new("Frame")
		ring.Name = "DropZoneRing"
		ring.Size = UDim2.new(0, 160, 0, 160)
		ring.Position = UDim2.new(0.5, -80, 0.5, -92)
		ring.BackgroundTransparency = 1
		ring.Parent = matFrame
		Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

		local ringStroke = Instance.new("UIStroke")
		ringStroke.Name = "NeonRingGlow"
		ringStroke.Color = cfg.isLocal and Color3.fromRGB(255, 215, 140) or Color3.fromRGB(255, 235, 200)
		ringStroke.Thickness = 4.5
		ringStroke.Parent = ring

		-- Mat Label: "YOUR PILE" or "PILE"
		local label = Instance.new("TextLabel")
		label.Name = "MatLabel"
		label.Size = UDim2.new(1, 0, 0, 26)
		label.Position = UDim2.new(0, 0, 1, -30)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 22
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeTransparency = 0.35
		label.TextStrokeColor3 = Color3.fromRGB(15, 15, 20)
		label.Text = cfg.label
		label.Parent = matFrame

		-- Seat 1 Spawn Location (anchored right at the front seat)
		if seatIdx == 1 then
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = "Seat1_SpawnLocation"
			spawn.Size = Vector3.new(2, 0.2, 2)
			spawn.CFrame = CFrame.new(cfg.standPos.X, 1.0, cfg.standPos.Z)
			spawn.Anchored = true
			spawn.CanCollide = false
			spawn.Transparency = 1
			spawn.Neutral = true
			spawn.Duration = 0
			spawn.Parent = arena
		end
	end

	-- 6. Sleek Black Armchairs Behind Each Seat
	for seatIdx, cfg in pairs(SEAT_CONFIGS) do
		local chairCF = CFrame.lookAt(cfg.standPos, cfg.lookAt)
		local chair = Instance.new("Part")
		chair.Name = "Armchair_" .. seatIdx
		chair.Size = Vector3.new(3.2, 3.6, 2.4)
		chair.CFrame = chairCF * CFrame.new(0, -0.6, 0.8)
		chair.Anchored = true
		chair.CanCollide = true
		chair.Material = Enum.Material.SmoothPlastic
		chair.Color = Color3.fromRGB(18, 16, 20) -- Sleek matte black armchair
		chair.Parent = tableModel
	end

	-- Stacks Container
	local stacksFolder = Instance.new("Folder")
	stacksFolder.Name = "TableCardStacks"
	stacksFolder.Parent = arena

	print("[TableBuilder] High-end competitive table parlor built successfully.")
	return arena
end

-- ============================================================================
-- 2. CREATE SLEEK FROSTED GLASSPHISM PLAYER NAMETAGS (Matching Reference)
-- ============================================================================
local function createPlayerTag(adornee: BasePart, displayName: string, seatIdx: number): BillboardGui
	local bill = Instance.new("BillboardGui")
	bill.Name = "PlayerInfoTag"
	bill.Size = UDim2.new(0, 220, 0, 48)
	bill.StudsOffset = Vector3.new(0, 2.8, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = adornee
	bill.Parent = adornee

	-- Gradient theme per seat (matching reference: Left=cyan/yellow, Back=cyan/pink, Right=orange/pink)
	local gradientColors = {
		[2] = { ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 225, 245)), ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 235, 100)) },
		[3] = { ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 220, 245)), ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 110, 180)) },
		[4] = { ColorSequenceKeypoint.new(0, Color3.fromRGB(250, 140, 50)), ColorSequenceKeypoint.new(1, Color3.fromRGB(245, 95, 145)) },
	}

	-- Capsule background
	local capsule = Instance.new("Frame")
	capsule.Name = "TagCapsule"
	capsule.Size = UDim2.new(1, 0, 1, 0)
	capsule.BackgroundColor3 = Color3.fromRGB(18, 16, 22)
	capsule.BackgroundTransparency = 0.25
	capsule.BorderSizePixel = 0
	capsule.Parent = bill
	Instance.new("UICorner", capsule).CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke")
	stroke.Name = "TagStroke"
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = capsule

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(gradientColors[seatIdx] or gradientColors[2])
	grad.Parent = stroke

	-- Avatar Icon Circle
	local avatarCircle = Instance.new("Frame")
	avatarCircle.Name = "AvatarCircle"
	avatarCircle.Size = UDim2.new(0, 36, 0, 36)
	avatarCircle.Position = UDim2.new(0, 6, 0.5, -18)
	avatarCircle.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	avatarCircle.Parent = capsule
	Instance.new("UICorner", avatarCircle).CornerRadius = UDim.new(1, 0)

	local aIcon = Instance.new("TextLabel")
	aIcon.Name = "IconLabel"
	aIcon.Size = UDim2.new(1, 0, 1, 0)
	aIcon.BackgroundTransparency = 1
	aIcon.Font = Enum.Font.FredokaOne
	aIcon.TextSize = 20
	aIcon.TextColor3 = Color3.fromRGB(220, 225, 235)
	aIcon.Text = "👤"
	aIcon.Parent = avatarCircle

	-- Player Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -95, 1, 0)
	nameLabel.Position = UDim2.new(0, 48, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 16
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = displayName
	nameLabel.Parent = capsule

	-- Locofficial-style Floating Card Count Badge
	local countBadge = Instance.new("Frame")
	countBadge.Name = "CardCountBadge"
	countBadge.Size = UDim2.new(0, 38, 0, 32)
	countBadge.Position = UDim2.new(1, -44, 0.5, -16)
	countBadge.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
	countBadge.BorderSizePixel = 0
	countBadge.Parent = capsule
	Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 8)

	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(25, 20, 32)
	bStroke.Thickness = 1.6
	bStroke.Parent = countBadge

	local cText = Instance.new("TextLabel")
	cText.Name = "CountText"
	cText.Size = UDim2.new(1, 0, 1, 0)
	cText.BackgroundTransparency = 1
	cText.Font = Enum.Font.FredokaOne
	cText.TextSize = 17
	cText.TextColor3 = Color3.fromRGB(20, 18, 25)
	cText.Text = "4"
	cText.Parent = countBadge
	cardCountLabels[seatIdx] = cText

	return bill
end

-- ============================================================================
-- 3. RENDER OPPONENT FANNED CIRCULAR CARDS (Matching Reference Hands)
-- ============================================================================
local function renderOpponentFannedHand(seatIdx: number, cardCount: number)
	if seatIdx == 1 or not arenaModel then return end
	local cfg = SEAT_CONFIGS[seatIdx]
	if not cfg or not cfg.handPos then return end

	local existing = opponentHands[seatIdx]
	if existing and existing.Parent then
		existing:Destroy()
	end

	if cardCount <= 0 then return end

	local handModel = Instance.new("Model")
	handModel.Name = "OpponentHand_" .. seatIdx
	handModel.Parent = arenaModel
	opponentHands[seatIdx] = handModel

	local TOKEN_DIAMETER = 1.35
	local SPACING = 0.55
	local startX = -(cardCount - 1) * SPACING / 2

	for i = 1, cardCount do
		local xOff = startX + (i - 1) * SPACING
		local tokenCF = CFrame.new(cfg.handPos)
			* CFrame.Angles(0, cfg.handRotY or 0, 0)
			* CFrame.new(xOff, 0, (i - 1) * 0.08)
			* CFrame.Angles(0, 0, math.rad(90))

		local token = Instance.new("Part")
		token.Name = "HandToken_" .. i
		token.Shape = Enum.PartType.Cylinder
		token.Size = Vector3.new(0.06, TOKEN_DIAMETER, TOKEN_DIAMETER)
		token.CFrame = tokenCF
		token.Anchored = true
		token.CanCollide = false
		token.Material = Enum.Material.SmoothPlastic
		token.Color = Color3.fromRGB(26, 22, 32) -- Sleek dark backing
		token.Parent = handModel

		-- Attach identical card backs to both faces so cards are 100% unpeekable (Locofficial style)
		for _, faceNormal in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
			local sg = Instance.new("SurfaceGui")
			sg.Name = "TokenGui_" .. faceNormal.Name
			sg.Face = faceNormal
			sg.CanvasSize = Vector2.new(128, 128)
			sg.Adornee = token
			sg.Parent = token

			local bg = Instance.new("Frame")
			bg.Size = UDim2.new(1, 0, 1, 0)
			bg.BackgroundColor3 = Color3.fromRGB(26, 22, 32)
			bg.BorderSizePixel = 0
			bg.Parent = sg
			Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

			local tStroke = Instance.new("UIStroke")
			tStroke.Color = Color3.fromRGB(245, 205, 80) -- Gold rim
			tStroke.Thickness = 2.6
			tStroke.Parent = bg

			local inner = Instance.new("Frame")
			inner.Size = UDim2.new(1, -12, 1, -12)
			inner.Position = UDim2.new(0, 6, 0, 6)
			inner.BackgroundTransparency = 1
			inner.Parent = bg
			Instance.new("UICorner", inner).CornerRadius = UDim.new(1, 0)

			local innerStroke = Instance.new("UIStroke")
			innerStroke.Color = Color3.fromRGB(255, 230, 140)
			innerStroke.Transparency = 0.45
			innerStroke.Thickness = 1.4
			innerStroke.Parent = inner

			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.new(1, 0, 1, 0)
			icon.BackgroundTransparency = 1
			icon.Font = Enum.Font.FredokaOne
			icon.TextSize = 52
			icon.TextColor3 = Color3.fromRGB(245, 210, 80)
			icon.Text = "✦" -- Anonymous geometric luxury medallion emblem
			icon.Parent = bg
		end
	end
end

-- ============================================================================
-- 4. SPAWN SLEEK DARK BOT AVATARS (Matching Concept Reference)
-- ============================================================================
function TableBuilder.SpawnStandingBot(botName: string, seatIndex: number)
	local cfg = SEAT_CONFIGS[seatIndex]
	if not cfg or not arenaModel then return end

	if botDummies[seatIndex] and botDummies[seatIndex].Parent then
		botDummies[seatIndex]:Destroy()
		botDummies[seatIndex] = nil
	end

	local targetCF = CFrame.lookAt(cfg.standPos, cfg.lookAt)

	local botModel = Instance.new("Model")
	botModel.Name = "Bot_" .. botName
	botModel.Parent = arenaModel

	-- Sleek matte black silhouette torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.4, 2.6, 1.4)
	torso.CFrame = targetCF * CFrame.new(0, -0.2, 0)
	torso.Anchored = true
	torso.CanCollide = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = Color3.fromRGB(15, 14, 18) -- Pure dark silhouette
	torso.Parent = botModel

	-- Silhouette Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.CFrame = targetCF * CFrame.new(0, 1.8, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.Color = Color3.fromRGB(15, 14, 18)
	head.Parent = botModel

	-- Left and Right blocky arms holding cards
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = Vector3.new(1.0, 2.4, 1.0)
	leftArm.CFrame = targetCF * CFrame.new(-1.6, -0.2, -0.4) * CFrame.Angles(math.rad(-25), 0, math.rad(-15))
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Color = Color3.fromRGB(15, 14, 18)
	leftArm.Parent = botModel

	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Size = Vector3.new(1.0, 2.4, 1.0)
	rightArm.CFrame = targetCF * CFrame.new(1.6, -0.2, -0.4) * CFrame.Angles(math.rad(-25), 0, math.rad(15))
	rightArm.Anchored = true
	rightArm.CanCollide = false
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Color = Color3.fromRGB(15, 14, 18)
	rightArm.Parent = botModel

	-- Floating Frosted Glass Nametag Banner above pile
	seatBillboards[seatIndex] = createPlayerTag(head, botName, seatIndex)
	botDummies[seatIndex] = botModel

	-- Render starting circular tokens in hand (4 tokens)
	renderOpponentFannedHand(seatIndex, 4)
	print("[TableBuilder] Spawned sleek bot:", botName, "at seat", seatIndex)
end

-- Position human player
function TableBuilder.StandPlayer(player: Player, seatIndex: number)
	local cfg = SEAT_CONFIGS[seatIndex]
	if not cfg then return end

	local function setupChar(char: Model)
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: Part?
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hrp or not hum then return end

		task.wait(0.1)
		local cf = CFrame.lookAt(cfg.standPos, cfg.lookAt)
		char:PivotTo(cf)
		hrp.CFrame = cf
		hrp.Anchored = true
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end

	task.spawn(function()
		if player.Character then setupChar(player.Character) end
		player.CharacterAdded:Connect(setupChar)
	end)
end

-- ============================================================================
-- 5. VISUAL POLISH & TURNS (Spark particle effects on active zones)
-- ============================================================================
function TableBuilder.HighlightTurn(activeSeatIndex: number?)
	for seatIdx, mat in pairs(pileMats) do
		local isActive = (activeSeatIndex ~= nil and seatIdx == activeSeatIndex)
		local matSg = mat:FindFirstChild("MatGui") :: SurfaceGui?
		local matFrame = matSg and matSg:FindFirstChild("Frame") :: Frame?
		local ring = matFrame and matFrame:FindFirstChild("DropZoneRing") :: Frame?
		local ringStroke = ring and ring:FindFirstChild("NeonRingGlow") :: UIStroke?
		if ringStroke then
			ringStroke.Color = isActive and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(255, 230, 180)
			ringStroke.Thickness = isActive and 6.0 or 3.5
		end
		local sparks = mat:FindFirstChild("TurnSparks") :: ParticleEmitter?
		if sparks then
			sparks.Enabled = isActive
		end
	end
end

function TableBuilder.UpdateScore(_seatIndex: number, _score: number)
	-- Score managed in top HUD
end

function TableBuilder.UpdateCardCount(seatIndex: number, count: number)
	renderOpponentFannedHand(seatIndex, count)
	local label = cardCountLabels[seatIndex]
	if label then
		label.Text = tostring(math.max(0, count))
	end
end

function TableBuilder.SetBotEmote(seatIndex: number, emote: string)
	local bill = seatBillboards[seatIndex]
	if not bill then return end
	local capsule = bill:FindFirstChild("TagCapsule") :: Frame?
	if not capsule then return end
	local avatarCircle = capsule:FindFirstChild("AvatarCircle") :: Frame?
	if not avatarCircle then return end
	local aIcon = avatarCircle:FindFirstChild("IconLabel") or avatarCircle:FindFirstChildWhichIsA("TextLabel")
	if aIcon and aIcon:IsA("TextLabel") then
		aIcon.Text = emote
	end
end

-- Accessors
function TableBuilder.GetCoasterCFrame(seatIndex: number): CFrame?
	local mat = pileMats[seatIndex]
	if not mat then return nil end
	return mat.CFrame * CFrame.new(0, 0.04, 0)
end

function TableBuilder.GetCoasterPart(seatIndex: number): Part?
	return pileMats[seatIndex]
end

function TableBuilder.GetStandingCFrame(seatIndex: number): CFrame?
	return standingCFrames[seatIndex]
end

return TableBuilder
