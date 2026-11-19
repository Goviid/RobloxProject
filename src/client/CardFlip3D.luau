--!strict
-- CardFlip3D.luau
-- Plays a revealed card's flip on this client, every frame, so it's smooth (a server
-- tween only arrives at network rate). The server has already put the card where it ends
-- up (face up on top of its pile, face art set) and left on it where it started (FlipFrom)
-- and its back image (FlipBack); see server Table/Card3DManager.RevealCard3D.
--
-- The flip: the card lifts off the pile showing its back, turns over a horizontal axis
-- until it's edge-on, swaps to the face while edge-on (so the swap can't be seen), keeps
-- turning the same way until flat, and lands on top of the pile.

local RunService = game:GetService("RunService")
local TableView = require(script.Parent.TableView)

local CardFlip3D = {}

local DURATION = 0.62
local LIFT = 1.5 -- studs at the top of the arc
local GROW = 1.15 -- slightly bigger at the top of the arc

-- Smooth start and end
local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

local function findCard(flipId: number): BasePart?
	local arena = TableView.GetArena()
	local folder = arena and arena:FindFirstChild("TableCardStacks")
	if not folder then
		return nil
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("FlipId") == flipId then
			return child
		end
	end
	return nil
end

function CardFlip3D.Play(flipId: number?)
	if type(flipId) ~= "number" or flipId <= 0 then
		return
	end
	local card = findCard(flipId)
	if not card then
		return
	end
	local fromCF = card:GetAttribute("FlipFrom")
	local back = card:GetAttribute("FlipBack")
	local gui = card:FindFirstChild("FaceGui")
	local art = gui and gui:FindFirstChild("CardArt")
	if typeof(fromCF) ~= "CFrame" or not art or not art:IsA("ImageLabel") then
		return
	end

	local toCF = card.CFrame -- where the server put it (face up)
	local size = card.Size
	local faceImage = art.Image
	if type(back) == "string" and back ~= "" then
		art.Image = back
	end

	-- Turn over the axis across the card as seen from the table centre, so it flips
	-- toward the middle of the table
	local origin = TableView.GetOrigin()
	local out = Vector3.new(fromCF.Position.X - origin.X, 0, fromCF.Position.Z - origin.Z)
	local axis = if out.Magnitude > 0.01 then out.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
	local rest = toCF.Rotation -- face-up orientation (the card's X axis points up)

	local start = os.clock()
	local swapped = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not card.Parent then
			conn:Disconnect()
			return
		end
		local t = math.min((os.clock() - start) / DURATION, 1)
		local e = ease(t)
		-- 0 -> 90 degrees (back still up), then from -90 back to 0 with the face up: at
		-- 90 / -90 the card is edge-on, so the jump between them is invisible
		local angle = if e < 0.5 then math.pi * e else math.pi * e - math.pi
		if e >= 0.5 and not swapped then
			swapped = true
			art.Image = faceImage
		end
		local pos = fromCF.Position:Lerp(toCF.Position, e) + Vector3.new(0, LIFT * math.sin(math.pi * t), 0)
		card.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(axis, angle) * rest
		local grow = 1 + (GROW - 1) * math.sin(math.pi * t)
		card.Size = Vector3.new(size.X, size.Y * grow, size.Z * grow)
		if t >= 1 then
			conn:Disconnect()
			art.Image = faceImage
			card.CFrame = toCF
			card.Size = size
		end
	end)
end

-- Someone else placed a card: it leaves the cards they're holding (their fanned hand)
-- and travels in a low arc onto their pile, laying itself down flat on the way. A local
-- animation of the server's card, which the server put straight where it rests.
local PLACE_SECONDS = 0.45
local PLACE_ARC = 0.9

function CardFlip3D.Place(seatIndex: number, stackCount: number)
	local arena = TableView.GetArena()
	local folder = arena and arena:FindFirstChild("TableCardStacks")
	local card = folder and folder:FindFirstChild("Card3D_Seat" .. seatIndex .. "_Card" .. stackCount)
	if not card or not card:IsA("BasePart") then
		return
	end
	local rest = card.CFrame
	local size = card.Size
	-- Start from the middle of their held cards, upright like them; without a hand in
	-- view, a little above the pile
	local fromCF = rest + Vector3.new(0, 1.2, 0)
	local hand = arena and arena:FindFirstChild("OpponentHand_" .. seatIndex)
	if hand and hand:IsA("Model") then
		local tokens = hand:GetChildren()
		local middle = tokens[math.max(1, math.ceil(#tokens / 2))]
		if middle and middle:IsA("BasePart") then
			fromCF = middle.CFrame
		else
			fromCF = hand:GetPivot()
		end
	end
	local held = Vector3.new(size.X, size.Y * 0.73, size.Z * 0.73) -- held tokens are 1.6 across

	local start = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not card.Parent then
			conn:Disconnect()
			return
		end
		local t = math.min((os.clock() - start) / PLACE_SECONDS, 1)
		local e = ease(t)
		local pos = fromCF.Position:Lerp(rest.Position, e) + Vector3.new(0, PLACE_ARC * math.sin(math.pi * t), 0)
		card.CFrame = CFrame.new(pos) * fromCF.Rotation:Lerp(rest.Rotation, e)
		card.Size = held:Lerp(size, e)
		if t >= 1 then
			conn:Disconnect()
			card.CFrame = rest
			card.Size = size
		end
	end)
end

return CardFlip3D
