--!strict
-- ActionBar.luau
-- Bottom-right action panel. Only visible on your turn, and only shows what you can
-- do right now:
--   Placement : hint, plus a bid stepper + "BID N" once bidding is allowed
--   Bidding   : bid stepper + "RAISE TO N", and "PASS"
--   Challenge : "FLIP MY PILE" while you have cards there, then "tap a pile" + "FLIP ANY PILE"
-- Everything else (whose turn, timers, bids) lives in StatusBar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Enums)
local Theme = require(ReplicatedStorage.Shared.Theme)
local UIKit = require(script.Parent.UIKit)

local ActionBar = {}

type ActionCallback = (action: string, data: any) -> ()

local root: Frame? = nil
local hintLabel: TextLabel? = nil
local stepperRow: Frame? = nil
local bidValue: TextLabel? = nil
local primaryButton: TextButton? = nil
local secondaryButton: TextButton? = nil
local onAction: ActionCallback? = nil

-- Current context, set by UpdateState
local currentBid = 1
local minBid = 1
local maxBid = 1
local primaryAction: string? = nil
local primaryData: (() -> any)? = nil

local PANEL_WIDTH = 270

local function makeStepButton(parent: Instance, name: string, order: number, text: string): TextButton
	local button = UIKit.Button(parent, { name = name, text = text, kind = "secondary", order = order, width = UDim.new(0, 44) })
	button.TextSize = Theme.TextSize.Heading
	return button
end

local function refreshBidText()
	if bidValue then
		bidValue.Text = tostring(currentBid)
	end
	if primaryButton and (primaryAction == Enums.PlayerAction.StartBid or primaryAction == Enums.PlayerAction.RaiseBid) then
		primaryButton.Text = if primaryAction == Enums.PlayerAction.StartBid
			then "BID " .. currentBid
			else "RAISE TO " .. currentBid
	end
end

function ActionBar.Create(parent: Instance, callback: ActionCallback): Frame
	onAction = callback

	-- Same panel style as the pop-ups, docked bottom-right
	local panel = UIKit.Panel(parent, { name = "ActionBarRoot", width = PANEL_WIDTH, zIndex = 30, padding = 12, gap = 8 })
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -16, 1, -16)

	local hint = UIKit.Label(panel, { name = "Hint", style = "heading", order = 1 })

	-- Bid stepper:  [-]  N  [+]
	local row = UIKit.Row(panel, 2, UIKit.ButtonHeight, 14)
	row.Name = "BidStepper"

	local minus = makeStepButton(row, "Minus", 1, "−")
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.LayoutOrder = 2
	value.Size = UDim2.fromOffset(60, 44)
	value.BackgroundTransparency = 1
	value.Font = Theme.Fonts.Title
	value.TextSize = Theme.TextSize.Title
	value.TextColor3 = Theme.Colors.TextGold
	value.Text = "1"
	value.Parent = row
	local plus = makeStepButton(row, "Plus", 3, "+")

	minus.Activated:Connect(function()
		if currentBid > minBid then
			currentBid -= 1
			refreshBidText()
		end
	end)
	plus.Activated:Connect(function()
		if currentBid < maxBid then
			currentBid += 1
			refreshBidText()
		end
	end)

	local primary = UIKit.Button(panel, { name = "Primary", kind = "primary", order = 3 })
	primary.Activated:Connect(function()
		if onAction and primaryAction then
			onAction(primaryAction, if primaryData then primaryData() else {})
		end
	end)

	local secondary = UIKit.Button(panel, { name = "Pass", text = "PASS", kind = "secondary", order = 4 })
	secondary.Activated:Connect(function()
		if onAction then
			onAction(Enums.PlayerAction.Pass, {})
		end
	end)

	root = panel
	hintLabel = hint
	stepperRow = row
	bidValue = value
	primaryButton = primary
	secondaryButton = secondary
	return panel
end

-- Last context the stepper was set up for, so a re-sync mid-turn keeps the player's choice
local lastStepperKey = ""

function ActionBar.UpdateState(
	isMyTurn: boolean,
	gameState: string,
	highestBid: number,
	totalCards: number,
	hasCardsInHand: boolean,
	hasCardsInStack: boolean,
	canStartBid: boolean?
)
	local panel, hint, row, primary, secondary = root, hintLabel, stepperRow, primaryButton, secondaryButton
	if not panel or not hint or not row or not primary or not secondary then
		return
	end

	primaryAction, primaryData = nil, nil
	if not isMyTurn then
		panel.Visible = false
		return
	end

	local showStepper, showPrimary, showPass = false, false, false
	local bidData = function()
		return { bid = currentBid }
	end

	if gameState == Enums.GameState.Placement then
		if canStartBid and totalCards > 0 then
			hint.Text = if hasCardsInHand
				then "Place a card from your hand, or start the bidding"
				else "No cards left in hand: start the bidding"
			minBid, maxBid = 1, totalCards
			showStepper, showPrimary = true, true
			primaryAction, primaryData = Enums.PlayerAction.StartBid, bidData
		else
			hint.Text = "Place a card from your hand"
		end
	elseif gameState == Enums.GameState.Bidding then
		if highestBid < totalCards then
			hint.Text = "Raise the bid, or pass"
			minBid, maxBid = highestBid + 1, totalCards
			showStepper, showPrimary = true, true
			primaryAction, primaryData = Enums.PlayerAction.RaiseBid, bidData
		else
			hint.Text = "The bid can't go higher"
		end
		showPass = true
	elseif gameState == Enums.GameState.Revealing then
		showPrimary = true
		primaryAction = Enums.PlayerAction.RevealCard
		if hasCardsInStack then
			hint.Text = "Flip your own pile first"
			primary.Text = "FLIP MY PILE"
			primaryData = function()
				return { targetUserId = Players.LocalPlayer.UserId }
			end
		else
			hint.Text = "Tap a pile on the table to flip it"
			primary.Text = "FLIP ANY PILE"
			primaryData = function()
				return {} -- the server picks an opponent's pile
			end
		end
	else
		panel.Visible = false
		return
	end

	if showStepper then
		-- New turn / new bid range: start at the smallest legal bid; otherwise keep the choice
		local key = gameState .. ":" .. minBid .. ":" .. maxBid
		if key ~= lastStepperKey then
			currentBid = minBid
			lastStepperKey = key
		end
		currentBid = math.clamp(currentBid, minBid, maxBid)
		refreshBidText()
	else
		lastStepperKey = ""
	end
	row.Visible = showStepper
	primary.Visible = showPrimary
	secondary.Visible = showPass
	if not panel.Visible then
		UIKit.Pop(panel, true)
	end
end

return ActionBar
