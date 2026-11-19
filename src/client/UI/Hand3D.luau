--!strict
-- Hand3D.luau
-- Your hand as oversized 3D cards floating in a fan at the bottom of your view.
-- The cards are local parts inside the camera, so only you see them; everyone else
-- sees your card backs fanned in front of your avatar (TableBuilder).
--   * hover a card: it lifts and grows
--   * click / tap it on your turn: it flies to your pile and the placement is sent
-- Same interface as the old 2D HandBar, so init.client only swaps the module.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Toast = require(script.Parent.Toast)

local Hand3D = {}

export type CardSelectCallback = (cardType: string, cardIndex: number) -> ()

type Card = {
	part: Part, -- the visible card (lifts, grows and comes forward on hover)
	restPos: Vector3, -- centre of its resting spot this frame; hover picks the nearest
	cardType: string,
	appearAt: number, -- deal animation start (os.clock)
	lift: number, -- 0..1 hover lift, eased per frame
}

-- Layout, in studs relative to the camera
local DISTANCE = 5.4 -- in front of the camera
local DROP = 2.3 -- below the centre of view
local SPACING = 1.05 -- between neighbouring cards
local DIAMETER = 1.55
local FAN_DEGREES = 7 -- rotation per card from the middle
local TILT_DEGREES = 12 -- top leans away from you
local HOVER_LIFT = 0.55
local HOVER_GROW = 1.15
local HOVER_FORWARD = 0.6 -- hovered card comes toward you, in front of its neighbours
local LIFT_SPEED = 0.35 -- per-frame easing of the hover lift (higher = snappier)
local HOVER_MARGIN = 0.12 -- share of the card spacing the current card is favoured by
local IDLE_DROP = 0.35 -- cards sit lower when it isn't your turn
local DEAL_SECONDS = 0.45

local onCardClicked: CardSelectCallback? = nil
-- Where the played card lands (top of your pile) and the folder the server's pile cards
-- are in (see SetPileTarget)
local pileTarget: (() -> (Vector3?, Instance?))? = nil
local PILE_CARD_COLOR = Color3.fromRGB(26, 22, 30) -- rim of the server's pile cards
local FLY_SECONDS = 0.42
local FLY_ARC = 0.8 -- studs above the straight line at mid-flight
local HANDOFF_TIMEOUT = 1.5 -- seconds to wait for the server's card before giving up
local folder: Folder? = nil
local cards: { Card } = {}
local currentHand: { string } = {}
local currentSetId: string? = nil
local isPlayerTurn = false
local canPlace = false
local isSubmitting = false
local selectedCard: string? = nil
local visible = true
local hovered: Card? = nil
local turnDrop = IDLE_DROP -- eased toward 0 on your turn

local function easeOut(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end

local function makeCardPart(cardType: string, setId: string?): Part
	local part = Instance.new("Part")
	part.Name = "HandCard_" .. cardType
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.06, DIAMETER, DIAMETER)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false -- hover / click use the resting spots, not the moving card
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = CardArt.Get(setId).accent:Lerp(Color3.new(1, 1, 1), 0.3)

	-- Face on the +X side, which the layout turns toward the camera
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.CanvasSize = Vector2.new(256, 256)
	gui.LightInfluence = 0
	gui.Adornee = part
	gui.Parent = part
	local art = Instance.new("ImageLabel")
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Image = CardArt.Face(setId, cardType)
	art.Parent = gui
	return part
end

-- Where card i of n sits this frame (camera space -> world); `lift` 0 = resting spot
local function cardCFrame(cam: Camera, index: number, total: number, card: Card, now: number, lift: number): CFrame
	local t = index - (total + 1) / 2
	local appear = easeOut((now - card.appearAt) / DEAL_SECONDS)
	local bob = math.sin(now * 1.6 + index * 0.9) * 0.035
	local y = -DROP - math.abs(t) * 0.09 - turnDrop + lift * HOVER_LIFT + bob - (1 - appear) * 3
	local offset = CFrame.new(t * SPACING, y, -DISTANCE + index * 0.02 + lift * HOVER_FORWARD)
		* CFrame.Angles(math.rad(TILT_DEGREES), 0, math.rad(-t * FAN_DEGREES))
		* CFrame.Angles(0, math.rad(-90), 0) -- cylinder face (+X) toward the camera
	return cam.CFrame * offset
