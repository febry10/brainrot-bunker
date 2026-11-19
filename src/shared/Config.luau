-- Config.luau (ReplicatedStorage.Shared)
-- Every tunable number and the whole brainrot cast live here, so the server
-- services and the client HUD all read the same truth. Data only, no state.

local Config = {}

-- Economy ---------------------------------------------------------------
Config.StartMoney = 150
Config.BaseWalkSpeed = 16

-- Rebirth ---------------------------------------------------------------
Config.RebirthCost = 100000 -- money needed to rebirth
Config.RebirthIncomeMulPer = 2 -- income multiplier is 2 ^ rebirths
Config.RebirthSpeedBonus = 2 -- +2 WalkSpeed per rebirth

-- Base lock ---------------------------------------------------------------
Config.LockDuration = 60 -- seconds a lock lasts
Config.LockCooldown = 30 -- seconds after a lock ends before it can be used again

-- Wave event --------------------------------------------------------------
Config.WaveInterval = 100 -- seconds between tsunami warnings
Config.WaveWarningTime = 5 -- countdown shown before the wave sweeps

-- Conveyor ----------------------------------------------------------------
Config.ConveyorCap = 10 -- max brainrots walking one lane at once
Config.SpawnInterval = 2.5 -- seconds between spawn attempts
Config.LaneMinX = -92 -- spawn end of the village conveyor
Config.LaneMaxX = 92 -- despawn end of the village conveyor
Config.LaneY = 0.6 -- top surface of the belt, relative to the world origin
Config.LaneHalfLength = 92 -- every world's lane runs origin.x +/- this

-- Worlds --------------------------------------------------------------------
-- Three zones in one place, far enough apart to never see each other.
-- Each world has its own conveyor lane (origin.x +/- LaneHalfLength at
-- origin.z, belt top at origin.y + LaneY) and its own base plots. The
-- city and the cloud land are reached by portal and gated by lifetime
-- progress (either condition unlocks).
Config.Worlds = {
	Village = { origin = Vector3.new(0, 0, 0) },
	City = { origin = Vector3.new(800, 0, 0), unlockEarned = 25000, unlockRebirths = 1 },
	Cloud = { origin = Vector3.new(-800, 260, 0), unlockEarned = 250000, unlockRebirths = 2 },
}

-- Per-world spawn weight multipliers by rarity: the city skews richer,
-- the cloud land richer still (applied inside PickCast).
Config.WorldWeights = {
	Village = { Common = 1, Rare = 1, Epic = 1, Legendary = 1, Mythic = 1 },
	City = { Common = 0.35, Rare = 1, Epic = 1.6, Legendary = 2, Mythic = 2.2 },
	Cloud = { Common = 0.1, Rare = 0.5, Epic = 1.6, Legendary = 2.4, Mythic = 3 },
}

-- Upgrades ------------------------------------------------------------------
Config.Upgrades = {
	Speed = { cost = 2500, amount = 4, maxStacks = 3 },
	Carry = { cost = 10000, maxStacks = 1 }, -- one purchase: carry capacity 1 -> 2
}

-- Rarities ------------------------------------------------------------------
Config.RarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
Config.RarityColors = {
	Common = Color3.fromRGB(205, 205, 205),
	Rare = Color3.fromRGB(70, 140, 255),
	Epic = Color3.fromRGB(170, 85, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 160),
}

-- Presentation only (no economy effect): how big a brainrot model is built
-- and how large its floating label is, per rarity. Rarer = bigger spectacle.
Config.RarityScale = {
	Common = 1,
	Rare = 1.1,
	Epic = 1.22,
	Legendary = 1.4,
	Mythic = 1.6,
}
Config.RarityLabelMul = {
	Common = 1,
	Rare = 1.08,
	Epic = 1.18,
	Legendary = 1.32,
	Mythic = 1.5,
}

