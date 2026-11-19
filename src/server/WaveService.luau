-- WaveService.luau (server ModuleScript)
-- The hazards, one per populated world, sharing one sweep engine:
--  - Village: every Config.WaveInterval seconds a "TSUNAMI GELOMBANG
--    OTAK" is announced (clients show the countdown banner), then a
--    translucent blue wall sweeps the island west to east.
--  - City: offset by half an interval, a "BLACKOUT" - a dark surge wall
--    sweeps the streets the same way (announced via the Announce remote).
-- Any player a wall catches outside a base plot is swept back to that
-- world's spawn and drops what they were carrying; players inside the
-- hazard's region who are not caught count it as survived (quest stat).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local WaveService = {}

local function isInsideAnyBase(position)
	for _, base in ipairs(GameState.bases) do
		local b = base.world.bounds
		if position.X >= b.minX and position.X <= b.maxX and position.Z >= b.minZ and position.Z <= b.maxZ then
			return true
		end
	end
	return false
end

local function inRegion(position, region)
	return math.abs(position.X - region.cx) <= region.r
		and math.abs(position.Z - region.cz) <= region.r
		and position.Y < region.maxY
end

local function sweepPlayer(player, spawnCFrame, text)
	local data = GameState.Get(player)
	local character = player.Character
	if not character then
		return
	end
	-- Drop carried brainrots: the hazard washes them away for good.
	if data then
		for _, record in ipairs(data.carrying) do
			GameState.DestroyBrainrot(record)
		end
		data.carrying = {}
	end
	character:PivotTo(spawnCFrame + Vector3.new(0, 2, 0))
	Remotes.Notify(player, text)
	local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
	EconomyService.SendState(player)
end

-- One west-to-east sweep through a world's region.
local function sweep(cfg)
	local wall = Instance.new("Part")
	wall.Name = cfg.wallName
	wall.Size = Vector3.new(8, 26, 240)
	wall.Color = cfg.wallColor
	wall.Material = cfg.wallMaterial
	wall.Transparency = cfg.wallTransparency
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanQuery = false
	wall.Parent = Workspace

	local hit = {}
	local x = cfg.region.cx - 135
	local xEnd = cfg.region.cx + 135
	while x <= xEnd do
		wall.CFrame = CFrame.new(x, cfg.region.cy, cfg.region.cz)
		for player, _ in pairs(GameState.players) do
			if not hit[player] then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and inRegion(root.Position, cfg.region)
					and root.Position.X <= x and not isInsideAnyBase(root.Position) then
					hit[player] = true
					sweepPlayer(player, cfg.spawnCFrame, cfg.caughtText)
				end
			end
		end
		x += 90 * 0.05 -- 90 studs per second
		task.wait(0.05)
	end
	wall:Destroy()
	-- Everyone inside the region the wall never touched survived it.
	for player, data in pairs(GameState.players) do
		if not hit[player] then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and inRegion(root.Position, cfg.region) then
				data.stats.wavesSurvived += 1
			end
		end
	end
end

function WaveService.Start(world)
	local villageSpawn = world and world.worlds and world.worlds.Village and world.worlds.Village.spawnCFrame
	local citySpawn = world and world.worlds and world.worlds.City and world.worlds.City.spawnCFrame

	if villageSpawn then
		task.spawn(function()
			-- Let the world settle and the first players arrive before wave one.
			task.wait(20)
			while true do
				task.wait(Config.WaveInterval)
				Remotes.Get("WaveWarning"):FireAllClients(Config.WaveWarningTime)
				task.wait(Config.WaveWarningTime)
				sweep({
					region = { cx = 0, cz = 0, cy = 11, r = 140, maxY = 100 },
					spawnCFrame = villageSpawn,
					wallName = "TsunamiWall",
					wallColor = Color3.fromRGB(60, 160, 255),
					wallMaterial = Enum.Material.Glass,
					wallTransparency = 0.35,
					caughtText = "The TSUNAMI swept you back to spawn!",
				})
			end
		end)
	end

	if citySpawn then
		task.spawn(function()
			-- Offset by half an interval so the two hazards alternate.
			task.wait(20 + Config.WaveInterval / 2)
			while true do
				task.wait(Config.WaveInterval)
				Remotes.Get("Announce"):FireAllClients(
					"BLACKOUT INCOMING IN " .. Config.WaveWarningTime .. "s - GET TO A CITY BASE!")
				task.wait(Config.WaveWarningTime)
				sweep({
					region = { cx = 800, cz = 0, cy = 11, r = 140, maxY = 100 },
					spawnCFrame = citySpawn,
					wallName = "BlackoutWall",
					wallColor = Color3.fromRGB(8, 8, 14),
					wallMaterial = Enum.Material.SmoothPlastic,
					wallTransparency = 0.45,
					caughtText = "The BLACKOUT swept you back to the city spawn!",
				})
			end
		end)
	end
end

return WaveService
