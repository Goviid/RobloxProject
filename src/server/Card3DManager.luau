--!strict
-- Card3DManager.luau
-- Manages physical oversized 3D cards placed on the table in front of players (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Constants = require(ReplicatedStorage.Shared.Constants)
local TableBuilder = require(script.Parent.TableBuilder)
local PlayerManager = require(script.Parent.PlayerManager)

local Card3DManager = {}

-- Art set of whoever sits in a seat (public; only the faces are secret)
local function seatCardSet(seatIndex: number): string?
	local p = PlayerManager.GetPlayerBySeat(seatIndex)
	return p and p.cardSet or nil
end

-- Container folder inside Workspace.SkullsArena
local function getCardsFolder(): Folder
	local arena = Workspace:WaitForChild("SkullsArena", 5)
	local existing = arena and arena:FindFirstChild("TableCardStacks")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "TableCardStacks"
	folder.Parent = arena or Workspace
	return folder
end

-- Stacks of 3D card parts per seat: seatIndex -> { Part }
local seatStacks: { [number]: { Part } } = {
	[1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {}, [6] = {}
}

-- All revealed cards currently in animation or settled on table
local revealedCards: { Part } = {}
local isRevealingClickEnabled = false

export type ActionHandler = (userId: number, action: string, data: any) -> (boolean, string?)
local roundActionHandler: ActionHandler? = nil

function Card3DManager.SetActionHandler(handler: ActionHandler)
	roundActionHandler = handler
end

-- Toggle ClickDetectors on 3D cards: ONLY enabled during Revealing phase!
function Card3DManager.SetRevealingEnabled(enabled: boolean)
	isRevealingClickEnabled = enabled
	local folder = getCardsFolder()
	for _, child in ipairs(folder:GetChildren()) do
		local clicker = child:FindFirstChildWhichIsA("ClickDetector")
		if clicker then
			clicker.MaxActivationDistance = enabled and 45 or 0
		end
	end

	-- Also enable ClickDetectors on coasters so clicking anywhere on the player's mat flips their top card!
	for seatIdx = 1, Constants.MAX_PLAYERS do
		local mat = TableBuilder.GetCoasterPart(seatIdx)
		if mat then
			local clicker = mat:FindFirstChildWhichIsA("ClickDetector")
			if not clicker and enabled then
				local newClicker = Instance.new("ClickDetector")
				newClicker.Parent = mat
				clicker = newClicker
				newClicker.MouseClick:Connect(function(clickingPlayer: Player)
					if roundActionHandler and isRevealingClickEnabled then
						local targetPlayer = PlayerManager.GetPlayerBySeat(seatIdx)
						if targetPlayer then
							roundActionHandler(clickingPlayer.UserId, Enums.PlayerAction.RevealCard, {
								targetUserId = targetPlayer.userId,
							})
						end
					end
				end)
			end
			if clicker then
				clicker.MaxActivationDistance = enabled and 45 or 0
			end
		end
	end
end

-- ============================================================================
-- 1. SPAWN CLEAN CIRCULAR 3D CARD IN PILE
-- ============================================================================
function Card3DManager.PlaceCard3D(seatIndex: number, stackCount: number)
	local coasterCF = TableBuilder.GetCoasterCFrame(seatIndex)
	if not coasterCF then
		return
	end

	-- Clean up any initial decorative placeholder tokens on first placement
	if stackCount == 1 then
		local matPart = TableBuilder.GetCoasterPart(seatIndex)
		if matPart then
			for _, child in ipairs(matPart:GetChildren()) do
				if string.find(child.Name, "PreStackedCard") then
					child:Destroy()
				end
			end
		end
	end

	local folder = getCardsFolder()
	local coasterPos = coasterCF.Position
	local baseY = 3.05
	local stackY = baseY + 0.03 + (stackCount - 1) * 0.06

	-- Target CFrame: Perfectly concentric clean circle flush on the mat
	local targetCF = CFrame.new(coasterPos.X, stackY, coasterPos.Z)
		* CFrame.Angles(0, 0, math.rad(90))

	-- Spawn only slightly above the mat for a snappy physical drop animation
	local spawnCF = targetCF + Vector3.new(0, 0.15, 0)

	local cardPart = Instance.new("Part")
	cardPart.Name = "Card3D_Seat" .. seatIndex .. "_Card" .. stackCount
	cardPart.Shape = Enum.PartType.Cylinder
	cardPart.Size = Vector3.new(0.06, 2.2, 2.2) -- Perfectly sized 2.2-stud circular token
	cardPart.CFrame = spawnCF
	cardPart.Anchored = true
	cardPart.CanCollide = false
	cardPart.Material = Enum.Material.SmoothPlastic
	cardPart.Color = Color3.fromRGB(26, 22, 30)
	cardPart.Parent = folder

	-- SurfaceGui on the top circular face (Right face on Z-rotated cylinder)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "FaceGui"
	sg.Face = Enum.NormalId.Right
	sg.CanvasSize = Vector2.new(256, 256)
	sg.AlwaysOnTop = false
	sg.Adornee = cardPart
	sg.Parent = cardPart

	-- Card back in the owner's art set. The face image is only applied at reveal time,
	-- so nothing on the client can tell what this card is before then.
	local art = Instance.new("ImageLabel")
	art.Name = "CardArt"
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Image = CardArt.Back(seatCardSet(seatIndex))
	art.Parent = sg

	-- ClickDetector: Allows clicking 3D cards directly on the pile (ONLY during Revealing phase!)
	local clicker = Instance.new("ClickDetector")
	clicker.MaxActivationDistance = isRevealingClickEnabled and 45 or 0
	clicker.Parent = cardPart
	clicker.MouseClick:Connect(function(clickingPlayer: Player)
		if roundActionHandler and isRevealingClickEnabled then
			local targetPlayer = PlayerManager.GetPlayerBySeat(seatIndex)
			if targetPlayer then
				roundActionHandler(clickingPlayer.UserId, Enums.PlayerAction.RevealCard, {
					targetUserId = targetPlayer.userId,
				})
			end
		end
	end)

	-- Smooth drop & settle tween straight down
	TweenService:Create(cardPart, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = targetCF,
	}):Play()

	table.insert(seatStacks[seatIndex], cardPart)
end

-- ============================================================================
-- 2. REVEAL 3D CARD (FLIPS UP SNAPPY & SETTLES FLAT, NEVER HOVERING IN AIR)
-- ============================================================================
function Card3DManager.RevealCard3D(seatIndex: number, cardType: string)
	local stack = seatStacks[seatIndex]
	if not stack or #stack == 0 then
		return
	end

	local cardPart = table.remove(stack)
	if not cardPart or not cardPart.Parent then
		return
	end
	table.insert(revealedCards, cardPart)

	-- Disable ClickDetector once card is revealed
	local clicker = cardPart:FindFirstChildWhichIsA("ClickDetector")
	if clicker then
		clicker.MaxActivationDistance = 0
	end

	local currentCF = cardPart.CFrame
	local liftCF = currentCF + Vector3.new(0, 1.2, 0)

	-- Show the face in the owner's art set
	local sg = cardPart:FindFirstChild("FaceGui")
	local art = sg and sg:FindFirstChild("CardArt")
	if art and art:IsA("ImageLabel") then
		art.Image = CardArt.Face(seatCardSet(seatIndex), cardType)
	end

	-- Snappy flip reveal
	local flipTween = TweenService:Create(cardPart, TweenInfo.new(0.40, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = liftCF * CFrame.Angles(0, math.rad(180), 0),
		Size = Vector3.new(0.06, 2.5, 2.5),
	})
	flipTween:Play()

	-- Settle smoothly down flat so it NEVER hovers in mid-air
	task.delay(1.0, function()
		if cardPart and cardPart.Parent then
			local settleCF = CFrame.new(currentCF.Position.X, 3.06, currentCF.Position.Z)
				* CFrame.Angles(0, 0, math.rad(90))
			TweenService:Create(cardPart, TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = settleCF,
				Size = Vector3.new(0.06, 2.2, 2.2),
			}):Play()
		end
	end)
