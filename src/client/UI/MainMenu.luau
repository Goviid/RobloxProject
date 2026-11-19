--!strict
-- MainMenu.luau
-- What players see when they enter: the title and a PLAY button, then the table picker
-- (each table with its seats taken and whether a match is running). Picking a table
-- sends JoinTable; the menu closes when the server confirms by setting the player's
-- "TableId" attribute. Built on UIKit, over a slow camera orbit of table 1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)
local Theme = require(ReplicatedStorage.Shared.Theme)
local UIKit = require(script.Parent.UIKit)

local MainMenu = {}

type TableInfo = { id: number, name: string, seated: number, maxPlayers: number, inMatch: boolean }

local localPlayer = Players.LocalPlayer

-- One row in the picker: name and status on the left, JOIN on the right
local function tableCard(parent: Instance, order: number, onJoin: () -> ()): (TextLabel, TextLabel, TextButton)
	local card = Instance.new("Frame")
	card.Name = "TableCard" .. order
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, 76)
	card.BackgroundColor3 = Theme.Colors.PanelBackground
	card.BorderSizePixel = 0
	card.Parent = parent
	Instance.new("UICorner", card).CornerRadius = Theme.CornerRadius.Medium
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Colors.PanelBorder
	stroke.Thickness = 1.5
	stroke.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, -130, 0, 26)
	title.Font = Theme.Fonts.Title
	title.TextSize = Theme.TextSize.Heading
	title.TextColor3 = Theme.Colors.TextGold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(0, 40)
	status.Size = UDim2.new(1, -130, 0, 22)
	status.Font = Theme.Fonts.Body
	status.TextSize = Theme.TextSize.Body
	status.TextColor3 = Theme.Colors.TextSecondary
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Parent = card

	local join = UIKit.Button(card, { name = "Join", text = "JOIN", kind = "success", width = UDim.new(0, 110) })
	join.AnchorPoint = Vector2.new(1, 0.5)
	join.Position = UDim2.fromScale(1, 0.5)
	join.Activated:Connect(onJoin)
	return title, status, join
end

local function describe(info: TableInfo): string
	local seats = string.format("%d/%d seated", info.seated, info.maxPlayers)
	if info.inMatch then
		return seats .. " · match on, you'll watch"
	elseif info.seated >= info.maxPlayers then
		return seats .. " · full, you'll watch"
	end
	return seats .. " · waiting for players"
end

