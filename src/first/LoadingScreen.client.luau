--!strict
-- LoadingScreen.client.luau  (ReplicatedFirst)
-- Runs before anything else on the client. Replaces Roblox's default loading screen
-- with a themed one that stays up until the scene is actually ready, so nothing pops in:
--   1. the game's instances have replicated          (game.Loaded)
--   2. the server has set up the tables              (workspace attribute "TableReady")
--   3. the tavern's meshes and textures are loaded   (ContentProvider:PreloadAsync on
--      Workspace.World and Lighting, a few at a time; the bar follows the real count)
--   4. card art + sounds are loaded                  (player attribute "ClientReady", set
--      by init.client once every card image reports IsLoaded)
--   5. your avatar has spawned
--   6. a short settle, still covered, so the lighting and shadows have built up
-- Every step has a timeout and the whole screen a hard cap, so nobody is ever stuck here.
-- A dim "Skip" button (bottom right, after a moment) lets impatient players in at once;
-- loading carries on behind the game. Tips about the rules rotate under the bar.
-- Colours, fonts and images mirror Shared/Theme (it may not have replicated yet when this
-- runs). The logo is preloaded first and replaces the text title once it's ready.

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
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
local TEXT_MUTED = Color3.fromRGB(184, 172, 162)
local TRACK = Color3.fromRGB(60, 42, 34)
local GLOW = Color3.fromRGB(120, 32, 44) -- dark rose glow behind the logo, as in the artwork
-- Same images as Theme.Images.Logo / Theme.Images.Glow (Theme may not be here yet)
local LOGO = "rbxassetid://114645623357001"
local GLOW_IMAGE = "rbxassetid://93681719710337"

local MAX_SECONDS = 40 -- hard cap on the whole screen
local MIN_SECONDS = 2.5 -- long enough to see the logo, even on a fast load
local SETTLE_SECONDS = 1.5 -- lighting and shadows build up behind the cover
local SKIP_AFTER = 1.5 -- the Skip button fades in after this
local TIP_SECONDS = 4.5

local TIPS = {
	"Bid on how many cards you can flip without hitting a skull.",
	"Win a challenge to score a point. Two points wins the match.",
	"The challenger flips their own pile first, so a skull at home can sink you.",
	"Face down, a rose and a skull look the same. Bluff away.",
	"Hit a skull and you lose a card. Lose them all and you're out.",
	"Once the first bid is made, nobody can place more cards this round.",
	"Bid the most cards on the table and bidding ends at once.",
}

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
track.Size = UDim2.fromOffset(320, 6)
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

local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.AnchorPoint = Vector2.new(0.5, 0)
tip.Position = UDim2.new(0.5, 0, 0.36, 236)
tip.Size = UDim2.new(1, -64, 0, 40)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.Gotham
tip.TextSize = 15
tip.TextWrapped = true
tip.TextColor3 = TEXT_MUTED
tip.Text = ""
tip.Parent = background

-- Skip: small and dim in the bottom-right corner, fades in after a moment
local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -20, 1, -20)
skip.Size = UDim2.fromOffset(84, 30)
skip.BackgroundColor3 = TRACK
skip.BackgroundTransparency = 1
skip.BorderSizePixel = 0
skip.AutoButtonColor = true
skip.Font = Enum.Font.GothamMedium
skip.TextSize = 15
skip.TextColor3 = TEXT_SECONDARY
skip.TextTransparency = 1
skip.Text = "Skip  ›"
skip.Visible = false
skip.Parent = background
Instance.new("UICorner", skip).CornerRadius = UDim.new(1, 0)

gui.Parent = playerGui

-- ── State ────────────────────────────────────────────────────────────────────
local started = os.clock()
local skipped = false
local finished = false

local function timeLeft(): number
	return MAX_SECONDS - (os.clock() - started)
end

local function stillLoading(): boolean
	return not skipped and timeLeft() > 0
end

-- The bar: each step owns a slice of it; `setProgress(step, 0..1)` moves within the slice
local SLICES = {
	{ text = "Opening the tavern...", weight = 0.1 }, -- game.Loaded
	{ text = "Setting the tables...", weight = 0.05 }, -- TableReady
	{ text = "Lighting the candles...", weight = 0.5 }, -- world meshes and textures
	{ text = "Shuffling the cards...", weight = 0.2 }, -- card art and sounds
	{ text = "Finding your seat...", weight = 0.05 }, -- avatar
	{ text = "Pulling up a chair...", weight = 0.1 }, -- settle
}
local shown = 0
local function setProgress(step: number, within: number)
	local before = 0
	for i = 1, step - 1 do
		before += SLICES[i].weight
	end
	local value = before + SLICES[step].weight * math.clamp(within, 0, 1)
	if value <= shown then
		return
	end
	shown = value
	TweenService:Create(fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(value, 1) }):Play()