end

local function render()
	local cam = workspace.CurrentCamera
	local f = folder
	if not cam or not f then
		return
	end
	f.Parent = if visible and #cards > 0 then cam else nil
	if not f.Parent then
		return
	end
	local now = os.clock()
	turnDrop += ((if isPlayerTurn and canPlace then 0 else IDLE_DROP) - turnDrop) * 0.15
	for i, card in ipairs(cards) do
		local target = if card == hovered then 1 else 0
		card.lift += (target - card.lift) * LIFT_SPEED
		local grow = 1 + (HOVER_GROW - 1) * card.lift
		card.part.Size = Vector3.new(0.06, DIAMETER * grow, DIAMETER * grow)
		card.part.CFrame = cardCFrame(cam, i, #cards, card, now, card.lift)
		card.restPos = cardCFrame(cam, i, #cards, card, now, 0).Position
	end
end

-- Card under the mouse / touch point, if any: the one whose resting spot's centre is
-- nearest on screen. Resting spots don't move when a card lifts, so the hover can't
-- bounce between neighbours; the current card gets a small head start so the edge
-- between two cards doesn't flicker, but switching still happens right at the midpoint.
local function cardAt(screenPos: Vector2): Card?
	local cam = workspace.CurrentCamera
	if not cam or #cards == 0 or not visible then
		return nil
	end

	local best: Card? = nil
	local bestDist = math.huge
	local currentDist = math.huge
	local radiusPx = 0
	for _, card in ipairs(cards) do
		local centre = cam:WorldToViewportPoint(card.restPos)
		local edge = cam:WorldToViewportPoint(card.restPos + cam.CFrame.RightVector * (DIAMETER / 2))
		radiusPx = math.max(radiusPx, (Vector2.new(edge.X, edge.Y) - Vector2.new(centre.X, centre.Y)).Magnitude)
		local dist = (Vector2.new(centre.X, centre.Y) - screenPos).Magnitude
		if dist < bestDist then
			best, bestDist = card, dist
		end
		if card == hovered then
			currentDist = dist
		end
	end

	if bestDist > radiusPx * 1.05 then
		return nil -- not over the hand
	end
	local spacingPx = radiusPx * 2 * SPACING / DIAMETER
	if hovered and currentDist - bestDist < spacingPx * HOVER_MARGIN and currentDist <= radiusPx * 1.05 then
		return hovered
	end
	return best
end

-- The server's card can arrive before ours lands (it's quick on the first placement):
-- hide it on this screen until then, so the pile doesn't show it early
local function setLocallyHidden(card: BasePart, hidden: boolean)
	card.LocalTransparencyModifier = if hidden then 1 else 0
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("SurfaceGui") then
			d.Enabled = not hidden
		end
	end
end

local function isCardAt(child: Instance, target: Vector3): boolean
	if not child:IsA("BasePart") or string.sub(child.Name, 1, 7) ~= "Card3D_" then
		return false
	end
	local p = child.Position
	return math.abs(p.Y - target.Y) < 0.04 and (Vector2.new(p.X, p.Z) - Vector2.new(target.X, target.Z)).Magnitude < 0.3
end

-- Is the server's card for this placement on the pile yet? (the top card, where ours landed)
local function serverCardAt(stacks: Instance?, target: Vector3): boolean
	if not stacks then
		return false
	end
	for _, child in ipairs(stacks:GetChildren()) do
		if isCardAt(child, target) then
			return true
		end
	end
	return false
end

-- Show the card's back on its -X side (which faces up once it lies upside down on the pile)
local function showBack(part: BasePart, gui: SurfaceGui, art: ImageLabel)
	gui.Face = Enum.NormalId.Left
	art.Image = CardArt.Back(currentSetId)
	part.Color = PILE_CARD_COLOR
end

-- The played card flies from your hand onto the top of your pile in an arc, turning
-- over on the way: at the moment it's edge-on to your camera it swaps to its card back,
-- so it lands face down, like the server's pile card. It stays there until that card has
-- arrived underneath it, then goes, so the handover can't be seen.
local function flyToPile(card: Card)
	local part = card.part
	local target: Vector3?, stacks: Instance? = nil, nil
	if pileTarget then
		target, stacks = pileTarget()
	end
	if not target then
		TweenService:Create(part, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(0.06, 0.1, 0.1) }):Play()
		task.delay(0.35, function()
			part:Destroy()
		end)
		return
	end
	local landPos: Vector3 = target
	part.Parent = workspace -- leave the camera so it can travel through the scene

	-- Keep the server's card for this placement hidden here until we've landed on it
	local landed = false
	local early: BasePart? = nil
	local function catch(child: Instance)
		if not landed and not early and isCardAt(child, landPos) then
			early = child :: BasePart
			setLocallyHidden(child :: BasePart, true)
		end
	end
	local addedConn: RBXScriptConnection? = nil
	if stacks then
		for _, child in ipairs(stacks:GetChildren()) do
			catch(child)
		end
		addedConn = stacks.ChildAdded:Connect(catch)
	end
	local function finishLanding()
		landed = true
		if addedConn then
			addedConn:Disconnect()
		end
		local hiddenCard = early
		if hiddenCard then
			setLocallyHidden(hiddenCard, false) -- it sits exactly under ours: swap at once
			part:Destroy()
		end
	end

	local gui = part:FindFirstChildWhichIsA("SurfaceGui")
	local art = gui and gui:FindFirstChildWhichIsA("ImageLabel")
	local fromCF = part.CFrame
	local fromSize = part.Size
	local pileSize = Vector3.new(0.06, 2.2, 2.2) -- the size of a card in the pile
	-- Aim for the pile card turned upside down (its +X face, the one with the art, pointing
	-- down): turning toward that, the face passes edge-on to the camera and then faces
	-- away; from then on the art is drawn on the other side (-X, facing up) as the back.
	local flipAxis = Vector3.xAxis
	local cam = workspace.CurrentCamera
	if cam then
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			flipAxis = flat.Unit:Cross(Vector3.yAxis)
		end
	end
	local downCF = CFrame.fromAxisAngle(flipAxis, math.pi) * CFrame.Angles(0, 0, math.rad(90))

	local start = os.clock()
	local swapped = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not part.Parent then
			conn:Disconnect()
			return
		end
		local t = math.min((os.clock() - start) / FLY_SECONDS, 1)
		local e = t * t * (3 - 2 * t)
		local pos = fromCF.Position:Lerp(landPos, e) + Vector3.new(0, FLY_ARC * math.sin(math.pi * t), 0)
		part.CFrame = CFrame.new(pos) * fromCF.Rotation:Lerp(downCF, e)
		part.Size = fromSize:Lerp(pileSize, e)
		if not swapped and gui and art then
			local camNow = workspace.CurrentCamera
			local toCamera = if camNow then (camNow.CFrame.Position - pos).Unit else Vector3.yAxis
			if part.CFrame.RightVector:Dot(toCamera) <= 0 then
				swapped = true -- edge-on now: the back shows on the side turning toward you
				showBack(part, gui, art)
			end
		end
		if t >= 1 then
			conn:Disconnect()
			if not swapped and gui and art then
				showBack(part, gui, art)
			end
			part.CFrame = CFrame.new(landPos) * downCF
			part.Size = pileSize
			finishLanding()
			if not part.Parent then
				return -- the server's card was already there (hidden) and is showing now
			end
			-- Otherwise wait for the server's card to land under it, then hand over
			task.spawn(function()
				local waited = os.clock()
				while part.Parent and os.clock() - waited < HANDOFF_TIMEOUT do
					if serverCardAt(stacks, landPos) then
						break
					end
					task.wait()
				end
				part:Destroy()
			end)
		end
	end)