function MainMenu.Show(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Dim the table orbit behind the menu
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Theme.Colors.Backing
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.Parent = gui

	-- Page 1: title and PLAY
	-- No box here: the logo (cut out on transparent) floats over the dimmed tavern, with
	-- the tagline and PLAY under it
	local home = UIKit.Panel(gui, { name = "Home", width = 540, gap = 10, padding = 0 })
	home.BackgroundTransparency = 1
	local border = home:FindFirstChild("Border")
	if border then
		border:Destroy()
	end
	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.LayoutOrder = 1
	-- Fixed height: an aspect-ratio constraint collapses to nothing inside the auto-sized
	-- panel. 540 x 364 keeps the art's 1024 x 690 shape.
	logo.Size = UDim2.new(1, 0, 0, 364)
	logo.ScaleType = Enum.ScaleType.Fit
	logo.BackgroundTransparency = 1
	logo.Image = Theme.Images.Logo
	logo.Parent = home
	local tagline = UIKit.Label(home, { text = "Bluff, bid and flip. Don't hit a skull.", style = "body", order = 2 })
	Theme.Outline(tagline)
	local play = UIKit.Button(home, { name = "Play", text = "PLAY", kind = "primary", order = 3, height = 54, width = UDim.new(0, 260) })

	-- Page 2: pick a table
	local picker = UIKit.Panel(gui, { name = "Tables", width = 460, gap = 12, padding = 22 })
	UIKit.Label(picker, { text = "Pick a table", style = "title", order = 1 })
	local list = Instance.new("Frame")
	list.Name = "List"
	list.LayoutOrder = 2
	list.Size = UDim2.fromScale(1, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.Parent = picker
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	local hint = UIKit.Label(picker, { text = "Loading tables...", style = "muted", order = 3 })
	local back = UIKit.Button(picker, { name = "Back", text = "BACK", kind = "secondary", order = 4, height = 40 })

	-- How to play: a small, quiet "?" under BACK opens the rules
	local help = Instance.new("TextButton")
	help.Name = "HowToPlay"
	help.LayoutOrder = 5
	help.Size = UDim2.fromOffset(30, 30)
	help.BackgroundColor3 = Theme.Colors.Backing
	help.BackgroundTransparency = 0.2
	help.BorderSizePixel = 0
	help.AutoButtonColor = true
	help.Font = Theme.Fonts.Title
	help.TextSize = Theme.TextSize.Body
	help.TextColor3 = Theme.Colors.TextMuted
	help.Text = "?"
	help.Parent = picker
	Instance.new("UICorner", help).CornerRadius = Theme.CornerRadius.Circular
	local helpStroke = Instance.new("UIStroke")
	helpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	helpStroke.Color = Theme.Colors.PanelBorder
	helpStroke.Thickness = 1.5
	helpStroke.Parent = help

	-- Page 3: the rules, short
	local rules = UIKit.Panel(gui, { name = "Rules", width = 480, gap = 10, padding = 24 })
	UIKit.Label(rules, { text = "How to play", style = "title", order = 1 })
	local RULES = {
		"Everyone starts with 3 roses and 1 skull.",
		"Take turns placing a card face down on your pile. Once everyone has placed one, you can open the bidding instead.",
		"Bid how many cards you can flip without finding a skull. The others raise or pass.",
		"The highest bidder flips: their own pile first, then anyone's, one card at a time.",
		"Flip only roses and you score a point. Two points wins the match.",
		"Hit a skull and you lose a card for good. Lose them all and you're out.",
	}
	for i, line in ipairs(RULES) do
		local label = UIKit.Label(rules, { text = i .. ".  " .. line, style = "body", order = 1 + i })
		label.TextXAlignment = Enum.TextXAlignment.Left
	end
	local gotIt = UIKit.Button(rules, { name = "GotIt", text = "GOT IT", kind = "primary", order = 10, height = 44 })

	local cards: { [number]: { title: TextLabel, status: TextLabel, join: TextButton } } = {}
	local joining = false

	local function join(tableId: number)
		if joining then
			return
		end
		joining = true
		for _, card in pairs(cards) do
			UIKit.SetEnabled(card.join, false)
		end
		hint.Text = "Taking your seat..."
		Network.JoinTable:FireServer(tableId)
	end

	local function render(tables: { TableInfo })
		for _, info in ipairs(tables) do
			local card = cards[info.id]
			if not card then
				local title, status, joinButton = tableCard(list, info.id, function()
					join(info.id)
				end)
				card = { title = title, status = status, join = joinButton }
				cards[info.id] = card
			end
			card.title.Text = string.format("%s (%d Players)", info.name, info.maxPlayers)
			card.status.Text = describe(info)
			UIKit.SetEnabled(card.join, not joining)
		end
		if not joining then
			hint.Text = "Empty seats can be filled with bots."
		end
	end

	local listConnection = Network.TableList.OnClientEvent:Connect(render)

	play.Activated:Connect(function()
		UIKit.Pop(home, false, function()
			UIKit.Pop(picker, true)
		end)
		Network.RequestTables:FireServer()
	end)
	back.Activated:Connect(function()
		UIKit.Pop(picker, false, function()
			UIKit.Pop(home, true)
		end)
	end)
	help.Activated:Connect(function()
		UIKit.Pop(picker, false, function()
			UIKit.Pop(rules, true)
		end)
	end)
	gotIt.Activated:Connect(function()
		UIKit.Pop(rules, false, function()
			UIKit.Pop(picker, true)
		end)
	end)

	-- The server confirms the seat by setting TableId; then the game UI takes over
	local joinedConnection: RBXScriptConnection
	joinedConnection = localPlayer:GetAttributeChangedSignal("TableId"):Connect(function()
		if localPlayer:GetAttribute("TableId") == nil then
			return
		end
		joinedConnection:Disconnect()
		listConnection:Disconnect()
		UIKit.Pop(picker, false, function()
			gui:Destroy()
		end)
	end)

	UIKit.Pop(home, true)
end

return MainMenu
