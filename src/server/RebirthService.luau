-- RebirthService.luau (server ModuleScript)
-- Progression beyond the ladder: the shop pedestals (walk speed, carry
-- capacity) and rebirthing - burn your money and your placed brainrots for
-- a permanent income multiplier and a little more speed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local RebirthService = {}

function RebirthService.BuyUpgrade(player, kind)
	local data = GameState.Get(player)
	if not data then
		return
	end
	local spec = Config.Upgrades[kind]
	if not spec then
		return
	end
	if kind == "Speed" then
		if data.speedStacks >= spec.maxStacks then
			Remotes.Notify(player, "Speed is maxed out!")
			return
		end
		if data.money < spec.cost then
			Remotes.Notify(player, "Need $" .. spec.cost .. " for the speed upgrade")
			return
		end
		data.money -= spec.cost
		data.speedStacks += 1
		data.speedBonus += spec.amount
		GameState.ApplyWalkSpeed(player)
		Remotes.Notify(player, "Speed upgrade bought! WalkSpeed +" .. spec.amount)
	elseif kind == "Carry" then
		if data.carryCapacity > 1 then
			Remotes.Notify(player, "You already carry 2!")
			return
		end
		if data.money < spec.cost then
			Remotes.Notify(player, "Need $" .. spec.cost .. " for the carry upgrade")
			return
		end
		data.money -= spec.cost
		data.carryCapacity = 2
		Remotes.Notify(player, "You can now carry 2 brainrots!")
	end
	GameState.SyncLeaderstats(player)
	local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
	EconomyService.SendState(player)
end

function RebirthService.TryRebirth(player)
	local data = GameState.Get(player)
	if not data then
		return
	end
	if data.money < Config.RebirthCost then
		Remotes.Notify(player, "Rebirth needs $" .. Config.RebirthCost .. " (you have $" .. math.floor(data.money) .. ")")
		return
	end
	-- Burn the placed brainrots (in every world) and the money; keep
	-- carried ones in hand. Each record frees its own pad.
	for _, record in ipairs(data.placed) do
		local base = record.baseIndex and GameState.GetBase(record.baseIndex)
		if base and record.padIndex then
			base.pads[record.padIndex] = nil
		end
		GameState.DestroyBrainrot(record)
	end
	data.placed = {}
	data.money = Config.StartMoney
	data.rebirths += 1
	GameState.SyncLeaderstats(player)
	GameState.ApplyWalkSpeed(player)
	local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
	EconomyService.SendState(player)
	Remotes.Notify(player, "REBIRTH! Income is now x" .. GameState.RebirthMultiplier(data) .. " forever")
end

-- Wire the three shop pedestals WorldBuilder made.
function RebirthService.Init(world)
	world.speedPrompt.Triggered:Connect(function(player)
		RebirthService.BuyUpgrade(player, "Speed")
	end)
	world.carryPrompt.Triggered:Connect(function(player)
		RebirthService.BuyUpgrade(player, "Carry")
	end)
	world.rebirthPrompt.Triggered:Connect(function(player)
		RebirthService.TryRebirth(player)
	end)
end

return RebirthService
