-- BaseService.luau (server ModuleScript)
-- Hands out the eight base plots as players join, wires their floor (walk
-- on your own base to place what you carry) and lock pad touches, and
-- cleans a base up when its owner leaves.

local Players = game:GetService("Players")

local GameState = require(script.Parent:WaitForChild("GameState"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local StealService = require(script.Parent:WaitForChild("StealService"))

local BaseService = {}

local function playerFromHit(hit)
	if not hit or not hit.Parent then
		return nil
	end
	return Players:GetPlayerFromCharacter(hit.Parent)
end

-- Connect the Touched events of one base's floor and lock pad. Done once
-- at startup for all eight bases; the handlers look the owner up live.
function BaseService.WireBase(base)
	base.world.floor.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and base.owner == player then
			EconomyService.TryPlace(player, base)
		end
	end)
	base.world.lockPad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and base.owner == player then
			StealService.TryLock(player, base)
		end
	end)
end

-- Claim the first free plot in one world for the player (idempotent).
-- The village claim also maintains data.baseIndex for the systems that
-- still speak of "the" base (persistence restore, rebirth).
function BaseService.AssignWorldBase(player, worldId)
	local data = GameState.Get(player)
	if not data then
		return nil
	end
	local existing = data.worldBases[worldId]
	if existing then
		return GameState.GetBase(existing)
	end
	for _, base in ipairs(GameState.bases) do
		if base.worldId == worldId and not base.owner then
			base.owner = player
			data.worldBases[worldId] = base.index
			if worldId == "Village" then
				data.baseIndex = base.index
			end
			base.world.ownerLabel.Text = player.Name .. "'s BASE"
			base.world.statusLabel.Text = ""
			return base
		end
	end
	return nil -- every plot in this world is taken
end

function BaseService.AssignBase(player)
	return BaseService.AssignWorldBase(player, "Village")
end

function BaseService.ReleaseBase(player)
	local data = GameState.Get(player)
	if not data then
		return
	end
	-- Everything the player had out in the world goes away with them.
	for _, record in ipairs(data.carrying) do
		GameState.DestroyBrainrot(record)
	end
	for _, record in ipairs(data.placed) do
		GameState.DestroyBrainrot(record)
	end
	data.carrying = {}
	data.placed = {}
	-- Release every claimed plot, in every world.
	for _, index in pairs(data.worldBases) do
		local base = GameState.GetBase(index)
		if base and base.owner == player then
			base.pads = {}
			base.owner = nil
			base.lockedUntil = 0
			base.lockReadyAt = 0
			base.world.ownerLabel.Text = "EMPTY BASE"
			base.world.statusLabel.Text = ""
			base.world.lockWall.Transparency = 1
			base.world.lockWall.CanCollide = false
		end
	end
	data.worldBases = {}
	data.baseIndex = nil
end

return BaseService
