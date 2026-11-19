-- QuestService.luau (server ModuleScript)
-- Every player always has one active quest. New players first follow
-- the structured QUEST CHAIN (Config.QuestChain): eleven ordered steps
-- that tour the whole game -- buy, place, earn, own, lock, buy rare,
-- fuse, reach the city unlock, place in the city, rebirth, visit the
-- clouds. Once the chain is finished, quests roll from the rotating
-- pool (Config.Quests) forever.
--
-- Progress is not tracked here at all: each quest kind maps to a
-- counter read by GameState.StatFor (incremented by the systems that
-- own the actions), and a quest completes when the counter has moved
-- past the baseline captured when the quest was issued -- chain steps
-- flagged absolute instead measure the counter itself (baseline zero).
-- Completion pays the money reward and immediately issues the next
-- quest; the chain step persists via DataService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local QuestService = {}

local rng = Random.new()

local function assignPoolQuest(data)
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

-- The next objective: the current chain step while the chain lasts, a
-- pool quest afterwards.
local function assignQuest(data)
	if data.chainStep <= #Config.QuestChain then
		local step = Config.QuestChain[data.chainStep]
		data.quest = {
			kind = step.kind,
			target = step.target,
			reward = step.reward,
			label = step.label,
			chain = data.chainStep,
			baseline = step.absolute and 0 or GameState.StatFor(data, step.kind),
		}
	else
		assignPoolQuest(data)
	end
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
					local quest = data.quest
					local reward = quest.reward
					data.money += reward
					GameState.SyncLeaderstats(player)
					if quest.chain then
						Remotes.Notify(player, string.format(
							"QUEST %d/%d COMPLETE! +$%d", quest.chain, #Config.QuestChain, reward))
						data.chainStep += 1
					else
						Remotes.Notify(player, "QUEST COMPLETE! +$" .. reward)
					end
					data.quest = nil
					assignQuest(data)
					EconomyService.SendState(player)
				end
			end
		end
	end)
end

return QuestService
