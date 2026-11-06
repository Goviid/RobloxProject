--!strict
-- Card3DManager.luau
-- Manages physical oversized 3D cards placed on the table in front of players (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local TableBuilder = require(script.Parent.TableBuilder)
local PlayerManager = require(script.Parent.PlayerManager)

local Card3DManager = {}

-- Container folder inside Workspace.SkullsArena
local function getCardsFolder(): Folder
	local arena = Workspace:WaitForChild("SkullsArena", 5) :: Model?
	local folder = arena and arena:FindFirstChild("TableCardStacks") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TableCardStacks"
		folder.Parent = arena or Workspace
	end
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
end

-- ============================================================================
-- 1. SPAWN CLEAN CIRCULAR 3D CARD IN PILE
-- ============================================================================
function Card3DManager.PlaceCard3D(seatIndex: number, stackCount: number)
	local coasterCF = TableBuilder.GetCoasterCFrame(seatIndex)
	if not coasterCF then return end

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

	-- Clean Circular Card Back Face
	local bg = Instance.new("Frame")
	bg.Name = "CardBackFace"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(28, 24, 34)
	bg.BorderSizePixel = 0
	bg.Parent = sg
	Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

	-- Outer Gold Concentric Ring (Clean Circle)
	local outerBorder = Instance.new("Frame")
	outerBorder.Name = "OuterBorder"
	outerBorder.Size = UDim2.new(1, -10, 1, -10)
	outerBorder.Position = UDim2.new(0, 5, 0, 5)
	outerBorder.BackgroundTransparency = 1
	outerBorder.Parent = bg
	Instance.new("UICorner", outerBorder).CornerRadius = UDim.new(1, 0)

	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Color3.fromRGB(245, 205, 75)
	borderStroke.Thickness = 3.5
	borderStroke.Parent = outerBorder

	-- Inner Accent Ring
	local innerRing = Instance.new("Frame")
	innerRing.Name = "InnerRing"
	innerRing.Size = UDim2.new(1, -26, 1, -26)
	innerRing.Position = UDim2.new(0, 13, 0, 13)
	innerRing.BackgroundTransparency = 1
	innerRing.Parent = bg
	Instance.new("UICorner", innerRing).CornerRadius = UDim.new(1, 0)

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(255, 235, 150)
	innerStroke.Transparency = 0.4
	innerStroke.Thickness = 1.8
	innerStroke.Parent = innerRing

	-- Center Stylized Medallion Emblem
	local patternIcon = Instance.new("TextLabel")
	patternIcon.Name = "Icon"
	patternIcon.Size = UDim2.new(1, 0, 1, 0)
	patternIcon.BackgroundTransparency = 1
	patternIcon.Font = Enum.Font.FredokaOne
	patternIcon.TextSize = 78
	patternIcon.TextColor3 = Color3.fromRGB(250, 215, 80)
	patternIcon.Text = "✦"
	patternIcon.Parent = bg

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
	if not stack or #stack == 0 then return end

	local cardPart = table.remove(stack)
	if not cardPart or not cardPart.Parent then return end
	table.insert(revealedCards, cardPart)

	-- Disable ClickDetector once card is revealed
	local clicker = cardPart:FindFirstChildWhichIsA("ClickDetector")
	if clicker then clicker.MaxActivationDistance = 0 end

	local isSkull = (cardType == Enums.CardType.Skull)
	local currentCF = cardPart.CFrame
	local liftCF = currentCF + Vector3.new(0, 1.2, 0)

	-- Update SurfaceGui face artwork
	local sg = cardPart:FindFirstChild("FaceGui") :: SurfaceGui?
	if sg then
		local bg = sg:FindFirstChild("CardBackFace") :: Frame?
		if bg then
			bg.BackgroundColor3 = isSkull and Color3.fromRGB(22, 18, 24) or Color3.fromRGB(165, 20, 38)
			local icon = bg:FindFirstChild("Icon") :: TextLabel?
			if icon then
				icon.Text = isSkull and "💀" or "🌹"
				icon.TextColor3 = isSkull and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 230, 235)
				icon.TextSize = 100
			end
		end
	end

	cardPart.Color = isSkull and Color3.fromRGB(18, 14, 20) or Color3.fromRGB(175, 22, 40)

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
	for seatIdx = 1, 6 do
		table.clear(seatStacks[seatIdx])
	end
	table.clear(revealedCards)
end

return Card3DManager
