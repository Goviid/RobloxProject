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
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Theme = require(ReplicatedStorage.Shared.Theme)

local TableBuilder = {}

-- Spatial State
local arenaModel: Model? = nil
local standingCFrames: { [number]: CFrame } = {}
local pileMats: { [number]: Part } = {}
local botDummies: { [number]: Model } = {}
local seatBillboards: { [number]: BillboardGui } = {}
local opponentHands: { [number]: Model } = {}
local seatCardSets: { [number]: string } = {} -- CardArt set per seat (card backs)
local pileCounters: { [number]: BillboardGui } = {} -- "N cards" label beside each pile
local cardCountLabels: { [number]: TextLabel } = {}
local scoreLabels: { [number]: TextLabel } = {}
-- Last known per-seat status, re-applied when a tag is rebuilt (e.g. a player respawns)
local seatStatus: { [number]: { score: number, cards: number, eliminated: boolean } } = {}
-- One respawn hook per player, replaced whenever they are re-seated
local standConnections: { [Player]: RBXScriptConnection } = {}

local function setStandHook(player: Player, place: (char: Model) -> ())
	local old = standConnections[player]
	if old then
		old:Disconnect()
	end
	standConnections[player] = player.CharacterAdded:Connect(place)
	if player.Character then
		task.spawn(place, player.Character)
	end
end

-- Table Seat Coordinates (4-Player Layout: 1=Front/You, 2=Left, 3=Back, 4=Right)
local SEAT_CONFIGS = {
	[1] = { -- You (Front) - Centered directly in front
		standPos = Vector3.new(0, 3.4, 7.8),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(0, 3.06, 4.4),
		handPos = Vector3.new(0, 4.4, 6.5),
		isLocal = true,
		label = "PILE", -- each client relabels its own mat "YOUR PILE" locally
	},
	[2] = { -- Left (BLUFFER_99) - Centered directly in front
		standPos = Vector3.new(-7.8, 3.4, 0),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(-4.4, 3.06, 0),
		handPos = Vector3.new(-6.5, 4.4, 0),
		isLocal = false,
		label = "PILE",
	},
	[3] = { -- Back (BLUFFE_99) - Centered directly in front
		standPos = Vector3.new(0, 3.4, -7.8),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(0, 3.06, -4.4),
		handPos = Vector3.new(0, 4.4, -6.5),
		isLocal = false,
		label = "PILE",
	},
	[4] = { -- Right (ROSE_KING) - Centered directly in front
		standPos = Vector3.new(7.8, 3.4, 0),
		lookAt = Vector3.new(0, 3.0, 0),
		pilePos = Vector3.new(4.4, 3.06, 0),
		handPos = Vector3.new(6.5, 4.4, 0),
		isLocal = false,
		label = "PILE",
	},
}

-- ============================================================================
-- 1. BUILD THE COMPLETE PARLOR ROOM & TABLE
-- ============================================================================
function TableBuilder.Build()
	local existing = Workspace:FindFirstChild("SkullsArena")
	if existing then
		existing:Destroy()
	end

	table.clear(standingCFrames)
	table.clear(pileMats)
	table.clear(botDummies)
	table.clear(seatBillboards)
	table.clear(opponentHands)
	table.clear(cardCountLabels)
	table.clear(scoreLabels)
	table.clear(pileCounters)

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
		if sky then
			sky:Destroy()
		end
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			atmosphere:Destroy()
		end
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
		matFrame.Position = UDim2.fromOffset(4, 4)
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
		ring.Size = UDim2.fromOffset(160, 160)
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
		label.TextStrokeTransparency = 0.15
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
local applySeatStatus: (seatIdx: number) -> ()

