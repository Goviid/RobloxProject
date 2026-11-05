--!strict
-- TableBuilder.luau
-- Constructs the 3D Arena environment (supports LOCOfficial Light Blue Void mode & Table Parlor mode)
-- Also manages clean, borderless floating overhead nametags with zero black boxes

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Enums = require(ReplicatedStorage.Shared.Enums)

local TableBuilder = {}

-- Spatial Configuration
local currentArenaMode = Constants.DEFAULT_ARENA_MODE or Enums.ArenaMode.Void

local arenaModel: Model? = nil
local standingCFrames: { [number]: CFrame } = {}
local coasterParts: { [number]: Part } = {}
local botDummies: { [number]: Model } = {}
local standPads: { [number]: Part } = {}
local seatBillboards: { [number]: BillboardGui } = {}

-- ============================================================================
-- 1. BUILD ARENA (Supports "Void" vs "Table")
-- ============================================================================
function TableBuilder.Build(modeOverride: string?)
	-- Select arena mode
	local mode = modeOverride or Workspace:GetAttribute("ArenaMode") or Constants.DEFAULT_ARENA_MODE or Enums.ArenaMode.Void
	currentArenaMode = mode
	Workspace:SetAttribute("ArenaMode", mode)

	-- Clean up previous arena on reload
	local existing = Workspace:FindFirstChild("SkullsArena")
	if existing then existing:Destroy() end

	table.clear(standingCFrames)
	table.clear(coasterParts)
	table.clear(botDummies)
	table.clear(standPads)
	table.clear(seatBillboards)

	local arena = Instance.new("Model")
	arena.Name = "SkullsArena"
	arena.Parent = Workspace

	-- Hide the default baseplate so arena styling is seamless
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
	end

	-- ========================================================================
	-- MODE A: LOCOFFICIAL LIGHT BLUE VOID (No Table, Cards on Ground)
	-- ========================================================================
	if mode == Enums.ArenaMode.Void then
		-- 1. Lighting: Serene clear light blue void
		pcall(function()
			Lighting.Brightness = 2.0
			Lighting.Ambient = Color3.fromRGB(155, 215, 255)
			Lighting.OutdoorAmbient = Color3.fromRGB(145, 205, 250)
			Lighting.ClockTime = 14.0
			Lighting.GlobalShadows = true
			Lighting.FogColor = Color3.fromRGB(130, 195, 250)
			Lighting.FogStart = 90
			Lighting.FogEnd = 320

			local oldCC = Lighting:FindFirstChild("SkullsColorCorrection")
			if oldCC then oldCC:Destroy() end
		end)

		-- 2. Void Arena Floor Platform (Smooth pastel light blue)
		local floor = Instance.new("Part")
		floor.Name = "VoidArenaFloor"
		floor.Shape = Enum.PartType.Cylinder
		floor.Size = Vector3.new(0.4, 56, 56)
		floor.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		floor.Anchored = true
		floor.CanCollide = true
		floor.Material = Enum.Material.SmoothPlastic
		floor.Color = Color3.fromRGB(118, 188, 246)
		floor.Parent = arena

		-- Center Swirl Rotation Ring (LOCOfficial style turn swirl)
		local centerRing = Instance.new("Part")
		centerRing.Name = "CenterSwirlRing"
		centerRing.Shape = Enum.PartType.Cylinder
		centerRing.Size = Vector3.new(0.04, 16, 16)
		centerRing.CFrame = CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.rad(90))
		centerRing.Anchored = true
		centerRing.CanCollide = false
		centerRing.Material = Enum.Material.SmoothPlastic
		centerRing.Color = Color3.fromRGB(240, 250, 255)
		centerRing.Transparency = 0.55
		centerRing.Parent = arena

		local centerSg = Instance.new("SurfaceGui")
		centerSg.Name = "SwirlGui"
		centerSg.Face = Enum.NormalId.Right
		centerSg.CanvasSize = Vector2.new(256, 256)
		centerSg.AlwaysOnTop = false
		centerSg.Adornee = centerRing
		centerSg.Parent = centerRing

		local swirlIcon = Instance.new("TextLabel")
		swirlIcon.Size = UDim2.new(1, 0, 1, 0)
		swirlIcon.BackgroundTransparency = 1
		swirlIcon.Font = Enum.Font.FredokaOne
		swirlIcon.TextSize = 130
		swirlIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
		swirlIcon.TextTransparency = 0.4
		swirlIcon.Text = "↺"
		swirlIcon.Parent = centerSg

		-- Outer Arena Border Ring
		local outerRing = Instance.new("Part")
		outerRing.Name = "OuterRing"
		outerRing.Shape = Enum.PartType.Cylinder
		outerRing.Size = Vector3.new(0.06, 55.5, 55.5)
		outerRing.CFrame = CFrame.new(0, 0.21, 0) * CFrame.Angles(0, 0, math.rad(90))
		outerRing.Anchored = true
		outerRing.CanCollide = false
		outerRing.Material = Enum.Material.Neon
		outerRing.Color = Color3.fromRGB(210, 240, 255)
		outerRing.Transparency = 0.6
		outerRing.Parent = arena

		-- 3. Radial Seats: Cards placed on the ground in front of each avatar (No table!)
		local COASTER_DIST = 4.8
		local STAND_DIST = 9.2

		for seatIdx = 1, 6 do
			local angle = math.rad((seatIdx - 1) * (360 / 6) + 90)
			local dirX = math.cos(angle)
			local dirZ = math.sin(angle)

			-- Flat Ground Coaster Pad (where cards stack in front of player on the ground)
			local coasterPos = Vector3.new(dirX * COASTER_DIST, 0.22, dirZ * COASTER_DIST)
			local coaster = Instance.new("Part")
			coaster.Name = "Coaster_" .. seatIdx
			coaster.Shape = Enum.PartType.Cylinder
			coaster.Size = Vector3.new(0.04, 3.2, 3.2)
			coaster.CFrame = CFrame.new(coasterPos) * CFrame.Angles(0, 0, math.rad(90))
			coaster.Anchored = true
			coaster.CanCollide = false
			coaster.Material = Enum.Material.SmoothPlastic
			coaster.Color = Color3.fromRGB(95, 170, 235)
			coaster.Parent = arena
			coasterParts[seatIdx] = coaster

			local trim = Instance.new("Highlight")
			trim.Name = "CoasterTrim"
			trim.FillTransparency = 1
			trim.OutlineColor = Color3.fromRGB(245, 250, 255)
			trim.OutlineTransparency = 0.35
			trim.Adornee = coaster
			trim.Parent = coaster

			-- Clean White Floor Standing Pad
			local standPos = Vector3.new(dirX * STAND_DIST, 0.21, dirZ * STAND_DIST)
			local standPad = Instance.new("Part")
			standPad.Name = "StandPad_" .. seatIdx
			standPad.Shape = Enum.PartType.Cylinder
			standPad.Size = Vector3.new(0.04, 3.4, 3.4)
			standPad.CFrame = CFrame.new(standPos) * CFrame.Angles(0, 0, math.rad(90))
			standPad.Anchored = true
			standPad.CanCollide = false
			standPad.Material = Enum.Material.Neon
			standPad.Color = Color3.fromRGB(245, 250, 255)
			standPad.Transparency = 0.35
			standPad.Parent = arena
			standPads[seatIdx] = standPad

			-- Standing CFrame (Y=3.2 for HumanoidRootPart, facing arena center)
			local charStandPos = Vector3.new(standPos.X, 3.2, standPos.Z)
			local lookTarget = Vector3.new(0, 1.2, 0)
			standingCFrames[seatIdx] = CFrame.lookAt(charStandPos, lookTarget)

			-- Seat 1 Spawn Location
			if seatIdx == 1 then
				local spawn = Instance.new("SpawnLocation")
				spawn.Name = "Seat1_SpawnLocation"
				spawn.Size = Vector3.new(3.0, 0.2, 3.0)
				spawn.CFrame = CFrame.lookAt(Vector3.new(standPos.X, 1.0, standPos.Z), lookTarget)
				spawn.Anchored = true
				spawn.CanCollide = true
				spawn.Transparency = 1
				spawn.Neutral = true
				spawn.Duration = 0
				spawn.Parent = arena
			end
		end

	-- ========================================================================
	-- MODE B: CLASSIC WOODEN TABLE PARLOR (Preserved Table Version)
	-- ========================================================================
	else
		pcall(function()
			Lighting.Brightness = 2.0
			Lighting.Ambient = Color3.fromRGB(150, 150, 150)
			Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
			Lighting.ClockTime = 14.0
			Lighting.GlobalShadows = true
			Lighting.FogEnd = 1000
		end)

		local floor = Instance.new("Part")
		floor.Name = "ArenaFloor"
		floor.Size = Vector3.new(140, 2, 140)
		floor.Position = Vector3.new(0, 0, 0)
		floor.Anchored = true
		floor.CanCollide = true
		floor.Material = Enum.Material.WoodPlanks
		floor.Color = Color3.fromRGB(125, 95, 75)
		floor.Parent = arena

		local rug = Instance.new("Part")
		rug.Name = "TableRug"
		rug.Shape = Enum.PartType.Cylinder
		rug.Size = Vector3.new(0.05, 26, 26)
		rug.CFrame = CFrame.new(0, 1.03, 0) * CFrame.Angles(0, 0, math.rad(90))
		rug.Anchored = true
		rug.CanCollide = false
		rug.Material = Enum.Material.Fabric
		rug.Color = Color3.fromRGB(55, 36, 28)
		rug.Parent = arena

		local TABLE_POS = Vector3.new(0, 3.0, 0)
		local TABLE_RAD = 7.5
		local tableBase = Instance.new("Part")
		tableBase.Name = "MainTable"
		tableBase.Shape = Enum.PartType.Cylinder
		tableBase.Size = Vector3.new(1.8, TABLE_RAD * 2, TABLE_RAD * 2)
		tableBase.CFrame = CFrame.new(TABLE_POS) * CFrame.Angles(0, 0, math.rad(90))
		tableBase.Anchored = true
		tableBase.CanCollide = true
		tableBase.Material = Enum.Material.Wood
		tableBase.Color = Color3.fromRGB(70, 45, 30)
		tableBase.Parent = arena

		local felt = Instance.new("Part")
		felt.Name = "TableFelt"
		felt.Shape = Enum.PartType.Cylinder
		felt.Size = Vector3.new(1.85, (TABLE_RAD - 0.7) * 2, (TABLE_RAD - 0.7) * 2)
		felt.CFrame = CFrame.new(TABLE_POS + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
		felt.Anchored = true
		felt.CanCollide = true
		felt.Material = Enum.Material.Fabric
		felt.Color = Color3.fromRGB(115, 26, 36)
		felt.Parent = arena

		local leg = Instance.new("Part")
		leg.Name = "TablePedestal"
		leg.Shape = Enum.PartType.Cylinder
		leg.Size = Vector3.new(3.0, 3.8, 3.8)
		leg.CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90))
		leg.Anchored = true
		leg.CanCollide = true
		leg.Material = Enum.Material.Wood
		leg.Color = Color3.fromRGB(50, 32, 22)
		leg.Parent = arena

		local COASTER_DIST = 5.0
		local STAND_DIST = 9.8

		for seatIdx = 1, 6 do
			local angle = math.rad((seatIdx - 1) * (360 / 6) + 90)
			local dirX = math.cos(angle)
			local dirZ = math.sin(angle)

			local coasterPos = Vector3.new(dirX * COASTER_DIST, TABLE_POS.Y + 0.96, dirZ * COASTER_DIST)
			local coaster = Instance.new("Part")
			coaster.Name = "Coaster_" .. seatIdx
			coaster.Shape = Enum.PartType.Cylinder
			coaster.Size = Vector3.new(0.08, 3.2, 3.2)
			coaster.CFrame = CFrame.new(coasterPos) * CFrame.Angles(0, 0, math.rad(90))
			coaster.Anchored = true
			coaster.CanCollide = false
			coaster.Material = Enum.Material.SmoothPlastic
			coaster.Color = Color3.fromRGB(68, 42, 28)
			coaster.Parent = arena
			coasterParts[seatIdx] = coaster

			local standPos = Vector3.new(dirX * STAND_DIST, 1.05, dirZ * STAND_DIST)
			local standPad = Instance.new("Part")
			standPad.Name = "StandPad_" .. seatIdx
			standPad.Shape = Enum.PartType.Cylinder
			standPad.Size = Vector3.new(0.1, 3.6, 3.6)
			standPad.CFrame = CFrame.new(standPos) * CFrame.Angles(0, 0, math.rad(90))
			standPad.Anchored = true
			standPad.CanCollide = false
			standPad.Material = Enum.Material.Metal
			standPad.Color = Color3.fromRGB(75, 55, 38)
			standPad.Parent = arena
			standPads[seatIdx] = standPad

			local charStandPos = Vector3.new(standPos.X, 4.0, standPos.Z)
			local lookTarget = Vector3.new(0, TABLE_POS.Y + 0.5, 0)
			standingCFrames[seatIdx] = CFrame.lookAt(charStandPos, lookTarget)

			if seatIdx == 1 then
				local spawn = Instance.new("SpawnLocation")
				spawn.Name = "Seat1_SpawnLocation"
				spawn.Size = Vector3.new(3.0, 0.2, 3.0)
				spawn.CFrame = CFrame.lookAt(Vector3.new(standPos.X, 1.2, standPos.Z), lookTarget)
				spawn.Anchored = true
				spawn.CanCollide = true
				spawn.Transparency = 1
				spawn.Neutral = true
				spawn.Duration = 0
				spawn.Parent = arena
			end
		end
	end

	-- Card Stacks Container
	local stacksFolder = Instance.new("Folder")
	stacksFolder.Name = "TableCardStacks"
	stacksFolder.Parent = arena

	arenaModel = arena
	print("[TableBuilder] Arena constructed successfully in mode:", mode)
	return arena
