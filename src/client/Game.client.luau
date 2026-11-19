-- Game.client.luau - BRAINROT BUNKER client bootstrap.
-- Builds the HUD and binds the L (lock) and R (rebirth) keys through
-- ContextActionService, so they never fight the camera's arrow keys.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")

local Hud = require(script.Parent:WaitForChild("Hud"))
Hud.Start(player, remotes)

local clientAction = remotes:WaitForChild("ClientAction")

ContextActionService:BindAction("BrainrotLock", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		clientAction:FireServer("Lock")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.L)

ContextActionService:BindAction("BrainrotRebirth", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		clientAction:FireServer("Rebirth")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.R)
