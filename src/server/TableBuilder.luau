--!strict
-- TableBuilder.luau
-- Builds the 3D Table Arena in Workspace with standing player pods, table coasters, and bot avatars (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local TableBuilder = {}

-- Arena Configuration
local TABLE_POSITION = Vector3.new(0, 3, 0)
local TABLE_RADIUS = 7.5
local STAND_DISTANCE = 9.8      -- Distance from table center to standing player
local COASTER_DISTANCE = 5.2    -- Distance from table center to card coaster on table

local arenaModel: Model? = nil
local standingCFrames: { [number]: CFrame } = {}
local coasterParts: { [number]: Part } = {}
local botDummies: { [number]: Model } = {}

-- ============================================================================
-- 1. BUILD THE 3D TABLE & ENVIRONMENT (LOCOfficial Style)
-- ============================================================================
function TableBuilder.Build()
	-- Clean up any previous arena on reload
	local existing = Workspace:FindFirstChild("SkullsArena")
	if existing then existing:Destroy() end

	local arena = Instance.new("Model")
	arena.Name = "SkullsArena"
	arena.Parent = Workspace

	-- Room Floor (Dark wood planks)
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(90, 2, 90)
	floor.Position = Vector3.new(0, -1, 0)
	floor.Anchored = true
	floor.CanCollide = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(24, 16, 12)
	floor.Parent = arena

	-- Center Circular Table (Thick wood rim)
	local tableBase = Instance.new("Part")
	tableBase.Name = "MainTable"
	tableBase.Shape = Enum.PartType.Cylinder
	tableBase.Size = Vector3.new(1.8, TABLE_RADIUS * 2, TABLE_RADIUS * 2)
	tableBase.CFrame = CFrame.new(TABLE_POSITION) * CFrame.Angles(0, 0, math.rad(90))
	tableBase.Anchored = true
	tableBase.CanCollide = true
	tableBase.Material = Enum.Material.Wood
	tableBase.Color = Color3.fromRGB(50, 30, 20)
	tableBase.Parent = arena

	-- Table Center Inset Felt
	local felt = Instance.new("Part")
	felt.Name = "TableFelt"
	felt.Shape = Enum.PartType.Cylinder
	felt.Size = Vector3.new(1.85, (TABLE_RADIUS - 0.7) * 2, (TABLE_RADIUS - 0.7) * 2)
	felt.CFrame = CFrame.new(TABLE_POSITION + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	felt.Anchored = true
	felt.CanCollide = true
	felt.Material = Enum.Material.Fabric
	felt.Color = Color3.fromRGB(30, 18, 14)
	felt.Parent = arena

	-- Overhead Warm Chandelier Light
	local lamp = Instance.new("Part")
	lamp.Name = "OverheadLamp"
	lamp.Size = Vector3.new(1, 0.5, 1)
	lamp.Position = TABLE_POSITION + Vector3.new(0, 15, 0)
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.Transparency = 1
	lamp.Parent = arena

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 215, 150)
	light.Brightness = 3
	light.Range = 40
	light.Shadows = true
	light.Parent = lamp

	-- Container for 3D card stacks
	local stacksFolder = Instance.new("Folder")
	stacksFolder.Name = "TableCardStacks"
	stacksFolder.Parent = arena

	-- ========================================================================
	-- 2. CREATE 6 STANDING PODS & TABLE COASTERS IN A CIRCLE
	-- ========================================================================
	for seatIdx = 1, 6 do
		local angle = math.rad((seatIdx - 1) * (360 / 6) + 90)
		local dirX = math.cos(angle)
		local dirZ = math.sin(angle)

		-- 3D Coaster on Table Surface
		local coasterPos = Vector3.new(TABLE_POSITION.X + dirX * COASTER_DISTANCE, TABLE_POSITION.Y + 0.95, TABLE_POSITION.Z + dirZ * COASTER_DISTANCE)
		local coaster = Instance.new("Part")
		coaster.Name = "Coaster_" .. seatIdx
		coaster.Shape = Enum.PartType.Cylinder
		coaster.Size = Vector3.new(0.08, 2.6, 2.6)
		coaster.CFrame = CFrame.new(coasterPos) * CFrame.Angles(0, 0, math.rad(90))
		coaster.Anchored = true
		coaster.CanCollide = false
		coaster.Material = Enum.Material.SmoothPlastic
		coaster.Color = Color3.fromRGB(65, 42, 28)
		coaster.Parent = arena
		coasterParts[seatIdx] = coaster

		-- Coaster Gold Trim Ring
		local trim = Instance.new("Highlight")
		trim.Name = "GoldTrim"
		trim.FillTransparency = 1
		trim.OutlineColor = Color3.fromRGB(230, 180, 50)
		trim.OutlineTransparency = 0.3
		trim.Adornee = coaster
		trim.Parent = coaster

		-- Standing Floor Marker (Circular brass ring where player stands)
		local standPos = Vector3.new(TABLE_POSITION.X + dirX * STAND_DISTANCE, 0.05, TABLE_POSITION.Z + dirZ * STAND_DISTANCE)
		local standPad = Instance.new("Part")
		standPad.Name = "StandPad_" .. seatIdx
		standPad.Shape = Enum.PartType.Cylinder
		standPad.Size = Vector3.new(0.1, 3.2, 3.2)
		standPad.CFrame = CFrame.new(standPos) * CFrame.Angles(0, 0, math.rad(90))
		standPad.Anchored = true
		standPad.CanCollide = false
		standPad.Material = Enum.Material.Metal
		standPad.Color = Color3.fromRGB(50, 38, 26)
		standPad.Parent = arena

		-- Standing CFrame: Standing on the pad, facing directly at the table center
		local lookTarget = Vector3.new(TABLE_POSITION.X, 3.0, TABLE_POSITION.Z)
		local charStandPos = Vector3.new(standPos.X, 3.0, standPos.Z)
		standingCFrames[seatIdx] = CFrame.lookAt(charStandPos, lookTarget)
	end

	arenaModel = arena
	print("[TableBuilder] 3D Arena created with 6 standing pods and table coasters.")
	return arena
end

-- ============================================================================
-- 3. POSITION PLAYERS & BOTS (STANDING FACING TABLE)
-- ============================================================================
function TableBuilder.StandPlayer(player: Player, seatIndex: number)
	local targetCF = standingCFrames[seatIndex]
	if not targetCF then return end

	task.spawn(function()
		local char = player.Character or player.CharacterAdded:Wait()
		local hrp = char:WaitForChild("HumanoidRootPart", 10) :: Part?
		local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?

		if hrp and humanoid then
			-- Position standing at the table
			hrp.CFrame = targetCF
			-- Freeze movement so the player stands in place at the table (LOCOfficial style)
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.AutoRotate = false

			-- Ensure player stays facing the table if they respawn
			player.CharacterAdded:Connect(function(newChar)
				task.wait(0.2)
				local newHrp = newChar:WaitForChild("HumanoidRootPart", 5) :: Part?
				local newHum = newChar:WaitForChild("Humanoid", 5) :: Humanoid?
				if newHrp and newHum then
					newHrp.CFrame = targetCF
					newHum.WalkSpeed = 0
					newHum.JumpPower = 0
					newHum.AutoRotate = false
				end
			end)
		end
	end)
end

-- Spawn a stylized Standing Bot Character (LOCOfficial style)
function TableBuilder.SpawnStandingBot(botName: string, seatIndex: number)
	local targetCF = standingCFrames[seatIndex]
	if not targetCF or not arenaModel then return end

	-- Clean up previous bot if re-spawning
	if botDummies[seatIndex] then
		botDummies[seatIndex]:Destroy()
		botDummies[seatIndex] = nil
	end

	local botModel = Instance.new("Model")
	botModel.Name = "Bot_" .. botName
	botModel.Parent = arenaModel

	-- Stylized torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2.4, 1.2)
	torso.CFrame = targetCF
	torso.Anchored = true
	torso.CanCollide = false
	torso.Material = Enum.Material.SmoothPlastic
	torso.Color = Color3.fromRGB(45, 30, 25)
	torso.Parent = botModel

	-- Stylized head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.CFrame = targetCF * CFrame.new(0, 1.9, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Material = Enum.Material.SmoothPlastic
	head.Color = Color3.fromRGB(220, 185, 155)
	head.Parent = botModel

	-- Bot Name Tag (BillboardGui)
	local bill = Instance.new("BillboardGui")
	bill.Name = "NameTag"
	bill.Size = UDim2.new(0, 120, 0, 36)
	bill.StudsOffset = Vector3.new(0, 2.2, 0)
	bill.AlwaysOnTop = true
	bill.Adornee = head
	bill.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundColor3 = Color3.fromRGB(15, 10, 8)
	nameLabel.BackgroundTransparency = 0.3
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(250, 230, 180)
	nameLabel.Text = botName .. " (Bot)"
	nameLabel.Parent = bill

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = nameLabel

	botDummies[seatIndex] = botModel
end

function TableBuilder.GetCoasterCFrame(seatIndex: number): CFrame?
	local coaster = coasterParts[seatIndex]
	return coaster and coaster.CFrame or nil
end

return TableBuilder