-- Mutations: rolled when a brainrot spawns on the conveyor ------------------
Config.Mutations = {
	Gold = { incomeMul = 5, costMul = 2, color = Color3.fromRGB(255, 205, 50) },
	Rainbow = { incomeMul = 10, costMul = 3, color = Color3.fromRGB(255, 90, 200) },
}
-- Per-rarity chances (0..1) of a spawn rolling a mutation.
Config.MutationOdds = {
	Common = { Gold = 0, Rainbow = 0 },
	Rare = { Gold = 0.06, Rainbow = 0.01 },
	Epic = { Gold = 0.08, Rainbow = 0.02 },
	Legendary = { Gold = 0.10, Rainbow = 0.03 },
	Mythic = { Gold = 0.12, Rainbow = 0.05 },
}

-- The cast ------------------------------------------------------------------
-- body/head/accent are Color3s the CharacterFactory builds the blocky body
-- from; prop names a signature prop builder in CharacterFactory.
Config.Cast = {
	{ id = "kakek-kentang", name = "Kakek Kentang", rarity = "Common", cost = 50, income = 2, speed = 7, weight = 100,
		body = Color3.fromRGB(176, 142, 90), head = Color3.fromRGB(198, 164, 108), accent = Color3.fromRGB(240, 240, 240), prop = "mustache" },
	{ id = "tahu-bulat", name = "Tahu Bulat Dadakan", rarity = "Common", cost = 100, income = 4, speed = 7.5, weight = 90,
		body = Color3.fromRGB(240, 220, 160), head = Color3.fromRGB(248, 232, 185), accent = Color3.fromRGB(220, 60, 40), prop = "antenna" },
	{ id = "bebek-betawi", name = "Bebek Betawi", rarity = "Common", cost = 200, income = 7, speed = 8, weight = 80,
		body = Color3.fromRGB(250, 220, 60), head = Color3.fromRGB(252, 228, 90), accent = Color3.fromRGB(230, 60, 60), prop = "scarf" },
	{ id = "siomay-terbang", name = "Siomay Terbang", rarity = "Rare", cost = 500, income = 15, speed = 8.5, weight = 45,
		body = Color3.fromRGB(235, 200, 170), head = Color3.fromRGB(242, 214, 190), accent = Color3.fromRGB(255, 255, 255), prop = "wings" },
	{ id = "cilok-meledak", name = "Cilok Meledak", rarity = "Rare", cost = 900, income = 26, speed = 9, weight = 40,
		body = Color3.fromRGB(232, 232, 228), head = Color3.fromRGB(240, 240, 238), accent = Color3.fromRGB(225, 45, 45), prop = "chili" },
	{ id = "kucing-oren", name = "Kucing Oren Barbar", rarity = "Rare", cost = 1500, income = 40, speed = 9.5, weight = 35,
		body = Color3.fromRGB(245, 140, 40), head = Color3.fromRGB(248, 156, 58), accent = Color3.fromRGB(120, 60, 20), prop = "ears" },
	{ id = "ayam-geprek", name = "Ayam Geprek Level Neraka", rarity = "Epic", cost = 4000, income = 95, speed = 10, weight = 18,
		body = Color3.fromRGB(205, 70, 45), head = Color3.fromRGB(218, 88, 60), accent = Color3.fromRGB(255, 80, 30), prop = "horns" },
	{ id = "bakso-beranak", name = "Bakso Beranak", rarity = "Epic", cost = 7500, income = 170, speed = 10, weight = 15,
		body = Color3.fromRGB(170, 120, 85), head = Color3.fromRGB(182, 134, 100), accent = Color3.fromRGB(90, 160, 70), prop = "cap" },
	{ id = "mas-rusdi", name = "Mas Rusdi", rarity = "Epic", cost = 12000, income = 280, speed = 10.5, weight = 12,
		body = Color3.fromRGB(90, 140, 200), head = Color3.fromRGB(240, 200, 160), accent = Color3.fromRGB(40, 40, 40), prop = "glasses" },
	{ id = "naga-indomie", name = "Naga Indomie", rarity = "Legendary", cost = 30000, income = 700, speed = 11, weight = 6,
		body = Color3.fromRGB(250, 200, 50), head = Color3.fromRGB(252, 210, 75), accent = Color3.fromRGB(60, 200, 90), prop = "horns" },
	{ id = "raja-singkong", name = "Raja Singkong", rarity = "Legendary", cost = 60000, income = 1400, speed = 11, weight = 5,
		body = Color3.fromRGB(150, 110, 70), head = Color3.fromRGB(164, 126, 86), accent = Color3.fromRGB(255, 205, 50), prop = "crown" },
	{ id = "phoenix-rendang", name = "Phoenix Rendang", rarity = "Mythic", cost = 150000, income = 3500, speed = 12, weight = 2,
		body = Color3.fromRGB(180, 40, 30), head = Color3.fromRGB(196, 56, 40), accent = Color3.fromRGB(255, 140, 30), prop = "wings" },
	{ id = "sate-titan", name = "Sate Klathak Titan", rarity = "Mythic", cost = 400000, income = 9000, speed = 12, weight = 1.5,
		body = Color3.fromRGB(120, 70, 40), head = Color3.fromRGB(136, 86, 54), accent = Color3.fromRGB(200, 200, 210), prop = "antenna" },
	{ id = "dewa-warteg", name = "Dewa Warteg", rarity = "Mythic", cost = 1000000, income = 25000, speed = 13, weight = 1,
		body = Color3.fromRGB(255, 240, 200), head = Color3.fromRGB(255, 246, 220), accent = Color3.fromRGB(255, 215, 60), prop = "halo" },
}

