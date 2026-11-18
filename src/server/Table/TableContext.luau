--!strict
-- TableContext.luau
-- Which table this copy of the game modules runs, and who is at it.
--
-- Every module in this folder keeps its state at module level (one game). To run
-- several tables in one server, init.server clones the whole folder once per table and
-- requires each clone separately, so each clone has its own state. Configure() is
-- called first, before any other module in the clone is required.
--
-- The remotes in Shared/Network are shared by all tables, so modules here never use
-- FireAllClients: they send to this table's members only (FireAll / GetPlayers).

local Players = game:GetService("Players")

export type Config = {
	id: number,
	name: string,
	maxPlayers: number,
	origin: Vector3, -- centre of this table on the floor; tables are only shifted sideways
}

local TableContext = {
	id = 0,
	name = "",
	maxPlayers = 4,
	origin = Vector3.zero,
}

-- userIds of players who joined this table (seated or waiting for the next match)
local members: { [number]: boolean } = {}
local changedHandler: (() -> ())? = nil

function TableContext.Configure(config: Config)
	TableContext.id = config.id
	TableContext.name = config.name
	TableContext.maxPlayers = config.maxPlayers
	TableContext.origin = config.origin
end

function TableContext.AddMember(player: Player)
	members[player.UserId] = true
end

function TableContext.RemoveMember(player: Player)
	members[player.UserId] = nil
end

function TableContext.IsMember(player: Player): boolean
	return members[player.UserId] == true
end

-- Players at this table who are still in the server
function TableContext.GetPlayers(): { Player }
	local list = {}
	for userId in pairs(members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			table.insert(list, player)
		end
	end
	return list
end

-- FireAllClients, limited to this table
function TableContext.FireAll(remote: RemoteEvent, ...: any)
	for _, player in ipairs(TableContext.GetPlayers()) do
		remote:FireClient(player, ...)
	end
end

-- The table directory (init.server) listens here to refresh the table list in the menu
function TableContext.OnChanged(handler: () -> ())
	changedHandler = handler
end

function TableContext.NotifyChanged()
	if changedHandler then
		task.defer(changedHandler)
	end
end

return TableContext
