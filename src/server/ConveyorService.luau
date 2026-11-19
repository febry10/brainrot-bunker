-- ConveyorService.luau (server ModuleScript)
-- Owns the conveyor lanes - one per world (village, city, cloud land).
-- Each lane spawns brainrots at its west portal on a weighted rarity roll
-- (skewed per world via Config.WorldWeights, with mutation rolls), walks
-- them east with a bob, and despawns them at the far end. Rainbow
-- mutations cycle through the spectrum. Buying is EconomyService's job;
-- this service only attaches the prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local ConveyorService = {}

local rng = Random.new()

-- Lane descriptors, built once from Config.Worlds: absolute coordinates,
-- so a record only needs its lane reference to know how to walk.
local lanes = {}
for worldId, world in pairs(Config.Worlds) do
	table.insert(lanes, {
		worldId = worldId,
		minX = world.origin.X - Config.LaneHalfLength,
		maxX = world.origin.X + Config.LaneHalfLength,
		y = world.origin.Y + Config.LaneY,
		z = world.origin.Z,
		list = GameState.conveyors[worldId],
	})
end

local function spawnBrainrot(lane)
	local entry = Config.PickCast(rng, lane.worldId)
	local mutation = Config.RollMutation(entry.rarity, rng,
		GameState.isNight and Config.NightMutationMul or 1)
	local model, visuals = CharacterFactory.Build(entry, mutation)
	if lane.worldId == "Cloud" then
		-- Sky sparkle tint for cloud-land spawns.
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 240, 190)
		sparkles.Parent = visuals.body
	end

	local record = {
		entry = entry,
		mutation = mutation,
		displayName = Config.DisplayName(entry, mutation),
		income = Config.IncomeFor(entry, mutation),
		cost = Config.CostFor(entry, mutation),
		model = model,
		bodyPart = visuals.body,
		headPart = visuals.head,
		state = "Conveyor",
		owner = nil,
		worldId = lane.worldId,
		lane = lane,
		x = lane.minX,
		bobPhase = rng:NextNumber(0, 6),
		spinPhase = 0,
		hue = rng:NextNumber(),
	}
	GameState.RegisterBrainrot(record)
	table.insert(lane.list, record)

	model:PivotTo(CFrame.new(record.x, lane.y, lane.z))
	model.Parent = Workspace:WaitForChild("BrainrotModels")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy - $" .. record.cost
	prompt.ObjectText = record.displayName
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = visuals.body
	prompt.Triggered:Connect(function(player)
		EconomyService.TryBuy(player, record)
	end)
	record.buyPrompt = prompt
end

function ConveyorService.Start()
	-- Spawn loop: every lane tops itself up independently.
	task.spawn(function()
		while true do
			task.wait(Config.SpawnInterval)
			for _, lane in ipairs(lanes) do
				if #lane.list < Config.ConveyorCap then
					spawnBrainrot(lane)
				end
			end
		end
	end)

	-- Walk loop: every lane's records stroll east along their own lane.
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for _, lane in ipairs(lanes) do
			for i = #lane.list, 1, -1 do
				local record = lane.list[i]
				record.x += (record.speed or record.entry.speed) * dt
				record.bobPhase += dt * 7
				if record.x >= lane.maxX then
					table.remove(lane.list, i)
					GameState.DestroyBrainrot(record)
				else
					local bob = math.abs(math.sin(record.bobPhase)) * 0.28
					record.model:PivotTo(CFrame.new(record.x, lane.y + bob, lane.z))
					if record.mutation == "Rainbow" then
						local color = Color3.fromHSV((t * 0.25 + record.hue) % 1, 0.65, 1)
						record.bodyPart.Color = color
					end
				end
			end
		end
	end)
end

return ConveyorService
