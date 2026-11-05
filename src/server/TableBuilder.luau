--!strict
-- TableBuilder.luau
-- Constructs the clean, open 3D tabletop environment with regular bright lighting (LOCOfficial 1-to-1 style)

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

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
-- 1. CONSTRUCT BASIC OPEN LEVEL WITH REGULAR BRIGHT LIGHTING
-- ============================================================================
function TableBuilder.Build()
	-- Clean up any previous arena instance on live reload
	local existing = Workspace:FindFirstChild("SkullsArena")
	if existing then existing:Destroy() end

	local arena = Instance.new("Model")
	arena.Name = "SkullsArena"
	arena.Parent = Workspace

	-- ------------------------------------------------------------------------
	-- A. Regular Bright Studio Lighting Setup
	-- ------------------------------------------------------------------------
	Lighting.Technology = Enum.Technology.ShadowMap
	Lighting.Brightness = 2.0
	Lighting.Ambient = Color3.fromRGB(140, 140, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
	Lighting.ClockTime = 14.0 -- 2 PM clear daytime
	Lighting.GlobalShadows = true

	-- Clean up any harsh dark color corrections from previous sessions
	local oldCC = Lighting:FindFirstChild("SkullsColorCorrection")
	if oldCC then oldCC:Destroy() end
	local oldBloom = Lighting:FindFirstChild("SkullsBloom")
	if oldBloom then oldBloom:Destroy() end

	-- ------------------------------------------------------------------------
	-- B. Open Studio Arena Floor (LOCOfficial Style)
	-- ------------------------------------------------------------------------
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(120, 2, 120)
	floor.Position = Vector3.new(0, -1, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(115, 88, 70)
	floor.Parent = arena

	-- Center Circular Accent Rug under the table
	local rug = Instance.new("Part")
	rug.Name = "TableRug"
	rug.Shape = Enum.PartType.Cylinder
	rug.Size = Vector3.new(0.05, 26, 26)
	rug.CFrame = CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90))
	rug.Anchored = true
	rug.CanCollide = false
	rug.Material = Enum.Material.Fabric
	rug.Color = Color3.fromRGB(50, 32, 26)
	rug.Parent = arena

	-- ------------------------------------------------------------------------
	-- C. Center Circular Table & Felt Inset
	-- ------------------------------------------------------------------------
	-- Outer table rim (Polished dark oak)
	local tableBase = Instance.new("Part")
	tableBase.Name = "MainTable"
	tableBase.Shape = Enum.PartType.Cylinder
	tableBase.Size = Vector3.new(1.8, TABLE_RADIUS * 2, TABLE_RADIUS * 2)
	tableBase.CFrame = CFrame.new(TABLE_POSITION) * CFrame.Angles(0, 0, math.rad(90))
	tableBase.Anchored = true
	tableBase.CanCollide = true
	tableBase.Material = Enum.Material.Wood
	tableBase.Color = Color3.fromRGB(65, 42, 28)
	tableBase.Parent = arena

	-- Center Felt Inset (Rich clean burgundy fabric surface)
	local felt = Instance.new("Part")
	felt.Name = "TableFelt"
	felt.Shape = Enum.PartType.Cylinder
	felt.Size = Vector3.new(1.85, (TABLE_RADIUS - 0.7) * 2, (TABLE_RADIUS - 0.7) * 2)
	felt.CFrame = CFrame.new(TABLE_POSITION + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	felt.Anchored = true
	felt.CanCollide = true
	felt.Material = Enum.Material.Fabric
	felt.Color = Color3.fromRGB(110, 24, 34)
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
	leg.Color = Color3.fromRGB(48, 30, 20)
	leg.Parent = arena

	-- ------------------------------------------------------------------------
	-- D. Overhead Brass Chandelier (Visual Polish & Soft Warm Accent)
	-- ------------------------------------------------------------------------
	local lampHood = Instance.new("Part")
	lampHood.Name = "OverheadLamp"
	lampHood.Shape = Enum.PartType.Cylinder
	lampHood.Size = Vector3.new(0.6, 3.2, 3.2)
	lampHood.CFrame = CFrame.new(0, 13.5, 0) * CFrame.Angles(0, 0, math.rad(90))
	lampHood.Anchored = true
	lampHood.CanCollide = false
	lampHood.Material = Enum.Material.Metal
	lampHood.Color = Color3.fromRGB(55, 42, 25)
	lampHood.Parent = arena

	local glowDiffuser = Instance.new("Part")
	glowDiffuser.Name = "LampGlow"
	glowDiffuser.Shape = Enum.PartType.Cylinder
	glowDiffuser.Size = Vector3.new(0.2, 2.8, 2.8)
	glowDiffuser.CFrame = CFrame.new(0, 13.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	glowDiffuser.Anchored = true
	glowDiffuser.CanCollide = false
	glowDiffuser.Material = Enum.Material.Neon
	glowDiffuser.Color = Color3.fromRGB(255, 245, 220)
	glowDiffuser.Parent = arena

	local tableLight = Instance.new("PointLight")
	tableLight.Color = Color3.fromRGB(255, 235, 200)
	tableLight.Brightness = 0.8
	tableLight.Range = 22
	tableLight.Shadows = false
	tableLight.Parent = glowDiffuser

	-- Container for 3D card stacks
	local stacksFolder = Instance.new("Folder")
	stacksFolder.Name = "TableCardStacks"
	stacksFolder.Parent = arena

	-- ------------------------------------------------------------------------
	-- E. 6 Standing Pods, Coasters, and Spawn Location
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
		coaster.Color = Color3.fromRGB(68, 42, 28)
		coaster.Parent = arena
		coasterParts[seatIdx] = coaster

		-- Gold Trim Ring on Coaster
		local trim = Instance.new("Highlight")
		trim.Name = "GoldTrim"
		trim.FillTransparency = 1
		trim.OutlineColor = Color3.fromRGB(235, 185, 55)
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
		standPad.Color = Color3.fromRGB(70, 52, 35)
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
			spawn.Duration = 0
			spawn.Parent = arena
		end
	end

	arenaModel = arena
	print("[TableBuilder] Clean LOCOfficial basic level with regular bright lighting created.")
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
	frame.BackgroundColor3 = Color3.fromRGB(24, 18, 16)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = bill

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name = "BorderStroke"
	stroke.Color = Color3.fromRGB(190, 150, 60)
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
		gem.TextColor3 = Color3.fromRGB(130, 110, 90)
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
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: Part?
		local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hrp or not humanoid then return end

		task.wait(0.2)

		char:PivotTo(targetCF)
		hrp.CFrame = targetCF
		hrp.Anchored = true

		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false

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

	if botDummies[seatIndex] then
		botDummies[seatIndex]:Destroy()
		botDummies[seatIndex] = nil
	end

	local botColorThemes: { [string]: { suit: Color3, trim: Color3 } } = {
		["Doña Flor"]    = { suit = Color3.fromRGB(150, 30, 42),  trim = Color3.fromRGB(240, 200, 70) },
		["El Bandido"]   = { suit = Color3.fromRGB(45, 45, 50),   trim = Color3.fromRGB(190, 140, 70) },
		["Don Diego"]    = { suit = Color3.fromRGB(28, 52, 95),   trim = Color3.fromRGB(220, 220, 230) },
		["La Catrina"]   = { suit = Color3.fromRGB(85, 30, 100),  trim = Color3.fromRGB(245, 200, 75) },
		["Señor Hueso"]  = { suit = Color3.fromRGB(220, 215, 205), trim = Color3.fromRGB(30, 25, 28) },
	}
	local theme = botColorThemes[botName] or { suit = Color3.fromRGB(50, 38, 30), trim = Color3.fromRGB(210, 180, 60) }

	local botModel = Instance.new("Model")
	botModel.Name = "Bot_" .. botName
	botModel.Parent = arenaModel

	-- Stylized Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.0, 2.4, 1.2)
	torso.CFrame = targetCF
	torso.Anchored = true
	torso.CanCollide = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = theme.suit
	torso.Parent = botModel

	-- Suit Lapel
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
	head.Color = Color3.fromRGB(230, 195, 165)
	head.Parent = botModel

	-- Arms
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
	legs.Color = Color3.fromRGB(25, 22, 25)
	legs.Parent = botModel

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
