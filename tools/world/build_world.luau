--!strict
-- build_world.luau
-- Builds the saved 3D world: one tavern room per table, in Workspace.World.Room_<id>.
-- Run it in Studio in Edit mode (command bar, or Studio MCP execute_luau), then save
-- the place. The game itself never builds the world; it reads each room's TableCenter
-- (see src/server/init.server.luau) and lays the seats out around it.
--
-- Re-running rebuilds the rooms from scratch. Detailed props (fireplace, barrels,
-- lanterns, ...) are cloned from ServerStorage.WorldProps when present (AI-generated
-- meshes kept in the place); missing ones are skipped.
--
-- Must match the game code (src/server/Table/TableBuilder.luau):
--   floor at Y = 0, table top at Y = 3.0, seats 7.8 studs from the centre at angles
--   -(i - 1) * 360 / seats from +Z (seat 1 at +Z, the camera looks from there to -Z).

local ServerStorage = game:GetService("ServerStorage")

local ROOMS = {
	{ id = 1, origin = Vector3.new(0, 0, 0), half = 23, seats = 4 },
	{ id = 2, origin = Vector3.new(300, 0, 0), half = 26, seats = 6 },
}
local HEIGHT = 18
local TABLE_RADIUS = 7.5
local TABLE_TOP = 3.0
local STAND_RADIUS = 7.8

local C = {
	floor = Color3.fromRGB(96, 62, 40),
	wall = Color3.fromRGB(104, 66, 42),
	wainscot = Color3.fromRGB(70, 42, 28),
	timber = Color3.fromRGB(58, 36, 24),
	ceiling = Color3.fromRGB(52, 34, 24),
	tableTop = Color3.fromRGB(128, 80, 52),
	tableEdge = Color3.fromRGB(110, 66, 40),
	iron = Color3.fromRGB(40, 36, 34),
	rug = Color3.fromRGB(78, 26, 28),
	rugBorder = Color3.fromRGB(126, 92, 42),
	glass = Color3.fromRGB(28, 42, 66),
	warmLight = Color3.fromRGB(255, 208, 160),
	fireLight = Color3.fromRGB(255, 130, 55),
}

local props = ServerStorage:FindFirstChild("WorldProps")

