--!strict
-- LoadingScreen.client.luau  (ReplicatedFirst)
-- Runs before anything else on the client. Replaces Roblox's default loading screen
-- with a themed one that stays up until the scene is actually ready, so the player
-- never sees the table, art or avatar pop in:
--   1. the game's assets have replicated   (game.Loaded)
--   2. the server has built the table      (workspace attribute "TableReady")
--   3. card art + sounds are preloaded     (player attribute "ClientReady", set by init.client)
--   4. your avatar has spawned
-- Every step has a timeout, so a slow or failed step never leaves anyone stuck here.
-- Colours, fonts and images mirror Shared/Theme (it may not have replicated yet when this
-- runs). The logo is preloaded first and replaces the text title once it's ready.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BACKING = Color3.fromRGB(16, 11, 9)
local GOLD = Color3.fromRGB(230, 180, 50)
local TEXT_GOLD = Color3.fromRGB(245, 200, 70)
local TEXT_SECONDARY = Color3.fromRGB(215, 204, 194)
local TRACK = Color3.fromRGB(60, 42, 34)
local GLOW = Color3.fromRGB(120, 32, 44) -- dark rose glow behind the logo, as in the artwork
-- Same images as Theme.Images.Logo / Theme.Images.Glow (Theme may not be here yet)
local LOGO = "rbxassetid://114645623357001"
local GLOW_IMAGE = "rbxassetid://93681719710337"

local MAX_SECONDS = 25 -- hard cap on the whole screen
local MIN_SECONDS = 1 -- avoid a one-frame flash on fast loads

-- ── UI ───────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = BACKING
background.BorderSizePixel = 0
background.Parent = gui

-- A soft dark-rose glow in the middle of the dark screen, and the logo over it
local glow = Instance.new("ImageLabel")
glow.Name = "Glow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.42)
glow.Size = UDim2.fromOffset(1100, 800)
glow.BackgroundTransparency = 1
glow.Image = GLOW_IMAGE
glow.ImageColor3 = GLOW
glow.ImageTransparency = 0.25
glow.Parent = background

-- Shows the text title until the logo image has loaded (a slow connection, Studio offline)
local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.36)
title.Size = UDim2.new(1, -32, 0, 60)
title.BackgroundTransparency = 1
title.Font = Enum.Font.FredokaOne
title.TextSize = 52
title.TextColor3 = TEXT_GOLD
title.Text = "SKULLS & ROSES"
title.Parent = background

local logo = Instance.new("ImageLabel")
logo.Name = "Logo"
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.36)
logo.Size = UDim2.fromOffset(460, 310) -- the art is 1024 x 690
logo.BackgroundTransparency = 1
logo.Image = LOGO
logo.ImageTransparency = 1
logo.Parent = background
local logoScale = Instance.new("UIScale")
logoScale.Parent = logo

local status = Instance.new("TextLabel")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0.36, 175)
status.Size = UDim2.new(1, -32, 0, 22)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 16
status.TextColor3 = TEXT_SECONDARY
status.Text = "Loading..."
status.Parent = background

local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0.36, 207)
track.Size = UDim2.fromOffset(260, 6)
track.BackgroundColor3 = TRACK
track.BorderSizePixel = 0
track.Parent = background
Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = GOLD
fill.BorderSizePixel = 0
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

gui.Parent = playerGui

-- Load the logo first (it's small), then swap it in for the text title with a little pop
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync({ logo, glow })
	end)
	-- The preload can report a failure and still finish loading later, so wait on the
	-- image itself (for as long as this screen is up)
	while not logo.IsLoaded and gui.Parent do
		task.wait(0.1)
	end
	if not gui.Parent then
		return -- never loaded: the text title stayed up
	end
	title.Visible = false
	logoScale.Scale = 0.9
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(logo, info, { ImageTransparency = 0 }):Play()
	TweenService:Create(logoScale, info, { Scale = 1 }):Play()
end)

-- ── Steps ────────────────────────────────────────────────────────────────────
local started = os.clock()

local function timeLeft(): number
	return MAX_SECONDS - (os.clock() - started)
end

-- Poll until `ready()` is true or the step / overall timeout runs out
local function waitFor(ready: () -> boolean, timeout: number)
	local deadline = os.clock() + math.min(timeout, math.max(0, timeLeft()))
	while not ready() and os.clock() < deadline do
		task.wait(0.1)
	end
end

type Step = { text: string, timeout: number, ready: () -> boolean }
local steps: { Step } = {
	{
		text = "Loading the world...",
		timeout = 15,
		ready = function()
			return game:IsLoaded()
		end,
	},
	{
		text = "Setting the table...",
		timeout = 10,
		ready = function()
			return workspace:GetAttribute("TableReady") == true
		end,
	},
	{
		text = "Shuffling the cards...",
		timeout = 12,
		ready = function()
			return player:GetAttribute("ClientReady") == true
		end,
	},
	{
		text = "Finding your seat...",
		timeout = 8,
		ready = function()
			local character = player.Character
			return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
		end,
	},
}

for i, step in ipairs(steps) do
	status.Text = step.text
	waitFor(step.ready, step.timeout)
	TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(i / #steps, 1) }):Play()
end

-- Let the camera settle on your seat, then fade out
task.wait(math.max(0.3, MIN_SECONDS - (os.clock() - started)))
status.Text = "Ready!"

local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(background, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(logo, fadeInfo, { ImageTransparency = 1 }):Play()
TweenService:Create(glow, fadeInfo, { ImageTransparency = 1 }):Play()
TweenService:Create(status, fadeInfo, { TextTransparency = 1 }):Play()
TweenService:Create(track, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, fadeInfo, { BackgroundTransparency = 1 }):Play()
task.wait(0.55)
gui:Destroy()
