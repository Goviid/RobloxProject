--!strict
-- TableView.luau
-- Which table this player joined and where it is. The server sets the player's
-- "TableId" attribute when they pick a table in the menu; each table's arena is
-- Workspace.SkullsArena_<id>, with its centre in the arena's "Origin" attribute.

local Players = game:GetService("Players")

local TableView = {}

local localPlayer = Players.LocalPlayer

function TableView.GetTableId(): number?
	local id = localPlayer:GetAttribute("TableId")
	return if type(id) == "number" then id else nil
end

function TableView.GetArena(): Model?
	local id = TableView.GetTableId()
	if not id then
		return nil
	end
	local arena = workspace:FindFirstChild("SkullsArena_" .. id)
	return if arena and arena:IsA("Model") then arena else nil
end

-- Centre of the player's table (table 1's centre while still in the menu)
function TableView.GetOrigin(): Vector3
	local arena = TableView.GetArena()
	local origin = arena and arena:GetAttribute("Origin")
	return if typeof(origin) == "Vector3" then origin else Vector3.zero
end

-- Calls `callback` every time the player joins a table, once its arena has loaded
function TableView.OnJoined(callback: (arena: Model) -> ())
	local function check()
		local id = TableView.GetTableId()
		if not id then
			return
		end
		task.spawn(function()
			local arena = workspace:WaitForChild("SkullsArena_" .. id, 30)
			if arena and arena:IsA("Model") and TableView.GetTableId() == id then
				callback(arena)
			end
		end)
	end
	localPlayer:GetAttributeChangedSignal("TableId"):Connect(check)
	check()
end

-- Calls `callback` every time the player leaves their table (back to the menu)
function TableView.OnLeft(callback: () -> ())
	localPlayer:GetAttributeChangedSignal("TableId"):Connect(function()
		if not TableView.GetTableId() then
			callback()
		end
	end)
end

return TableView
