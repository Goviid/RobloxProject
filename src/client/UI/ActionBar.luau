--!strict
-- ActionBar.luau
-- Clean, modern floating Bidding controls (LOCOfficial style)
-- Features a sleek floating Start Bid pill during placement, and a compact frosted glass Bidding capsule during bidding

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Enums = require(game:GetService("ReplicatedStorage").Shared.Enums)

local ActionBar = {}

local containerFrame: Frame? = nil
local startBidPill: TextButton? = nil
local biddingCapsule: Frame? = nil
local passButton: TextButton? = nil
local bidConfirmButton: TextButton? = nil
local bidValueLabel: TextLabel? = nil
local waitingPill: TextLabel? = nil

local currentBidSelected = 1
local minAllowedBid = 1
local maxAllowedBid = 1
local currentActiveGameState = Enums.GameState.Placement
local onActionCallback: ((action: string, data: any) -> ())? = nil

-- ============================================================================
-- 1. SETUP & CREATION (Ultra-Clean Floating Elements)
-- ============================================================================
function ActionBar.Create(parent: GuiObject, callback: (action: string, data: any) -> ()): Frame
	onActionCallback = callback

	-- Root transparent container
	local root = Instance.new("Frame")
	root.Name = "ActionBarRoot"
	root.Size = UDim2.new(1, 0, 1, 0)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ZIndex = 25
	root.Parent = parent

	-- ========================================================================
	-- A. SLEEK "START BID" FLOATING PILL (During Placement Phase)
	-- Hovering cleanly centered above the raised hand cards
	-- ========================================================================
	local pill = Instance.new("TextButton")
	pill.Name = "StartBidPill"
	pill.AnchorPoint = Vector2.new(0.5, 1)
	pill.Size = UDim2.new(0, 190, 0, 42)
	pill.Position = UDim2.new(0.5, 0, 1, -215) -- Pinned cleanly above the raised hand
	pill.BackgroundColor3 = Color3.fromRGB(225, 140, 25)
	pill.BorderSizePixel = 0
	pill.AutoButtonColor = false
	pill.Font = Enum.Font.FredokaOne
	pill.TextSize = 14
	pill.TextColor3 = Color3.fromRGB(255, 255, 255)
	pill.Text = "⚡ START BID (1)"
	pill.ZIndex = 30
	pill.Visible = false
	pill.Parent = root

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(1, 0)
	pillCorner.Parent = pill

	local pillGradient = Instance.new("UIGradient")
	pillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(245, 165, 35)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(205, 115, 15)),
	})
	pillGradient.Rotation = 90
	pillGradient.Parent = pill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = Color3.fromRGB(255, 235, 140)
	pillStroke.Thickness = 2.0
	pillStroke.Parent = pill

	-- Tactile pill hover animation
	pill.MouseEnter:Connect(function()
		TweenService:Create(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 202, 0, 45),
		}):Play()
		TweenService:Create(pillStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 3.0,
			Color = Color3.fromRGB(255, 250, 180),
		}):Play()
	end)

	pill.MouseLeave:Connect(function()
		TweenService:Create(pill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 190, 0, 42),
		}):Play()
		TweenService:Create(pillStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 2.0,
			Color = Color3.fromRGB(255, 235, 140),
		}):Play()
	end)

	pill.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.StartBid, { bid = currentBidSelected })
		end
	end)

	-- ========================================================================
	-- B. SLEEK FROSTED GLASS BIDDING CAPSULE (During Bidding Phase)
	-- Compact, modern floating bar at bottom center
	-- ========================================================================
	local capsule = Instance.new("Frame")
	capsule.Name = "BiddingCapsule"
	capsule.AnchorPoint = Vector2.new(0.5, 1)
	capsule.Size = UDim2.new(0, 360, 0, 52)
	capsule.Position = UDim2.new(0.5, 0, 1, -40)
	capsule.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
	capsule.BackgroundTransparency = 0.22
	capsule.BorderSizePixel = 0
	capsule.ZIndex = 30
	capsule.Visible = false
	capsule.Parent = root

	local capsuleCorner = Instance.new("UICorner")
	capsuleCorner.CornerRadius = UDim.new(1, 0)
	capsuleCorner.Parent = capsule

	local capsuleStroke = Instance.new("UIStroke")
	capsuleStroke.Color = Color3.fromRGB(140, 195, 255)
	capsuleStroke.Transparency = 0.45
	capsuleStroke.Thickness = 1.6
	capsuleStroke.Parent = capsule

	-- 1. Pass Button (Left)
	local passBtn = Instance.new("TextButton")
	passBtn.Name = "PassButton"
	passBtn.Size = UDim2.new(0, 84, 0, 38)
	passBtn.Position = UDim2.new(0, 8, 0.5, -19)
	passBtn.BackgroundColor3 = Color3.fromRGB(175, 32, 45)
	passBtn.BorderSizePixel = 0
	passBtn.AutoButtonColor = true
	passBtn.Font = Enum.Font.FredokaOne
	passBtn.TextSize = 13
	passBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	passBtn.Text = "✕ PASS"
	passBtn.ZIndex = 32
	passBtn.Parent = capsule
	Instance.new("UICorner", passBtn).CornerRadius = UDim.new(1, 0)

	passBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			onActionCallback(Enums.PlayerAction.Pass, {})
		end
	end)

	-- 2. Stepper Frame (Center: − [ 2 ] +)
	local stepper = Instance.new("Frame")
	stepper.Name = "StepperFrame"
	stepper.Size = UDim2.new(0, 120, 0, 38)
	stepper.Position = UDim2.new(0.5, -60, 0.5, -19)
	stepper.BackgroundTransparency = 1
	stepper.ZIndex = 32
	stepper.Parent = capsule

	-- Minus Button
	local minusBtn = Instance.new("TextButton")
	minusBtn.Name = "MinusBtn"
	minusBtn.Size = UDim2.new(0, 32, 0, 32)
	minusBtn.Position = UDim2.new(0, 2, 0.5, -16)
	minusBtn.BackgroundColor3 = Color3.fromRGB(30, 48, 75)
	minusBtn.BorderSizePixel = 0
	minusBtn.Font = Enum.Font.FredokaOne
	minusBtn.TextSize = 18
	minusBtn.TextColor3 = Color3.fromRGB(255, 225, 80)
	minusBtn.Text = "−"
	minusBtn.ZIndex = 33
	minusBtn.Parent = stepper
	Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(1, 0)

	-- Value Label
	local valLabel = Instance.new("TextLabel")
	valLabel.Name = "ValueLabel"
	valLabel.Size = UDim2.new(0, 44, 0, 32)
	valLabel.Position = UDim2.new(0.5, -22, 0.5, -16)
	valLabel.BackgroundColor3 = Color3.fromRGB(18, 30, 50)
	valLabel.BorderSizePixel = 0
	valLabel.Font = Enum.Font.FredokaOne
	valLabel.TextSize = 18
	valLabel.TextColor3 = Color3.fromRGB(255, 225, 80)
	valLabel.Text = "1"
	valLabel.ZIndex = 33
	valLabel.Parent = stepper
	Instance.new("UICorner", valLabel).CornerRadius = UDim.new(0, 8)

	-- Plus Button
	local plusBtn = Instance.new("TextButton")
	plusBtn.Name = "PlusBtn"
	plusBtn.Size = UDim2.new(0, 32, 0, 32)
	plusBtn.Position = UDim2.new(1, -34, 0.5, -16)
	plusBtn.BackgroundColor3 = Color3.fromRGB(30, 48, 75)
	plusBtn.BorderSizePixel = 0
	plusBtn.Font = Enum.Font.FredokaOne
	plusBtn.TextSize = 18
	plusBtn.TextColor3 = Color3.fromRGB(255, 225, 80)
	plusBtn.Text = "+"
	plusBtn.ZIndex = 33
	plusBtn.Parent = stepper
	Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(1, 0)

	minusBtn.MouseButton1Click:Connect(function()
		ActionBar.AdjustBid(-1)
	end)

	plusBtn.MouseButton1Click:Connect(function()
		ActionBar.AdjustBid(1)
	end)

	-- 3. Raise / Confirm Button (Right)
	local raiseBtn = Instance.new("TextButton")
	raiseBtn.Name = "RaiseButton"
	raiseBtn.Size = UDim2.new(0, 110, 0, 38)
	raiseBtn.Position = UDim2.new(1, -118, 0.5, -19)
	raiseBtn.BackgroundColor3 = Color3.fromRGB(225, 140, 25)
	raiseBtn.BorderSizePixel = 0
	raiseBtn.AutoButtonColor = true
	raiseBtn.Font = Enum.Font.FredokaOne
	raiseBtn.TextSize = 13
	raiseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	raiseBtn.Text = "⚡ BID 1"
	raiseBtn.ZIndex = 32
	raiseBtn.Parent = capsule
	Instance.new("UICorner", raiseBtn).CornerRadius = UDim.new(1, 0)

	raiseBtn.MouseButton1Click:Connect(function()
		if onActionCallback then
			local action = (currentActiveGameState == Enums.GameState.Placement) and Enums.PlayerAction.StartBid or Enums.PlayerAction.RaiseBid
			onActionCallback(action, { bid = currentBidSelected })
		end
	end)

	-- 4. Waiting / Spectating Pill (Clean floating text when not your turn during Bidding)
	local waitLabel = Instance.new("TextLabel")
	waitLabel.Name = "WaitingPill"
	waitLabel.AnchorPoint = Vector2.new(0.5, 1)
	waitLabel.Size = UDim2.new(0, 300, 0, 36)
	waitLabel.Position = UDim2.new(0.5, 0, 1, -40)
	waitLabel.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
	waitLabel.BackgroundTransparency = 0.35
	waitLabel.BorderSizePixel = 0
	waitLabel.Font = Enum.Font.FredokaOne
	waitLabel.TextSize = 13
	waitLabel.TextColor3 = Color3.fromRGB(215, 235, 255)
	waitLabel.Text = "Waiting for opponents to bid..."
	waitLabel.ZIndex = 30
	waitLabel.Visible = false
	waitLabel.Parent = root
	Instance.new("UICorner", waitLabel).CornerRadius = UDim.new(1, 0)

	containerFrame = root
	startBidPill = pill
	biddingCapsule = capsule
	passButton = passBtn
	bidConfirmButton = raiseBtn
	bidValueLabel = valLabel
	waitingPill = waitLabel

	return root
