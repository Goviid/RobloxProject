--!strict
-- LobbyManager.luau
-- Pre-match lobby: seats human players, runs the ready check and countdown, lets the
-- host force-start or toggle bots, fills empty seats with bots at match start, and
-- takes everyone back here when a match ends.
--
-- Seating: humans take seats 1..MAX_PLAYERS while in the lobby. Anyone who joins during
-- a match (or when the table is full) waits and is seated at the next lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Enums = require(ReplicatedStorage.Shared.Enums)
local Network = require(ReplicatedStorage.Shared.Network)
local PlayerManager = require(script.Parent.PlayerManager)
local RoundManager = require(script.Parent.RoundManager)
local TableBuilder = require(script.Parent.TableBuilder)

local LobbyManager = {}

local BOT_NAMES = { "BLUFFER_99", "BLUFFE_99", "ROSE_KING" }

local ready: { [number]: boolean } = {}
local joinOrder: { number } = {} -- userIds in the order they joined (host = first still here)
local addBots = Constants.ENABLE_BOTS
local countdownThread: thread? = nil
local countdownLeft: number? = nil

local function inLobby(): boolean
	return RoundManager.GetGameState() == Enums.GameState.Lobby
end

local function seatedHumans(): { PlayerManager.PlayerData }
	local list = {}
	for _, p in ipairs(PlayerManager.GetActivePlayers()) do
		if not p.isBot then
			table.insert(list, p)
		end
	end
	return list
end

local function getHostId(): number?
	for _, id in ipairs(joinOrder) do
		if PlayerManager.GetPlayer(id) then
			return id
		end
	end
	return nil
end

local function canStart(): boolean
	local humans = #seatedHumans()
	if humans == 0 then
		return false
	end
	local total = humans + (if addBots then Constants.MAX_PLAYERS - humans else 0)
	return total >= Constants.MIN_PLAYERS
end

local function allReady(): boolean
	local humans = seatedHumans()
	if #humans == 0 then
		return false
	end
	for _, p in ipairs(humans) do
		if not ready[p.userId] then
			return false
		end
	end
	return true
end

function LobbyManager.Broadcast()
	local seats = {}
	local hostId = getHostId()
	for _, p in ipairs(PlayerManager.GetActivePlayers()) do
		if not p.isBot then
			table.insert(seats, {
				userId = p.userId,
				name = p.name,
				seatIndex = p.seatIndex,
				ready = ready[p.userId] == true,
				isHost = p.userId == hostId,
			})
		end
	end
	local waiting = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if not PlayerManager.GetPlayer(plr.UserId) then
			waiting += 1
		end
	end
	Network.LobbyState:FireAllClients({
		inLobby = inLobby(),
		hostId = hostId,
		addBots = addBots,
		botsAllowed = Constants.ENABLE_BOTS,
		seats = seats,
		maxSeats = Constants.MAX_PLAYERS,
		waitingCount = waiting,
		countdown = countdownLeft,
		canStart = canStart(),
	})
end

local function cancelCountdown()
	if countdownThread and coroutine.running() ~= countdownThread then
		pcall(task.cancel, countdownThread)
	end
	countdownThread = nil
	countdownLeft = nil
end

local function startMatch()
	cancelCountdown()
	if not inLobby() or not canStart() then
		LobbyManager.Broadcast()
		return
	end

	-- Fill empty seats with bots
	if addBots then
		local nameIndex = 1
		while #PlayerManager.GetActivePlayers() < Constants.MAX_PLAYERS and nameIndex <= #BOT_NAMES + 3 do
			local name = BOT_NAMES[nameIndex] or ("BOT_" .. nameIndex)
			nameIndex += 1
			local bot = PlayerManager.AddBot(name)
			if bot then
				TableBuilder.SpawnStandingBot(bot.name, bot.seatIndex)
			end
		end
	end

	table.clear(ready)
	RoundManager.StartMatch()
	LobbyManager.Broadcast()
end

-- Start (or stop) the countdown depending on whether everyone seated is ready
local function refreshCountdown()
	if inLobby() and allReady() and canStart() then
		if not countdownThread then
			countdownLeft = Constants.LOBBY_COUNTDOWN
			countdownThread = task.spawn(function()
				while countdownLeft and countdownLeft > 0 do
					LobbyManager.Broadcast()
					task.wait(1)
					if countdownLeft then
						countdownLeft -= 1
					end
				end
				countdownThread = nil
				startMatch()
			end)
			return -- the countdown loop broadcasts
		end
	else
		cancelCountdown()
	end
	LobbyManager.Broadcast()
end

local function seatPlayer(player: Player): boolean
	local data = PlayerManager.AddPlayer(player)
	if data then
		TableBuilder.StandPlayer(player, data.seatIndex)
		return true
	end
	TableBuilder.StandSpectator(player)
	return false
end

-- Back to the lobby: drop bots, reset the match, seat everyone who was waiting
function LobbyManager.EnterLobby()
	cancelCountdown()
	for id, p in pairs(PlayerManager.GetAllPlayers()) do
		if p.isBot then
			TableBuilder.ClearSeat(p.seatIndex)
			PlayerManager.RemovePlayer(id)
		end
	end
	PlayerManager.ResetMatch()
	table.clear(ready)
	RoundManager.EnterLobby()

	for _, plr in ipairs(Players:GetPlayers()) do
		if not PlayerManager.GetPlayer(plr.UserId) then
			seatPlayer(plr)
		end
	end
	RoundManager.EnterLobby() -- re-broadcast table state with the new seating
	LobbyManager.Broadcast()
end

function LobbyManager.OnPlayerAdded(player: Player)
	if not table.find(joinOrder, player.UserId) then
		table.insert(joinOrder, player.UserId)
	end
	if inLobby() then
		seatPlayer(player)
		cancelCountdown() -- a new player hasn't readied yet
		RoundManager.EnterLobby()
	else
		TableBuilder.StandSpectator(player)
		RoundManager.SendStateToPlayer(player.UserId)
	end
	LobbyManager.Broadcast()
end

function LobbyManager.OnPlayerRemoving(player: Player)
	local userId = player.UserId
	ready[userId] = nil
	local idx = table.find(joinOrder, userId)
	if idx then
		table.remove(joinOrder, idx)
	end
	TableBuilder.ForgetPlayer(player)

	local data = PlayerManager.GetPlayer(userId)
	if data then
		local name = data.name
		TableBuilder.ClearSeat(data.seatIndex)
		PlayerManager.RemovePlayer(userId)
		if inLobby() then
			refreshCountdown()
			RoundManager.EnterLobby()
		else
			RoundManager.OnPlayerLeft(name)
		end
	end
	LobbyManager.Broadcast()
end

local function onLobbyAction(player: Player, action: any, value: any)
	if not inLobby() or type(action) ~= "string" then
		return
	end
	local userId = player.UserId
	local isSeated = PlayerManager.GetPlayer(userId) ~= nil
	local isHost = getHostId() == userId

	if action == "ToggleReady" and isSeated then
		ready[userId] = not ready[userId]
		refreshCountdown()
	elseif action == "SetAddBots" and isHost and Constants.ENABLE_BOTS then
		addBots = value == true
		refreshCountdown()
	elseif action == "Start" and isHost and canStart() then
		startMatch()
	end
end

function LobbyManager.Init()
	RoundManager.SetMatchOverHandler(LobbyManager.EnterLobby)
	Network.LobbyAction.OnServerEvent:Connect(onLobbyAction)
	RoundManager.EnterLobby()
end

return LobbyManager
