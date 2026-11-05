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

export type ActionHandler = (userId: number, action: string, data: any) -> (boolean, string?)
local roundActionHandler: ActionHandler? = nil

function Card3DManager.SetActionHandler(handler: ActionHandler)
	roundActionHandler = handler
end

-- ============================================================================
-- 1. SPAWN OVERSIZED 3D CARD ON TABLE IN FRONT OF PLAYER
-- ============================================================================
function Card3DManager.PlaceCard3D(seatIndex: number, stackCount: number)
	local coasterCF = TableBuilder.GetCoasterCFrame(seatIndex)
	if not coasterCF then return end

	local folder = getCardsFolder()
	local coasterPos = coasterCF.Position
	local baseY = coasterPos.Y + 0.04
	local stackY = baseY + 0.08 + (stackCount - 1) * 0.12
	local randomJitterRot = math.rad(math.random(-14, 14))

	-- Target CFrame: cylinder flat circular face up (Z=90 deg) with slight Y-jitter
	local targetCF = CFrame.new(coasterPos.X, stackY, coasterPos.Z)
		* CFrame.Angles(0, randomJitterRot, math.rad(90))

	-- Spawn slightly above the stack for a snappy physical drop animation
	local spawnCF = targetCF + Vector3.new(0, 1.4, 0)

	local cardPart = Instance.new("Part")
	cardPart.Name = "Card3D_Seat" .. seatIndex .. "_Card" .. stackCount
	cardPart.Shape = Enum.PartType.Cylinder
	cardPart.Size = Vector3.new(0.10, 2.9, 2.9) -- Oversized 2.9-stud diameter
	cardPart.CFrame = spawnCF
	cardPart.Anchored = true
	cardPart.CanCollide = false
	cardPart.Material = Enum.Material.SmoothPlastic
	cardPart.Color = Color3.fromRGB(46, 28, 20)
	cardPart.Parent = folder

	-- Ornate Gold Outer Rim Highlight
	local stroke = Instance.new("Highlight")
	stroke.Name = "GoldRim"
	stroke.FillTransparency = 1
	stroke.OutlineColor = Color3.fromRGB(240, 190, 50)
	stroke.OutlineTransparency = 0.15
	stroke.Adornee = cardPart
	stroke.Parent = cardPart

	-- SurfaceGui on the top circular face (Right face on Z-rotated cylinder)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "FaceGui"
	sg.Face = Enum.NormalId.Right
	sg.CanvasSize = Vector2.new(220, 220)
	sg.AlwaysOnTop = false
	sg.Adornee = cardPart
	sg.Parent = cardPart

	-- Coaster Filigree Center Pattern (Face-Down)
	local bg = Instance.new("Frame")
	bg.Name = "CardBackFace"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(38, 24, 18)
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bg

	local patternIcon = Instance.new("TextLabel")
	patternIcon.Name = "Icon"
	patternIcon.Size = UDim2.new(1, 0, 1, 0)
	patternIcon.BackgroundTransparency = 1
	patternIcon.Font = Enum.Font.FredokaOne
	patternIcon.TextSize = 82
	patternIcon.TextColor3 = Color3.fromRGB(245, 195, 60)
	patternIcon.Text = "✨"
	patternIcon.Parent = bg

	-- ClickDetector: Allows clicking 3D cards directly on the table
	local clicker = Instance.new("ClickDetector")
	clicker.MaxActivationDistance = 45
	clicker.Parent = cardPart
	clicker.MouseClick:Connect(function(clickingPlayer: Player)
		if roundActionHandler then
			local targetPlayer = PlayerManager.GetPlayerBySeat(seatIndex)
			if targetPlayer then
				roundActionHandler(clickingPlayer.UserId, Enums.PlayerAction.RevealCard, {
					targetUserId = targetPlayer.userId,
				})
			end
		end
	end)

	-- Smooth drop & settle tween
	TweenService:Create(cardPart, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = targetCF,
	}):Play()

	table.insert(seatStacks[seatIndex], cardPart)
end

-- ============================================================================
-- 2. REVEAL OVERSIZED 3D CARD (PHYSICALLY FLIPS UP OFF TABLE)
-- ============================================================================
function Card3DManager.RevealCard3D(seatIndex: number, cardType: string)
	local stack = seatStacks[seatIndex]
	if not stack or #stack == 0 then return end

	local cardPart = table.remove(stack)
	if not cardPart or not cardPart.Parent then return end

	local isSkull = (cardType == Enums.CardType.Skull)
	local currentCF = cardPart.CFrame
	local liftCF = currentCF + Vector3.new(0, 2.5, 0)

	-- Update SurfaceGui face artwork
	local sg = cardPart:FindFirstChild("FaceGui") :: SurfaceGui?
	if sg then
		local bg = sg:FindFirstChild("CardBackFace") :: Frame?
		if bg then
			bg.BackgroundColor3 = isSkull and Color3.fromRGB(25, 20, 22) or Color3.fromRGB(155, 20, 32)
			local icon = bg:FindFirstChild("Icon") :: TextLabel?
			if icon then
				icon.Text = isSkull and "💀" or "🌹"
				icon.TextColor3 = isSkull and Color3.fromRGB(255, 65, 65) or Color3.fromRGB(255, 220, 225)
				icon.TextSize = 92
			end
		end
	end

	cardPart.Color = isSkull and Color3.fromRGB(22, 18, 20) or Color3.fromRGB(165, 22, 35)

	local flipTween = TweenService:Create(cardPart, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = liftCF * CFrame.Angles(0, math.rad(180), 0),
		Size = Vector3.new(0.10, 3.4, 3.4),
	})
	flipTween:Play()
end

-- ============================================================================
-- 3. RESET ALL 3D CARDS (ROUND END CLEANUP)
-- ============================================================================
function Card3DManager.ClearAllCards()
	for seatIdx = 1, 6 do
		local stack = seatStacks[seatIdx]
		if stack then
			for _, cardPart in ipairs(stack) do
				task.spawn(function()
					local tween = TweenService:Create(cardPart, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Size = Vector3.new(0, 0, 0),
						Transparency = 1,
					})
					tween:Play()
					tween.Completed:Connect(function()
						cardPart:Destroy()
					end)
				end)
			end
			table.clear(stack)
		end
	end
end

return Card3DManager
