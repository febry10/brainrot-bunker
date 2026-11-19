-- DataService.luau (server ModuleScript)
-- Persistence, following Roblox's official data-store best practices:
-- one store, one key per player ("User_<UserId>"), the record loaded once
-- on join and buffered in memory (GameState IS the buffer), saved on a
-- staggered autosave, on leave and in BindToClose, with transient
-- failures retried with backoff and saves going through UpdateAsync so
-- two servers can never silently clobber each other.
--
-- What is saved: money, rebirths, speed stacks, carry capacity, the
-- Brainrotdex (+ which milestones were paid), the lifetime quest stats
-- and the placed brainrots as {cast id, mutation} pairs - models are
-- rebuilt by CharacterFactory on load, never stored.
--
-- If the DataStore API is unavailable (Studio without API access, an
-- outage), a one-time probe detects it and the whole service quietly
-- no-ops: the session runs on in-memory state alone. If a player's load
-- fails after retries, that player's saves are also skipped - a fresh
-- session must never overwrite data it could not read.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local DataService = {}

local store = nil
local probed = false
local apiOk = false

-- One-time availability probe: a single cheap read decides whether this
-- server persists at all (Studio without API access fails it at once).
local function apiAvailable()
	if probed then
		return apiOk
	end
	probed = true
	local ok, result = pcall(function()
		if not store then
			store = DataStoreService:GetDataStore(Config.DataStoreName)
		end
		return store:GetAsync("__probe__")
	end)
	apiOk = ok
	if not ok then
		warn("[BrainrotBunker] DataStore API unavailable - playing without persistence: " .. tostring(result))
	end
	return apiOk
end

local function withRetry(fn)
	local lastErr = nil
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < 3 then
			task.wait(attempt * attempt + math.random())
		end
	end
	return false, lastErr
end

local function keyFor(player)
	return "User_" .. player.UserId
end

local function snapshot(player)
	local data = GameState.Get(player)
	if not data then
		return nil
	end
	local placed = {}
	for _, record in ipairs(data.placed) do
		local base = record.baseIndex and GameState.GetBase(record.baseIndex)
		table.insert(placed, {
			id = record.entry.id,
			mutation = record.mutation,
			world = (base and base.worldId) or "Village",
		})
	end
	local dex = {}
	for id in pairs(data.dex) do
		table.insert(dex, id)
	end
	return {
		version = 1,
		money = math.floor(data.money),
		rebirths = data.rebirths,
		chainStep = data.chainStep,
		speedStacks = data.speedStacks,
		carryCapacity = data.carryCapacity,
		dex = dex,
		dexPaid = data.dexPaid,
		stats = data.stats,
		placed = placed,
	}
end