end

local function onClick(screenPos: Vector2): boolean
	local card = cardAt(screenPos)
	if not card then
		return false
	end
	if isSubmitting then
		return true
	end
	if not isPlayerTurn then
		Toast.Show("Wait for your turn to place a card", "info", 1.5)
		return true
	end
	if not canPlace then
		Toast.Show("Cards can only be placed before the bidding starts", "info", 1.5)
		return true
	end

	local index = table.find(cards, card)
	if not index then
		return true
	end
	isSubmitting = true
	selectedCard = card.cardType
	table.remove(cards, index)
	table.remove(currentHand, index)
	if hovered == card then
		hovered = nil
	end
	flyToPile(card)
	if onCardClicked then
		onCardClicked(card.cardType, index)
	end
	return true
end

-- `parent` is unused (kept for HandBar compatibility); cards live in the camera
function Hand3D.Create(_parent: Instance?, onSelect: CardSelectCallback?)
	onCardClicked = onSelect
	local f = Instance.new("Folder")
	f.Name = "Hand3D"
	folder = f

	RunService:BindToRenderStep("Hand3DLayout", Enum.RenderPriority.Last.Value + 1, render)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = input.Position
			hovered = cardAt(Vector2.new(pos.X, pos.Y))
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local pos = input.Position
			onClick(Vector2.new(pos.X, pos.Y))
		end
	end)
