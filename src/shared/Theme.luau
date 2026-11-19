--!strict
-- Theme.luau
-- Design system and styling tokens for Skulls & Roses (Theme A: Calavera / Day of the Dead).
-- Shared so server-built 3D labels (name tags, pile counters) match the screen UI.

local Theme = {}

-- ============================================================================
-- 1. COLOR PALETTE (Warm wood, gold filigree, marigold amber, crimson velvet)
-- ============================================================================
Theme.Colors = {
	-- Background & Table
	TableDark = Color3.fromRGB(24, 14, 10),         -- Deep dark mahogany table
	TableSurface = Color3.fromRGB(38, 22, 16),      -- Table center felt/wood
	TableBorder = Color3.fromRGB(74, 44, 30),       -- Wooden rim border

	-- Metallic Accents (Gold filigree)
	Gold = Color3.fromRGB(230, 180, 50),            -- Vibrant ornate gold
	GoldMuted = Color3.fromRGB(160, 125, 40),       -- Subdued gold outline
	GoldGlow = Color3.fromRGB(255, 215, 80),        -- Highlight pulse

	-- Card Colors
	RosePrimary = Color3.fromRGB(190, 30, 45),      -- Deep floral crimson
	RoseAccent = Color3.fromRGB(245, 90, 110),      -- Bright petal highlight
	SkullPrimary = Color3.fromRGB(30, 25, 28),      -- Obsidian charcoal skull base
	SkullAccent = Color3.fromRGB(235, 60, 60),      -- Dangerous crimson eye glow
	CardBack = Color3.fromRGB(45, 28, 20),          -- Ornate coaster back
	CardBorder = Color3.fromRGB(200, 150, 40),      -- Coaster border rim

	-- UI Surfaces & Containers
	PanelBackground = Color3.fromRGB(22, 16, 14),   -- Card trays, action bars
	PanelBorder = Color3.fromRGB(60, 42, 34),       -- Panel stroke
	TextPrimary = Color3.fromRGB(250, 245, 240),    -- Crisp warm white
	TextSecondary = Color3.fromRGB(215, 204, 194),  -- Light beige (readable on dark panels)
	TextMuted = Color3.fromRGB(184, 172, 162),      -- Muted beige, still >= 4.5:1 on panels
	TextGold = Color3.fromRGB(245, 200, 70),        -- Golden highlighted text

	-- Status & Turn Accents
	ActiveTurnGlow = Color3.fromRGB(255, 185, 30),  -- Glowing active player pod
	SuccessGreen = Color3.fromRGB(60, 190, 90),     -- Score checkmark
	WarningAmber = Color3.fromRGB(240, 140, 20),    -- High bid warning
	AlertRed = Color3.fromRGB(225, 45, 45),         -- Skull reveal alert
	TimerBar = Color3.fromRGB(235, 175, 40),        -- Countdown bar

	-- Readability
	TextOutline = Color3.fromRGB(12, 8, 6),         -- Stroke behind text drawn over the 3D scene
	Backing = Color3.fromRGB(16, 11, 9),            -- Dark pill behind floating labels
}

-- ============================================================================
-- 2. TYPOGRAPHY & SIZING
-- ============================================================================
Theme.Fonts = {
	Title = Enum.Font.FredokaOne,                   -- Bold, friendly display font
	Header = Enum.Font.GothamBold,                  -- Clean modern bold headers
	Body = Enum.Font.GothamMedium,                  -- Readable standard text
	Sub = Enum.Font.GothamMedium,                   -- Fine details (regular Gotham is too thin when small)
}

-- Text sizes. Nothing on screen goes below Min.
Theme.TextSize = {
	Min = 14,
	Small = 14,
	Body = 16,
	Label = 18,
	Heading = 22,
	Title = 28,
	Display = 34,
}

-- Give text a dark outline so it stays readable over the 3D table
function Theme.Outline(label: Instance, strength: number?)
	if label:IsA("TextLabel") or label:IsA("TextButton") then
		local text = label :: any -- both have the TextStroke* properties
		text.TextStrokeColor3 = Theme.Colors.TextOutline
		text.TextStrokeTransparency = 1 - (strength or 0.75)
	end
end

Theme.CornerRadius = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 16),
	Circular = UDim.new(1, 0),                      -- Perfect circle for cards & coasters
}

-- Uploaded UI images (sources in "Artwork assets/UI"). Icons are white on transparent,
-- so ImageColor3 tints them.
Theme.Images = {
	Logo = "rbxassetid://114645623357001",          -- title logo, cut out on transparent (1024 x 690)
	Glow = "rbxassetid://93681719710337",           -- soft round white glow (tinted), behind the loading logo
	IconSettings = "rbxassetid://77065799955205",   -- cogwheel (opens the corner options)
	IconClose = "rbxassetid://94659965491952",      -- X (closes them)
	IconLeave = "rbxassetid://129890911249185",     -- door with an arrow out
	IconLook = "rbxassetid://76378751033424",       -- t-shirt (character look)
	IconPiles = "rbxassetid://114676544442331",     -- stack of round cards
}

return table.freeze(Theme)

