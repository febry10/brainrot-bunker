-- BRAINROT BUNKER - server bootstrap.
-- Builds the world, creates the remotes, starts every service and wires
-- player join/leave. All game logic lives in the sibling modules; all
-- state lives in GameState.
--
-- Every subsystem starts inside its own pcall: one broken module must
-- never take the whole game down with it. Failures are warn()ed with the
-- subsystem's name so the output log says exactly what is missing.

local Players = game:GetService("Players")

-- Load each module under pcall: a load error in one file leaves the rest
-- of the game alive (and names the culprit in the log).
local modules = {}
for _, name in ipairs({
	"GameState", "Remotes", "WorldBuilder", "ConveyorService",
	"EconomyService", "BaseService", "StealService", "WaveService",
	"RebirthService",
}) do
	local ok, result = pcall(function()
		return require(script:WaitForChild(name))
	end)
	if ok then
		modules[name] = result
	else
		warn(("[BrainrotBunker] FAILED to load module %s: %s"):format(name, tostring(result)))
	end
end

local GameState = modules.GameState
local Remotes = modules.Remotes
local WorldBuilder = modules.WorldBuilder
local ConveyorService = modules.ConveyorService
local EconomyService = modules.EconomyService
local BaseService = modules.BaseService
local StealService = modules.StealService
local WaveService = modules.WaveService
local RebirthService = modules.RebirthService

local function start(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn(("[BrainrotBunker] subsystem '%s' failed to start: %s"):format(name, tostring(err)))
	end
	return ok
end

print("[BrainrotBunker] building world...")
if Remotes then
	start("Remotes", function()
		Remotes.Init()
	end)
end

local world = nil
if WorldBuilder then
	start("WorldBuilder", function()
		world = WorldBuilder.Build()
	end)
end

if world and GameState then
	start("Bases", function()
		GameState.InitBases(world.bases)
		if BaseService then
			for _, base in ipairs(GameState.bases) do
				BaseService.WireBase(base)
			end
		end
	end)
	if RebirthService then
		start("RebirthService", function()
			RebirthService.Init(world)
		end)
	end
end

if ConveyorService then
	start("ConveyorService", function()
		ConveyorService.Start()
	end)
end
if EconomyService then
	start("EconomyService", function()
		EconomyService.Start()
	end)
end
if StealService then
	start("StealService", function()
		StealService.Start()
	end)
end
if WaveService and world then
	start("WaveService", function()
		WaveService.Start(world.spawnCFrame)
	end)
end
print("[BrainrotBunker] world ready")

if GameState then
	local function onPlayerAdded(player)
		GameState.CreatePlayerData(player)
		if BaseService then
			BaseService.AssignBase(player)
		end
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			GameState.ApplyWalkSpeed(player)
			if EconomyService then
				EconomyService.SendState(player)
			end
		end)
		if player.Character then
			GameState.ApplyWalkSpeed(player)
		end
		if EconomyService then
			EconomyService.SendState(player)
		end
	end

	local function onPlayerRemoving(player)
		if BaseService then
			BaseService.ReleaseBase(player)
		end
		GameState.RemovePlayerData(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
else
	warn("[BrainrotBunker] GameState failed to load: player wiring skipped")
end

-- HUD buttons arrive here: Lock / Rebirth / upgrades.
if Remotes then
	start("ClientAction", function()
		Remotes.Get("ClientAction").OnServerEvent:Connect(function(player, action)
			if action == "Lock" and StealService then
				StealService.TryLock(player)
			elseif action == "Rebirth" and RebirthService then
				RebirthService.TryRebirth(player)
			elseif action == "BuySpeed" and RebirthService then
				RebirthService.BuyUpgrade(player, "Speed")
			elseif action == "BuyCarry" and RebirthService then
				RebirthService.BuyUpgrade(player, "Carry")
			end
		end)
	end)
end
