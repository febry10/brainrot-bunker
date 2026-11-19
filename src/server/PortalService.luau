-- PortalService.luau (server ModuleScript)
-- Travel between the three worlds. The village <-> city portals are
-- stone/neon arches with a ProximityPrompt: the city side is gated by
-- lifetime progress (Config.Worlds.City unlock rule), the way back is
-- always open. The cloud land is reached by WIND PORTALS - glowing pads
-- that launch you on a swirling arc through the sky - and left via a
-- drop pad that rides the wind back down. Arriving in a world claims
-- your plot there and restores any saved brainrots waiting for it.
-- Carried brainrots travel with you (they ride above your head anyway).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local BaseService = require(script.Parent:WaitForChild("BaseService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local PortalService = {}

local function unlocked(player, worldId)
	local data = GameState.Get(player)
	local rule = Config.Worlds[worldId]
	if not data or not rule or not rule.unlockEarned then
		return true
	end
	return data.stats.earned >= rule.unlockEarned or data.rebirths >= rule.unlockRebirths
end

local function lockText(worldId)
	local rule = Config.Worlds[worldId]
	return "Locked! Reach $" .. rule.unlockEarned .. " lifetime earned or "
		.. rule.unlockRebirths .. " rebirth(s) to open this portal."
end

-- Land a player in a world: claim their plot, restore their saved
-- brainrots for that world, sync the HUD.
local function arrive(player, worldId, spawnCFrame, welcomeText)
	local data = GameState.Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	character:PivotTo(spawnCFrame + Vector3.new(0, 2, 0))
	data.currentWorld = worldId
	if worldId == "Cloud" then
		data.stats.cloudVisits += 1
	end
	BaseService.AssignWorldBase(player, worldId)
	local DataService = require(script.Parent:WaitForChild("DataService"))
	pcall(function()
		DataService.RestoreWorld(player, worldId)
	end)
	EconomyService.SendState(player)
	if welcomeText then
		Remotes.Notify(player, welcomeText)
	end
end

-- A rising ring swirl at a wind pad, purely cosmetic.
local function spawnSwirl(position)
	local model = Instance.new("Model")
	model.Name = "WindSwirl"
	model.Parent = Workspace
	local rings = {}
	for i = 1, 5 do
		local ring = Instance.new("Part")
		ring.Name = "Ring"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(6 + i * 0.7, 0.35, 6 + i * 0.7)
		ring.Color = Color3.fromRGB(190, 240, 255)
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.35
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CFrame = CFrame.new(position + Vector3.new(0, 0.5 + i * 0.8, 0))
		ring.Parent = model
		rings[i] = ring
	end
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 1.4 do
			local dt = task.wait()
			for i, ring in ipairs(rings) do
				ring.CFrame = ring.CFrame * CFrame.Angles(0, dt * (2 + i * 0.4), 0)
					+ Vector3.new(0, dt * 7, 0)
				ring.Transparency = math.min(0.35 + (os.clock() - t0) * 0.45, 1)
			end
		end
		model:Destroy()
	end)
end

local flying = {} -- [Player] -> true while riding the wind

-- Ride the wind: an arcing flight (with a spin) from wherever the player
-- stands to a world's spawn, then arrive() there.
local function flyTo(player, worldId, spawnCFrame, arcHeight, welcomeText)
	if flying[player] then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	flying[player] = true
	spawnSwirl(root.Position)
	local startPos = root.Position
	local endPos = spawnCFrame.Position + Vector3.new(0, 2, 0)
	local duration = 2.4
	task.spawn(function()
		local t0 = os.clock()
		while character.Parent do
			local a = math.min((os.clock() - t0) / duration, 1)
			local pos = startPos:Lerp(endPos, a)
			pos = Vector3.new(pos.X,
				startPos.Y + (endPos.Y - startPos.Y) * a + math.sin(a * math.pi) * arcHeight,
				pos.Z)
			root.AssemblyLinearVelocity = Vector3.zero
			character:PivotTo(CFrame.new(pos) * CFrame.Angles(0, a * math.pi * 3, 0))
			if a >= 1 then
				break
			end
			task.wait()
		end
		flying[player] = nil
		arrive(player, worldId, spawnCFrame, welcomeText)
	end)
end

local function playerFromHit(hit)
	if not hit or not hit.Parent then
		return nil
	end
	return Players:GetPlayerFromCharacter(hit.Parent)
end

local lastPadUse = {} -- [Player] -> os.clock of last wind/drop pad trigger

local function wirePad(part, fn)
	part.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if not player then
			return
		end
		local now = os.clock()
		if lastPadUse[player] and now - lastPadUse[player] < 3 then
			return
		end
		lastPadUse[player] = now
		fn(player)
	end)
end

function PortalService.Start(world)
	local portals = world.portals
	local spawns = {
		Village = world.worlds.Village.spawnCFrame,
		City = world.worlds.City and world.worlds.City.spawnCFrame,
		Cloud = world.worlds.Cloud and world.worlds.Cloud.spawnCFrame,
	}

	-- Village -> City (gated).
	if portals.cityVillage and spawns.City then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Enter the City"
		prompt.ObjectText = "City Portal"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = portals.cityVillage
		prompt.Triggered:Connect(function(player)
			if unlocked(player, "City") then
				arrive(player, "City", spawns.City,
					"Welcome to KOTA BRAINROT! Richer brainrots roll down this lane.")
			else
				Remotes.Notify(player, lockText("City"))
			end
		end)
	end

	-- City -> Village (always open).
	if portals.cityCity and spawns.Village then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Return to the Village"
		prompt.ObjectText = "Village Portal"
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = portals.cityCity
		prompt.Triggered:Connect(function(player)
			arrive(player, "Village", spawns.Village, "Back in the village.")
		end)
	end

	-- Wind pads -> Cloud land (gated, launched on the wind).
	local function windRide(player)
		if unlocked(player, "Cloud") then
			flyTo(player, "Cloud", spawns.Cloud, 90,
				"Welcome to NEGERI AWAN, the cloud land! The richest brainrots drift here.")
		else
			Remotes.Notify(player, lockText("Cloud"))
		end
	end
	if portals.windVillage and spawns.Cloud then
		wirePad(portals.windVillage, windRide)
	end
	if portals.windCity and spawns.Cloud then
		wirePad(portals.windCity, windRide)
	end

	-- Cloud drop pad -> back down to the village.
	if portals.cloudDrop and spawns.Village then
		wirePad(portals.cloudDrop, function(player)
			flyTo(player, "Village", spawns.Village, 50, "The wind sets you down in the village.")
		end)
	end
end

return PortalService
