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
			EconomyService.TryPlace(player)
		end
	end)
	base.world.lockPad.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player and base.owner == player then
			StealService.TryLock(player)
		end
	end)
end

function BaseService.AssignBase(player)
	local data = GameState.Get(player)
	if not data then
		return nil
	end
	for _, base in ipairs(GameState.bases) do
		if not base.owner then
			base.owner = player
			data.baseIndex = base.index
			base.world.ownerLabel.Text = player.Name .. "'s BASE"
			base.world.statusLabel.Text = ""
			return base
		end
	end
	return nil -- all eight plots taken: the player spectates from the plaza
end

function BaseService.ReleaseBase(player)
	local data = GameState.Get(player)
	if not data or not data.baseIndex then
		return
	end
	local base = GameState.GetBase(data.baseIndex)
	if not base then
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
	base.pads = {}
	base.owner = nil
	base.lockedUntil = 0
	base.lockReadyAt = 0
	base.world.ownerLabel.Text = "EMPTY BASE"
	base.world.statusLabel.Text = ""
	base.world.lockWall.Transparency = 1
	base.world.lockWall.CanCollide = false
	data.baseIndex = nil
end

return BaseService
