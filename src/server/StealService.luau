-- StealService.luau (server ModuleScript)
-- The genre's tension: brainrots placed on an UNLOCKED enemy base can be
-- stolen with their prompt (they become carried - dash home!), and every
-- base can be locked for Config.LockDuration from its lock pad, the HUD
-- button or the L key. While locked, the entrance wall turns solid and all
-- steal prompts on that base switch off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local StealService = {}

local function setStealPromptsEnabled(base, enabled)
	for _, record in pairs(base.pads) do
		if record.stealPrompt then
			record.stealPrompt.Enabled = enabled
		end
	end
end

function StealService.TrySteal(player, record)
	local data = GameState.Get(player)
	if not data or record.state ~= "Placed" then
		return
	end
	local owner = record.owner
	if not owner or owner == player then
		return
	end
	local base = GameState.GetBase(record.baseIndex)
	if base and GameState.IsLocked(base) then
		Remotes.Notify(player, "That base is LOCKED!")
		return
	end
	if #data.carrying >= data.carryCapacity then
		Remotes.Notify(player, "Hands full! Can't steal right now.")
		return
	end

	-- Unlink from the victim.
	local ownerData = GameState.Get(owner)
	if ownerData then
		GameState.RemoveFromList(ownerData.placed, record)
	end
	if base and record.padIndex then
		base.pads[record.padIndex] = nil
	end
	if record.stealPrompt then
		record.stealPrompt:Destroy()
		record.stealPrompt = nil
	end

	record.state = "Carried"
	record.owner = player
	record.baseIndex = nil
	record.padIndex = nil
	table.insert(data.carrying, record)

	Remotes.Notify(player, "STOLE " .. record.displayName .. "! Dash home!")
	if owner then
		Remotes.Notify(owner, player.Name .. " stole your " .. record.displayName .. "!")
		local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
		EconomyService.SendState(owner)
	end
end

-- Lock one of the player's bases: the one whose lock pad was touched
-- when a base is passed in, otherwise the base in the world the player
-- is currently in (HUD button / L key).
function StealService.TryLock(player, touchedBase)
	local data = GameState.Get(player)
	if not data then
		return
	end
	local base = touchedBase
	if not base or base.owner ~= player then
		local index = data.worldBases[data.currentWorld] or data.baseIndex
		base = index and GameState.GetBase(index)
	end
	if not base or base.owner ~= player then
		return
	end
	local now = os.clock()
	if GameState.IsLocked(base) then
		Remotes.Notify(player, "Base already locked (" .. math.ceil(base.lockedUntil - now) .. "s left)")
		return
	end
	if now < base.lockReadyAt then
		Remotes.Notify(player, "Lock recharging (" .. math.ceil(base.lockReadyAt - now) .. "s)")
		return
	end
	base.lockedUntil = now + Config.LockDuration
	base.lockReadyAt = base.lockedUntil + Config.LockCooldown
	base.world.lockWall.Transparency = 0.45
	base.world.lockWall.CanCollide = true
	setStealPromptsEnabled(base, false)
	data.stats.locks += 1
	Remotes.Notify(player, "Base LOCKED for " .. Config.LockDuration .. "s!")
end

local function unlock(base)
	base.lockedUntil = 0
	base.world.lockWall.Transparency = 1
	base.world.lockWall.CanCollide = false
	base.world.statusLabel.Text = ""
	setStealPromptsEnabled(base, true)
end

-- Watches lock expiries and keeps the sign countdowns fresh.
function StealService.Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, base in ipairs(GameState.bases) do
				if base.owner then
					if base.lockedUntil > 0 and now >= base.lockedUntil then
						unlock(base)
					elseif GameState.IsLocked(base) then
						base.world.statusLabel.Text = "LOCKED " .. math.ceil(base.lockedUntil - now) .. "s"
					end
				end
			end
		end
	end)
end

return StealService
