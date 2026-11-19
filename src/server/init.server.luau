-- BRAINROT BUNKER - server bootstrap.
-- Builds the world, creates the remotes, starts every service and wires
-- player join/leave. All game logic lives in the sibling modules; all
-- state lives in GameState.

local Players = game:GetService("Players")

local GameState = require(script:WaitForChild("GameState"))
local Remotes = require(script:WaitForChild("Remotes"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local ConveyorService = require(script:WaitForChild("ConveyorService"))
local EconomyService = require(script:WaitForChild("EconomyService"))
local BaseService = require(script:WaitForChild("BaseService"))
local StealService = require(script:WaitForChild("StealService"))
local WaveService = require(script:WaitForChild("WaveService"))
local RebirthService = require(script:WaitForChild("RebirthService"))

print("[BrainrotBunker] building world...")
Remotes.Init()
local world = WorldBuilder.Build()
GameState.InitBases(world.bases)
for _, base in ipairs(GameState.bases) do
	BaseService.WireBase(base)
end
RebirthService.Init(world)

ConveyorService.Start()
EconomyService.Start()
StealService.Start()
WaveService.Start(world.spawnCFrame)
print("[BrainrotBunker] world ready")

local function onPlayerAdded(player)
	GameState.CreatePlayerData(player)
	BaseService.AssignBase(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		GameState.ApplyWalkSpeed(player)
		EconomyService.SendState(player)
	end)
	if player.Character then
		GameState.ApplyWalkSpeed(player)
	end
	EconomyService.SendState(player)
end

local function onPlayerRemoving(player)
	BaseService.ReleaseBase(player)
	GameState.RemovePlayerData(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- HUD buttons arrive here: Lock / Rebirth / upgrades.
Remotes.Get("ClientAction").OnServerEvent:Connect(function(player, action)
	if action == "Lock" then
		StealService.TryLock(player)
	elseif action == "Rebirth" then
		RebirthService.TryRebirth(player)
	elseif action == "BuySpeed" then
		RebirthService.BuyUpgrade(player, "Speed")
	elseif action == "BuyCarry" then
		RebirthService.BuyUpgrade(player, "Carry")
	end
end)