-- Fusion --------------------------------------------------------------------
-- Three placed brainrots of the same cast member fuse into one of the next
-- rarity tier (see FusionService). The result is the cheapest cast member
-- of the tier above; Mythic cannot fuse further.
Config.RarityRank = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }

function Config.NextRarity(rarity)
	local rank = Config.RarityRank[rarity]
	if not rank or rank >= #Config.RarityOrder then
		return nil
	end
	return Config.RarityOrder[rank + 1]
end

function Config.FirstOfRarity(rarity)
	local best = nil
	for _, entry in ipairs(Config.Cast) do
		if entry.rarity == rarity and (best == nil or entry.cost < best.cost) then
			best = entry
		end
	end
	return best
end

-- Quests ----------------------------------------------------------------------
-- One active quest per player, drawn from this pool; progress is read from
-- the lifetime stat counters in GameState (see QuestService). The label is
-- a string.format pattern with one %d for the target.
Config.Quests = {
	{ kind = "buy", target = 3, reward = 300, label = "Buy %d brainrots" },
	{ kind = "place", target = 4, reward = 400, label = "Place %d brainrots on your base" },
	{ kind = "earn", target = 2000, reward = 500, label = "Earn $%d from your base" },
	{ kind = "fuse", target = 1, reward = 1500, label = "Fuse %d brainrot trio" },
	{ kind = "survive", target = 2, reward = 600, label = "Survive %d tsunamis in a base" },
}

-- The structured quest chain every player follows FIRST (QuestService):
-- eleven ordered steps touring the whole game, from the first buy to
-- the cloud land. Kinds resolve through GameState.StatFor; steps with
-- absolute = true measure the lifetime/snapshot value itself (baseline
-- zero), the rest measure progress made after the step is issued. After
-- step 11 the rotating pool above takes over.
Config.QuestChain = {
	{ kind = "buy", target = 1, reward = 100, label = "Buy your first brainrot" },
	{ kind = "place", target = 1, reward = 100, label = "Place a brainrot on your base" },
	{ kind = "earn", target = 500, reward = 150, label = "Earn $%d from your base" },
	{ kind = "own", target = 3, reward = 250, label = "Own %d brainrots at once", absolute = true },
	{ kind = "lock", target = 1, reward = 300, label = "Lock your base once" },
	{ kind = "buyRare", target = 1, reward = 500, label = "Buy a Rare-or-better brainrot" },
	{ kind = "fuse", target = 1, reward = 1500, label = "Fuse %d brainrot trio" },
	{ kind = "earn", target = 25000, reward = 1000, label = "Reach $%d lifetime earned - the city portal opens!", absolute = true },
	{ kind = "placeCity", target = 1, reward = 2000, label = "Place a brainrot in the city" },
	{ kind = "rebirth", target = 1, reward = 2500, label = "Rebirth once", absolute = true },
	{ kind = "visitCloud", target = 1, reward = 5000, label = "Visit the cloud land" },
}