end

-- ============================================================================
-- 3. RESET ALL 3D CARDS (ROUND END CLEANUP - GUARANTEED ZERO FLOATING CARDS)
-- ============================================================================
-- Skull penalty: a face-down card rises from the challenger's pile, catches fire and burns
-- away. Purely visual (and face-down, so it never reveals which card was lost).
local BURN_SECONDS = 1.6
-- "Pyro Fire Ball Burst 9 (SFX)", Pro Sound Effects (verified Audio asset, 1.5 s)
local BURN_SOUND_ID = "rbxassetid://9117983605"

function Card3DManager.BurnCard(seatIndex: number)
	local coasterCF = TableBuilder.GetCoasterCFrame(seatIndex)
	if not coasterCF then
		return
	end
	local pos = coasterCF.Position
	local startCF = CFrame.new(pos.X, 3.2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))

	local card = Instance.new("Part")
	card.Name = "BurningCard_Seat" .. seatIndex
	card.Shape = Enum.PartType.Cylinder
	card.Size = Vector3.new(0.06, 2.2, 2.2)
	card.CFrame = startCF
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	card.Material = Enum.Material.SmoothPlastic
	card.Color = Color3.fromRGB(26, 22, 30)
	card.Parent = getCardsFolder()

	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Color = Color3.fromRGB(255, 150, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = card

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.EmissionDirection = Enum.NormalId.Right -- the card's top face (cylinder is rotated)
	embers.Rate = 45
	embers.Lifetime = NumberRange.new(0.6, 1.2)
	embers.Speed = NumberRange.new(1.5, 3.5)
	embers.SpreadAngle = Vector2.new(40, 40)
	embers.Acceleration = Vector3.new(0, 3, 0)
	embers.LightEmission = 1
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
	embers.Transparency = NumberSequence.new(0.1, 1)
	embers.Parent = card

	-- Face-down: the owner's card back on top
	local backGui = Instance.new("SurfaceGui")
	backGui.Face = Enum.NormalId.Right
	backGui.CanvasSize = Vector2.new(256, 256)
	backGui.Adornee = card
	backGui.Parent = card
	local backArt = Instance.new("ImageLabel")
	backArt.Size = UDim2.fromScale(1, 1)
	backArt.BackgroundTransparency = 1
	backArt.Image = CardArt.Back(seatCardSet(seatIndex))
	backArt.Parent = backGui
	TweenService:Create(backArt, TweenInfo.new(BURN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		ImageColor3 = Color3.fromRGB(40, 15, 5), -- chars as it burns
		ImageTransparency = 1,
	}):Play()

	-- Played from the card on the server, so everyone hears it coming from that pile
	local whoosh = Instance.new("Sound")
	whoosh.Name = "BurnSound"
	whoosh.SoundId = BURN_SOUND_ID
	whoosh.Volume = 0.7
	whoosh.RollOffMinDistance = 20 -- full volume anywhere around the table
	whoosh.RollOffMaxDistance = 80
	whoosh.Parent = card
	whoosh:Play()

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 130, 40)
	glow.Range = 9
	glow.Brightness = 2.5
	glow.Parent = card

	-- Lift off the pile, char to black, shrink and fade while burning
	local info = TweenInfo.new(BURN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(card, info, {
		CFrame = startCF * CFrame.new(0.9, 0, 0) * CFrame.Angles(math.rad(25), 0, 0), -- local X = up
		Size = Vector3.new(0.06, 0.5, 0.5),
		Color = Color3.fromRGB(18, 8, 4),
		Transparency = 1,
	}):Play()
	TweenService:Create(glow, info, { Brightness = 0 }):Play()

	task.delay(BURN_SECONDS * 0.8, function()
		fire.Enabled = false
		embers.Enabled = false
	end)
	Debris:AddItem(card, BURN_SECONDS + 1.5)
end

function Card3DManager.ClearAllCards()
	isRevealingClickEnabled = false
	local folder = getCardsFolder()
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			task.spawn(function()
				local tween = TweenService:Create(child, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = Vector3.new(0, 0, 0),
					Transparency = 1,
				})
				tween:Play()
				tween.Completed:Connect(function()
					child:Destroy()
				end)
			end)
		end
	end
	for seatIdx = 1, Constants.MAX_PLAYERS do
		table.clear(seatStacks[seatIdx])
	end
	table.clear(revealedCards)
end

return Card3DManager
