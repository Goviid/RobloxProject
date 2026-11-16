--!strict
-- LobbyPanel.luau
-- Pre-match lobby screen: seat list with ready status, the local player's READY toggle,
-- and host controls (bots on/off, force start). Rendered from the server's LobbyState.
-- Built on UIKit.

local Theme = require(game:GetService("ReplicatedStorage").Shared.Theme)
local UIKit = require(script.Parent.UIKit)

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

local MAX_ROWS = 4
local ROW_HEIGHT = 34

-- Rich-text colours, taken from the theme
local GOLD = "#" .. Theme.Colors.TextGold:ToHex()
local GREEN = "#" .. Theme.Colors.SuccessGreen:ToHex()
local MUTED = "#" .. Theme.Colors.TextMuted:ToHex()

local root: Frame? = nil
local statusLabel: TextLabel? = nil
local rows: { TextLabel } = {}
local footerLabel: TextLabel? = nil
local readyButton: TextButton? = nil
local botsButton: TextButton? = nil
local startButton: TextButton? = nil
local isOpen = false

function LobbyPanel.Create(parent: Instance, onAction: (action: string, value: any) -> ())
	local frame = UIKit.Panel(parent, { name = "LobbyPanel", width = 440, zIndex = 70, padding = 20 })
	frame.Position = UDim2.fromScale(0.5, 0.5)

	UIKit.Label(frame, { name = "Title", style = "display", order = 1, text = "SKULLS & ROSES" })
	local status = UIKit.Label(frame, { name = "Status", style = "body", order = 2 })

	-- Seat list
	local list = Instance.new("Frame")
	list.Name = "Seats"
	list.LayoutOrder = 3
	list.Size = UDim2.fromScale(1, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.BackgroundTransparency = 1
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for i = 1, MAX_ROWS do
		local row = Instance.new("TextLabel")
		row.Name = "Seat" .. i
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundColor3 = Theme.Colors.TableSurface
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Font = Theme.Fonts.Header
		row.TextSize = Theme.TextSize.Body
		row.RichText = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Theme.Colors.TextPrimary
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.Text = ""
		row.Parent = list
		Instance.new("UICorner", row).CornerRadius = Theme.CornerRadius.Small
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = row
		rows[i] = row
	end

	local footer = UIKit.Label(frame, { name = "Footer", style = "muted", order = 4 })

	-- Buttons: three per row, shrinking on narrow screens
	local buttons = UIKit.Row(frame, 5, UIKit.ButtonHeight, 8)
	buttons.Name = "Buttons"
	local third = UDim.new(1 / 3, -6)

	local readyBtn = UIKit.Button(buttons, { name = "ReadyButton", text = "READY", kind = "success", order = 1, width = third })
	readyBtn.Activated:Connect(function()
		onAction("ToggleReady", nil)
	end)

	local botsBtn = UIKit.Button(buttons, { name = "BotsButton", text = "BOTS: ON", kind = "secondary", order = 2, width = third })
	botsBtn.Activated:Connect(function()
		onAction("SetAddBots", botsBtn:GetAttribute("NextValue") == true)
	end)

	local startBtn = UIKit.Button(buttons, { name = "StartButton", text = "START", kind = "primary", order = 3, width = third })
	startBtn.Activated:Connect(function()
		if startBtn.Active then
			onAction("Start", nil)
		end
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

	if state.inLobby ~= isOpen then
		isOpen = state.inLobby
		UIKit.Pop(frame, isOpen)
	end
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
				tags ..= ` <font color="{GOLD}">HOST</font>`
			end
			if seat.userId == localUserId then
				tags ..= ` <font color="{MUTED}">(you)</font>`
			end
			local readyText = if seat.ready
				then `<font color="{GREEN}">READY</font>`
				else `<font color="{MUTED}">not ready</font>`
			row.Text = `{seat.name}{tags}  ·  {readyText}`
			row.BackgroundTransparency = 0.2
		else
			local openText = if state.addBots then "Open seat: a bot will play" else "Open seat"
			row.Text = `<font color="{MUTED}">{openText}</font>`
			row.BackgroundTransparency = 0.6
		end
	end

	footer.Text = if state.waitingCount > 0 then (state.waitingCount .. " waiting for a seat") else ""
	footer.Visible = state.waitingCount > 0

	-- Buttons
	readyBtn.Visible = me ~= nil
	if me then
		readyBtn.Text = if me.ready then "UNREADY" else "READY"
		UIKit.SetButtonKind(readyBtn, if me.ready then "secondary" else "success")
	end

	botsBtn.Visible = isHost and state.botsAllowed
	botsBtn.Text = if state.addBots then "BOTS: ON" else "BOTS: OFF"
	botsBtn:SetAttribute("NextValue", not state.addBots)

	startBtn.Visible = isHost
	UIKit.SetEnabled(startBtn, state.canStart)
end

function LobbyPanel.IsVisible(): boolean
	return isOpen
end

return LobbyPanel
