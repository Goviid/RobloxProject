--!strict
-- TableView.luau
-- Clean LOCOfficial-style HUD: Top Match Status Badge & Sleek Player Strip (leaves 3D table completely unobstructed)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local TableView = {}

local mainContainer: Frame? = nil
local statusBadge: Frame? = nil
local phaseLabel: TextLabel? = nil
local bidLabel: TextLabel? = nil
local subLabel: TextLabel? = nil
local playerStripFrame: Frame? = nil
local playerPills: { [number]: Frame } = {}

export type StackClickCallback = (targetUserId: number) -> ()
local onStackClickedCallback: StackClickCallback? = nil

-- ============================================================================
-- 1. CREATE COMPACT PLAYER PILL (Sleek LOCOfficial Top Strip)
-- ============================================================================
local function createPlayerPill(userId: number, name: string, isBot: boolean): Frame
	local pill = Instance.new("Frame")
	pill.Name = "Pill_" .. userId
	pill.Size = UDim2.new(0, 136, 0, 44)
	pill.BackgroundColor3 = Theme.Colors.PanelBackground
	pill.BackgroundTransparency = 0.2
	pill.BorderSizePixel = 0

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 10)
	pillCorner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Name = "PillStroke"
	stroke.Color = Theme.Colors.PanelBorder
	stroke.Thickness = 1.5
	stroke.Parent = pill

	-- Turn Highlight Halo (Glows gold when it is this player's turn)
	local turnHalo = Instance.new("Frame")
	turnHalo.Name = "TurnHalo"
	turnHalo.Size = UDim2.new(1, 8, 1, 8)
	turnHalo.Position = UDim2.new(0, -4, 0, -4)
	turnHalo.BackgroundColor3 = Theme.Colors.ActiveTurnGlow
	turnHalo.BackgroundTransparency = 1
	turnHalo.Parent = pill

	local haloCorner = Instance.new("UICorner")
	haloCorner.CornerRadius = UDim.new(0, 12)
	haloCorner.Parent = turnHalo

	-- Avatar Headshot Circle
	local avatarBox = Instance.new("Frame")
	avatarBox.Name = "AvatarBox"
	avatarBox.Size = UDim2.new(0, 32, 0, 32)
	avatarBox.Position = UDim2.new(0, 6, 0.5, -16)
	avatarBox.BackgroundColor3 = Color3.fromRGB(35, 22, 16)
	avatarBox.BorderSizePixel = 0
	avatarBox.Parent = pill

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = Theme.CornerRadius.Circular
	avatarCorner.Parent = avatarBox

	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "AvatarImage"
	avatarImage.Size = UDim2.new(1, 0, 1, 0)
	avatarImage.BackgroundTransparency = 1
	avatarImage.Parent = avatarBox

	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = Theme.CornerRadius.Circular
	imgCorner.Parent = avatarImage

	task.spawn(function()
		if not isBot and userId > 0 then
			local thumb, isReady = Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
			if isReady and avatarImage.Parent then
				avatarImage.Image = thumb
			end
		else
			-- Bot Icon
			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.new(1, 0, 1, 0)
			icon.BackgroundTransparency = 1
			icon.Font = Enum.Font.FredokaOne
			icon.TextSize = 18
			icon.TextColor3 = Theme.Colors.Gold
			icon.Text = "🤖"
			icon.Parent = avatarBox
		end
	end)

	-- Player Name Label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -78, 0, 16)
	nameLabel.Position = UDim2.new(0, 42, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Theme.Fonts.Header
	nameLabel.TextSize = 11
	nameLabel.TextColor3 = Theme.Colors.TextPrimary
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = name
	nameLabel.Parent = pill

	-- Score Gems Display (Two gems: 2 points to win)
	local scoreRow = Instance.new("Frame")
	scoreRow.Name = "ScoreRow"
	scoreRow.Size = UDim2.new(0, 36, 0, 14)
	scoreRow.Position = UDim2.new(0, 42, 0, 22)
	scoreRow.BackgroundTransparency = 1
	scoreRow.Parent = pill

	local scoreLayout = Instance.new("UIListLayout")
	scoreLayout.FillDirection = Enum.FillDirection.Horizontal
	scoreLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scoreLayout.Padding = UDim.new(0, 4)
	scoreLayout.Parent = scoreRow

	for gemIdx = 1, Constants.POINTS_TO_WIN do
		local gem = Instance.new("TextLabel")
		gem.Name = "Gem_" .. gemIdx
		gem.Size = UDim2.new(0, 14, 0, 14)
		gem.BackgroundTransparency = 1
		gem.Font = Enum.Font.GothamBold
		gem.TextSize = 11
		gem.Text = "◇"
		gem.TextColor3 = Color3.fromRGB(110, 95, 80)
		gem.LayoutOrder = gemIdx
		gem.Parent = scoreRow
	end

	-- Card Stack Badge Button (Clickable during Revealing phase)
	local stackButton = Instance.new("TextButton")
	stackButton.Name = "StackButton"
	stackButton.Size = UDim2.new(0, 28, 0, 28)
	stackButton.Position = UDim2.new(1, -34, 0.5, -14)
	stackButton.BackgroundColor3 = Color3.fromRGB(24, 16, 12)
	stackButton.BorderSizePixel = 0
	stackButton.Font = Theme.Fonts.Title
	stackButton.TextSize = 12
	stackButton.TextColor3 = Theme.Colors.Gold
	stackButton.Text = "0"
	stackButton.AutoButtonColor = false
	stackButton.Parent = pill

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = Theme.CornerRadius.Circular
	btnCorner.Parent = stackButton

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Name = "BtnStroke"
	btnStroke.Color = Theme.Colors.GoldMuted
	btnStroke.Thickness = 1.5
	btnStroke.Parent = stackButton

	-- Interaction callback for challenger reveal
	stackButton.MouseButton1Click:Connect(function()
		if onStackClickedCallback then
			onStackClickedCallback(userId)
		end
	end)

	return pill
end

-- ============================================================================
-- 2. SETUP TOP HUD CONTAINER
-- ============================================================================
function TableView.Create(parent: GuiObject, onStackClicked: StackClickCallback?): Frame
	onStackClickedCallback = onStackClicked

	local container = Instance.new("Frame")
	container.Name = "TableView"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- A. Top-Center Match Status Badge
	local center = Instance.new("Frame")
	center.Name = "CenterStatusBadge"
	center.Size = UDim2.new(0, 260, 0, 56)
	center.Position = UDim2.new(0.5, -130, 0, 56)
	center.BackgroundColor3 = Theme.Colors.PanelBackground
	center.BackgroundTransparency = 0.25
	center.BorderSizePixel = 0
	center.Parent = container

	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = Theme.CornerRadius.Large
	centerCorner.Parent = center

	local centerStroke = Instance.new("UIStroke")
	centerStroke.Color = Theme.Colors.PanelBorder
	centerStroke.Thickness = 1.5
	centerStroke.Parent = center

	-- Phase Title
	local pLabel = Instance.new("TextLabel")
	pLabel.Name = "PhaseLabel"
	pLabel.Size = UDim2.new(1, 0, 0, 18)
	pLabel.Position = UDim2.new(0, 0, 0, 6)
	pLabel.BackgroundTransparency = 1
	pLabel.Font = Theme.Fonts.Header
	pLabel.TextSize = 11
	pLabel.TextColor3 = Theme.Colors.TextSecondary
	pLabel.Text = "PLACEMENT PHASE"
	pLabel.Parent = center

	-- Main Metric (Bid / Status)
	local bLabel = Instance.new("TextLabel")
	bLabel.Name = "BidLabel"
	bLabel.Size = UDim2.new(1, 0, 0, 24)
	bLabel.Position = UDim2.new(0, 0, 0, 24)
	bLabel.BackgroundTransparency = 1
	bLabel.Font = Theme.Fonts.Title
	bLabel.TextSize = 17
	bLabel.TextColor3 = Theme.Colors.TextGold
	bLabel.Text = "PLACE A CARD"
	bLabel.Parent = center

	-- Subtitle (Total cards in play)
	local sLabel = Instance.new("TextLabel")
	sLabel.Name = "SubLabel"
	sLabel.Size = UDim2.new(1, 0, 0, 16)
	sLabel.Position = UDim2.new(0, 0, 1, 4)
	sLabel.BackgroundTransparency = 1
	sLabel.Font = Theme.Fonts.Body
	sLabel.TextSize = 11
	sLabel.TextColor3 = Theme.Colors.TextMuted
	sLabel.Text = ""
	sLabel.Parent = center

	-- B. Sleek Player Strip (Pinned below status badge)
	local strip = Instance.new("Frame")
	strip.Name = "PlayerStrip"
	strip.Size = UDim2.new(1, -40, 0, 50)
	strip.Position = UDim2.new(0, 20, 0, 120)
	strip.BackgroundTransparency = 1
	strip.Parent = container

	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Padding = UDim.new(0, 12)
	stripLayout.Parent = strip

	mainContainer = container
	statusBadge = center
	phaseLabel = pLabel
	bidLabel = bLabel
	subLabel = sLabel
	playerStripFrame = strip

	return container
end

-- ============================================================================
-- 3. UPDATE PLAYER STRIP (Scores, Stacks, Turn Highlights)
-- ============================================================================
function TableView.UpdateLayout(playersData: { [string]: any }, activePlayerId: number?, challengerId: number?)
	if not playerStripFrame then return end

	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0
	local sortedPlayers = {}

	for _, p in pairs(playersData) do
		table.insert(sortedPlayers, p)
	end

	-- Order players by seat index
	table.sort(sortedPlayers, function(a, b)
		return a.seatIndex < b.seatIndex
	end)

	for _, p in ipairs(sortedPlayers) do
		local uid = p.userId
		local pill = playerPills[uid]
		if not pill then
			pill = createPlayerPill(uid, p.name, p.isBot)
			pill.Parent = playerStripFrame
			playerPills[uid] = pill
		end

		pill.LayoutOrder = p.seatIndex

		-- Update Stack Count Badge
		local stackBtn = pill:FindFirstChild("StackButton") :: TextButton?
		if stackBtn then
			stackBtn.Text = tostring(p.stackCount or 0)

			-- Challenger reveal target glow
			local myData = playersData[tostring(localUserId)]
			local myStackCount = myData and myData.stackCount or 0
			local isRevealing = (challengerId == localUserId and activePlayerId == localUserId)
			local canClickThisStack = false
			if isRevealing and (p.stackCount and p.stackCount > 0) then
				if myStackCount > 0 then
					canClickThisStack = (uid == localUserId)
				else
					canClickThisStack = (uid ~= localUserId)
				end
			end

			local btnStroke = stackBtn:FindFirstChild("BtnStroke") :: UIStroke?
			if btnStroke then
				btnStroke.Color = canClickThisStack and Theme.Colors.GoldGlow or Theme.Colors.GoldMuted
				btnStroke.Thickness = canClickThisStack and 3.0 or 1.5
			end
		end

		-- Update Score Gems
		local scoreRow = pill:FindFirstChild("ScoreRow")
		if scoreRow then
			for gemIdx = 1, Constants.POINTS_TO_WIN do
				local gem = scoreRow:FindFirstChild("Gem_" .. gemIdx) :: TextLabel?
				if gem then
					local hasPoint = (p.score and p.score >= gemIdx)
					gem.Text = hasPoint and "◆" or "◇"
					gem.TextColor3 = hasPoint and Theme.Colors.Gold or Color3.fromRGB(110, 95, 80)
				end
			end
		end

		-- Update Turn Highlight Halo
		local isCurrentTurn = (activePlayerId == uid)
		local halo = pill:FindFirstChild("TurnHalo") :: Frame?
		if halo then
			halo.BackgroundTransparency = isCurrentTurn and 0.4 or 1
		end

		local pillStroke = pill:FindFirstChild("PillStroke") :: UIStroke?
		if pillStroke then
			pillStroke.Color = isCurrentTurn and Theme.Colors.ActiveTurnGlow or Theme.Colors.PanelBorder
			pillStroke.Thickness = isCurrentTurn and 2.5 or 1.5
		end

		-- Elimination styling
		if p.isEliminated then
			pill.BackgroundTransparency = 0.7
		end
	end
end

-- ============================================================================
-- 4. UPDATE TOP STATUS BADGE
-- ============================================================================
function TableView.UpdateCenter(gameState: string, highestBid: number, challengerName: string?, totalCardsOnTable: number?)
	if not statusBadge or not phaseLabel or not bidLabel then return end

	if gameState == Enums.GameState.Lobby then
		phaseLabel.Text = "WAITING FOR PLAYERS"
		bidLabel.Text = "LOBBY"
	elseif gameState == Enums.GameState.Placement then
		phaseLabel.Text = "PLACEMENT PHASE"
		bidLabel.Text = "PLACE A CARD"
	elseif gameState == Enums.GameState.Bidding then
		phaseLabel.Text = "BIDDING PHASE"
		bidLabel.Text = "CURRENT BID: " .. highestBid
	elseif gameState == Enums.GameState.Revealing then
		phaseLabel.Text = "REVEALING PHASE"
		bidLabel.Text = "CHALLENGER: " .. (challengerName or "PLAYER") .. " (" .. highestBid .. ")"
	elseif gameState == Enums.GameState.RoundEnd then
		phaseLabel.Text = "ROUND FINISHED"
		bidLabel.Text = "PREPARING NEXT ROUND"
	elseif gameState == Enums.GameState.MatchEnd then
		phaseLabel.Text = "MATCH OVER"
		bidLabel.Text = "VICTORY!"
	end

	if subLabel and totalCardsOnTable then
		subLabel.Text = "🃏 " .. totalCardsOnTable .. " Cards Placed On Table"
		subLabel.Visible = (gameState == Enums.GameState.Placement or gameState == Enums.GameState.Bidding or gameState == Enums.GameState.Revealing)
	end
end

return TableView
