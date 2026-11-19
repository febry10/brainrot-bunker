-- DayNightService.luau (server ModuleScript)
-- A full Lighting ClockTime cycle every Config.DayLengthSeconds. While it
-- is night (Config.NightStartHour..NightEndHour) two things change: the
-- village lamps switch their PointLights on, and conveyor spawns roll
-- mutations with boosted odds (ConveyorService reads GameState.isNight,
-- the flag maintained here). The HUD shows the phase from the same flag.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))

local DayNightService = {}

function DayNightService.Start()
	-- Cache every lamp light baked into the world (Decor lamps, bridge and
	-- dock lamps, stone lanterns) once; toggling them is then trivial.
	local lampLights = {}
	local world = Workspace:WaitForChild("World")
	for _, descendant in ipairs(world:GetDescendants()) do
		if descendant:IsA("PointLight") then
			table.insert(lampLights, descendant)
		end
	end

	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / Config.DayLengthSeconds) % 24
			local hour = Lighting.ClockTime
			local night = hour >= Config.NightStartHour or hour < Config.NightEndHour
			if night ~= GameState.isNight then
				GameState.isNight = night
				for _, light in ipairs(lampLights) do
					light.Enabled = night
				end
				print("[BrainrotBunker] " .. (night and "night falls - mutations boosted" or "day breaks"))
			end
		end
	end)
end

return DayNightService
