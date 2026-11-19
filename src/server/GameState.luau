-- GameState.luau (server ModuleScript)
-- The ONE place game state lives: per-player data, the eight bases and the
-- registry of every brainrot record in the world. Services read and mutate
-- state only through here, so there is never a second copy of the truth.
--
-- A brainrot record is a plain table:
--   { id, entry (Config cast entry), mutation ("None"|"Gold"|"Rainbow"),
--     displayName, income, cost, model, bodyPart, headPart,
--     state = "Conveyor" | "Carried" | "Placed",
--     owner (Player|nil), baseIndex, padIndex, x, bobPhase, spinPhase,
--     buyPrompt, stealPrompt }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local GameState = {}

GameState.players = {} -- [Player] -> data table
GameState.bases = {} -- [1..8] -> base table
GameState.brainrots = {} -- [id] -> record
GameState.conveyor = {} -- array of records currently walking the lane
GameState.nextId = 0

-- Bases ---------------------------------------------------------------------

-- worldBases: the array WorldBuilder.Build() returned (geometry + refs).
function GameState.InitBases(worldBases)
	GameState.bases = {}
	for i, world in ipairs(worldBases) do
		GameState.bases[i] = {
			index = i,
			world = world,
			owner = nil, -- Player or nil
			pads = {}, -- [padIndex] -> record or nil
			lockedUntil = 0, -- os.clock() time the current lock ends
			lockReadyAt = 0, -- os.clock() time the lock can be used again
		}
	end
end

function GameState.GetBase(index)
	return GameState.bases[index]
end

function GameState.IsLocked(base)
	return os.clock() < base.lockedUntil
end

-- Players -------------------------------------------------------------------

function GameState.CreatePlayerData(player)
	local data = {
		money = Config.StartMoney,
		rebirths = 0,
		carryCapacity = 1,
		speedBonus = 0,
		speedStacks = 0,
		carrying = {}, -- array of records, oldest first
		placed = {}, -- array of records earning on the base
		baseIndex = nil,
		lastPlaceAt = 0,
	}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = data.money
	money.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
	data.leaderstats = leaderstats

	GameState.players[player] = data
	return data
end

function GameState.Get(player)
	return GameState.players[player]
end

function GameState.RemovePlayerData(player)
	GameState.players[player] = nil
end

function GameState.RebirthMultiplier(data)
	return Config.RebirthIncomeMulPer ^ data.rebirths
end

-- Total $/s a player's placed brainrots earn right now (mutations already
-- folded into each record's income; the rebirth multiplier applies on top).
function GameState.ComputeIncomePerSec(player)
	local data = GameState.players[player]
	if not data then
		return 0
	end
	local sum = 0
	for _, record in ipairs(data.placed) do
		sum += record.income
	end
	return sum * GameState.RebirthMultiplier(data)
end

function GameState.SyncLeaderstats(player)
	local data = GameState.players[player]
	if not data or not data.leaderstats then
		return
	end
	data.leaderstats.Money.Value = math.floor(data.money)
	data.leaderstats.Rebirths.Value = data.rebirths
end

function GameState.ApplyWalkSpeed(player)
	local data = GameState.players[player]
	if not data then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.BaseWalkSpeed + data.speedBonus
			+ Config.RebirthSpeedBonus * data.rebirths
	end
end

-- Brainrot records ------------------------------------------------------------

function GameState.RegisterBrainrot(record)
	GameState.nextId += 1
	record.id = GameState.nextId
	GameState.brainrots[record.id] = record
	return record
end

-- Remove a record from a plain array (carrying / placed / conveyor).
function GameState.RemoveFromList(list, record)
	for i, item in ipairs(list) do
		if item == record then
			table.remove(list, i)
			return true
		end
	end
	return false
end

-- Fully destroy a brainrot: model gone, registry entry gone. Callers are
-- responsible for unlinking it from carrying/placed/conveyor/pads first.
function GameState.DestroyBrainrot(record)
	if record.buyPrompt then
		record.buyPrompt:Destroy()
		record.buyPrompt = nil
	end
	if record.stealPrompt then
		record.stealPrompt:Destroy()
		record.stealPrompt = nil
	end
	if record.model then
		record.model:Destroy()
		record.model = nil
	end
	GameState.brainrots[record.id] = nil
end

return GameState