local world: Instance
do
	local existing = workspace:FindFirstChild("World")
	if existing then
		world = existing
	else
		local folder = Instance.new("Folder")
		folder.Name = "World"
		folder.Parent = workspace
		world = folder
	end
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A horizontal disc (cylinders run along X, so turn X up)
local UP = CFrame.Angles(0, 0, math.rad(90))
local function disc(parent: Instance, name: string, diameter: number, thickness: number, centre: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(centre) * UP, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function light(parent: Instance, class: string, props_: { [string]: any }): Light
	local l = Instance.new(class) :: Light
	for k, v in pairs(props_) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- Clone a prop template, scale it to `height` studs tall (if given) and stand it at cf
-- (cf's position is the bottom centre of the prop). Returns nil if the template is missing.
local function prop(parent: Instance, name: string, cf: CFrame, height: number?): Model?
	local template = props and props:FindFirstChild(name)
	if not template then
		return nil
	end
	local model: Model
	if template:IsA("Model") then
		model = template:Clone()
	else
		model = Instance.new("Model")
		model.Name = name
		template:Clone().Parent = model
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
		end
	end
	local _, size = model:GetBoundingBox()
	if height and size.Y > 0 then
		model:ScaleTo(model:GetScale() * height / size.Y)
		_, size = model:GetBoundingBox()
	end
	model:PivotTo(cf * CFrame.new(0, size.Y / 2, 0))
	model.Parent = parent
	return model
end

local function buildRoom(spec: { id: number, origin: Vector3, half: number, seats: number })
	local old = world:FindFirstChild("Room_" .. spec.id)
	if old then
		old:Destroy()
	end
	local room = Instance.new("Model")
	room.Name = "Room_" .. spec.id
	local O = spec.origin
	local h = spec.half
	local W = h * 2
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(O + Vector3.new(x, y, z))
	end
	-- Facing into the room from a wall: +Z wall faces -Z etc.
	local function facing(x: number, y: number, z: number, lookX: number, lookZ: number): CFrame
		local pos = O + Vector3.new(x, y, z)
		return CFrame.lookAt(pos, pos + Vector3.new(lookX, 0, lookZ))
	end

	local shell = Instance.new("Folder")
	shell.Name = "Shell"
	shell.Parent = room

	-- Floor, rug, ceiling
	local floor = part(shell, "Floor", Vector3.new(W + 2, 1, W + 2), at(0, -0.5, 0), C.floor, Enum.Material.WoodPlanks)
	floor.CanCollide = true
	disc(shell, "RugBorder", 24, 0.08, O + Vector3.new(0, 0.04, 0), C.rugBorder, Enum.Material.Fabric)
	disc(shell, "Rug", 22.6, 0.1, O + Vector3.new(0, 0.06, 0), C.rug, Enum.Material.Fabric)
	part(shell, "Ceiling", Vector3.new(W + 2, 1, W + 2), at(0, HEIGHT + 0.5, 0), C.ceiling, Enum.Material.WoodPlanks)

	-- Walls: plank wall, dark wainscot below, a rail and a skirting board
	local walls = {
		{ name = "North", pos = Vector3.new(0, 0, -h - 0.5), size = Vector3.new(W + 2, 0, 1), inward = Vector3.new(0, 0, 1) },
		{ name = "South", pos = Vector3.new(0, 0, h + 0.5), size = Vector3.new(W + 2, 0, 1), inward = Vector3.new(0, 0, -1) },
		{ name = "East", pos = Vector3.new(h + 0.5, 0, 0), size = Vector3.new(1, 0, W + 2), inward = Vector3.new(-1, 0, 0) },
		{ name = "West", pos = Vector3.new(-h - 0.5, 0, 0), size = Vector3.new(1, 0, W + 2), inward = Vector3.new(1, 0, 0) },
	}
	for _, w in ipairs(walls) do
		local base = O + w.pos
		part(shell, "Wall_" .. w.name, Vector3.new(w.size.X, HEIGHT, w.size.Z), CFrame.new(base + Vector3.new(0, HEIGHT / 2, 0)), C.wall, Enum.Material.WoodPlanks)
		-- Trim strips run the inside length of the wall, standing proud of its inner face
		local alongX = w.size.X > 1
		local function strip(name: string, height: number, y: number, depth: number, color: Color3, material: Enum.Material)
			local size = if alongX then Vector3.new(W, height, depth) else Vector3.new(depth, height, W)
			local pos = base + w.inward * (0.5 + depth / 2) + Vector3.new(0, y, 0)
			part(shell, w.name .. "_" .. name, size, CFrame.new(pos), color, material)
		end
		strip("Wainscot", 4.2, 2.1, 0.3, C.wainscot, Enum.Material.WoodPlanks)
		strip("Rail", 0.35, 4.3, 0.5, C.timber, Enum.Material.Wood)
		strip("Skirting", 0.5, 0.25, 0.45, C.timber, Enum.Material.Wood)
		strip("TopBeam", 1.2, HEIGHT - 0.6, 0.9, C.timber, Enum.Material.Wood)
	end

	-- Corner and mid-wall posts, ceiling beams
	local posts = { -h + 0.7, h - 0.7 }
	for _, x in ipairs(posts) do
		for _, z in ipairs(posts) do
			part(shell, "CornerPost", Vector3.new(1.6, HEIGHT, 1.6), at(x, HEIGHT / 2, z), C.timber)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		local m = s * h * 0.5
		part(shell, "Post_N", Vector3.new(1.2, HEIGHT, 1.0), at(m, HEIGHT / 2, -h + 0.5), C.timber)
		part(shell, "Post_S", Vector3.new(1.2, HEIGHT, 1.0), at(m, HEIGHT / 2, h - 0.5), C.timber)
		part(shell, "Post_E", Vector3.new(1.0, HEIGHT, 1.2), at(h - 0.5, HEIGHT / 2, m), C.timber)
		part(shell, "Post_W", Vector3.new(1.0, HEIGHT, 1.2), at(-h + 0.5, HEIGHT / 2, m), C.timber)
	end
	for z = -h + 4, h - 4, 8 do
		part(shell, "CeilingBeam", Vector3.new(W, 1.4, 1.4), at(0, HEIGHT - 0.7, z), C.timber)
	end
	part(shell, "CeilingBeam_Cross", Vector3.new(1.6, 1.6, W), at(0, HEIGHT - 1.6, 0), C.timber)

	-- Windows (night outside) on the east and west walls, and a door on the south wall
	local function window(name: string, cf: CFrame)
		local f = Instance.new("Model")
		f.Name = name
		f.Parent = shell
		part(f, "Glass", Vector3.new(4, 5, 0.2), cf, C.glass, Enum.Material.Glass)
		part(f, "FrameTop", Vector3.new(4.8, 0.4, 0.5), cf * CFrame.new(0, 2.7, 0), C.timber)
		part(f, "FrameBottom", Vector3.new(5.2, 0.5, 0.9), cf * CFrame.new(0, -2.7, 0.2), C.timber)
		part(f, "FrameLeft", Vector3.new(0.4, 5.8, 0.5), cf * CFrame.new(-2.2, 0, 0), C.timber)
		part(f, "FrameRight", Vector3.new(0.4, 5.8, 0.5), cf * CFrame.new(2.2, 0, 0), C.timber)
		part(f, "BarV", Vector3.new(0.2, 5, 0.3), cf, C.timber)
		part(f, "BarH", Vector3.new(4, 0.2, 0.3), cf, C.timber)
		local moon = part(f, "Moonlight", Vector3.new(3.8, 4.8, 0.05), cf * CFrame.new(0, 0, 0.12), C.glass, Enum.Material.SmoothPlastic)
		moon.Transparency = 1
		light(moon, "SurfaceLight", { Face = Enum.NormalId.Back, Color = Color3.fromRGB(120, 150, 210), Brightness = 0.5, Range = 10, Angle = 80, Shadows = false })
	end
	window("Window_East", facing(h - 0.05, 9, -h * 0.35, -1, 0))
	window("Window_West", facing(-h + 0.05, 9, h * 0.35, 1, 0))

	local door = Instance.new("Model")
	door.Name = "Door"
	door.Parent = shell
	local doorCF = facing(0, 5, h - 0.1, 0, -1)
	part(door, "Planks", Vector3.new(5.5, 10, 0.4), doorCF, Color3.fromRGB(74, 46, 30), Enum.Material.WoodPlanks)
	part(door, "Frame", Vector3.new(7, 11, 0.3), doorCF * CFrame.new(0, 0.5, 0.15), C.timber)
	for _, y in ipairs({ -3, 3 }) do
		part(door, "Band", Vector3.new(5.6, 0.35, 0.5), doorCF * CFrame.new(0, y, 0), C.iron, Enum.Material.Metal)
	end
	local handle = part(door, "Handle", Vector3.new(0.15, 0.7, 0.7), doorCF * CFrame.new(1.8, 0, -0.3) * CFrame.Angles(0, math.rad(90), 0), C.iron, Enum.Material.Metal)
	handle.Shape = Enum.PartType.Cylinder

	-- The table: round top (edge at TABLE_RADIUS, top surface at TABLE_TOP), pedestal, foot
	local tableModel = Instance.new("Model")
	tableModel.Name = "Table"
	tableModel.Parent = room
	disc(tableModel, "Top", TABLE_RADIUS * 2, 0.5, O + Vector3.new(0, TABLE_TOP - 0.25, 0), C.tableTop, Enum.Material.Wood)
	disc(tableModel, "Edge", TABLE_RADIUS * 2 + 0.5, 0.45, O + Vector3.new(0, TABLE_TOP - 0.42, 0), C.tableEdge, Enum.Material.Wood)
	local stem = part(tableModel, "Pedestal", Vector3.new(TABLE_TOP - 0.6, 2.2, 2.2), CFrame.new(O + Vector3.new(0, (TABLE_TOP - 0.6) / 2 + 0.1, 0)) * UP, C.tableEdge)
	stem.Shape = Enum.PartType.Cylinder
	disc(tableModel, "Foot", 6, 0.4, O + Vector3.new(0, 0.3, 0), C.timber)
	local centre = part(tableModel, "TableCenter", Vector3.new(1, 0.1, 1), at(0, 0.05, 0), C.timber)
	centre.Transparency = 1
	centre:SetAttribute("Seats", spec.seats)

	-- Chairs round the table, one per seat, facing the centre
	for i = 1, spec.seats do
		local angle = -(i - 1) * 2 * math.pi / spec.seats
		local dir = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local base = O + dir * (STAND_RADIUS + 0.35)
		local cf = CFrame.lookAt(base, O) -- -Z faces the table
		local chair = prop(tableModel, "Chair", cf, 4.6)
		if chair then
			chair.Name = "Chair_" .. i
		else
			local m = Instance.new("Model")
			m.Name = "Chair_" .. i
			m.Parent = tableModel
			part(m, "Seat", Vector3.new(2.2, 0.35, 2.1), cf * CFrame.new(0, 2.15, 0), C.tableEdge)
			part(m, "Back", Vector3.new(2.1, 2.6, 0.3), cf * CFrame.new(0, 3.6, 0.95), C.tableEdge)
			for _, lx in ipairs({ -0.9, 0.9 }) do
				for _, lz in ipairs({ -0.85, 0.85 }) do
					part(m, "Leg", Vector3.new(0.3, 2.0, 0.3), cf * CFrame.new(lx, 1.0, lz), C.timber)
				end
			end
		end
	end

	-- Chandelier over the table: iron ring with candles, the main light (with shadows)
	local chandelier = Instance.new("Model")
	chandelier.Name = "Chandelier"
	chandelier.Parent = room
	local ringY = 12.5
	disc(chandelier, "Ring", 6, 0.3, O + Vector3.new(0, ringY, 0), C.iron, Enum.Material.Metal)
	disc(chandelier, "RingHole", 5.2, 0.32, O + Vector3.new(0, ringY, 0), C.ceiling, Enum.Material.Metal).Transparency = 1
	part(chandelier, "Chain", Vector3.new(0.2, HEIGHT - ringY - 1.5, 0.2), at(0, (HEIGHT - 1.5 + ringY) / 2, 0), C.iron, Enum.Material.Metal)
	for k = 0, 5 do
		local a = k * math.pi / 3
		local pos = Vector3.new(math.cos(a) * 2.8, ringY + 0.55, math.sin(a) * 2.8)
		part(chandelier, "Candle", Vector3.new(0.3, 0.8, 0.3), at(pos.X, pos.Y, pos.Z), Color3.fromRGB(235, 222, 196), Enum.Material.SmoothPlastic)
		local flame = part(chandelier, "Flame", Vector3.new(0.18, 0.3, 0.18), at(pos.X, pos.Y + 0.55, pos.Z), Color3.fromRGB(255, 196, 96), Enum.Material.Neon)
		flame.CastShadow = false
	end
	local lamp = part(chandelier, "LightSource", Vector3.new(0.5, 0.5, 0.5), at(0, ringY - 0.6, 0), C.iron)
	lamp.Transparency = 1
	lamp.CastShadow = false
	light(lamp, "PointLight", { Color = C.warmLight, Brightness = 1.5, Range = 26, Shadows = true })
	-- Soft downlight so the cards on the table read clearly from every seat
	local fill = part(chandelier, "TableFill", Vector3.new(0.5, 0.5, 0.5), at(0, 10.5, 0), C.iron)
	fill.Transparency = 1
	fill.CastShadow = false
	light(fill, "SpotLight", { Face = Enum.NormalId.Bottom, Color = Color3.fromRGB(255, 220, 175), Brightness = 1.0, Range = 14, Angle = 75, Shadows = false })

	-- Props (AI meshes from ServerStorage.WorldProps)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = room
	local north = -h + 1
	prop(decor, "Fireplace", facing(0, 0, north + 1.2, 0, 1), 15)
	local fireLight = part(decor, "FireLight", Vector3.new(0.5, 0.5, 0.5), at(0, 2.5, north + 2.6), C.iron)
	fireLight.Transparency = 1
	fireLight.CastShadow = false
	light(fireLight, "PointLight", { Color = C.fireLight, Brightness = 2.4, Range = 18, Shadows = true })
	local flames = Instance.new("Fire")
	flames.Size = 4
	flames.Heat = 6
	flames.Color = Color3.fromRGB(255, 140, 40)
	flames.SecondaryColor = Color3.fromRGB(255, 70, 20)
	flames.Parent = fireLight
	-- Skull plaque on the chimney breast, above the mantel
	prop(decor, "SkullPlaque", facing(0, 9.6, north + 2.4, 0, 1), 3.6)
	prop(decor, "Firewood", facing(-9, 0, north + 1.6, 0, 1), 2.6)
	prop(decor, "Firewood", facing(9, 0, north + 1.6, 0, 1), 2.6)

	-- Wall lanterns (each with a small warm light)
	local function lantern(x: number, y: number, z: number, lookX: number, lookZ: number)
		local cf = facing(x, y, z, lookX, lookZ)
		local m = prop(decor, "Lantern", cf, 1.8)
		local glow = part(decor, "LanternLight", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(0, 0.9, 0), C.iron)
		glow.Transparency = 1
		glow.CastShadow = false
		light(glow, "PointLight", { Color = C.warmLight, Brightness = 0.9, Range = 11, Shadows = false })
		if not m then
			local body = part(decor, "LanternBody", Vector3.new(0.8, 1.2, 0.8), cf * CFrame.new(0, 0.9, 0), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
			body.CastShadow = false
		end
		-- wall bracket
		part(decor, "LanternBracket", Vector3.new(0.2, 0.2, 1.2), cf * CFrame.new(0, 1.9, 0.6), C.iron, Enum.Material.Metal)
	end
	lantern(-7, 8, north + 0.8, 0, 1)
	lantern(7, 8, north + 0.8, 0, 1)
	lantern(-4.5, 6.5, h - 1.2, 0, -1)
	lantern(4.5, 6.5, h - 1.2, 0, -1)
	lantern(h - 1.2, 7.5, -h * 0.35 + 3.8, -1, 0) -- beside the east window
	lantern(-h + 1.2, 7.5, h * 0.35 - 3.8, 1, 0) -- beside the west window

	-- East wall: barrels and a shelf; west wall: shelf, books on a side table
	prop(decor, "Shelf", facing(h - 0.9, 6.5, h * 0.35, -1, 0), 3)
	prop(decor, "Barrel", facing(h - 2.4, 0, -h + 3, -1, 0), 4)
	prop(decor, "Barrel", facing(h - 2.4, 0, -h + 6.4, -1, 0), 4)
	prop(decor, "Barrel", facing(h - 5.6, 0, -h + 3, -1, 0), 4)
	prop(decor, "Barrel", facing(h - 2.4, 4, -h + 4.6, -1, 0), 3.6)
	prop(decor, "Barrel", facing(-h + 2.4, 0, h - 3, 1, 0), 4)
	prop(decor, "Barrel", facing(-h + 5.6, 0, h - 3, 1, 0), 4)
	prop(decor, "Shelf", facing(-h + 0.9, 6.5, -h * 0.35, 1, 0), 3)
	local sideTable = Instance.new("Model")
	sideTable.Name = "SideTable"
	sideTable.Parent = decor
	local stCF = facing(-h + 2.2, 0, -h * 0.35, 1, 0)
	part(sideTable, "Top", Vector3.new(3.6, 0.3, 2.2), stCF * CFrame.new(0, 3, 0), C.tableEdge)
	for _, lx in ipairs({ -1.5, 1.5 }) do
		for _, lz in ipairs({ -0.8, 0.8 }) do
			part(sideTable, "Leg", Vector3.new(0.3, 3, 0.3), stCF * CFrame.new(lx, 1.5, lz), C.timber)
		end
	end
	prop(decor, "Books", stCF * CFrame.new(-0.6, 3.15, 0), 0.9)
	if spec.seats > 4 then
		-- Bigger room: more barrels in the far corners
		prop(decor, "Barrel", facing(-h + 2.4, 0, -h + 3, 1, 0), 4)
		prop(decor, "Barrel", facing(-h + 2.4, 0, -h + 6.4, 1, 0), 4)
		prop(decor, "Barrel", facing(h - 2.4, 0, h - 3, -1, 0), 4)
		prop(decor, "Firewood", facing(h - 3, 0, h - 6.5, -1, 0), 2.6)
	end

	room.Parent = world
end

for _, spec in ipairs(ROOMS) do
	buildRoom(spec)
end
print("[build_world] Rooms built:", #ROOMS, "props folder:", props ~= nil)
return true
