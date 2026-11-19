-- QuestService.luau (server ModuleScript)
-- Every player always has one active quest from the Config.Quests pool.
-- Progress is not tracked here at all: each quest kind maps to a lifetime
-- counter in GameState (incremented by the systems that own the actions -
-- EconomyService buys/places/earns, FusionService fuses, WaveService
-- survivals), and a quest completes when the counter has moved past the
-- baseline captured when the quest was issued. Completion pays the money
-- reward and immediately issues the next quest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local QuestService = {}

local rng = Random.new()

local function assignQuest(data)
	local pool = Config.Quests
	local pick = pool[rng:NextInteger(1, #pool)]
	if data.quest and #pool > 1 then
		local guard = 0
		while pick.kind == data.quest.kind and guard < 5 do
			pick = pool[rng:NextInteger(1, #pool)]
			guard += 1
		end
	end
	data.quest = {
		kind = pick.kind,
		target = pick.target,
		reward = pick.reward,
		label = pick.label,
		baseline = GameState.StatFor(data, pick.kind),
	}
end

function QuestService.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for player, data in pairs(GameState.players) do
				if not data.quest then
					assignQuest(data)
					EconomyService.SendState(player)
				elseif GameState.StatFor(data, data.quest.kind) - data.quest.baseline >= data.quest.target then
					local reward = data.quest.reward
					data.money += reward
					GameState.SyncLeaderstats(player)
					Remotes.Notify(player, "QUEST COMPLETE! +$" .. reward)
					assignQuest(data)
					EconomyService.SendState(player)
				end
			end
		end
	end)
end

return QuestService
