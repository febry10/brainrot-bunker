-- ConveyorService.luau (server ModuleScript)
-- Owns the conveyor lane: spawns brainrots at the west portal on a weighted
-- rarity roll (with mutation rolls), walks them east with a bob, despawns
-- them at the far end, and cycles Rainbow mutations through the spectrum.
-- Buying is EconomyService's job; this service only attaches the prompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))

local ConveyorService = {}

local rng = Random.new()

local function spawnBrainrot()
	local entry = Config.PickCast(rng)
	local mutation = Config.RollMutation(entry.rarity, rng)
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
		state = "Conveyor",
		owner = nil,
		x = Config.LaneMinX,
		bobPhase = rng:NextNumber(0, 6),
		spinPhase = 0,
		hue = rng:NextNumber(),
	}
	GameState.RegisterBrainrot(record)
	table.insert(GameState.conveyor, record)

	model:PivotTo(CFrame.new(record.x, Config.LaneY, 0))
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
	-- Spawn loop.
	task.spawn(function()
		while true do
			task.wait(Config.SpawnInterval)
			if #GameState.conveyor < Config.ConveyorCap then
				spawnBrainrot()
			end
		end
	end)

	-- Walk loop.
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for i = #GameState.conveyor, 1, -1 do
			local record = GameState.conveyor[i]
			record.x += record.entry.speed * dt
			record.bobPhase += dt * 7
			if record.x >= Config.LaneMaxX then
				table.remove(GameState.conveyor, i)
				GameState.DestroyBrainrot(record)
			else
				local bob = math.abs(math.sin(record.bobPhase)) * 0.28
				record.model:PivotTo(CFrame.new(record.x, Config.LaneY + bob, 0))
				if record.mutation == "Rainbow" then
					local color = Color3.fromHSV((t * 0.25 + record.hue) % 1, 0.65, 1)
					record.bodyPart.Color = color
				end
			end
		end
	end)
end

return ConveyorService
