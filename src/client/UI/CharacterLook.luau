--!strict
-- CharacterLook.luau
-- Test switch between the two character looks ("Classic" calavera avatar and "Bean"),
-- a small dim pill in the top-right corner left of "Piles". It changes the look for
-- everyone at your table; the pill shows the table's current look (the arena's
-- "CharacterLook" attribute, set by the server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local Network = require(ReplicatedStorage.Shared.Network)
local TableView = require(script.Parent.Parent.TableView)

local CharacterLook = {}

local NAMES = { classic = "Classic", bean = "Bean" }

function CharacterLook.Create(parent: Instance)
	local pill = Instance.new("TextButton")
	pill.Name = "CharacterLookPill"
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -146, 0, 10) -- left of the Piles pill
	pill.Size = UDim2.fromOffset(100, 24)
	pill.BackgroundColor3 = Theme.Colors.Backing
	pill.BackgroundTransparency = 0.45
	pill.BorderSizePixel = 0
	pill.AutoButtonColor = true
	pill.Font = Theme.Fonts.Sub
	pill.TextSize = Theme.TextSize.Small
	pill.TextColor3 = Theme.Colors.TextMuted
	pill.TextTransparency = 0.2
	pill.ZIndex = 5
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = Theme.CornerRadius.Circular

	local function current(): string
		local arena = TableView.GetArena()
		local look = arena and arena:GetAttribute("CharacterLook")
		return if look == "bean" then "bean" else "classic"
	end

	local function refresh()
		pill.Text = "Look: " .. NAMES[current()]
	end

	local function watch(arena: Instance)
		refresh()
		arena:GetAttributeChangedSignal("CharacterLook"):Connect(refresh)
	end

	local arena = TableView.GetArena()
	if arena then
		watch(arena)
	else
		refresh()
	end
	TableView.OnJoined(function(joined: Model)
		if pill.Parent then
			watch(joined)
		end
	end)

	pill.Activated:Connect(function()
		Network.SetCharacterLook:FireServer(if current() == "bean" then "classic" else "bean")
	end)
end

return CharacterLook