end

-- ============================================================================
-- 2. HELPER: CREATE OVERHEAD FLOATING NAMETAG (Zero Black Boxes!)
-- ============================================================================
local function createOverheadBillboard(adorneePart: BasePart, displayName: string, isBot: boolean): BillboardGui
	local bill = Instance.new("BillboardGui")
	bill.Name = "PlayerInfoTag"
	bill.Size = UDim2.new(0, 180, 0, 80)
	bill.StudsOffset = Vector3.new(0, 3.2, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = adorneePart
	bill.Parent = adorneePart

	-- Turn Indicator Arrow (Appears directly above name when active)
	local turnArrow = Instance.new("TextLabel")
	turnArrow.Name = "TurnArrow"
	turnArrow.Size = UDim2.new(1, 0, 0, 16)
	turnArrow.Position = UDim2.new(0, 0, 0, 0)
	turnArrow.BackgroundTransparency = 1
	turnArrow.Font = Enum.Font.FredokaOne
	turnArrow.TextSize = 15
	turnArrow.TextColor3 = Color3.fromRGB(255, 225, 75)
	turnArrow.TextStrokeTransparency = 0.4
	turnArrow.TextStrokeColor3 = Color3.fromRGB(60, 45, 0)
	turnArrow.Text = "▼ ACTIVE"
	turnArrow.Visible = false
	turnArrow.Parent = bill

	-- Clean Floating Player Name (No dark rectangular background!)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 0, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = Color3.fromRGB(245, 250, 255)
	nameLabel.TextStrokeTransparency = 0.45
	nameLabel.TextStrokeColor3 = Color3.fromRGB(15, 35, 65)
	nameLabel.Text = displayName .. (isBot and " [BOT]" or "")
	nameLabel.Parent = bill

	-- Floating Score Gems Display (◇ ◇)
	local scoreFrame = Instance.new("Frame")
	scoreFrame.Name = "ScoreRow"
	scoreFrame.Size = UDim2.new(1, 0, 0, 18)
	scoreFrame.Position = UDim2.new(0, 0, 0, 42)
	scoreFrame.BackgroundTransparency = 1
	scoreFrame.Parent = bill

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
		gem.Font = Enum.Font.FredokaOne
		gem.TextSize = 16
		gem.Text = "◇"
		gem.TextColor3 = Color3.fromRGB(210, 230, 255)
		gem.TextStrokeTransparency = 0.5
		gem.TextStrokeColor3 = Color3.fromRGB(15, 35, 65)
		gem.LayoutOrder = i
		gem.Parent = scoreFrame
	end

	-- LOCOfficial Clean White Card Count Badge (Floating beside/above)
	local cardBadge = Instance.new("Frame")
	cardBadge.Name = "CardCountBadge"
	cardBadge.Size = UDim2.new(0, 24, 0, 32)
	cardBadge.Position = UDim2.new(1, -24, 0, 12)
	cardBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	cardBadge.BorderSizePixel = 0
	cardBadge.Parent = bill

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 5)
	badgeCorner.Parent = cardBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(180, 205, 235)
	badgeStroke.Thickness = 1.5
	badgeStroke.Parent = cardBadge

	local badgeNum = Instance.new("TextLabel")
	badgeNum.Name = "CountNum"
	badgeNum.Size = UDim2.new(1, 0, 1, 0)
	badgeNum.BackgroundTransparency = 1
	badgeNum.Font = Enum.Font.GothamBold
	badgeNum.TextSize = 14
	badgeNum.TextColor3 = Color3.fromRGB(30, 35, 45)
	badgeNum.Text = "4"
	badgeNum.Parent = cardBadge

	return bill