end

-- Poll until `ready()` is true, the step's timeout runs out, or the player skips
local function waitFor(ready: () -> boolean, timeout: number)
	local deadline = os.clock() + timeout
	while not ready() and os.clock() < deadline and stillLoading() do
		task.wait(0.1)
	end
end

-- ── Logo, tips, skip ─────────────────────────────────────────────────────────
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

-- Tips: a random one first, then the next every few seconds, cross-faded
task.spawn(function()
	local index = math.random(1, #TIPS)
	while gui.Parent and not finished do
		tip.Text = "Tip: " .. TIPS[index]
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		task.wait(TIP_SECONDS)
		if not gui.Parent or finished then
			break
		end
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		task.wait(0.3)
		index = index % #TIPS + 1
	end
end)

task.delay(SKIP_AFTER, function()
	if finished or not gui.Parent then
		return
	end
	skip.Visible = true
	local info = TweenInfo.new(0.4)
	TweenService:Create(skip, info, { BackgroundTransparency = 0.35, TextTransparency = 0.15 }):Play()
end)

skip.Activated:Connect(function()
	skipped = true
end)

-- ── Steps ────────────────────────────────────────────────────────────────────
local function step(i: number)
	status.Text = SLICES[i].text
	setProgress(i, 0)
end

-- 1. Instances replicated
step(1)
waitFor(function()
	return game:IsLoaded()
end, 20)
setProgress(1, 1)

-- 2. Tables set up by the server
step(2)
waitFor(function()
	return workspace:GetAttribute("TableReady") == true
end, 10)
setProgress(2, 1)

-- 3. The tavern's meshes, textures and decals, a few at a time so the bar moves
step(3)
if stillLoading() then
	local content: { Instance } = {}
	local roots: { Instance } = { Lighting }
	local world = workspace:FindFirstChild("World")
	if world then
		table.insert(roots, world)
	end
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if
				d:IsA("MeshPart")
				or d:IsA("SpecialMesh")
				or d:IsA("Decal") -- includes Texture
				or d:IsA("SurfaceAppearance")
				or d:IsA("Sky")
				or d:IsA("ParticleEmitter")
			then
				table.insert(content, d)
			end
		end
	end
	local CHUNK = 12
	local total = #content
	local index = 1
	while index <= total and stillLoading() do
		local chunk = table.move(content, index, math.min(index + CHUNK - 1, total), 1, {})
		pcall(function()
			ContentProvider:PreloadAsync(chunk)
		end)
		index += CHUNK
		setProgress(3, (index - 1) / total)
	end
end
setProgress(3, 1)

-- 4. Card art and sounds (init.client sets ClientReady once every card image has loaded)
step(4)
waitFor(function()
	return player:GetAttribute("ClientReady") == true
end, 15)
setProgress(4, 1)

-- 5. Avatar spawned
step(5)
waitFor(function()
	local character = player.Character
	return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
end, 10)
setProgress(5, 1)

-- 6. Let the lighting and shadows build up behind the cover (and show the logo a moment
-- on very fast loads)
step(6)
local settleUntil = math.max(os.clock() + SETTLE_SECONDS, started + MIN_SECONDS)
while os.clock() < settleUntil and not skipped do
	setProgress(6, 1 - (settleUntil - os.clock()) / SETTLE_SECONDS)
	task.wait(0.05)
end
setProgress(6, 1)
status.Text = "Ready!"
finished = true

-- ── Fade out ─────────────────────────────────────────────────────────────────
local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(background, fadeInfo, { BackgroundTransparency = 1 }):Play()
for _, label in ipairs({ title, status, tip }) do
	TweenService:Create(label, fadeInfo, { TextTransparency = 1 }):Play()
end
TweenService:Create(logo, fadeInfo, { ImageTransparency = 1 }):Play()
TweenService:Create(glow, fadeInfo, { ImageTransparency = 1 }):Play()
TweenService:Create(track, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(skip, fadeInfo, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
task.wait(0.55)
gui:Destroy()
