--!strict
-- TableView.luau
-- Circular tabletop layout for 2 to 6 players, showing stacks, score coasters, and turn highlights

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local TableView = {}

local tableFrame: Frame? = nil
local centerBadge: Frame? = nil
local centerBidLabel: TextLabel? = nil
local centerPhaseLabel: TextLabel? = nil
local playerPods: { [number]: Frame } = {}

-- Callback when challenger clicks a stack to reveal
export type StackClickCallback = (targetUserId: number) -> ()
local onStackClickedCallback: StackClickCallback? = nil

-- ============================================================================
-- 1. PLAYER POD CREATION HELPER
-- ============================================================================
local function createPlayerPod(userId: number, name: string, isBot: boolean): Frame
	local pod = Instance.new("Frame")
	pod.Name = "Pod_" .. userId
	pod.Size = UDim2.new(0, 120, 0, 140)
	pod.AnchorPoint = Vector2.new(0.5, 0.5)
	pod.BackgroundTransparency = 1

	-- Turn Highlight Halo (glowing ring when it's this player's turn)
	local halo = Instance.new("Frame")
	halo.Name = "TurnHalo"
	halo.Size = UDim2.new(1, 16, 1, 16)
	halo.Position = UDim2.new(0, -8, 0, -8)
	halo.BackgroundColor3 = Theme.Colors.ActiveTurnGlow
	halo.BackgroundTransparency = 1 -- Visible only on turn
	halo.Parent = pod

	local haloCorner = Instance.new("UICorner")
	haloCorner.CornerRadius = Theme.CornerRadius.Large
	haloCorner.Parent = halo

	-- Coaster / Stack Display Area (top portion of pod)
	local stackBox = Instance.new("ImageButton")
	stackBox.Name = "StackBox"
	stackBox.Size = UDim2.new(0, 72, 0, 72)
	stackBox.Position = UDim2.new(0.5, -36, 0, 4)
	stackBox.BackgroundColor3 = Theme.Colors.CardBack
	stackBox.BorderSizePixel = 0
	stackBox.AutoButtonColor = false
	stackBox.Parent = pod

	local stackCorner = Instance.new("UICorner")
	stackCorner.CornerRadius = Theme.CornerRadius.Circular
	stackCorner.Parent = stackBox

	local stackStroke = Instance.new("UIStroke")
	stackStroke.Name = "StackStroke"
	stackStroke.Color = Theme.Colors.GoldMuted
	stackStroke.Thickness = 2
	stackStroke.Parent = stackBox

	-- Coaster Pattern Art
	local coasterPattern = Instance.new("TextLabel")
	coasterPattern.Name = "CoasterIcon"
	coasterPattern.Size = UDim2.new(1, 0, 1, 0)
	coasterPattern.BackgroundTransparency = 1
	coasterPattern.Font = Theme.Fonts.Title
	coasterPattern.TextSize = 28
	coasterPattern.Text = "✨"
	coasterPattern.TextColor3 = Theme.Colors.Gold
	coasterPattern.Parent = stackBox

	-- Stack Card Count Badge
	local countBadge = Instance.new("Frame")
	countBadge.Name = "CountBadge"
	countBadge.Size = UDim2.new(0, 24, 0, 24)
	countBadge.Position = UDim2.new(1, -16, 1, -16)
	countBadge.BackgroundColor3 = Color3.fromRGB(15, 10, 8)
	countBadge.BorderSizePixel = 0
	countBadge.Parent = stackBox

	local countCorner = Instance.new("UICorner")
	countCorner.CornerRadius = Theme.CornerRadius.Circular
	countCorner.Parent = countBadge

	local countStroke = Instance.new("UIStroke")
	countStroke.Color = Theme.Colors.Gold
	countStroke.Thickness = 1.5
	countStroke.Parent = countBadge

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(1, 0, 1, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Theme.Fonts.Header
	countLabel.TextSize = 11
	countLabel.TextColor3 = Theme.Colors.TextGold
	countLabel.Text = "0"
	countLabel.Parent = countBadge

	-- Player Info Container (Name + Score)
	local infoCard = Instance.new("Frame")
	infoCard.Name = "InfoCard"
	infoCard.Size = UDim2.new(1, 0, 0, 52)
	infoCard.Position = UDim2.new(0, 0, 0, 82)
	infoCard.BackgroundColor3 = Theme.Colors.PanelBackground
	infoCard.BackgroundTransparency = 0.2
	infoCard.BorderSizePixel = 0
	infoCard.Parent = pod

	local infoCorner = Instance.new("UICorner")
	infoCorner.CornerRadius = Theme.CornerRadius.Medium
	infoCorner.Parent = infoCard

	local infoStroke = Instance.new("UIStroke")
	infoStroke.Color = Theme.Colors.PanelBorder
	infoStroke.Thickness = 1
	infoStroke.Parent = infoCard

	-- Player Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -8, 0, 20)
	nameLabel.Position = UDim2.new(0, 4, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Theme.Fonts.Header
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = Theme.Colors.TextPrimary
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = name
	nameLabel.Parent = infoCard

	-- Score Petals / Coaster Gems (2 win points)
	local scoreBox = Instance.new("Frame")
	scoreBox.Name = "ScoreBox"
	scoreBox.Size = UDim2.new(1, 0, 0, 20)
	scoreBox.Position = UDim2.new(0, 0, 0, 26)
	scoreBox.BackgroundTransparency = 1
	scoreBox.Parent = infoCard

	local scoreLayout = Instance.new("UIListLayout")
	scoreLayout.FillDirection = Enum.FillDirection.Horizontal
	scoreLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	scoreLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	scoreLayout.Padding = UDim.new(0, 8)
	scoreLayout.Parent = scoreBox

	for i = 1, Constants.POINTS_TO_WIN do
		local gem = Instance.new("Frame")
		gem.Name = "Gem_" .. i
		gem.Size = UDim2.new(0, 14, 0, 14)
		gem.BackgroundColor3 = Color3.fromRGB(35, 25, 20)
		gem.BorderSizePixel = 0
		gem.Parent = scoreBox

		local gemCorner = Instance.new("UICorner")
		gemCorner.CornerRadius = Theme.CornerRadius.Circular
		gemCorner.Parent = gem

		local gemStroke = Instance.new("UIStroke")
		gemStroke.Name = "GemStroke"
		gemStroke.Color = Theme.Colors.PanelBorder
		gemStroke.Thickness = 1
		gemStroke.Parent = gem
	end

	-- Stack click interaction for the challenger
	stackBox.MouseButton1Click:Connect(function()
		if onStackClickedCallback then
			onStackClickedCallback(userId)
		end
	end)

	return pod
end

-- ============================================================================
-- 2. SETUP & TABLE CREATION
-- ============================================================================
function TableView.Create(parent: GuiObject, onStackClicked: StackClickCallback?): Frame
	onStackClickedCallback = onStackClicked

	local container = Instance.new("Frame")
	container.Name = "TableView"
	container.Size = UDim2.new(1, 0, 1, -140) -- Leaves room for Hand & Action Bar at bottom
	container.Position = UDim2.new(0, 0, 0, 70) -- Below notification banner
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- Center Circular Board
	local center = Instance.new("Frame")
	center.Name = "CenterTable"
	center.Size = UDim2.new(0, 200, 0, 200)
	center.Position = UDim2.new(0.5, -100, 0.45, -100)
	center.BackgroundColor3 = Theme.Colors.TableSurface
	center.BackgroundTransparency = 0.2
	center.BorderSizePixel = 0
	center.Parent = container

	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = Theme.CornerRadius.Circular
	centerCorner.Parent = center

	local centerStroke = Instance.new("UIStroke")
	centerStroke.Color = Theme.Colors.TableBorder
	centerStroke.Thickness = 4
	centerStroke.Parent = center

	-- Center Phase Title
	local phaseLabel = Instance.new("TextLabel")
	phaseLabel.Name = "PhaseLabel"
	phaseLabel.Size = UDim2.new(1, 0, 0, 24)
	phaseLabel.Position = UDim2.new(0, 0, 0, 36)
	phaseLabel.BackgroundTransparency = 1
	phaseLabel.Font = Theme.Fonts.Header
	phaseLabel.TextSize = 12
	phaseLabel.TextColor3 = Theme.Colors.TextSecondary
	phaseLabel.Text = "WAITING FOR PLAYERS"
	phaseLabel.Parent = center

	-- Center Highest Bid Value
	local bidLabel = Instance.new("TextLabel")
	bidLabel.Name = "BidLabel"
	bidLabel.Size = UDim2.new(1, 0, 0, 48)
	bidLabel.Position = UDim2.new(0, 0, 0, 64)
	bidLabel.BackgroundTransparency = 1
	bidLabel.Font = Theme.Fonts.Title
	bidLabel.TextSize = 28
	bidLabel.TextColor3 = Theme.Colors.TextGold
	bidLabel.Text = "SKULL & ROSES"
	bidLabel.Parent = center

	-- Subtitle (e.g. Total cards on table)
	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "SubLabel"
	subLabel.Size = UDim2.new(1, 0, 0, 20)
	subLabel.Position = UDim2.new(0, 0, 0, 118)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Theme.Fonts.Body
	subLabel.TextSize = 11
	subLabel.TextColor3 = Theme.Colors.TextSecondary
	subLabel.Text = "4 Cards on Table"
	subLabel.Parent = center

	tableFrame = container
	centerBadge = center
	centerBidLabel = bidLabel
	centerPhaseLabel = phaseLabel

	return container
end

-- ============================================================================
-- 3. DYNAMIC RADIAL SEATING LAYOUT (2 to 6 Players)
-- ============================================================================
function TableView.UpdateLayout(playersData: { [string]: any }, activePlayerId: number?, challengerId: number?)
	if not tableFrame then return end

	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0
	local count = 0
	local sortedPlayers = {}

	for _, p in pairs(playersData) do
		count += 1
		table.insert(sortedPlayers, p)
	end

	-- Sort with LocalPlayer at the bottom seat (seat 1 perspective)
	table.sort(sortedPlayers, function(a, b)
		return a.seatIndex < b.seatIndex
	end)

	local angles = Constants.SEAT_DISTRIBUTIONS[count] or Constants.SEAT_DISTRIBUTIONS[4]
	local radiusX = 280
	local radiusY = 160

	for i, p in ipairs(sortedPlayers) do
		local uid = p.userId
		local pod = playerPods[uid]
		if not pod then
			pod = createPlayerPod(uid, p.name, p.isBot)
			pod.Parent = tableFrame
			playerPods[uid] = pod
		end

		-- Position radially around table center
		local angleDeg = angles[i] or 0
		local angleRad = math.rad(angleDeg)
		local posX = 0.5 + (math.cos(angleRad) * radiusX / (tableFrame.AbsoluteSize.X > 0 and tableFrame.AbsoluteSize.X or 800))
		local posY = 0.45 + (math.sin(angleRad) * radiusY / (tableFrame.AbsoluteSize.Y > 0 and tableFrame.AbsoluteSize.Y or 600))

		pod.Position = UDim2.new(posX, 0, posY, 0)

		-- Update Stack Count
		local stackBox = pod:FindFirstChild("StackBox") :: ImageButton?
		if stackBox then
			local countLabel = stackBox:FindFirstChild("CountBadge") and stackBox.CountBadge:FindFirstChild("CountLabel") :: TextLabel?
			if countLabel then
				countLabel.Text = tostring(p.stackCount or 0)
			end
			-- Coaster appearance
			stackBox.BackgroundTransparency = (p.stackCount and p.stackCount > 0) and 0 or 0.7
		end

		-- Update Score Petals (Gems)
		local infoCard = pod:FindFirstChild("InfoCard")
		if infoCard and infoCard:FindFirstChild("ScoreBox") then
			local scoreBox = infoCard.ScoreBox
			for gemIdx = 1, Constants.POINTS_TO_WIN do
				local gem = scoreBox:FindFirstChild("Gem_" .. gemIdx) :: Frame?
				if gem then
					local hasPoint = (p.score and p.score >= gemIdx)
					gem.BackgroundColor3 = hasPoint and Theme.Colors.Gold or Color3.fromRGB(35, 25, 20)
					local stroke = gem:FindFirstChild("GemStroke") :: UIStroke?
					if stroke then
						stroke.Color = hasPoint and Theme.Colors.GoldGlow or Theme.Colors.PanelBorder
					end
				end
			end
		end

		-- Update Turn Highlight Halo
		local isCurrentTurn = (activePlayerId == uid)
		local halo = pod:FindFirstChild("TurnHalo") :: Frame?
		if halo then
			halo.BackgroundTransparency = isCurrentTurn and 0.4 or 1
		end

		-- Elimination styling
		if p.isEliminated then
			pod.GroupTransparency = 0.6
		end
	end

	-- Clean up departed player pods
	for uid, pod in pairs(playerPods) do
		local found = false
		for _, p in pairs(playersData) do
			if p.userId == uid then
				found = true
				break
			end
		end
		if not found then
			pod:Destroy()
			playerPods[uid] = nil
		end
	end
end

-- Update center table info
function TableView.UpdateCenter(gameState: string, currentBid: number, challengerName: string?, totalCards: number)
	if not centerBidLabel or not centerPhaseLabel then return end

	local phaseNames = {
		[Enums.GameState.Lobby] = "WAITING FOR PLAYERS",
		[Enums.GameState.Placement] = "PLACEMENT PHASE",
		[Enums.GameState.Bidding] = "BIDDING PHASE",
		[Enums.GameState.Revealing] = "REVEALING PHASE",
		[Enums.GameState.RoundEnd] = "ROUND OVER",
		[Enums.GameState.MatchEnd] = "MATCH OVER",
	}

	centerPhaseLabel.Text = phaseNames[gameState] or gameState

	if gameState == Enums.GameState.Bidding or gameState == Enums.GameState.Revealing then
		centerBidLabel.Text = "BID: " .. currentBid
		if challengerName then
			centerBidLabel.Text = currentBid .. " (" .. challengerName .. ")"
		end
	else
		centerBidLabel.Text = "SKULL & ROSES"
	end

	if centerBadge and centerBadge:FindFirstChild("SubLabel") then
		local sub = centerBadge.SubLabel :: TextLabel
		sub.Text = totalCards .. " Cards on Table"
	end
end

return TableView
