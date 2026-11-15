--!strict
-- LobbyPanel.luau
-- Pre-match lobby screen: seat list with ready status, the local player's READY toggle,
-- and host controls (bots on/off, force start). Rendered from the server's LobbyState.

local Theme = require(script.Parent.Theme)

local LobbyPanel = {}

export type LobbySeat = { userId: number, name: string, seatIndex: number, ready: boolean, isHost: boolean }
export type LobbyState = {
	inLobby: boolean,
	hostId: number?,
	addBots: boolean,
	botsAllowed: boolean,
	seats: { LobbySeat },
	maxSeats: number,
	waitingCount: number,
	countdown: number?,
	canStart: boolean,
}

local root: Frame? = nil
local statusLabel: TextLabel? = nil
local rows: { TextLabel } = {}
local footerLabel: TextLabel? = nil
local readyButton: TextButton? = nil
local botsButton: TextButton? = nil
local startButton: TextButton? = nil

local function makeButton(parent: Instance, name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1 / 3, -6, 0, 40) -- three per row, shrinks on narrow screens
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Font = Theme.Fonts.Title
	button.TextSize = 16
	button.TextColor3 = Theme.Colors.TextPrimary
	button.Text = text
	button.ZIndex = 72
	button.Parent = parent
	Instance.new("UICorner", button).CornerRadius = Theme.CornerRadius.Circular
	return button
end

function LobbyPanel.Create(parent: Instance, onAction: (action: string, value: any) -> ())
	local frame = Instance.new("Frame")
	frame.Name = "LobbyPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.new(1, -32, 0, 360)
	frame.BackgroundColor3 = Theme.Colors.PanelBackground
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 70
	frame.Parent = parent
	Instance.new("UICorner", frame).CornerRadius = Theme.CornerRadius.Large

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(420, 360)
	sizeLimit.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Gold
	stroke.Thickness = 2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 14)
	title.Size = UDim2.new(1, 0, 0, 34)
	title.Font = Theme.Fonts.Title
	title.TextSize = 30
	title.TextColor3 = Theme.Colors.TextGold
	title.Text = "SKULLS & ROSES"
	title.ZIndex = 71
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(16, 50)
	status.Size = UDim2.new(1, -32, 0, 22)
	status.Font = Theme.Fonts.Body
	status.TextSize = 15
	status.TextWrapped = true
	status.TextColor3 = Theme.Colors.TextSecondary
	status.Text = ""
	status.ZIndex = 71
	status.Parent = frame

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(20, 82)
	list.Size = UDim2.new(1, -40, 0, 4 * 38)
	list.ZIndex = 71
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for i = 1, 4 do
		local row = Instance.new("TextLabel")
		row.Name = "Seat" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = Theme.Colors.TableSurface
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Font = Theme.Fonts.Header
		row.TextSize = 15
		row.RichText = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Theme.Colors.TextPrimary
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.Text = ""
		row.ZIndex = 72
		row.Parent = list
		Instance.new("UICorner", row).CornerRadius = Theme.CornerRadius.Small
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = row
		rows[i] = row
	end

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.fromOffset(16, 82 + 4 * 38 + 4)
	footer.Size = UDim2.new(1, -32, 0, 20)
	footer.Font = Theme.Fonts.Sub
	footer.TextSize = 13
	footer.TextColor3 = Theme.Colors.TextMuted
	footer.Text = ""
	footer.ZIndex = 71
	footer.Parent = frame

	local buttons = Instance.new("Frame")
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.new(0.5, 0, 1, -16)
	buttons.Size = UDim2.new(1, -24, 0, 40)
	buttons.ZIndex = 71
	buttons.Parent = frame
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Padding = UDim.new(0, 8)
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Parent = buttons

	local readyBtn = makeButton(buttons, "ReadyButton", "READY", Theme.Colors.SuccessGreen)
	readyBtn.LayoutOrder = 1
	readyBtn.Activated:Connect(function()
		onAction("ToggleReady", nil)
	end)

	local botsBtn = makeButton(buttons, "BotsButton", "BOTS: ON", Theme.Colors.PanelBorder)
	botsBtn.LayoutOrder = 2
	botsBtn.Activated:Connect(function()
		onAction("SetAddBots", botsBtn:GetAttribute("NextValue") == true)
	end)

	local startBtn = makeButton(buttons, "StartButton", "START", Theme.Colors.WarningAmber)
	startBtn.LayoutOrder = 3
	startBtn.Activated:Connect(function()
		onAction("Start", nil)
	end)

	root = frame
	statusLabel = status
	footerLabel = footer
	readyButton = readyBtn
	botsButton = botsBtn
	startButton = startBtn
