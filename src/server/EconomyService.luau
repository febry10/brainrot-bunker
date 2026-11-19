-- EconomyService.luau (server ModuleScript)
-- Money: the per-second income tick, buying brainrots off the conveyor,
-- carrying them (they ride above your head), and placing them on your base
-- where they start earning. All money changes happen here or in
-- RebirthService; all state lives in GameState.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local EconomyService = {}

-- Push the HUD numbers to one player's client.
function EconomyService.SendState(player)
	local data = GameState.Get(player)
	if not data then
		return
	end
	local carryName = ""
	if data.carrying[1] then
		carryName = data.carrying[1].displayName
	end
	local questLine = ""
	if data.quest then
		local done = GameState.StatFor(data, data.quest.kind) - data.quest.baseline
		questLine = "QUEST: " .. string.format(data.quest.label, data.quest.target)
			.. " (" .. math.min(done, data.quest.target) .. "/" .. data.quest.target .. ")"
			.. "  +$" .. data.quest.reward
	end
	Remotes.Get("StateUpdate"):FireClient(player, {
		money = math.floor(data.money),
		income = GameState.ComputeIncomePerSec(player),
		rebirths = data.rebirths,
		multiplier = GameState.RebirthMultiplier(data),
		carrying = #data.carrying,
		capacity = data.carryCapacity,
		carryName = carryName,
		lockReadyIn = 0,
		dexCount = GameState.DexCount(data),
		questLine = questLine,
		isNight = GameState.isNight,
	})
end

-- Buy a brainrot off the conveyor: it becomes carried above your head.
function EconomyService.TryBuy(player, record)
	local data = GameState.Get(player)
	if not data or record.state ~= "Conveyor" then
		return
	end
	if #data.carrying >= data.carryCapacity then
		Remotes.Notify(player, "Hands full! Place what you carry first.")
		return
	end
	if data.money < record.cost then
		Remotes.Notify(player, "Not enough money for " .. record.displayName .. " ($" .. record.cost .. ")")
		return
	end
	data.money -= record.cost
	GameState.RemoveFromList(GameState.conveyor, record)
	record.state = "Carried"
	record.owner = player
	data.stats.bought += 1
	data.dex[record.entry.id] = true
	table.insert(data.carrying, record)
	if record.buyPrompt then
		record.buyPrompt:Destroy()
		record.buyPrompt = nil
	end
	GameState.SyncLeaderstats(player)
	EconomyService.SendState(player)
	Remotes.Notify(player, "Got " .. record.displayName .. "! Carry it to your base.")
end

-- Put a record on a specific pad of a base: registry fields, the model
-- transform, and the steal prompt anyone else can use while it is unlocked.
-- Shared by TryPlace, FusionService and DataService restores.
local function attachToPad(player, record, base, padIndex)
	local data = GameState.Get(player)
	base.pads[padIndex] = record
	record.state = "Placed"
	record.owner = player
	record.baseIndex = base.index
	record.padIndex = padIndex
	table.insert(data.placed, record)

	local pad = base.world.pads[padIndex]
	record.model:PivotTo(CFrame.new(pad.pos) * CFrame.Angles(0, base.world.faceAngle, 0))

	-- Anyone else may try to steal it while the base is unlocked.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "STEAL"
	prompt.ObjectText = record.displayName
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not GameState.IsLocked(base)
	prompt.Parent = record.bodyPart
	prompt.Triggered:Connect(function(otherPlayer)
		local StealService = require(script.Parent:WaitForChild("StealService"))
		StealService.TrySteal(otherPlayer, record)
	end)
	record.stealPrompt = prompt
end

-- Place a record (built by the caller) on the first free pad of the
-- player's own base. Returns false when there is no base or no free pad.
function EconomyService.PlaceOnFreePad(player, record)
	local data = GameState.Get(player)
	if not data or not data.baseIndex then
		return false
	end
	local base = GameState.GetBase(data.baseIndex)
	if not base then
		return false
	end
	for i = 1, 6 do
		if not base.pads[i] then
			attachToPad(player, record, base, i)
			EconomyService.SendState(player)
			return true
		end
	end
	return false
end

-- Place the longest-carried brainrot on a free display pad of your base.
-- Called when you walk onto your own base floor.
function EconomyService.TryPlace(player)
	local data = GameState.Get(player)
	if not data or #data.carrying == 0 or not data.baseIndex then
		return
	end
	local now = os.clock()
	if now - data.lastPlaceAt < 0.4 then
		return
	end
	local base = GameState.GetBase(data.baseIndex)
	if not base then
		return
	end
	local padIndex = nil
	for i = 1, 6 do
		if not base.pads[i] then
			padIndex = i
			break
		end
	end
	if not padIndex then
		data.lastPlaceAt = now
		Remotes.Notify(player, "Base full! (6 brainrots max)")
		return
	end
	data.lastPlaceAt = now

	local record = table.remove(data.carrying, 1)
	attachToPad(player, record, base, padIndex)
	data.stats.placed += 1

	EconomyService.SendState(player)
	Remotes.Notify(player, record.displayName .. " placed! Earning $" .. record.income .. "/s")
end

function EconomyService.Start()
	-- Income tick: every second, placed brainrots pay their owners.
	task.spawn(function()
		while true do
			task.wait(1)
			for player, data in pairs(GameState.players) do
				local income = GameState.ComputeIncomePerSec(player)
				if income > 0 then
					data.money += income
					data.stats.earned += income
					GameState.SyncLeaderstats(player)
				end
				EconomyService.SendState(player)
			end
		end
	end)

	-- Carried brainrots ride above their owner's head, slowly spinning.
	RunService.Heartbeat:Connect(function(dt)
		for player, data in pairs(GameState.players) do
			if #data.carrying > 0 then
				local character = player.Character
				local head = character and character:FindFirstChild("Head")
				if head then
					for i, record in ipairs(data.carrying) do
						record.spinPhase += dt * 1.6
						local pos = head.Position + Vector3.new(0, 2.7 + (i - 1) * 3.6, 0)
						record.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, record.spinPhase, 0))
					end
				end
			end
		end
	end)
end

return EconomyService
