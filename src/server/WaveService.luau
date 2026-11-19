-- WaveService.luau (server ModuleScript)
-- The hazard: every Config.WaveInterval seconds a "TSUNAMI GELOMBANG OTAK"
-- is announced (clients show the countdown banner), then a translucent
-- blue wall sweeps the plaza west to east. Any player it catches outside
-- a base plot is swept back to spawn and drops what they were carrying.

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

local function sweepPlayer(player, spawnCFrame)
	local data = GameState.Get(player)
	local character = player.Character
	if not character then
		return
	end
	-- Drop carried brainrots: the wave washes them away for good.
	if data then
		for _, record in ipairs(data.carrying) do
			GameState.DestroyBrainrot(record)
		end
		data.carrying = {}
	end
	character:PivotTo(spawnCFrame + Vector3.new(0, 2, 0))
	Remotes.Notify(player, "The TSUNAMI swept you back to spawn!")
	local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
	EconomyService.SendState(player)
end

function WaveService.Start(spawnCFrame)
	task.spawn(function()
		-- Let the world settle and the first players arrive before wave one.
		task.wait(20)
		while true do
			task.wait(Config.WaveInterval)
			Remotes.Get("WaveWarning"):FireAllClients(Config.WaveWarningTime)
			task.wait(Config.WaveWarningTime)

			local wall = Instance.new("Part")
			wall.Name = "TsunamiWall"
			wall.Size = Vector3.new(8, 26, 240)
			wall.Color = Color3.fromRGB(60, 160, 255)
			wall.Material = Enum.Material.Glass
			wall.Transparency = 0.35
			wall.Anchored = true
			wall.CanCollide = false
			wall.CanQuery = false
			wall.Parent = Workspace

			local hit = {}
			local x = -135
			while x <= 135 do
				wall.CFrame = CFrame.new(x, 11, 0)
				for player, _ in pairs(GameState.players) do
					if not hit[player] then
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if root and root.Position.X <= x and not isInsideAnyBase(root.Position) then
							hit[player] = true
							sweepPlayer(player, spawnCFrame)
						end
					end
				end
				x += 90 * 0.05 -- 90 studs per second
				task.wait(0.05)
			end
			wall:Destroy()
			-- Everyone the wave never touched survived it (quest counter).
			for player, data in pairs(GameState.players) do
				if not hit[player] then
					data.stats.wavesSurvived += 1
				end
			end
		end
	end)
end

return WaveService