end

function LobbyPanel.Update(state: LobbyState, localUserId: number)
	local frame, status, footer = root, statusLabel, footerLabel
	local readyBtn, botsBtn, startBtn = readyButton, botsButton, startButton
	if not frame or not status or not footer or not readyBtn or not botsBtn or not startBtn then
		return
	end

	frame.Visible = state.inLobby
	if not state.inLobby then
		return
	end

	local me: LobbySeat? = nil
	local bySeat: { [number]: LobbySeat } = {}
	for _, seat in ipairs(state.seats) do
		bySeat[seat.seatIndex] = seat
		if seat.userId == localUserId then
			me = seat
		end
	end
	local isHost = state.hostId == localUserId

	-- Status line
	if state.countdown then
		status.Text = "Starting in " .. state.countdown .. "..."
		status.TextColor3 = Theme.Colors.TextGold
	elseif not me then
		status.Text = "The table is full. You'll get a seat when one opens."
		status.TextColor3 = Theme.Colors.TextSecondary
	elseif not state.canStart then
		status.Text = "Need at least 2 players. Invite a friend or turn bots on."
		status.TextColor3 = Theme.Colors.TextSecondary
	else
		status.Text = "Ready up! The match starts when everyone is ready."
		status.TextColor3 = Theme.Colors.TextSecondary
	end

	-- Seat rows
	for i, row in ipairs(rows) do
		row.Visible = i <= state.maxSeats
		local seat = bySeat[i]
		if seat then
			local tags = ""
			if seat.isHost then
				tags ..= ` <font color="#FFD23F">HOST</font>`
			end
			if seat.userId == localUserId then
				tags ..= ` <font color="#8C8278">(you)</font>`
			end
			local readyText = if seat.ready
				then `<font color="#3CBE5A">READY</font>`
				else `<font color="#8C8278">not ready</font>`
			row.Text = `{seat.name}{tags}  ·  {readyText}`
			row.BackgroundTransparency = 0.2
		elseif state.addBots then
			row.Text = `<font color="#8C8278">Open seat: a bot will play</font>`
			row.BackgroundTransparency = 0.6
		else
			row.Text = `<font color="#8C8278">Open seat</font>`
			row.BackgroundTransparency = 0.6
		end
	end

	footer.Text = if state.waitingCount > 0 then (state.waitingCount .. " waiting for a seat") else ""

	-- Buttons
	readyBtn.Visible = me ~= nil
	if me then
		readyBtn.Text = if me.ready then "UNREADY" else "READY"
		readyBtn.BackgroundColor3 = if me.ready then Theme.Colors.PanelBorder else Theme.Colors.SuccessGreen
	end

	botsBtn.Visible = isHost and state.botsAllowed
	botsBtn.Text = if state.addBots then "BOTS: ON" else "BOTS: OFF"
	botsBtn:SetAttribute("NextValue", not state.addBots)

	startBtn.Visible = isHost
	startBtn.Active = state.canStart
	startBtn.AutoButtonColor = state.canStart
	startBtn.BackgroundTransparency = if state.canStart then 0 else 0.6
end

function LobbyPanel.IsVisible(): boolean
	return root ~= nil and root.Visible
end

return LobbyPanel