-- Day / night cycle -------------------------------------------------------------
Config.DayLengthSeconds = 240 -- one full 24h cycle
Config.NightStartHour = 18.5 -- Lighting ClockTime hours that count as night
Config.NightEndHour = 5.5
Config.NightMutationMul = 2.5 -- mutation odds multiplier while it is night

-- Giant event -------------------------------------------------------------------
Config.GiantFirstDelay = 75 -- seconds after server start before the first giant
Config.GiantInterval = 150 -- seconds between giants
Config.GiantScale = 2.5 -- model scale on top of the rarity scale
Config.GiantCostMul = 5 -- price multiplier over the plain Gold version
Config.GiantIncomeMul = 5 -- income multiplier over the plain Gold version

-- Brainrotdex -------------------------------------------------------------------
Config.DexMilestones = {
	{ count = 5, reward = 1000 },
	{ count = 10, reward = 5000 },
	{ count = 14, reward = 25000 },
}

-- Persistence -------------------------------------------------------------------
Config.DataStoreName = "BrainrotBunkerPlayerData_v1"
Config.AutosaveSeconds = 150

-- Helpers -------------------------------------------------------------------

function Config.GetEntry(id)
	for _, entry in ipairs(Config.Cast) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Config.RarityColor(rarity)
	return Config.RarityColors[rarity] or Color3.fromRGB(255, 255, 255)
end

-- Weighted random cast entry (commons flood the village lane, mythics are
-- an event; other worlds skew the weights via Config.WorldWeights).
function Config.PickCast(rng, worldId)
	local weights = worldId and Config.WorldWeights[worldId]
	local function weightOf(entry)
		if weights then
			return entry.weight * (weights[entry.rarity] or 1)
		end
		return entry.weight
	end
	local total = 0
	for _, entry in ipairs(Config.Cast) do
		total += weightOf(entry)
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in ipairs(Config.Cast) do
		roll -= weightOf(entry)
		if roll <= 0 then
			return entry
		end
	end
	return Config.Cast[1]
end

-- Roll a mutation name ("None" | "Gold" | "Rainbow") for a rarity.
-- oddsMul scales both chances (the day/night cycle boosts them at night).
function Config.RollMutation(rarity, rng, oddsMul)
	local odds = Config.MutationOdds[rarity]
	if not odds then
		return "None"
	end
	local mul = oddsMul or 1
	local rainbow = math.min(odds.Rainbow * mul, 0.6)
	local gold = math.min(odds.Gold * mul, 0.9 - rainbow)
	local roll = rng:NextNumber()
	if roll < rainbow then
		return "Rainbow"
	elseif roll < rainbow + gold then
		return "Gold"
	end
	return "None"
end

function Config.IncomeFor(entry, mutation)
	local mul = 1
	if mutation ~= "None" and Config.Mutations[mutation] then
		mul = Config.Mutations[mutation].incomeMul
	end
	return entry.income * mul
end

function Config.CostFor(entry, mutation)
	local mul = 1
	if mutation ~= "None" and Config.Mutations[mutation] then
		mul = Config.Mutations[mutation].costMul
	end
	return math.floor(entry.cost * mul + 0.5)
end

function Config.DisplayName(entry, mutation)
	if mutation ~= "None" then
		return string.upper(mutation) .. " " .. entry.name
	end
	return entry.name
end

return Config
