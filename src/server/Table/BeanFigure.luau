--!strict
-- BeanFigure.luau
-- The "bean" character look (a test alongside the classic calavera avatar): a rounded
-- brown capsule sitting on the chair, two stubby arms reaching toward the table, the
-- sugar-skull face wrapped round the front and a sombrero on top. The face flowers and
-- the sombrero follow the seat's card colour, like the classic look.
--
-- Built from plain anchored parts (no rig, so no animations): reactions are a little hop.
-- The model has an invisible "Head" part above the body for the name tag and turn dot.

local RunService = game:GetService("RunService")

local BeanFigure = {}

local SKULL_FACE = "rbxassetid://94176651222783" -- same art as the classic skull (512 x 512)
local FACE_PIXELS = 512
local BODY = Color3.fromRGB(150, 92, 54) -- warm mid brown, like the concept art
local HAT_BAND = Color3.fromRGB(140, 100, 36)
local HAT_SHADE = 0.3 -- sombrero = card colour this much toward black (as the classic look)

-- Shape, in studs, measured from the chair seat (y = 0) at the body's centre
local RADIUS = 1.2 -- body is 2.4 across, a little wider than the chair
local LOWER_DOME = 1.0 -- height of the rounded bottom
local MIDDLE = 2.65 -- straight section, where the face sits
local UPPER_DOME = 1.2 -- height of the rounded top
local FACE_SIZE = 2.2 -- face width, round the front
-- Only the drawn part of the art is used (rows FACE_TOP..FACE_BOTTOM of the 512 x 512
-- image: the dot down to the teeth), so the empty margins don't hang off the curve
local FACE_TOP = 80
local FACE_BOTTOM = 420
local FACE_HEIGHT = FACE_SIZE * (FACE_BOTTOM - FACE_TOP) / FACE_PIXELS
local FACE_Y = LOWER_DOME + MIDDLE - FACE_HEIGHT / 2 + 0.05 -- high on the body, above the held cards
local FACE_STRIPS = 9 -- the flat face is cut into strips that follow the curve

local SEAT_HEIGHT = 2.05 -- chair seat surface (floor at 0)
BeanFigure.SEAT_RADIUS = 8.2 -- body centre's distance from the table centre (chairs sit at ~8.15)
-- Where a bean holds its cards: lower and nearer the table than the classic avatar, between
-- its arms, so the fan doesn't cover its face
BeanFigure.HAND_RADIUS = 6.1
BeanFigure.HAND_HEIGHT = 4.1 -- the lowest token clears the table top (Y 3.0)

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, meshType: Enum.MeshType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	if meshType then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = meshType
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

