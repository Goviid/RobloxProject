--!strict
-- Network.luau
-- Manages RemoteEvents and RemoteFunctions for Skulls & Roses client-server sync

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "SkullsNetwork"
local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)

if not folder and RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
elseif not folder then
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10) :: Folder
end

local function getOrCreateRemoteEvent(name: string): RemoteEvent
	local event = folder:FindFirstChild(name) :: RemoteEvent?
	if not event and RunService:IsServer() then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	elseif not event then
		event = folder:WaitForChild(name, 10) :: RemoteEvent
	end
	return event
end

local function getOrCreateRemoteFunction(name: string): RemoteFunction
	local rf = folder:FindFirstChild(name) :: RemoteFunction?
	if not rf and RunService:IsServer() then
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = folder
	elseif not rf then
		rf = folder:WaitForChild(name, 10) :: RemoteFunction
	end
	return rf
end

local Network = {
	-- Server -> Client Events
	GameStateChanged = getOrCreateRemoteEvent("GameStateChanged"),
	TurnStarted = getOrCreateRemoteEvent("TurnStarted"),
	CardPlayed = getOrCreateRemoteEvent("CardPlayed"),
	BidUpdated = getOrCreateRemoteEvent("BidUpdated"),
	CardRevealed = getOrCreateRemoteEvent("CardRevealed"),
	CardLost = getOrCreateRemoteEvent("CardLost"),
	PlayerEliminated = getOrCreateRemoteEvent("PlayerEliminated"),
	Notification = getOrCreateRemoteEvent("Notification"),
	GameOver = getOrCreateRemoteEvent("GameOver"),

	-- Client -> Server Actions
	SubmitAction = getOrCreateRemoteFunction("SubmitAction"),
	RequestState = getOrCreateRemoteEvent("RequestState"),
}

return Network

