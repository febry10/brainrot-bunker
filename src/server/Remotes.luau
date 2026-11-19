-- Remotes.luau (server ModuleScript)
-- Creates and hands out the RemoteEvents in ReplicatedStorage.BrainrotRemotes:
--   StateUpdate  server -> client  HUD numbers (money, income, ...)
--   WaveWarning  server -> client  tsunami countdown (seconds)
--   Notify       server -> client  one-line feedback message
--   ClientAction client -> server  "Lock" | "Rebirth" | "BuySpeed" | "BuyCarry"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}
Remotes.folder = nil

local NAMES = { "StateUpdate", "WaveWarning", "Notify", "ClientAction" }

function Remotes.Init()
	if Remotes.folder then
		return Remotes.folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "BrainrotRemotes"
	for _, name in ipairs(NAMES) do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	Remotes.folder = folder
	return folder
end

function Remotes.Get(name)
	return Remotes.folder:WaitForChild(name)
end

function Remotes.Notify(player, text)
	Remotes.Get("Notify"):FireClient(player, text)
end

return Remotes