end

-- ============================================================================
-- 2. ADJUST CURRENT BID VALUE
-- ============================================================================
function ActionBar.AdjustBid(delta: number)
	local nextVal = math.clamp(currentBidSelected + delta, minAllowedBid, maxAllowedBid)
	currentBidSelected = nextVal

	if bidValueLabel then
		bidValueLabel.Text = tostring(currentBidSelected)
	end
	if bidConfirmButton then
		bidConfirmButton.Text = "⚡ BID " .. currentBidSelected
	end
	if startBidPill then
		startBidPill.Text = "⚡ START BID (" .. currentBidSelected .. ")"
	end
end

-- ============================================================================
-- 3. UPDATE STATE FROM GAME LOOP
-- ============================================================================
function ActionBar.UpdateState(
	isMyTurn: boolean,
	gameState: string,
	highestBid: number,
	totalCardsOnTable: number,
	hasCardsInHand: boolean,
	hasCardsOnTable: boolean,
	canStartBidServer: boolean?
)
	currentActiveGameState = gameState

	if gameState == Enums.GameState.Placement then
		-- Placement Phase: Hand is visible. Show StartBidPill only if player has played at least 1 card and it is their turn!
		if biddingCapsule then biddingCapsule.Visible = false end
		if waitingPill then waitingPill.Visible = false end

		local allowedByServer = (canStartBidServer ~= false)
		local canStartBid = isMyTurn and hasCardsOnTable and allowedByServer
		minAllowedBid = 1
		maxAllowedBid = math.max(1, totalCardsOnTable)
		currentBidSelected = 1

		if startBidPill then
			startBidPill.Visible = canStartBid
			startBidPill.Text = "⚡ START BID (1)"
		end

	elseif gameState == Enums.GameState.Bidding then
		-- Bidding Phase: Hand is hidden. Show Bidding Capsule if my turn, or Waiting Pill if opponent's turn.
		if startBidPill then startBidPill.Visible = false end

		minAllowedBid = highestBid + 1
		maxAllowedBid = math.max(minAllowedBid, totalCardsOnTable)
		currentBidSelected = minAllowedBid

		if isMyTurn then
			if biddingCapsule then biddingCapsule.Visible = true end
			if waitingPill then waitingPill.Visible = false end
			if bidValueLabel then bidValueLabel.Text = tostring(currentBidSelected) end
			if bidConfirmButton then bidConfirmButton.Text = "⚡ BID " .. currentBidSelected end
		else
			if biddingCapsule then biddingCapsule.Visible = false end
			if waitingPill then
				waitingPill.Visible = true
				waitingPill.Text = "Waiting for other players to bid..."
			end
		end

	else
		-- Revealing, RoundEnd, Lobby: Hide all bidding controls
		if startBidPill then startBidPill.Visible = false end
		if biddingCapsule then biddingCapsule.Visible = false end
		if waitingPill then waitingPill.Visible = false end
	end
end

function ActionBar.SetSelectedCard(_cardType: string)
	-- No-op: cards are placed directly upon click
end

return ActionBar