function DataService.SavePlayer(player)
	local data = GameState.Get(player)
	if not data or data.loadFailed or not apiAvailable() then
		return
	end
	local snap = snapshot(player)
	if not snap then
		return
	end
	local ok, err = withRetry(function()
		return store:UpdateAsync(keyFor(player), function()
			return snap
		end)
	end)
	if not ok then
		warn("[BrainrotBunker] save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataService.LoadAndRestore(player)
	local data = GameState.Get(player)
	if not data or data.loadAttempted then
		return
	end
	data.loadAttempted = true
	if not apiAvailable() then
		return
	end
	local ok, saved = withRetry(function()
		return store:GetAsync(keyFor(player))
	end)
	if not ok then
		data.loadFailed = true
		warn("[BrainrotBunker] load failed for " .. player.Name .. " - saves disabled this session: " .. tostring(saved))
		return
	end
	if type(saved) ~= "table" then
		return -- brand-new player: defaults already in place
	end

	-- Scalars, each validated before it touches live state.
	if type(saved.money) == "number" then
		data.money = math.max(0, saved.money)
	end
	if type(saved.rebirths) == "number" then
		data.rebirths = math.max(0, math.floor(saved.rebirths))
	end
	if type(saved.chainStep) == "number" then
		data.chainStep = math.clamp(math.floor(saved.chainStep), 1, #Config.QuestChain + 1)
	end
	if type(saved.speedStacks) == "number" then
		data.speedStacks = math.clamp(math.floor(saved.speedStacks), 0, Config.Upgrades.Speed.maxStacks)
		data.speedBonus = data.speedStacks * Config.Upgrades.Speed.amount
	end
	if saved.carryCapacity == 2 then
		data.carryCapacity = 2
	end
	if type(saved.dex) == "table" then
		for _, id in ipairs(saved.dex) do
			if type(id) == "string" and Config.GetEntry(id) then
				data.dex[id] = true
			end
		end
	end
	if type(saved.dexPaid) == "table" then
		for _, count in ipairs(saved.dexPaid) do
			if type(count) == "number" then
				table.insert(data.dexPaid, count)
			end
		end
	end
	if type(saved.stats) == "table" then
		for field in pairs(data.stats) do
			if type(saved.stats[field]) == "number" then
				data.stats[field] = saved.stats[field]
			end
		end
	end
	GameState.SyncLeaderstats(player)
	GameState.ApplyWalkSpeed(player)

	-- Rebuild the placed brainrots, world by world: the village base is
	-- already claimed at join, so village brainrots come back at once.
	-- Brainrots that lived in another world wait in pendingRestore until
	-- the player next claims a base there (see RestoreWorld).
	if type(saved.placed) == "table" then
		local byWorld = {}
		for _, item in ipairs(saved.placed) do
			if type(item) == "table" then
				local worldId = type(item.world) == "string" and item.world or "Village"
				byWorld[worldId] = byWorld[worldId] or {}
				table.insert(byWorld[worldId], item)
			end
		end
		for worldId, items in pairs(byWorld) do
			if worldId == "Village" then
				DataService.RestoreItems(player, items, data.baseIndex)
			else
				data.pendingRestore[worldId] = items
			end
		end
	end
	EconomyService.SendState(player)
end

-- Rebuild saved {cast id, mutation} items onto one specific base.
function DataService.RestoreItems(player, items, baseIndex)
	local data = GameState.Get(player)
	if not data or not baseIndex or type(items) ~= "table" then
		return
	end
	for _, item in ipairs(items) do
		local base = GameState.GetBase(baseIndex)
		if not base then
			return
		end
		local used = 0
		for i = 1, 6 do
			if base.pads[i] then
				used += 1
			end
		end
		if used >= 6 then
			break
		end
		local entry = type(item) == "table" and Config.GetEntry(item.id) or nil
		if entry then
			local mutation = item.mutation
			if mutation ~= "Gold" and mutation ~= "Rainbow" then
				mutation = "None"
			end
			local model, visuals = CharacterFactory.Build(entry, mutation)
			local record = {
				entry = entry,
				mutation = mutation,
				displayName = Config.DisplayName(entry, mutation),
				income = Config.IncomeFor(entry, mutation),
				cost = Config.CostFor(entry, mutation),
				model = model,
				bodyPart = visuals.body,
				headPart = visuals.head,
				state = "Placed",
				owner = player,
			}
			GameState.RegisterBrainrot(record)
			model.Parent = Workspace:WaitForChild("BrainrotModels")
			data.dex[entry.id] = true
			if not EconomyService.PlaceOnFreePad(player, record, baseIndex) then
				GameState.DestroyBrainrot(record)
			end
		end
	end
end

-- Called when the player claims a base in a world that still has saved
-- brainrots waiting (PortalService calls this on arrival).
function DataService.RestoreWorld(player, worldId)
	local data = GameState.Get(player)
	if not data then
		return
	end
	local items = data.pendingRestore[worldId]
	if not items then
		return
	end
	local baseIndex = data.worldBases[worldId]
	if not baseIndex then
		return
	end
	data.pendingRestore[worldId] = nil
	DataService.RestoreItems(player, items, baseIndex)
	EconomyService.SendState(player)
end

function DataService.Start()
	-- Staggered autosave (random initial offset, per the best practices:
	-- never let every server save on the same schedule).
	task.spawn(function()
		task.wait(math.random(20, 40))
		while true do
			task.wait(Config.AutosaveSeconds)
			for player in pairs(GameState.players) do
				task.spawn(function()
					DataService.SavePlayer(player)
				end)
			end
		end
	end)

	-- Final flush on server shutdown.
	game:BindToClose(function()
		for player in pairs(GameState.players) do
			DataService.SavePlayer(player)
		end
	end)

	-- Safety net for leaving players; init saves first (before the base
	-- is released), so this only fires on paths init did not cover.
	Players.PlayerRemoving:Connect(function(player)
		DataService.SavePlayer(player)
	end)
end

return DataService
