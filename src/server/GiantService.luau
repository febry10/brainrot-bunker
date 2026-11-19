-- GiantService.luau (server ModuleScript)
-- The spectacle event: every Config.GiantInterval a GIANT golden brainrot
-- (an Epic-or-rarer cast member, Gold visuals, scaled x Config.GiantScale,
-- at a premium price for premium income) lumbers down the conveyor lane.
-- It is an ordinary conveyor record in every way that matters - the walk
-- loop moves it, the buy prompt sells it, and reaching the lane end
-- despawns it - it is just very, very big. Announced to everyone through
-- the Announce remote (the HUD's big banner).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local GiantService = {}

local rng = Random.new()

local function pickGiantEntry()
	for _ = 1, 12 do
		local entry = Config.PickCast(rng)
		if Config.RarityRank[entry.rarity] >= 3 then
			return entry
		end
	end
	return Config.FirstOfRarity("Epic")
end

local function spawnGiant()
	if #GameState.conveyor >= Config.ConveyorCap + 2 then
		return -- lane is crowded enough already
	end
	local entry = pickGiantEntry()
	local mutation = "Gold"
	local model, visuals = CharacterFactory.Build(entry, mutation)
	model:ScaleTo(model:GetScale() * Config.GiantScale)

	local record = {
		entry = entry,
		mutation = mutation,
		displayName = "GIANT " .. Config.DisplayName(entry, mutation),
		income = Config.IncomeFor(entry, mutation) * Config.GiantIncomeMul,
		cost = Config.CostFor(entry, mutation) * Config.GiantCostMul,
		model = model,
		bodyPart = visuals.body,
		headPart = visuals.head,
		state = "Conveyor",
		owner = nil,
		x = Config.LaneMinX,
		speed = entry.speed * 0.65, -- giants lumber
		bobPhase = rng:NextNumber(0, 6),
		spinPhase = 0,
		hue = rng:NextNumber(),
		isGiant = true,
	}
	GameState.RegisterBrainrot(record)
	table.insert(GameState.conveyor, record)

	model:PivotTo(CFrame.new(record.x, Config.LaneY, 0))
	model.Parent = Workspace:WaitForChild("BrainrotModels")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy GIANT - $" .. record.cost
	prompt.ObjectText = record.displayName
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = visuals.body
	prompt.Triggered:Connect(function(player)
		EconomyService.TryBuy(player, record)
	end)
	record.buyPrompt = prompt

	Remotes.Get("Announce"):FireAllClients(
		"A GIANT GOLDEN " .. string.upper(entry.name) .. " IS ON THE LANE! $" .. record.cost)
end

function GiantService.Start()
	task.spawn(function()
		task.wait(Config.GiantFirstDelay)
		while true do
			local ok, err = pcall(spawnGiant)
			if not ok then
				warn("[BrainrotBunker] giant spawn failed: " .. tostring(err))
			end
			task.wait(Config.GiantInterval)
		end
	end)
end

return GiantService
