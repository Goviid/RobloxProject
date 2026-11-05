--!strict
-- TableBuilder.luau
-- Constructs the clean, open 3D tabletop environment with regular bright lighting and standing bot avatars (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local TableBuilder = {}

-- Arena Spatial Configuration
local TABLE_POSITION = Vector3.new(0, 3.0, 0)
local TABLE_RADIUS = 7.5
local STAND_DISTANCE = 9.8        -- Distance from table center to player standing pod
local COASTER_DISTANCE = 5.0      -- Distance from table center to card coaster on table surface

local arenaModel: Model? = nil
local standingCFrames: { [number]: CFrame } = {}
local coasterParts: { [number]: Part } = {}
local botDummies: { [number]: Model } = {}
local standPads: { [number]: Part } = {}
local seatBillboards: { [number]: BillboardGui } = {}

-- ============================================================================
-- 1. CONSTRUCT BASIC OPEN LEVEL WITH REGULAR BRIGHT LIGHTING
-- ============================================================================
function TableBuilder.Build()
	-- Clean up any previous arena instance on live reload
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

	-- ------------------------------------------------------------------------
	-- A. Regular Bright Studio Lighting Setup
	-- ------------------------------------------------------------------------
	pcall(function()
		Lighting.Brightness = 2.0
		Lighting.Ambient = Color3.fromRGB(150, 150, 150)
		Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
		Lighting.ClockTime = 14.0 -- 2 PM clear daytime
		Lighting.GlobalShadows = true

		local oldCC = Lighting:FindFirstChild("SkullsColorCorrection")
		if oldCC then oldCC:Destroy() end
		local oldBloom = Lighting:FindFirstChild("SkullsBloom")
		if oldBloom then oldBloom:Destroy() end
	end)

	-- Hide the default baseplate so only the polished LOCOfficial arena floor is visible
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
	end

	-- ------------------------------------------------------------------------
	-- B. Open Studio Arena Floor (LOCOfficial Style)
	-- ------------------------------------------------------------------------
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(140, 2, 140)
	floor.Position = Vector3.new(0, 0, 0) -- Elevated cleanly above baseplate
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(125, 95, 75)
	floor.Parent = arena

	-- Center Circular Accent Rug under the table
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

	-- ------------------------------------------------------------------------
	-- C. Center Circular Table & Felt Inset
	-- ------------------------------------------------------------------------
	local tableBase = Instance.new("Part")
	tableBase.Name = "MainTable"
	tableBase.Shape = Enum.PartType.Cylinder
	tableBase.Size = Vector3.new(1.8, TABLE_RADIUS * 2, TABLE_RADIUS * 2)
	tableBase.CFrame = CFrame.new(TABLE_POSITION) * CFrame.Angles(0, 0, math.rad(90))
	tableBase.Anchored = true
	tableBase.CanCollide = true
	tableBase.Material = Enum.Material.Wood
	tableBase.Color = Color3.fromRGB(70, 45, 30)
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
	felt.Color = Color3.fromRGB(115, 26, 36)
	felt.Parent = arena

	-- Table Pedestal Leg
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
	lampHood.Color = Color3.fromRGB(60, 48, 28)
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

		-- 3D Card Coaster on Table Surface (Oversized 3.2 studs)
		local coasterPos = Vector3.new(TABLE_POSITION.X + dirX * COASTER_DISTANCE, TABLE_POSITION.Y + 0.96, TABLE_POSITION.Z + dirZ * COASTER_DISTANCE)
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

		-- Gold Trim Ring on Coaster
		local trim = Instance.new("Highlight")
		trim.Name = "GoldTrim"
		trim.FillTransparency = 1
		trim.OutlineColor = Color3.fromRGB(235, 185, 55)
		trim.OutlineTransparency = 0.2
		trim.Adornee = coaster
		trim.Parent = coaster

		-- Standing Floor Pad (Brass ring on floor resting on ArenaFloor Y=1.0)
		local standPos = Vector3.new(TABLE_POSITION.X + dirX * STAND_DISTANCE, 1.05, TABLE_POSITION.Z + dirZ * STAND_DISTANCE)
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

		-- Standing CFrame: Standing on the pad (Y=4.0 for HumanoidRootPart), facing directly at table center
		local lookTarget = Vector3.new(TABLE_POSITION.X, TABLE_POSITION.Y + 0.5, TABLE_POSITION.Z)
		local charStandPos = Vector3.new(standPos.X, 4.0, standPos.Z)
		standingCFrames[seatIdx] = CFrame.lookAt(charStandPos, lookTarget)

		-- Seat 1 Default Spawn Location: Engine places the joining player right on Pad 1
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
	bill.Size = UDim2.new(0, 150, 0, 52)
	bill.StudsOffset = Vector3.new(0, 2.8, 0)
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
	stroke.Color = Color3.fromRGB(210, 165, 60)
	stroke.Thickness = 1.8
	stroke.Parent = frame

	-- Player Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.Position = UDim2.new(0, 0, 0, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(255, 240, 215)
	nameLabel.Text = displayName .. (isBot and " [BOT]" or "")
	nameLabel.Parent = frame

	-- Score Gems Display (Two gems for 2 points to win)
	local scoreFrame = Instance.new("Frame")
	scoreFrame.Name = "ScoreRow"
	scoreFrame.Size = UDim2.new(1, 0, 0, 20)
	scoreFrame.Position = UDim2.new(0, 0, 0, 26)
	scoreFrame.BackgroundTransparency = 1
	scoreFrame.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = scoreFrame

	for i = 1, 2 do
		local gem = Instance.new("TextLabel")
		gem.Name = "Gem_" .. i
		gem.Size = UDim2.new(0, 18, 0, 18)
		gem.BackgroundTransparency = 1
		gem.Font = Enum.Font.GothamBold
		gem.TextSize = 14
		gem.Text = "◇"
		gem.TextColor3 = Color3.fromRGB(140, 120, 100)
		gem.LayoutOrder = i
		gem.Parent = scoreFrame
	end

	return bill
end

-- ============================================================================
-- 3. POSITION HUMAN PLAYERS (STANDING AT POD, FACING TABLE)
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
-- 4. SPAWN STYLIZED STANDING BOT AVATARS (LOCOfficial Character Style)
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

	-- Stylized Torso (Prominent R6 proportions)
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.4, 2.8, 1.4)
	torso.CFrame = targetCF
	torso.Anchored = true
	torso.CanCollide = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = theme.suit
	torso.Parent = botModel

	-- Suit Lapel / Vest
	local lapel = Instance.new("Part")
	lapel.Name = "Lapel"
	lapel.Size = Vector3.new(1.2, 1.8, 0.2)
	lapel.CFrame = targetCF * CFrame.new(0, 0.4, -0.7)
	lapel.Anchored = true
	lapel.CanCollide = false
	lapel.Material = Enum.Material.SmoothPlastic
	lapel.Color = theme.trim
	lapel.Parent = botModel

	-- Stylized Head
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

	-- Stylized Face SurfaceGui (Looking directly at table center)
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
	print("[TableBuilder] Spawned visible standing bot:", botName, "at seat", seatIndex)
end

-- ============================================================================
-- 5. VISUAL POLISH & FEEDBACK (LOCOfficial Turn Glow, Scores & Emotes)
-- ============================================================================
-- Highlight floor pod of active player with glowing golden ring
function TableBuilder.HighlightTurn(activeSeatIndex: number?)
	for seatIdx, pad in pairs(standPads) do
		local isActive = (activeSeatIndex ~= nil and seatIdx == activeSeatIndex)
		local highlight = pad:FindFirstChild("TurnGlow") :: Highlight?
		if isActive then
			if not highlight then
				highlight = Instance.new("Highlight")
				highlight.Name = "TurnGlow"
				highlight.FillColor = Color3.fromRGB(245, 195, 55)
				highlight.FillTransparency = 0.5
				highlight.OutlineColor = Color3.fromRGB(255, 220, 80)
				highlight.OutlineTransparency = 0.1
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

-- Update overhead billboard score gems (◆ ◆)
function TableBuilder.UpdateScore(seatIndex: number, score: number)
	local bill = seatBillboards[seatIndex]
	if not bill then return end
	local container = bill:FindFirstChild("Container") :: Frame?
	local scoreRow = container and container:FindFirstChild("ScoreRow") :: Frame?
	if not scoreRow then return end

	for i = 1, 2 do
		local gem = scoreRow:FindFirstChild("Gem_" .. i) :: TextLabel?
		if gem then
			local hasPoint = (score >= i)
			gem.Text = hasPoint and "◆" or "◇"
			gem.TextColor3 = hasPoint and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(140, 120, 100)
		end
	end
end

-- Change bot face emote (e.g. "😱" on skull, "🎉" on score, "🤠" normal)
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

return TableBuilder