end

-- ============================================================================
-- 3. POSITION HUMAN PLAYERS (STANDING AT POD)
-- ============================================================================
function TableBuilder.StandPlayer(player: Player, seatIndex: number)
	local function setupPlayerCharacter(char: Model)
		local targetCF = standingCFrames[seatIndex]
		if not targetCF then return end

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
			seatBillboards[seatIndex] = createOverheadBillboard(head, player.DisplayName, false)
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
-- 4. SPAWN STYLIZED STANDING BOT AVATARS (LOCOfficial Style)
-- ============================================================================
function TableBuilder.SpawnStandingBot(botName: string, seatIndex: number)
	local targetCF = standingCFrames[seatIndex]
	if not targetCF or not arenaModel then return end

	if botDummies[seatIndex] and botDummies[seatIndex].Parent then
		botDummies[seatIndex]:Destroy()
		botDummies[seatIndex] = nil
	end

	local botColorThemes: { [string]: { suit: Color3, trim: Color3, skin: Color3 } } = {
		["Doña Flor"]    = { suit = Color3.fromRGB(160, 30, 45),  trim = Color3.fromRGB(245, 205, 75), skin = Color3.fromRGB(235, 195, 165) },
		["El Bandido"]   = { suit = Color3.fromRGB(48, 48, 54),   trim = Color3.fromRGB(195, 145, 70), skin = Color3.fromRGB(215, 175, 145) },
		["Don Diego"]    = { suit = Color3.fromRGB(28, 55, 105),  trim = Color3.fromRGB(225, 225, 235), skin = Color3.fromRGB(230, 190, 160) },
		["La Catrina"]   = { suit = Color3.fromRGB(90, 32, 110),  trim = Color3.fromRGB(250, 205, 80), skin = Color3.fromRGB(240, 235, 225) },
		["Señor Hueso"]  = { suit = Color3.fromRGB(225, 220, 210), trim = Color3.fromRGB(35, 28, 32), skin = Color3.fromRGB(245, 240, 230) },
	}
	local theme = botColorThemes[botName] or { suit = Color3.fromRGB(55, 40, 32), trim = Color3.fromRGB(215, 185, 65), skin = Color3.fromRGB(225, 190, 160) }

	local botModel = Instance.new("Model")
	botModel.Name = "Bot_" .. botName
	botModel.Parent = arenaModel

	-- Stylized Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.4, 2.8, 1.4)
	torso.CFrame = targetCF
	torso.Anchored = true
	torso.CanCollide = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = theme.suit
	torso.Parent = botModel

	-- Suit Lapel
	local lapel = Instance.new("Part")
	lapel.Name = "Lapel"
	lapel.Size = Vector3.new(1.2, 1.8, 0.2)
	lapel.CFrame = targetCF * CFrame.new(0, 0.4, -0.7)
	lapel.Anchored = true
	lapel.CanCollide = false
	lapel.Material = Enum.Material.SmoothPlastic
	lapel.Color = theme.trim
	lapel.Parent = botModel

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.8, 1.8, 1.8)
	head.CFrame = targetCF * CFrame.new(0, 2.1, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.Color = theme.skin
	head.Parent = botModel

	-- Face Gui
	local faceGui = Instance.new("SurfaceGui")
	faceGui.Name = "FaceGui"
	faceGui.Face = Enum.NormalId.Front
	faceGui.CanvasSize = Vector2.new(128, 128)
	faceGui.AlwaysOnTop = false
	faceGui.Adornee = head
	faceGui.Parent = head

	local faceIcon = Instance.new("TextLabel")
	faceIcon.Size = UDim2.new(1, 0, 1, 0)
	faceIcon.BackgroundTransparency = 1
	faceIcon.Font = Enum.Font.FredokaOne
	faceIcon.TextSize = 64
	faceIcon.Text = (botName == "Señor Hueso" or botName == "La Catrina") and "💀" or "🤠"
	faceIcon.Parent = faceGui

	-- Arms
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = Vector3.new(1.0, 2.6, 1.0)
	leftArm.CFrame = targetCF * CFrame.new(-1.7, -0.1, 0)
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Color = theme.suit
	leftArm.Parent = botModel

	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Size = Vector3.new(1.0, 2.6, 1.0)
	rightArm.CFrame = targetCF * CFrame.new(1.7, -0.1, 0)
	rightArm.Anchored = true
	rightArm.CanCollide = false
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Color = theme.suit
	rightArm.Parent = botModel

	-- Legs
	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(2.2, 2.4, 1.2)
	legs.CFrame = targetCF * CFrame.new(0, -2.4, 0)
	legs.Anchored = true
	legs.CanCollide = false
	legs.Material = Enum.Material.SmoothPlastic
	legs.Color = Color3.fromRGB(25, 22, 25)
	legs.Parent = botModel

	seatBillboards[seatIndex] = createOverheadBillboard(head, botName, true)
	botDummies[seatIndex] = botModel
	print("[TableBuilder] Spawned standing bot:", botName, "at seat", seatIndex)
end

-- ============================================================================
-- 5. VISUAL POLISH & HIGHLIGHTS (Turn Glow, Scores & Emotes)
-- ============================================================================
-- Highlights the active player's name and floor pad when it's their turn
function TableBuilder.HighlightTurn(activeSeatIndex: number?)
	for seatIdx, bill in pairs(seatBillboards) do
		local isActive = (activeSeatIndex ~= nil and seatIdx == activeSeatIndex)
		local nameLabel = bill:FindFirstChild("NameLabel") :: TextLabel?
		local turnArrow = bill:FindFirstChild("TurnArrow") :: TextLabel?

		if nameLabel then
			if isActive then
				nameLabel.TextColor3 = Color3.fromRGB(255, 225, 75)
				nameLabel.TextStrokeColor3 = Color3.fromRGB(70, 45, 0)
				nameLabel.TextSize = 17
			else
				nameLabel.TextColor3 = Color3.fromRGB(245, 250, 255)
				nameLabel.TextStrokeColor3 = Color3.fromRGB(15, 35, 65)
				nameLabel.TextSize = 15
			end
		end

		if turnArrow then
			turnArrow.Visible = isActive
		end
	end

	for seatIdx, pad in pairs(standPads) do
		local isActive = (activeSeatIndex ~= nil and seatIdx == activeSeatIndex)
		local highlight = pad:FindFirstChild("TurnGlow") :: Highlight?
		if isActive then
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "TurnGlow"
				highlight.FillColor = Color3.fromRGB(255, 215, 50)
				highlight.FillTransparency = 0.4
				highlight.OutlineColor = Color3.fromRGB(255, 235, 90)
				highlight.OutlineTransparency = 0.05
				highlight.Adornee = pad
				highlight.Parent = pad
			end
		else
			if highlight then
				highlight:Destroy()
			end
		end
	end
end

-- Update overhead score gems (◆ ◆)
function TableBuilder.UpdateScore(seatIndex: number, score: number)
	local bill = seatBillboards[seatIndex]
	if not bill then return end
	local scoreRow = bill:FindFirstChild("ScoreRow") :: Frame?
	if not scoreRow then return end

	for i = 1, 2 do
		local gem = scoreRow:FindFirstChild("Gem_" .. i) :: TextLabel?
		if gem then
			local hasPoint = (score >= i)
			gem.Text = hasPoint and "◆" or "◇"
			gem.TextColor3 = hasPoint and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(210, 230, 255)
		end
	end
end

-- Update remaining card count badge [ 4 ]
function TableBuilder.UpdateCardCount(seatIndex: number, count: number)
	local bill = seatBillboards[seatIndex]
	if not bill then return end
	local badge = bill:FindFirstChild("CardCountBadge") :: Frame?
	local num = badge and badge:FindFirstChild("CountNum") :: TextLabel?
	if num then
		num.Text = tostring(count)
	end
end

-- Change bot face emote
function TableBuilder.SetBotEmote(seatIndex: number, emote: string)
	local bot = botDummies[seatIndex]
	if not bot then return end
	local head = bot:FindFirstChild("Head") :: BasePart?
	local faceGui = head and head:FindFirstChild("FaceGui") :: SurfaceGui?
	local icon = faceGui and faceGui:FindFirstChild("Icon") :: TextLabel?
	if icon then
		icon.Text = emote
	end
end

-- ============================================================================
-- 6. ACCESSORS & GETTERS
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

function TableBuilder.GetArenaMode(): string
	return currentArenaMode
end

return TableBuilder
