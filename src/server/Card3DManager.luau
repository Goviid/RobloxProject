--!strict
-- Card3DManager.luau
-- Manages physical 3D cards placed on the table in front of players (LOCOfficial style)

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local TableBuilder = require(script.Parent.TableBuilder)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

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

-- ============================================================================
-- 1. SPAWN 3D CARD ON TABLE IN FRONT OF PLAYER
-- ============================================================================
function Card3DManager.PlaceCard3D(seatIndex: number, stackCount: number)
	local coasterCF = TableBuilder.GetCoasterCFrame(seatIndex)
	if not coasterCF then return end

	local folder = getCardsFolder()
	local heightOffset = (stackCount - 1) * 0.12
	local randomJitterRot = math.rad(math.random(-12, 12))

	-- Physical 3D Card Part (Cylinder coaster)
	local cardPart = Instance.new("Part")
	cardPart.Name = "Card3D_Seat" .. seatIndex .. "_Card" .. stackCount
	cardPart.Shape = Enum.PartType.Cylinder
	cardPart.Size = Vector3.new(0.08, 2.3, 2.3)

	-- Place slightly above coaster and drop with a quick snap
	local targetCF = (coasterCF + Vector3.new(0, heightOffset + 0.08, 0))
		* CFrame.Angles(0, randomJitterRot, 0)

	local spawnCF = targetCF + Vector3.new(0, 1.2, 0)
	cardPart.CFrame = spawnCF
	cardPart.Anchored = true
	cardPart.CanCollide = false
	cardPart.Material = Enum.Material.SmoothPlastic
	cardPart.Color = Color3.fromRGB(48, 28, 20)
	cardPart.Parent = folder

	-- Ornate gold rim
	local stroke = Instance.new("Highlight")
	stroke.Name = "Rim"
	stroke.FillTransparency = 1
	stroke.OutlineColor = Color3.fromRGB(220, 175, 45)
	stroke.OutlineTransparency = 0.2
	stroke.Adornee = cardPart
	stroke.Parent = cardPart

	-- SurfaceGui for Face-Down pattern
	local sg = Instance.new("SurfaceGui")
	sg.Name = "FaceGui"
	sg.Face = Enum.NormalId.Right -- Cylinder flat circular face
	sg.CanvasSize = Vector2.new(200, 200)
	sg.AlwaysOnTop = false
	sg.Adornee = cardPart
	sg.Parent = cardPart

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.FredokaOne
	icon.TextSize = 64
	icon.TextColor3 = Color3.fromRGB(240, 195, 60)
	icon.Text = "✨"
	icon.Parent = sg

	-- Quick satisfying drop animation
	TweenService:Create(cardPart, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = targetCF,
	}):Play()

	table.insert(seatStacks[seatIndex], cardPart)
end

-- ============================================================================
-- 2. REVEAL 3D CARD (PHYSICALLY FLIPS UP OFF TABLE)
-- ============================================================================
function Card3DManager.RevealCard3D(seatIndex: number, cardType: string)
	local stack = seatStacks[seatIndex]
	if not stack or #stack == 0 then return end

	-- Pop the top card
	local cardPart = table.remove(stack)
	if not cardPart or not cardPart.Parent then return end

	local isSkull = (cardType == Enums.CardType.Skull)
	local currentCF = cardPart.CFrame
	local liftCF = currentCF + Vector3.new(0, 2.0, 0)

	-- Update SurfaceGui face
	local sg = cardPart:FindFirstChild("FaceGui") :: SurfaceGui?
	if sg then
		local icon = sg:FindFirstChildOfClass("TextLabel")
		if icon then
			icon.Text = isSkull and "💀" or "🌹"
			icon.TextColor3 = isSkull and Color3.fromRGB(245, 60, 60) or Color3.fromRGB(255, 210, 215)
		end
	end

	-- Color change based on card type
	cardPart.Color = isSkull and Color3.fromRGB(25, 20, 22) or Color3.fromRGB(180, 28, 40)

	-- Tween lift and spin flip
	local flipTween = TweenService:Create(cardPart, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = liftCF * CFrame.Angles(0, math.rad(180), 0),
		Size = Vector3.new(0.08, 2.7, 2.7), -- Scales up slightly while hovering
	})
	flipTween:Play()
end

-- ============================================================================
-- 3. RESET ALL 3D CARDS (ROUND END)
-- ============================================================================
function Card3DManager.ClearAllCards()
	for seatIdx = 1, 6 do
		local stack = seatStacks[seatIdx]
		if stack then
			for _, cardPart in ipairs(stack) do
				task.spawn(function()
					local tween = TweenService:Create(cardPart, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
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
