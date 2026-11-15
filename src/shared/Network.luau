--!strict
-- Network.luau
-- Manages RemoteEvents and RemoteFunctions for Skulls & Roses client-server sync

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "SkullsNetwork"

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
	if existing then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function getOrCreateRemoteEvent(name: string): RemoteEvent
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	else
		return folder:WaitForChild(name) :: RemoteEvent
	end
end

local function getOrCreateRemoteFunction(name: string): RemoteFunction
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteFunction") then
			return existing
		end
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = folder
		return rf
	else
		return folder:WaitForChild(name) :: RemoteFunction
	end
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
	LobbyState = getOrCreateRemoteEvent("LobbyState"),

	-- Client -> Server Actions
	SubmitAction = getOrCreateRemoteFunction("SubmitAction"),
	RequestState = getOrCreateRemoteEvent("RequestState"),
	LobbyAction = getOrCreateRemoteEvent("LobbyAction"), -- (action: "ToggleReady" | "SetAddBots" | "Start", value: any)
}

return Network
