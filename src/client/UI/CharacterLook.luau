--!strict
-- CharacterLook.luau
-- Test switch between the two character looks ("Classic" calavera avatar and "Bean"):
-- a small dim pill (t-shirt icon and the current look's name) in the top-right corner,
-- left of "Piles". It changes the look for
-- everyone at your table; the pill shows the table's current look (the arena's
-- "CharacterLook" attribute, set by the server).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local Network = require(ReplicatedStorage.Shared.Network)
local TableView = require(script.Parent.Parent.TableView)
local CornerPill = require(script.Parent.CornerPill)

local CharacterLook = {}

local NAMES = { classic = "Classic", bean = "Bean" }

function CharacterLook.Create(parent: Instance)
	local corner = CornerPill.Create(parent, "CharacterLookPill", Theme.Images.IconLook, "Look", 1) -- left of Piles
	local pill = corner.button

	local function current(): string
		local arena = TableView.GetArena()
		local look = arena and arena:GetAttribute("CharacterLook")
		return if look == "bean" then "bean" else "classic"
	end

	local function refresh()
		corner.label.Text = NAMES[current()]
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
