--!strict
-- ChatBox.luau
-- Translucent Roblox-Style 2D Chat Box on Top-Left (Matching concept reference Image 4)

local TweenService = game:GetService("TweenService")

local ChatBox = {}

local rootFrame: Frame? = nil
local scrollFrame: ScrollingFrame? = nil

-- Initial bustling match chat lines matching Image 4
local INITIAL_MESSAGES = {
	{ sender = "asonuner_99", text = "u", color = "#50E1F5" },
	{ sender = "BLUFFER_99", text = "What's Skulls & Roses?", color = "#FFD23F" },
	{ sender = "Bsoninnal89", text = "no", color = "#50E1F5" },
	{ sender = "BLUFFER_99", text = "skulls & roses", color = "#FFD23F" },
	{ sender = "BLUFFER_99", text = "Change now rhat k place card!", color = "#FFD23F" },
	{ sender = "BLUFFER_99", text = "Bet", color = "#FFD23F" },
	{ sender = "BLUFFER_99", text = "snm", color = "#FFD23F" },
	{ sender = "BLUFFER_99", text = "PLACE CARD?", color = "#FFD23F" },
	{ sender = "BLUFFER_99", text = "yes", color = "#FFD23F" },
}

function ChatBox.Create(parent: GuiObject): Frame
	local box = Instance.new("Frame")
	box.Name = "RobloxChatBox"
	box.Size = UDim2.new(0, 310, 0, 195)
	box.Position = UDim2.new(0, 16, 0, 16) -- Top-left pinned matching reference
	box.BackgroundColor3 = Color3.fromRGB(12, 10, 18)
	box.BackgroundTransparency = 0.45 -- Translucent Roblox-style
	box.BorderSizePixel = 0
	box.ZIndex = 30
	box.Parent = parent
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 50, 75)
	stroke.Transparency = 0.55
	stroke.Thickness = 1.4
	stroke.Parent = box

	-- Message List Container (ScrollingFrame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "MessageScroll"
	scroll.Size = UDim2.new(1, -12, 1, -40)
	scroll.Position = UDim2.new(0, 6, 0, 6)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 110, 140)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 31
	scroll.Parent = box
	scrollFrame = scroll

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = scroll

	-- Bottom Chat Input Bar (Translucent glass with placeholder)
	local inputBar = Instance.new("Frame")
	inputBar.Name = "ChatInputBar"
	inputBar.Size = UDim2.new(1, -12, 0, 26)
	inputBar.Position = UDim2.new(0, 6, 1, -32)
	inputBar.BackgroundColor3 = Color3.fromRGB(24, 20, 32)
	inputBar.BackgroundTransparency = 0.35
	inputBar.BorderSizePixel = 0
	inputBar.ZIndex = 31
	inputBar.Parent = box
	Instance.new("UICorner", inputBar).CornerRadius = UDim.new(0, 6)

	local inputPlaceholder = Instance.new("TextLabel")
	inputPlaceholder.Name = "Placeholder"
	inputPlaceholder.Size = UDim2.new(1, -12, 1, 0)
	inputPlaceholder.Position = UDim2.new(0, 8, 0, 0)
	inputPlaceholder.BackgroundTransparency = 1
	inputPlaceholder.Font = Enum.Font.SourceSans
	inputPlaceholder.TextSize = 13
	inputPlaceholder.TextColor3 = Color3.fromRGB(160, 155, 175)
	inputPlaceholder.TextXAlignment = Enum.TextXAlignment.Left
	inputPlaceholder.Text = 'Tap here or chat or "/" to chat'
	inputPlaceholder.ZIndex = 32
	inputPlaceholder.Parent = inputBar

	-- Populate initial messages matching Image 4
	for idx, msg in ipairs(INITIAL_MESSAGES) do
		ChatBox.AddMessage(msg.sender, msg.text, msg.color, idx)
	end

	rootFrame = box
	return box
end

function ChatBox.AddMessage(sender: string, text: string, colorHex: string?, order: number?)
	if not scrollFrame then return end

	local color = colorHex or "#FFD23F"
	local msgLabel = Instance.new("TextLabel")
	msgLabel.Name = "ChatMsg_" .. sender
	msgLabel.Size = UDim2.new(1, 0, 0, 16)
	msgLabel.BackgroundTransparency = 1
	msgLabel.Font = Enum.Font.SourceSansBold
	msgLabel.TextSize = 13
	msgLabel.TextColor3 = Color3.fromRGB(240, 235, 245)
	msgLabel.TextXAlignment = Enum.TextXAlignment.Left
	msgLabel.RichText = true
	msgLabel.Text = `<font color="{color}">[{sender}]:</font> {text}`
	msgLabel.LayoutOrder = order or 100
	msgLabel.ZIndex = 32
	msgLabel.Parent = scrollFrame

	-- Auto scroll to bottom
	task.defer(function()
		if scrollFrame then
			scrollFrame.CanvasPosition = Vector2.new(0, 99999)
		end
	end)
end

return ChatBox