local function createPlayerTag(adornee: BasePart, displayName: string, seatIdx: number, hideFrom: Player?): BillboardGui
	local old = adornee:FindFirstChild("PlayerInfoTag")
	if old then
		old:Destroy()
	end

	local bill = Instance.new("BillboardGui")
	bill.Name = "PlayerInfoTag"
	if hideFrom then
		bill.PlayerToHideFrom = hideFrom -- your own tag would just block your view
	end
	bill.Size = UDim2.fromOffset(220, 56)
	bill.StudsOffset = Vector3.new(0, 2.8, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = adornee
	bill.Parent = adornee


	-- Capsule background
	local capsule = Instance.new("Frame")
	capsule.Name = "TagCapsule"
	capsule.Size = UDim2.fromScale(1, 1)
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

	-- Outline runs from the player's card colour into gold (set in applySeatStatus)
	local grad = Instance.new("UIGradient")
	grad.Name = "TagGradient"
	grad.Parent = stroke

	-- Avatar Icon Circle
	local avatarCircle = Instance.new("Frame")
	avatarCircle.Name = "AvatarCircle"
	avatarCircle.Size = UDim2.fromOffset(36, 36)
	avatarCircle.Position = UDim2.new(0, 6, 0.5, -18)
	avatarCircle.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	avatarCircle.Parent = capsule
	Instance.new("UICorner", avatarCircle).CornerRadius = UDim.new(1, 0)

	local aIcon = Instance.new("TextLabel")
	aIcon.Name = "IconLabel"
	aIcon.Size = UDim2.fromScale(1, 1)
	aIcon.BackgroundTransparency = 1
	aIcon.Font = Enum.Font.FredokaOne
	aIcon.TextSize = 20
	aIcon.TextColor3 = Color3.fromRGB(220, 225, 235)
	aIcon.Text = "👤"
	aIcon.Parent = avatarCircle

	-- Player Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -95, 0.58, 0)
	nameLabel.Position = UDim2.new(0, 48, 0.06, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = Theme.TextSize.Label
	Theme.Outline(nameLabel, 0.6)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = displayName
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = capsule

	-- Points toward the win, as pips (gold = scored)
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(1, -95, 0.36, 0)
	scoreLabel.Position = UDim2.new(0, 48, 0.58, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Font = Enum.Font.FredokaOne
	scoreLabel.TextSize = 15
	Theme.Outline(scoreLabel, 0.6)
	scoreLabel.RichText = true
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Text = ""
	scoreLabel.Parent = capsule
	scoreLabels[seatIdx] = scoreLabel

	-- Lives: one small card shape per card the player still owns (hand + table), so it
	-- can't be confused with the pile counter's number. A skull replaces them when out.
	local countBadge = Instance.new("Frame")
	countBadge.Name = "CardCountBadge"
	countBadge.Size = UDim2.fromOffset(44, 32)
	countBadge.Position = UDim2.new(1, -50, 0.5, -16)
	countBadge.BackgroundColor3 = Theme.Colors.Backing
	countBadge.BorderSizePixel = 0
	countBadge.Parent = capsule
	Instance.new("UICorner", countBadge).CornerRadius = UDim.new(0, 8)

	local lives = Instance.new("Frame")
	lives.Name = "Lives"
	lives.Size = UDim2.fromScale(1, 1)
	lives.BackgroundTransparency = 1
	lives.Parent = countBadge
	local livesLayout = Instance.new("UIListLayout")
	livesLayout.FillDirection = Enum.FillDirection.Horizontal
	livesLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	livesLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	livesLayout.Padding = UDim.new(0, 2)
	livesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	livesLayout.Parent = lives
	for i = 1, Constants.CARDS_PER_PLAYER do
		local pip = Instance.new("Frame")
		pip.Name = "Life" .. i
		pip.LayoutOrder = i
		pip.Size = UDim2.fromOffset(7, 16)
		pip.BorderSizePixel = 0
		pip.Parent = lives
		Instance.new("UICorner", pip).CornerRadius = UDim.new(0, 2)
	end

	local cText = Instance.new("TextLabel")
	cText.Name = "CountText"
	cText.Size = UDim2.fromScale(1, 1)
	cText.BackgroundTransparency = 1
	cText.Font = Theme.Fonts.Title
	cText.TextSize = Theme.TextSize.Label
	cText.Text = ""
	cText.Parent = countBadge
	cardCountLabels[seatIdx] = cText

	applySeatStatus(seatIdx)
	return bill
end

local function getStatus(seatIdx: number)
	local status = seatStatus[seatIdx]
	if not status then
		status = { score = 0, cards = Constants.CARDS_PER_PLAYER, eliminated = false }
		seatStatus[seatIdx] = status
	end
	return status
end

local function scorePips(score: number): string
	local parts = {}
	for i = 1, Constants.POINTS_TO_WIN do
		local color = if i <= score then "#FFD23F" else "#5A5560"
		table.insert(parts, `<font color="{color}">●</font>`)
	end
	return table.concat(parts, " ") .. `  <font color="#B4A59B">{score}/{Constants.POINTS_TO_WIN}</font>`
end

applySeatStatus = function(seatIdx: number)
	local status = getStatus(seatIdx)
	local scoreLabel = scoreLabels[seatIdx]
	if scoreLabel then
		scoreLabel.Text = if status.eliminated then `<font color="#FF6B6B">ELIMINATED</font>` else scorePips(status.score)
	end
	local countLabel = cardCountLabels[seatIdx]
	if countLabel then
		countLabel.Text = if status.eliminated then "💀" else ""
		local badge = countLabel.Parent
		local lives = badge and badge:FindFirstChild("Lives")
		if lives and lives:IsA("Frame") then
			lives.Visible = not status.eliminated
			local accent = CardArt.Get(seatCardSets[seatIdx]).accent
			for i = 1, Constants.CARDS_PER_PLAYER do
				local pip = lives:FindFirstChild("Life" .. i)
				if pip and pip:IsA("Frame") then
					local alive = i <= status.cards
					pip.BackgroundColor3 = if alive then accent:Lerp(Color3.new(1, 1, 1), 0.35) else Theme.Colors.PanelBorder
					pip.BackgroundTransparency = if alive then 0 else 0.3
				end
			end
		end
	end
	local bill = seatBillboards[seatIdx] or (scoreLabel and scoreLabel:FindFirstAncestorOfClass("BillboardGui"))
	local capsule = bill and bill:FindFirstChild("TagCapsule") :: Frame?
	local tagStroke = capsule and capsule:FindFirstChild("TagStroke")
	local tagGradient = tagStroke and tagStroke:FindFirstChild("TagGradient")
	if tagGradient and tagGradient:IsA("UIGradient") then
		local accent = CardArt.Get(seatCardSets[seatIdx]).accent
		tagGradient.Color = ColorSequence.new(accent, Theme.Colors.Gold)
	end
	if capsule then
		capsule.BackgroundTransparency = if status.eliminated then 0.6 else 0.25
		local nameLabel = capsule:FindFirstChild("NameLabel") :: TextLabel?
		if nameLabel then
			nameLabel.TextTransparency = if status.eliminated then 0.5 else 0
		end
	end
end

-- ============================================================================
-- 3. RENDER OPPONENT FANNED CIRCULAR CARDS (Matching Reference Hands)
-- ============================================================================
local function renderOpponentFannedHand(seatIdx: number, cardCount: number)
	-- Rendered for every seat; each client hides its own seat's tokens locally
	if not arenaModel then
		return
	end
	local cfg = SEAT_CONFIGS[seatIdx]
	if not cfg or not cfg.handPos then
		return
	end

	local setId = seatCardSets[seatIdx] or CardArt.DefaultSetId
	local existing = opponentHands[seatIdx]
	local prevCount = 0
	if existing and existing.Parent then
		local stored = existing:GetAttribute("CardCount")
		prevCount = if type(stored) == "number" then stored else 0
		-- State updates arrive constantly; only rebuild when the count or art changes,
		-- otherwise running deal animations would be cut off
		if prevCount == cardCount and existing:GetAttribute("CardSet") == setId then
			return
		end
		if existing:GetAttribute("CardSet") ~= setId then
			prevCount = 0 -- new art (new match): deal the whole hand again
		end
		existing:Destroy()
	end
	opponentHands[seatIdx] = nil

	if cardCount <= 0 then
		return
	end

	local handModel = Instance.new("Model")
	handModel.Name = "OpponentHand_" .. seatIdx
	handModel:SetAttribute("CardCount", cardCount)
	handModel:SetAttribute("CardSet", setId)
	handModel.Parent = arenaModel
	opponentHands[seatIdx] = handModel

	-- Held upright in front of the player, faces toward the centre, fanned like a hand
	-- of cards. Cylinder faces sit on its X axis, so turn X toward the centre.
	local TOKEN_DIAMETER = 1.6
	local SPACING = 0.65
	local FAN_DEGREES = 9
	local startZ = -(cardCount - 1) * SPACING / 2
	local facing = CFrame.lookAt(cfg.handPos, Vector3.new(0, cfg.handPos.Y, 0)) * CFrame.Angles(0, math.rad(90), 0)

	for i = 1, cardCount do
		local t = i - (cardCount + 1) / 2 -- -n..n around the middle card
		local tokenCF = facing
			* CFrame.new(-(i - 1) * 0.04, -math.abs(t) * 0.1, startZ + (i - 1) * SPACING)
			* CFrame.Angles(math.rad(-t * FAN_DEGREES), 0, 0)

		local token = Instance.new("Part")
		token.Name = "HandToken_" .. i
		token.Shape = Enum.PartType.Cylinder
		token.Size = Vector3.new(0.06, TOKEN_DIAMETER, TOKEN_DIAMETER)
		token.CFrame = tokenCF
		token.Anchored = true
		token.CanCollide = false
		token.Material = Enum.Material.SmoothPlastic
		token.Color = CardArt.Get(setId).accent:Lerp(Color3.new(0, 0, 0), 0.6) -- rim in the set's colour
		token.Parent = handModel

		-- The player's card back on both faces, so tokens never reveal anything
		for _, faceNormal in ipairs({ Enum.NormalId.Right, Enum.NormalId.Left }) do
			local sg = Instance.new("SurfaceGui")
			sg.Name = "TokenGui_" .. faceNormal.Name
			sg.Face = faceNormal
			sg.CanvasSize = Vector2.new(256, 256)
			sg.Adornee = token
			sg.Parent = token

			local art = Instance.new("ImageLabel")
			art.Name = "CardArt"
			art.Size = UDim2.fromScale(1, 1)
			art.BackgroundTransparency = 1
			art.Image = CardArt.Back(setId)
			art.Parent = sg
		end

		-- Deal: tokens the hand just gained (cards back at round start) fly in from the table
		-- centre, staggered by seat and by card so it reads as a dealer going round the table
		if i > prevCount then
			token.CFrame = CFrame.new(0, cfg.handPos.Y, 0) * facing.Rotation
			token.Size = Vector3.new(0.06, TOKEN_DIAMETER * 0.4, TOKEN_DIAMETER * 0.4)
			local delayTime = (seatIdx - 1) * 0.12 + (i - prevCount - 1) * 0.09
			TweenService:Create(token, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delayTime), {
				CFrame = tokenCF,
				Size = Vector3.new(0.06, TOKEN_DIAMETER, TOKEN_DIAMETER),
			}):Play()
		end
	end
end

-- ============================================================================
-- 4. SPAWN SLEEK DARK BOT AVATARS (Matching Concept Reference)
-- ============================================================================
function TableBuilder.SpawnStandingBot(botName: string, seatIndex: number)
	local cfg = SEAT_CONFIGS[seatIndex]
	if not cfg or not arenaModel then
		return
	end

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
	if not cfg then
		return
	end

	local function setupChar(char: Model)
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: Part?
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hrp or not hum then
			return
		end

		task.wait(0.1)
		local head = char:FindFirstChild("Head") :: BasePart?
		if head then
			seatBillboards[seatIndex] = createPlayerTag(head, player.DisplayName, seatIndex, player)
		end
		local cf = CFrame.lookAt(cfg.standPos, cfg.lookAt)
		char:PivotTo(cf)
		hrp.CFrame = cf
		hrp.Anchored = true
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end

	setStandHook(player, setupChar)
end

-- Forget a player's respawn hook (they left the game)
function TableBuilder.ForgetPlayer(player: Player)
	local conn = standConnections[player]
	if conn then
		conn:Disconnect()
	end
	standConnections[player] = nil
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

function TableBuilder.UpdateScore(seatIndex: number, score: number)
	getStatus(seatIndex).score = score
	applySeatStatus(seatIndex)
end

-- handCount drives the fanned tokens; totalCards (hand + table) is what the badge shows,
-- since that is how many cards the player has left before elimination.
function TableBuilder.UpdateCardCount(seatIndex: number, handCount: number, totalCards: number?)
	renderOpponentFannedHand(seatIndex, handCount)
	getStatus(seatIndex).cards = totalCards or handCount
	applySeatStatus(seatIndex)
end

-- ============================================================================
-- PILE COUNTERS: how many face-down cards are in each pile (public information)
-- ============================================================================
local function getPileCounter(seatIndex: number): BillboardGui?
	local existing = pileCounters[seatIndex]
	if existing and existing.Parent then
		return existing
	end
	local mat = pileMats[seatIndex]
	if not mat then
		return nil
	end

	-- Just outside the pile, on the owner's side, so cards never cover it
	local flat = Vector3.new(mat.Position.X, 0, mat.Position.Z)
	local outward = if flat.Magnitude > 0 then flat.Unit else Vector3.new(0, 0, 1)

	local bill = Instance.new("BillboardGui")
	bill.Name = "PileCount_" .. seatIndex
	bill.Adornee = mat
	bill.Size = UDim2.fromOffset(72, 34)
	bill.StudsOffsetWorldSpace = outward * 2.1 + Vector3.new(0, 0.5, 0)
	bill.AlwaysOnTop = true
	bill.LightInfluence = 0
	bill.MaxDistance = 80
	bill.Enabled = false
	bill.Parent = mat

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Theme.Colors.Backing
	pill.BorderSizePixel = 0
	pill.Parent = bill
	Instance.new("UICorner", pill).CornerRadius = Theme.CornerRadius.Circular
	local stroke = Instance.new("UIStroke")
	stroke.Name = "PillStroke"
	stroke.Thickness = 1.5
	stroke.Parent = pill
	-- Clients enlarge this locally on hover; the server never touches it
	local hover = Instance.new("UIScale")
	hover.Name = "HoverScale"
	hover.Parent = pill

	local icon = Instance.new("ImageLabel")
	icon.Name = "BackIcon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 6, 0.5, 0)
	icon.Size = UDim2.fromOffset(24, 24)
	icon.BackgroundTransparency = 1
	icon.Parent = pill

	local count = Instance.new("TextLabel")
	count.Name = "Count"
	count.Position = UDim2.fromOffset(32, 0)
	count.Size = UDim2.new(1, -36, 1, 0)
	count.BackgroundTransparency = 1
	count.Font = Theme.Fonts.Title
	count.TextXAlignment = Enum.TextXAlignment.Center
	count.Text = "0"
	count.Parent = pill
	Theme.Outline(count, 0.6)

	pileCounters[seatIndex] = bill
	return bill
end

-- `emphasis`: bidding / challenge, when pile sizes drive decisions
function TableBuilder.UpdatePileCount(seatIndex: number, count: number, emphasis: boolean)
	local bill = getPileCounter(seatIndex)
	if not bill then
		return
	end
	bill.Enabled = count > 0
	local pill = bill:FindFirstChild("Pill")
	if not pill or not pill:IsA("Frame") then
		return
	end
	pill.BackgroundTransparency = if emphasis then 0.05 else 0.35
	local stroke = pill:FindFirstChild("PillStroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = if emphasis then Theme.Colors.Gold else Theme.Colors.PanelBorder
	end
	local icon = pill:FindFirstChild("BackIcon")
	if icon and icon:IsA("ImageLabel") then
		icon.Image = CardArt.Back(seatCardSets[seatIndex])
	end
	local label = pill:FindFirstChild("Count")
	if label and label:IsA("TextLabel") then
		label.Text = tostring(count)
		label.TextSize = if emphasis then Theme.TextSize.Heading else Theme.TextSize.Label
		label.TextColor3 = if emphasis then Theme.Colors.TextGold else Theme.Colors.TextSecondary
	end
end

-- Which card art set a seat uses (backs on its hand tokens); applied on the next render
function TableBuilder.SetSeatCardSet(seatIndex: number, setId: string?)
	if setId and seatCardSets[seatIndex] ~= setId then
		seatCardSets[seatIndex] = setId
		applySeatStatus(seatIndex) -- recolour the name tag
	end
end

function TableBuilder.SetEliminated(seatIndex: number, eliminated: boolean)
	getStatus(seatIndex).eliminated = eliminated
	applySeatStatus(seatIndex)
end

function TableBuilder.SetBotEmote(seatIndex: number, emote: string)
	local bill = seatBillboards[seatIndex]
	if not bill then
		return
	end
	local capsule = bill:FindFirstChild("TagCapsule") :: Frame?
	if not capsule then
		return
	end
	local avatarCircle = capsule:FindFirstChild("AvatarCircle") :: Frame?
	if not avatarCircle then
		return
	end
	local aIcon = avatarCircle:FindFirstChild("IconLabel") or avatarCircle:FindFirstChildWhichIsA("TextLabel")
	if aIcon and aIcon:IsA("TextLabel") then
		aIcon.Text = emote
	end
end

-- Empty a seat: remove a bot's dummy, its tag and fanned tokens, and reset the seat's status
function TableBuilder.ClearSeat(seatIndex: number)
	local dummy = botDummies[seatIndex]
	if dummy then
		dummy:Destroy()
		botDummies[seatIndex] = nil
	end
	local hand = opponentHands[seatIndex]
	if hand then
		hand:Destroy()
		opponentHands[seatIndex] = nil
	end
	seatBillboards[seatIndex] = nil
	scoreLabels[seatIndex] = nil
	cardCountLabels[seatIndex] = nil
	seatStatus[seatIndex] = nil
	seatCardSets[seatIndex] = nil
end

-- Players without a seat (waiting for the next match) stand back from the table
function TableBuilder.StandSpectator(player: Player)
	local function place(char: Model)
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hrp or not hum then
			return
		end
		task.wait(0.1)
		local head = char:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("PlayerInfoTag")
		if tag then
			tag:Destroy()
		end
		local cf = CFrame.lookAt(Vector3.new(0, 3.4, 15), Vector3.new(0, 3.0, 0))
		char:PivotTo(cf)
		hrp.Anchored = true
		hum.WalkSpeed = 0
		hum.JumpPower = 0
	end
	setStandHook(player, place)
end

-- Accessors
function TableBuilder.GetCoasterCFrame(seatIndex: number): CFrame?
	local mat = pileMats[seatIndex]
	if not mat then
		return nil
	end
	return mat.CFrame * CFrame.new(0, 0.04, 0)
end

function TableBuilder.GetCoasterPart(seatIndex: number): Part?
	return pileMats[seatIndex]
end

function TableBuilder.GetStandingCFrame(seatIndex: number): CFrame?
	return standingCFrames[seatIndex]
end

return TableBuilder
