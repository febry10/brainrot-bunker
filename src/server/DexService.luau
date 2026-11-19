-- DexService.luau (server ModuleScript)
-- The Brainrotdex: GameState tracks every cast id a player has ever owned
-- (EconomyService marks buys, FusionService marks fusion results,
-- DataService restores count too). This service watches the collection
-- size and pays each Config.DexMilestones bonus exactly once per player;
-- data.dexPaid is the receipt, and it is part of the saved snapshot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local DexService = {}

function DexService.Start()
	task.spawn(function()
		while true do
			task.wait(2)
			for player, data in pairs(GameState.players) do
				local count = GameState.DexCount(data)
				for _, milestone in ipairs(Config.DexMilestones) do
					if count >= milestone.count and not table.find(data.dexPaid, milestone.count) then
						table.insert(data.dexPaid, milestone.count)
						data.money += milestone.reward
						GameState.SyncLeaderstats(player)
						Remotes.Notify(player, "BRAINROTDEX " .. count .. "/" .. #Config.Cast
							.. " discovered! +$" .. milestone.reward)
						EconomyService.SendState(player)
					end
				end
			end
		end
	end)
end

return DexService
