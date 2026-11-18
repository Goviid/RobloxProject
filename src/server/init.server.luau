--!strict
-- init.server.luau
-- Server entry point for Skulls & Roses: the table directory.
--
-- Players arrive in the main menu (Play -> pick a table). Each table in Constants.TABLES
-- runs its own copy of the game modules in the Table folder (see Table/TableContext),
-- built at its own spot in the world. This script routes each player's requests to the
-- table they joined (or out of it, back to the menu), and keeps everyone's table list
-- (seats taken, match running) fresh.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Network = require(ReplicatedStorage.Shared.Network)

local template = script:WaitForChild("Table")

-- Types come from the template modules; the code runs in each table's own copy
type TableInstance = {
	id: number,
	name: string,
	context: typeof(require(script.Table.TableContext)),
	lobby: typeof(require(script.Table.LobbyManager)),
	round: typeof(require(script.Table.RoundManager)),
}

print("[Skulls & Roses] Server initializing...")

-- Where players stand while they are in the menu: a small hidden platform away from
-- the tables, so a menu player never appears in someone's seat
local menuSpawn = Instance.new("SpawnLocation")
menuSpawn.Name = "MenuSpawn"
menuSpawn.Size = Vector3.new(6, 1, 6)
menuSpawn.CFrame = CFrame.new(Constants.MENU_SPAWN)
menuSpawn.Anchored = true
menuSpawn.Transparency = 1
menuSpawn.Neutral = true
menuSpawn.Duration = 0
menuSpawn.Parent = workspace

local runningTables: { TableInstance } = {}
local tableOf: { [Player]: TableInstance } = {}

local tableModules = Instance.new("Folder")
tableModules.Name = "Tables"
tableModules.Parent = ServerStorage

for id, info in ipairs(Constants.TABLES) do
	local copy = template:Clone()
	copy.Name = "Table_" .. id
	copy.Parent = tableModules

	local context = (require :: any)(copy.TableContext)
	context.Configure({
		id = id,
		name = info.name,
		maxPlayers = info.maxPlayers,
		origin = Vector3.new((id - 1) * Constants.TABLE_SPACING, 0, 0),
	})
	local builder = (require :: any)(copy.TableBuilder)
	builder.Build()

	local entry: TableInstance = {
		id = id,
		name = info.name,
		context = context,
		lobby = (require :: any)(copy.LobbyManager),
		round = (require :: any)(copy.RoundManager),
	}
	entry.lobby.Init()
	table.insert(runningTables, entry)
end
workspace:SetAttribute("TableReady", true) -- the client loading screen waits for this

-- Table list for the menu
local function tableList(): { any }
	local list = {}
	for _, t in ipairs(runningTables) do
		local summary = t.lobby.GetSummary()
		table.insert(list, {
			id = t.id,
			name = t.name,
			seated = summary.seated,
			maxPlayers = summary.maxPlayers,
			inMatch = summary.inMatch,
		})
	end
	return list
end

local listQueued = false
local function broadcastTableList()
	if listQueued then
		return
	end
	listQueued = true
	task.defer(function()
		listQueued = false
		Network.TableList:FireAllClients(tableList())
	end)
end
for _, t in ipairs(runningTables) do
	t.context.OnChanged(broadcastTableList)
end

local function joinTable(player: Player, tableId: any)
	if tableOf[player] or type(tableId) ~= "number" then
		return -- already at a table (leave it first)
	end
	local target = runningTables[tableId]
	if not target then
		return
	end
	tableOf[player] = target
	target.context.AddMember(player)
	player:SetAttribute("TableId", target.id) -- the client switches from the menu to the game on this
	print("[Skulls & Roses] " .. player.Name .. " joined " .. target.name)
	target.lobby.OnPlayerAdded(player)
	broadcastTableList()
end

-- Leaving a table, or the game: the table treats both the same (a player leaving
-- mid-match restarts the round without them, see LobbyManager.OnPlayerRemoving)
local function leaveTable(player: Player)
	local t = tableOf[player]
	if not t then
		return
	end
	-- Out of the table's audience first, so a reset to the lobby doesn't seat them again
	t.context.RemoveMember(player)
	tableOf[player] = nil
	t.lobby.OnPlayerRemoving(player)
	broadcastTableList()
end

-- Client -> server, routed to the player's table
Network.JoinTable.OnServerEvent:Connect(joinTable)

Network.LeaveTable.OnServerEvent:Connect(function(player: Player)
	if not tableOf[player] then
		return
	end
	print("[Skulls & Roses] " .. player.Name .. " left " .. tableOf[player].name)
	leaveTable(player)
	player:SetAttribute("TableId", nil) -- the client goes back to the menu on this
	task.spawn(function()
		player:LoadCharacterAsync() -- fresh avatar on the menu platform, out of the seat
	end)
end)

Network.RequestTables.OnServerEvent:Connect(function(player: Player)
	Network.TableList:FireClient(player, tableList())
end)

Network.SubmitAction.OnServerInvoke = function(player: Player, action: string, data: any)
	local t = tableOf[player]
	if not t then
		return false, "Pick a table first"
	end
	return t.round.HandlePlayerAction(player.UserId, action, data)
end

-- Client initial state request (guarantees the UI syncs as soon as it loads)
Network.RequestState.OnServerEvent:Connect(function(player: Player)
	local t = tableOf[player]
	if t then
		t.round.SendStateToPlayer(player.UserId)
		t.lobby.Broadcast()
	end
end)

Network.LobbyAction.OnServerEvent:Connect(function(player: Player, action: any, value: any)
	local t = tableOf[player]
	if t then
		t.lobby.HandleAction(player, action, value)
	end
end)

local function onPlayerAdded(player: Player)
	print("[Skulls & Roses] Player joined: " .. player.Name .. " (" .. player.UserId .. ")")
end

local function onPlayerRemoving(player: Player)
	print("[Skulls & Roses] Player left: " .. player.Name)
	leaveTable(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle any players already in game (e.g. during live reload)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print("[Skulls & Roses] Server ready!")