-- Builds the figure sitting on the chair of the seat in direction `dir` (unit, flat) from
-- the table centre `origin`, facing the table. Not parented.
function BeanFigure.Build(name: string, origin: Vector3, dir: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Look", "bean")

	local seatPos = origin + dir * BeanFigure.SEAT_RADIUS + Vector3.new(0, SEAT_HEIGHT, 0)
	local base = CFrame.lookAt(seatPos, Vector3.new(origin.X, seatPos.Y, origin.Z)) -- -Z faces the table
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis (X) pointing up
	local d = RADIUS * 2

	-- Body: rounded bottom, straight middle, rounded top
	local body = part(model, "Body", Vector3.new(MIDDLE, d, d), base * CFrame.new(0, LOWER_DOME + MIDDLE / 2, 0) * upright, BODY)
	body.Shape = Enum.PartType.Cylinder
	part(model, "BodyBottom", Vector3.new(d, LOWER_DOME * 2, d), base * CFrame.new(0, LOWER_DOME, 0), BODY, Enum.MeshType.Sphere)
	part(model, "BodyTop", Vector3.new(d, UPPER_DOME * 2, d), base * CFrame.new(0, LOWER_DOME + MIDDLE, 0), BODY, Enum.MeshType.Sphere)
	model.PrimaryPart = body

	-- Stubby arms out of the sides, reaching forward and a little down toward the table
	for _, side in ipairs({ -1, 1 }) do
		local armCF = base
			* CFrame.new(side * (RADIUS + 0.05), LOWER_DOME + 0.75, -0.55)
			* CFrame.Angles(math.rad(-8), math.rad(side * 16), 0)
		part(model, if side < 0 then "LeftArm" else "RightArm", Vector3.new(0.8, 0.8, 1.8), armCF, BODY, Enum.MeshType.Sphere)
	end

	-- Face: invisible strips standing on the curve, each showing its slice of the face art
	local arc = FACE_SIZE / RADIUS -- angle the face spans round the body
	local step = arc / FACE_STRIPS
	local stripWidth = 2 * (RADIUS + 0.02) * math.sin(step / 2)
	for i = 1, FACE_STRIPS do
		-- strip 1 is the face's left edge as seen from the front (on the figure's right, +X);
		-- turning by a positive angle moves a strip toward -X
		local angle = -arc / 2 + (i - 0.5) * step
		local stripCF = base
			* CFrame.new(0, FACE_Y, 0)
			* CFrame.Angles(0, angle, 0)
			* CFrame.new(0, 0, -(RADIUS + 0.02) * math.cos(step / 2))
		local strip = part(model, "FaceStrip_" .. i, Vector3.new(stripWidth, FACE_HEIGHT, 0.05), stripCF, BODY)
		strip.Transparency = 1
		strip.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Name = "FaceGui"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 1
		gui.Adornee = strip
		gui.Parent = strip
		local image = Instance.new("ImageLabel")
		image.Name = "SkullFace"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = SKULL_FACE
		image.ImageRectOffset = Vector2.new((i - 1) * FACE_PIXELS / FACE_STRIPS, FACE_TOP)
		image.ImageRectSize = Vector2.new(FACE_PIXELS / FACE_STRIPS, FACE_BOTTOM - FACE_TOP)
		image.Parent = gui
	end

	-- Sombrero: the brim rests on the top dome where it has narrowed to the crown's width,
	-- so the crown covers all of the dome above it
	local brimY = LOWER_DOME + MIDDLE + UPPER_DOME * 0.66
	local function hat(hatName: string, height: number, across: number, centreY: number)
		local p = part(model, hatName, Vector3.new(height, across, across), base * CFrame.new(0, centreY, 0) * upright, BODY)
		p.Shape = Enum.PartType.Cylinder
		p.CastShadow = false
	end
	hat("SombreroBrim", 0.14, 4.2, brimY)
	hat("SombreroBand", 0.26, 1.86, brimY + 0.2)
	hat("SombreroCrown", 1.15, 1.8, brimY + 0.64)

	-- Anchor for the name tag and turn dot (an R15 head sits about here)
	local head = part(model, "Head", Vector3.new(1, 1, 1), base * CFrame.new(0, LOWER_DOME + MIDDLE + 0.7, 0), BODY)
	head.Transparency = 1
	head.CastShadow = false

	return model
end

-- Face flowers and sombrero take the card colour; body and band stay fixed
function BeanFigure.Color(model: Model, accent: Color3)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ImageLabel") and d.Name == "SkullFace" then
			d.ImageColor3 = accent
		elseif d:IsA("BasePart") then
			if d.Name == "SombreroBand" then
				d.Color = HAT_BAND
			elseif d.Name == "SombreroBrim" or d.Name == "SombreroCrown" then
				d.Color = accent:Lerp(Color3.new(0, 0, 0), HAT_SHADE)
			end
		end
	end
end

-- A reaction: small happy hops for `seconds`, then back down on the chair
local hopping: { [Model]: boolean } = {}
function BeanFigure.Hop(model: Model, seconds: number)
	if hopping[model] then
		return
	end
	hopping[model] = true
	local rest = model:GetPivot()
	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - start
		if not model.Parent or t >= seconds then
			conn:Disconnect()
			hopping[model] = nil
			if model.Parent then
				model:PivotTo(rest)
			end
			return
		end
		model:PivotTo(rest * CFrame.new(0, math.abs(math.sin(t * 9)) * 0.35, 0))
	end)
end

return BeanFigure
