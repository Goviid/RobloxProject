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
local RunService = game:GetService("RunService")
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
local pileCounters: { [number]: BillboardGui } = {}
local turnDots: { [number]: BillboardGui } = {} -- small gold dot just above the active player's name tag
local activeTurnSeat: number? = nil -- "N cards" label beside each pile
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
	table.clear(turnDots)

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
		-- Soft bloom: only neon (the turn orb, LED rings) glows; lit bodies don't
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		if bloom then
			bloom.Intensity = 0.35
			bloom.Size = 18
			bloom.Threshold = 2.6
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


	-- 6. Low-backed wooden chairs. Players sit with their root where they used to stand
	-- (the seated pose only folds the legs forward under the table), so heads stay at
	-- the same height. The back stops below the shoulders and is narrower than a body,
	-- so it never pokes out past the avatar.
	local CHAIR_WOOD = Color3.fromRGB(58, 32, 24)
	local CHAIR_CUSHION = Color3.fromRGB(120, 28, 36)
	for seatIdx, cfg in pairs(SEAT_CONFIGS) do
		local seatCF = CFrame.lookAt(cfg.standPos, cfg.lookAt) -- -Z faces the table
		local chair = Instance.new("Model")
		chair.Name = "Chair_" .. seatIdx
		chair.Parent = tableModel
		local function chairPart(name: string, size: Vector3, offset: Vector3, color: Color3)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.CFrame = seatCF * CFrame.new(offset)
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Color = color
			p.Parent = chair
		end
		-- Seat top sits just under the thighs (about 1 stud below the avatar's root)
		chairPart("Cushion", Vector3.new(2.0, 0.3, 1.9), Vector3.new(0, -1.15, -0.35), CHAIR_CUSHION)
		chairPart("SeatFrame", Vector3.new(2.1, 0.25, 2.0), Vector3.new(0, -1.42, -0.35), CHAIR_WOOD)
		chairPart("Back", Vector3.new(1.5, 1.4, 0.22), Vector3.new(0, -0.35, 0.72), CHAIR_WOOD)
		chairPart("Pedestal", Vector3.new(0.45, cfg.standPos.Y - 1.55, 0.45), Vector3.new(0, -(cfg.standPos.Y + 1.55) / 2, -0.35), CHAIR_WOOD)
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

	-- Turn marker: a small gold dot sitting just below the tag, shown only on your turn.
	-- Its own tiny billboard, shifted by its own height (SizeOffset), so it always sits
	-- the same few pixels below the capsule whatever the avatar.
	local oldDot = adornee:FindFirstChild("TurnDot")
	if oldDot then
		oldDot:Destroy()
	end
	local dotGui = Instance.new("BillboardGui")
	dotGui.Name = "TurnDot"
	if hideFrom then
		dotGui.PlayerToHideFrom = hideFrom
	end
	dotGui.Size = UDim2.fromOffset(10, 10)
	dotGui.StudsOffset = bill.StudsOffset
	dotGui.SizeOffset = Vector2.new(0, -4) -- 40px down: capsule half-height (28) plus a small gap
	dotGui.AlwaysOnTop = true
	dotGui.Enabled = activeTurnSeat == seatIdx
	dotGui.Adornee = adornee
	dotGui.Parent = adornee
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = Color3.fromRGB(255, 205, 90)
	dot.BorderSizePixel = 0
	dot.Parent = dotGui
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	turnDots[seatIdx] = dotGui


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
		token.Color = CardArt.Get(setId).accent:Lerp(Color3.new(1, 1, 1), 0.25) -- rim in the set's colour
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
-- 4. BOT AVATARS, ANIMATION & REACTIONS
-- ============================================================================
local Players = game:GetService("Players")

-- Roblox's own R15 animations (the ones every default avatar uses)
local ANIM = {
	Cheer = "rbxassetid://507770677",
	Laugh = "rbxassetid://507770818",
	Point = "rbxassetid://507770453",
	Dance = "rbxassetid://507771019",
	Shock = "rbxassetid://507767968", -- the fall pose: arms flung up
}
local REACTION_SECONDS = 2.6

-- Seated-at-the-table pose: elbows bent so the hands hold the card fan from behind,
-- hips and knees bent as if sitting. The root stays where it was, so heads keep their
-- height. Angles were checked on a live bot: hands land about 0.9 studs out, 0.8 up and
-- 0.7 forward of the root, just behind the held cards (1.25 forward), so they don't
-- poke through.
local TABLE_POSE: { [string]: CFrame } = {
	RightShoulder = CFrame.Angles(math.rad(15), 0, math.rad(-30)),
	LeftShoulder = CFrame.Angles(math.rad(15), 0, math.rad(30)),
	RightElbow = CFrame.Angles(math.rad(135), 0, 0),
	LeftElbow = CFrame.Angles(math.rad(135), 0, 0),
	RightHip = CFrame.Angles(math.rad(90), 0, 0),
	LeftHip = CFrame.Angles(math.rad(90), 0, 0),
	RightKnee = CFrame.Angles(math.rad(-90), 0, 0),
	LeftKnee = CFrame.Angles(math.rad(-90), 0, 0),
}

-- Turn an attachment by `rotation` on top of its original orientation (saved once in an
-- attribute, so posing again never stacks). Only the orientation is touched; the
-- position is left to Roblox's avatar scaling.
local function rotateAttachment(att: Attachment, rotation: CFrame?)
	local base = att:GetAttribute("BaseRotation")
	if typeof(base) ~= "CFrame" then
		base = att.CFrame.Rotation
		att:SetAttribute("BaseRotation", base)
	end
	local turned = if rotation then (base :: CFrame) * rotation else base :: CFrame
	att.CFrame = CFrame.new(att.Position) * turned
end

-- Today's R15 avatars are jointed with AnimationConstraints, which follow the attachment
-- on the parent side (Attachment0), so that is what gets turned. Older rigs use Motor6Ds:
-- their C0 is turned too, along with the attachment Roblox rebuilds them from.
local function applyTablePose(character: Model, seated: boolean)
	for _, joint in ipairs(character:GetDescendants()) do
		local pose = TABLE_POSE[joint.Name]
		if not pose then
			continue
		end
		local rotation = if seated then pose else nil
		if joint:IsA("AnimationConstraint") then
			local att = joint.Attachment0
			if att then
				rotateAttachment(att, rotation)
			end
		elseif joint:IsA("Motor6D") then
			local part0 = joint.Part0
			local att = part0 and part0:FindFirstChild(joint.Name .. "RigAttachment")
			if att and att:IsA("Attachment") then
				rotateAttachment(att, rotation)
			end
			local base = joint:GetAttribute("BaseRotation")
			if typeof(base) ~= "CFrame" then
				base = joint.C0.Rotation
				joint:SetAttribute("BaseRotation", base)
			end
			local turned = if rotation then (base :: CFrame) * rotation else base :: CFrame
			joint.C0 = CFrame.new(joint.C0.Position) * turned
		end
	end
end

-- Seat or unseat a character. Any looping animation (the idle sway every avatar plays)
-- holds the arms at its own angles and cancels the pose, so seated characters play none:
-- the default Animate script is removed, and players' clients also stop their own
-- tracks when they see the "SeatedAtTable" attribute (see init.client). Short reactions
-- still play over the pose. Applied again shortly after, in case Roblox's avatar
-- loading or scaling resets the joints in between.
local function setTablePose(character: Model, seated: boolean)
	character:SetAttribute("SeatedAtTable", seated)
	if seated then
		local animate = character:FindFirstChild("Animate")
		if animate then
			animate:Destroy()
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				if track.Looped then
					track:Stop(0)
				end
			end
		end
	end
	applyTablePose(character, seated)
	for _, delaySeconds in ipairs({ 0.5, 2 }) do
		task.delay(delaySeconds, function()
			if character.Parent and character:GetAttribute("SeatedAtTable") == seated then
				applyTablePose(character, seated)
			end
		end)
	end
end

-- Character standing at each seat (bot model or a player's character), for reactions
local seatCharacters: { [number]: Model } = {}
-- Loaded animation tracks per character, so each animation is only loaded once
local trackCache: { [Model]: { [string]: AnimationTrack } } = {}

local function getTrack(character: Model, animId: string): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local created = Instance.new("Animator")
		created.Parent = humanoid
		animator = created
	end
	local cache = trackCache[character]
	if not cache then
		cache = {}
		trackCache[character] = cache
		character.Destroying:Connect(function()
			trackCache[character] = nil
		end)
	end
	local track = cache[animId]
	if track then
		return track
	end
	local ok, loaded = pcall(function()
		local anim = Instance.new("Animation")
		anim.AnimationId = animId
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if not ok or not loaded then
		return nil
	end
	cache[animId] = loaded
	return loaded
end

-- Calavera look for bots: brown skull and hands, a dark suit, a sugar-skull face and a
-- sombrero. The face's flowers and the sombrero take the bot's card colour.
-- Face art: "Artwork assets/Bots/skull_face.png" (white parts are tinted, black stays black)
local SKULL_FACE = "rbxassetid://94176651222783"
local BONE = Color3.fromRGB(70, 46, 32) -- deep warm brown; light colours glare like bulbs under the room's bright ambient light
local SUIT = Color3.fromRGB(34, 30, 38)
local HAT_BAND = Color3.fromRGB(140, 100, 36)
local HAT_SHADE = 0.6 -- sombrero = card colour this much toward black, so it doesn't glare

-- Each bot's skull and sombrero live in their own model beside the bot (not inside it):
-- Roblox's avatar scaling resizes every part inside a character, which squashed the
-- hat into the head. They are welded to the head and removed with the bot.
local botCostumes: { [Model]: Model } = {}

-- Hide the default head and weld on a classic Roblox head shape carrying the skull face.
-- Decals on the default (mesh) head get stretched over its curves; on the classic head
-- shape they sit flat like a classic face. Then add the sombrero.
local function dressSkeleton(model: Model, parent: Instance)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	head.Transparency = 1 -- still carries the name tag and turn dot
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") then
			child:Destroy()
		end
	end

	local costume = Instance.new("Model")
	costume.Name = "Calavera_" .. model.Name
	local function weldedPart(name: string, size: Vector3, cf: CFrame): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = p
		weld.Parent = p
		p.Parent = costume
		return p
	end

	local skull = weldedPart("Skull", Vector3.new(1.5, 1.5, 1.5), head.CFrame)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = skull
	local face = Instance.new("Decal")
	face.Name = "SkullFace"
	face.Face = Enum.NormalId.Front
	face.Texture = SKULL_FACE
	face.Parent = skull

	local top = head.Size.Y / 2
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis (X) pointing up
	local function hatPart(name: string, size: Vector3, offsetY: number)
		local p = weldedPart(name, size, head.CFrame * CFrame.new(0, offsetY, 0) * upright)
		p.Shape = Enum.PartType.Cylinder
		p.CastShadow = false
	end
	-- Brim rests on top of the skull; the crown sinks only slightly into it
	hatPart("SombreroBrim", Vector3.new(0.12, 3.1, 3.1), top + 0.02)
	hatPart("SombreroBand", Vector3.new(0.22, 1.2, 1.2), top + 0.18)
	hatPart("SombreroCrown", Vector3.new(0.95, 1.15, 1.15), top + 0.5)
	costume.Parent = parent
	botCostumes[model] = costume
	model.Destroying:Connect(function()
		botCostumes[model] = nil
		costume:Destroy()
	end)
end

-- Colours: bone and suit are fixed; the face flowers and sombrero follow the card colour.
-- Everything is matte so the bodies don't shine.
local function colorBot(model: Model, accent: Color3)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local name = part.Name
			part.Material = Enum.Material.SmoothPlastic
			if string.find(name, "Torso") or string.find(name, "Leg") or string.find(name, "Foot") then
				part.Color = SUIT
			elseif string.find(name, "Arm") or string.find(name, "Hand") or name == "Head" then
				part.Color = BONE
			end
		end
	end
	local costume = botCostumes[model]
	if costume then
		for _, part in ipairs(costume:GetChildren()) do
			if part:IsA("BasePart") then
				if part.Name == "Skull" then
					part.Color = BONE
					local face = part:FindFirstChild("SkullFace")
					if face and face:IsA("Decal") then
						face.Color3 = accent
					end
				elseif part.Name == "SombreroBand" then
					part.Color = HAT_BAND
				else
					part.Color = accent:Lerp(Color3.new(0, 0, 0), HAT_SHADE)
				end
			end
		end
	end
end

-- An R15 avatar with skeleton proportions: thin limbs and torso, a big skull head.
-- Only the root is anchored so animations can move the limbs. Returns nil if Roblox
-- can't build one.
local function buildBotAvatar(botName: string): Model?
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.WidthScale = 0.7
		desc.DepthScale = 0.7
		desc.HeightScale = 1
		desc.HeadScale = 1.3
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[TableBuilder] Couldn't build a bot avatar:", model)
		return nil
	end
	model.Name = "Bot_" .. botName
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- we draw our own tag
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = part.Name == "HumanoidRootPart"
			part.CanCollide = false
		end
	end
	return model
end

-- Fallback if no avatar can be built: the old dark silhouette
local function buildBotSilhouette(botName: string, targetCF: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Bot_" .. botName
	local function piece(name: string, size: Vector3, cf: CFrame)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(15, 14, 18)
		p.Parent = model
	end
	piece("Torso", Vector3.new(2.4, 2.6, 1.4), targetCF * CFrame.new(0, -0.2, 0))
	piece("Head", Vector3.new(1.4, 1.4, 1.4), targetCF * CFrame.new(0, 1.8, 0))
	piece("LeftArm", Vector3.new(1.0, 2.4, 1.0), targetCF * CFrame.new(-1.6, -0.2, -0.4) * CFrame.Angles(math.rad(-25), 0, math.rad(-15)))
	piece("RightArm", Vector3.new(1.0, 2.4, 1.0), targetCF * CFrame.new(1.6, -0.2, -0.4) * CFrame.Angles(math.rad(-25), 0, math.rad(15)))
	return model
end

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
	local avatar = buildBotAvatar(botName)
	if avatar then
		avatar:PivotTo(targetCF)
	end
	local botModel: Model = avatar or buildBotSilhouette(botName, targetCF)
	botModel.Parent = arenaModel
	if avatar then
		-- No idle loop: it would hold the arms down (see setTablePose)
		setTablePose(avatar, true)
		-- Dress once the rig has settled in the world: the head moves into place when the
		-- joints first solve, and a hat welded before that ends up sunk into the skull
		RunService.Heartbeat:Wait()
		dressSkeleton(avatar, arenaModel)
		colorBot(avatar, CardArt.Get(seatCardSets[seatIndex]).accent)
	end

	local head = botModel:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		seatBillboards[seatIndex] = createPlayerTag(head, botName, seatIndex)
	end
	botDummies[seatIndex] = botModel
	seatCharacters[seatIndex] = botModel

	-- Render starting circular tokens in hand (4 tokens)
	renderOpponentFannedHand(seatIndex, 4)
	print("[TableBuilder] Spawned bot:", botName, "at seat", seatIndex)
end

-- Play a short reaction on whoever stands at a seat (bot or player):
-- "Cheer", "Laugh", "Point", "Dance" or "Shock". Silently does nothing if the
-- animation can't load (e.g. Studio offline) or the seat is empty.
function TableBuilder.PlayReaction(seatIndex: number, kind: string, seconds: number?)
	local character = seatCharacters[seatIndex]
	local animId = ANIM[kind]
	if not character or not character.Parent or not animId then
		return
	end
	local track = getTrack(character, animId)
	if not track then
		return
	end
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.2)
	task.delay(seconds or REACTION_SECONDS, function()
		if track.IsPlaying then
			track:Stop(0.3)
		end
	end)
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
		seatCharacters[seatIndex] = char
		setTablePose(char, true)
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
	activeTurnSeat = activeSeatIndex
	for seatIdx, dotGui in pairs(turnDots) do
		dotGui.Enabled = activeSeatIndex ~= nil and seatIdx == activeSeatIndex
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
		local bot = botDummies[seatIndex]
		if bot and bot:FindFirstChildOfClass("Humanoid") then
			colorBot(bot, CardArt.Get(setId).accent)
		end
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
	local dotGui = turnDots[seatIndex]
	if dotGui then
		dotGui:Destroy()
		turnDots[seatIndex] = nil
	end
	seatCharacters[seatIndex] = nil
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
		local dotGui = head and head:FindFirstChild("TurnDot")
		if dotGui then
			dotGui:Destroy()
		end
		local cf = CFrame.lookAt(Vector3.new(0, 3.4, 15), Vector3.new(0, 3.0, 0))
		setTablePose(char, false) -- standing back from the table
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
