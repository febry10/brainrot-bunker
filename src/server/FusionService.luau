-- FusionService.luau (server ModuleScript)
-- Progression sink: three placed brainrots of the same cast member fuse
-- into one brainrot of the next rarity tier (the cheapest member of that
-- tier). The trio consumed is the three weakest mutations of the group,
-- and the result keeps the best mutation among the three it ate - so a
-- Rainbow you placed is never the one burned. Triggered from the plaza
-- fusion pedestal or the HUD button; validated entirely against
-- GameState, like every other system.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local FusionService = {}

local MUTATION_RANK = { None = 0, Gold = 1, Rainbow = 2 }

function FusionService.TryFuse(player)
	local data = GameState.Get(player)
	if not data then
		return
	end

	-- Group the placed brainrots by cast member.
	local groups = {}
	for _, record in ipairs(data.placed) do
		local group = groups[record.entry.id]
		if not group then
			group = {}
			groups[record.entry.id] = group
		end
		table.insert(group, record)
	end

	-- Pick the fusable group whose result earns the most.
	local best = nil
	for _, group in pairs(groups) do
		if #group >= 3 then
			local entry = group[1].entry
			local nextRarity = Config.NextRarity(entry.rarity)
			local resultEntry = nextRarity and Config.FirstOfRarity(nextRarity)
			if resultEntry then
				table.sort(group, function(a, b)
					return MUTATION_RANK[a.mutation] < MUTATION_RANK[b.mutation]
				end)
				local consumed = { group[1], group[2], group[3] }
				local resultMutation = consumed[3].mutation
				local score = Config.IncomeFor(resultEntry, resultMutation)
				if not best or score > best.score then
					best = {
						entry = entry,
						resultEntry = resultEntry,
						consumed = consumed,
						resultMutation = resultMutation,
						score = score,
					}
				end
			end
		end
	end

	if not best then
		Remotes.Notify(player, "No fusable trio - place 3 of the same brainrot first!")
		return
	end

	-- The result goes back on the base the trio lived on.
	local resultBase = best.consumed[1].baseIndex

	-- Burn the trio: free their pads, drop the records and models.
	for _, record in ipairs(best.consumed) do
		local base = record.baseIndex and GameState.GetBase(record.baseIndex)
		if base and record.padIndex then
			base.pads[record.padIndex] = nil
		end
		GameState.RemoveFromList(data.placed, record)
		GameState.DestroyBrainrot(record)
	end

	-- Build the result and put it on a freed pad.
	local model, visuals = CharacterFactory.Build(best.resultEntry, best.resultMutation)
	local record = {
		entry = best.resultEntry,
		mutation = best.resultMutation,
		displayName = Config.DisplayName(best.resultEntry, best.resultMutation),
		income = Config.IncomeFor(best.resultEntry, best.resultMutation),
		cost = Config.CostFor(best.resultEntry, best.resultMutation),
		model = model,
		bodyPart = visuals.body,
		headPart = visuals.head,
		state = "Placed",
		owner = player,
	}
	GameState.RegisterBrainrot(record)
	model.Parent = Workspace:WaitForChild("BrainrotModels")
	data.stats.fusions += 1
	data.dex[best.resultEntry.id] = true

	if EconomyService.PlaceOnFreePad(player, record, resultBase) then
		Remotes.Notify(player, "FUSION! 3x " .. best.entry.name .. " became " .. record.displayName .. "!")
	else
		-- Unreachable in practice (the trio freed three pads), but never
		-- leave a built record orphaned.
		GameState.DestroyBrainrot(record)
		Remotes.Notify(player, "Fusion fizzled - your base is full!")
	end
	EconomyService.SendState(player)
end

-- Wire the plaza fusion pedestal WorldBuilder made.
function FusionService.Init(world)
	if world.fusionPrompt then
		world.fusionPrompt.Triggered:Connect(function(player)
			FusionService.TryFuse(player)
		end)
	end
end

return FusionService