end

-- Where a played card lands (the top of your pile) and the folder holding the server's
-- pile cards (to see when the real card has arrived), for the fly-to-pile animation
function Hand3D.SetPileTarget(getter: () -> (Vector3?, Instance?))
	pileTarget = getter
end

function Hand3D.UpdateHand(hand: { string }, isTurn: boolean, placeAllowed: boolean, deal: boolean?, setId: string?)
	table.sort(hand, function(a, b)
		return a == Enums.CardType.Rose and b == Enums.CardType.Skull
	end)
	isSubmitting = false
	isPlayerTurn = isTurn
	canPlace = placeAllowed

	local same = #hand == #currentHand and #cards == #hand and setId == currentSetId
	if same then
		for i = 1, #hand do
			if hand[i] ~= currentHand[i] then
				same = false
				break
			end
		end
	end
	if same and not deal then
		return
	end

	local previousCount = #cards
	for _, card in ipairs(cards) do
		card.part:Destroy()
	end
	table.clear(cards)
	hovered = nil
	currentHand = table.clone(hand)
	currentSetId = setId

	local f = folder
	if not f then
		return
	end
	local now = os.clock()
	for i, cardType in ipairs(hand) do
		local part = makeCardPart(cardType, setId)
		part.Parent = f
		-- Dealt cards rise in one after another; a plain re-sync just appears
		local appearAt = if deal or previousCount == 0 then now + 0.2 + (i - 1) * 0.1 else now - DEAL_SECONDS
		table.insert(cards, { part = part, restPos = Vector3.zero, cardType = cardType, appearAt = appearAt, lift = 0 })
	end
end

function Hand3D.SetVisible(isVisible: boolean)
	visible = isVisible
end

-- Kept for HandBar compatibility: drop a card without animating it
function Hand3D.ConsumeCard(cardIndex: number)
	local card = cards[cardIndex]
	if card then
		card.part:Destroy()
		table.remove(cards, cardIndex)
		table.remove(currentHand, cardIndex)
	end
end

function Hand3D.GetSelectedCard(): string?
	return selectedCard
end

function Hand3D.GetRemainingCardsCount(): number
	return #currentHand
end

return Hand3D
