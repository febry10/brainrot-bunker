-- WorldBuilder.luau (server ModuleScript)
-- Builds the whole 3D world at runtime, deterministically: a plaza island,
-- the conveyor lane across the middle, eight player base plots around it,
-- the spawn + upgrade shop, and bright decor. Returns the geometry refs the
-- services need (base pads/signs/lock parts, shop prompts, spawn CFrame).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local WorldBuilder = {}

local BASE_COLORS = {
	Color3.fromRGB(255, 95, 95), Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 225, 80),
	Color3.fromRGB(110, 220, 110), Color3.fromRGB(80, 200, 220), Color3.fromRGB(90, 130, 255),
	Color3.fromRGB(180, 110, 255), Color3.fromRGB(255, 110, 200),
}

local function makePart(parent, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local function makeLabel(parent, size, offset, lines)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = size
	billboard.StudsOffset = offset
	billboard.MaxDistance = 160
	billboard.AlwaysOnTop = false
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = billboard
	local labels = {}
	for i, spec in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. i
		label.Size = UDim2.new(1, 0, 0, spec.height)
		label.BackgroundTransparency = 1
		label.Text = spec.text
		label.TextColor3 = spec.color
		label.TextStrokeTransparency = 0.3
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = billboard
		labels[i] = label
	end
	billboard.Parent = parent
	return labels
end

local function buildPalm(parent, x, z)
	local palm = Instance.new("Model")
	palm.Name = "Palm"
	local trunk = makePart(palm, "Trunk", Vector3.new(1.1, 7.5, 1.1),
		CFrame.new(x, 3.75, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(140, 100, 60), Enum.Material.Wood, Enum.PartType.Cylinder)
	trunk.CanCollide = false
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + x
		local leaf = makePart(palm, "Leaf", Vector3.new(5.2, 0.9, 2.1),
			CFrame.new(x + math.cos(angle) * 1.9, 7.6, z + math.sin(angle) * 1.9) * CFrame.Angles(0, -angle, math.rad(12)),
			Color3.fromRGB(60, 190, 80))
		leaf.CanCollide = false
	end
	palm.Parent = parent
end

local function buildBase(parent, index, cx, cz, isNorth)
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base" .. index
	local color = BASE_COLORS[index]
	-- North bases sit at z<0 and face +Z toward the plaza; south face -Z.
	local faceAngle = isNorth and math.rad(-90) or math.rad(90)
	local backZ = isNorth and (cz - 13) or (cz + 13)
	local frontZ = isNorth and (cz + 15) or (cz - 15)

	local floor = makePart(baseFolder, "Floor", Vector3.new(38, 0.4, 30), CFrame.new(cx, 0, cz), color, Enum.Material.Smooth)
	floor.Name = "Floor"

	-- Low rim walls on the two sides and the back.
	makePart(baseFolder, "WallBack", Vector3.new(38, 2.2, 0.8), CFrame.new(cx, 1.3, backZ + (isNorth and -0.4 or 0.4)), color)
	makePart(baseFolder, "WallL", Vector3.new(0.8, 2.2, 30), CFrame.new(cx - 18.6, 1.3, cz), color)
	makePart(baseFolder, "WallR", Vector3.new(0.8, 2.2, 30), CFrame.new(cx + 18.6, 1.3, cz), color)

	-- Six display pads, 3 x 2.
	local pads = {}
	local padColors = Color3.fromRGB(245, 245, 245)
	for row, dz in ipairs({ -6.5, 6.5 }) do
		for col, dx in ipairs({ -11, 0, 11 }) do
			local padPart = makePart(baseFolder, "Pad", Vector3.new(7, 0.4, 7), CFrame.new(cx + dx, 0.4, cz + dz), padColors, Enum.Material.Neon)
			padPart.CanCollide = false
			pads[(row - 1) * 3 + col] = { part = padPart, pos = Vector3.new(cx + dx, 0.6, cz + dz) }
		end
	end

	-- Owner sign on a pole at the back.
	local pole = makePart(baseFolder, "SignPole", Vector3.new(0.5, 7.5, 0.5), CFrame.new(cx - 15, 3.75, backZ), Color3.fromRGB(70, 70, 80))
	pole.CanCollide = false
	local signLabels = makeLabel(pole, UDim2.fromOffset(280, 84), Vector3.new(0, 4.6, 0), {
		{ text = "EMPTY BASE", color = color, height = 46 },
		{ text = "", color = Color3.fromRGB(120, 230, 255), height = 34 },
	})

	-- Lock pad near the entrance.
	local lockPad = makePart(baseFolder, "LockPad", Vector3.new(5, 0.5, 5), CFrame.new(cx + 13.5, 0.45, frontZ + (isNorth and -3 or 3)), Color3.fromRGB(120, 255, 120), Enum.Material.Neon)
	makeLabel(lockPad, UDim2.fromOffset(120, 36), Vector3.new(0, 2.4, 0), {
		{ text = "LOCK", color = Color3.fromRGB(255, 255, 255), height = 36 },
	})

	-- Lock wall across the entrance: invisible until the base locks.
	local lockWall = makePart(baseFolder, "LockWall", Vector3.new(38, 7, 0.6), CFrame.new(cx, 3.7, frontZ), Color3.fromRGB(110, 220, 255), Enum.Material.ForceField)
	lockWall.Transparency = 1
	lockWall.CanCollide = false

	baseFolder.Parent = parent

	return {
		index = index,
		center = Vector3.new(cx, 0, cz),
		faceAngle = faceAngle,
		floor = floor,
		pads = pads,
		ownerLabel = signLabels[1],
		statusLabel = signLabels[2],
		baseColor = color,
		lockPad = lockPad,
		lockWall = lockWall,
		bounds = { minX = cx - 19, maxX = cx + 19, minZ = cz - 15, maxZ = cz + 15 },
	}
end

function WorldBuilder.Build()
	local world = Instance.new("Folder")
	world.Name = "World"

	-- Island: sand rim under a grass top.
	makePart(world, "Sand", Vector3.new(252, 3.6, 252), CFrame.new(0, -2.2, 0), Color3.fromRGB(240, 215, 150))
	local grass = makePart(world, "Grass", Vector3.new(240, 4, 240), CFrame.new(0, -2, 0), Color3.fromRGB(105, 205, 90), Enum.Material.Smooth)
	grass.Name = "Grass"

	-- Conveyor lane across the middle (X axis, z = 0).
	local belt = makePart(world, "Belt", Vector3.new(196, 0.6, 11), CFrame.new(0, 0.3, 0), Color3.fromRGB(45, 45, 55), Enum.Material.DiamondPlate)
	belt.CanCollide = false
	for _, side in ipairs({ -1, 1 }) do
		local rail = makePart(world, "BeltRail", Vector3.new(196, 0.5, 0.6), CFrame.new(0, 0.85, side * 5.6), Color3.fromRGB(80, 220, 255), Enum.Material.Neon)
		rail.CanCollide = false
	end
	for x = -90, 90, 15 do
		local stripe = makePart(world, "BeltStripe", Vector3.new(2.2, 0.1, 9.6), CFrame.new(x, 0.63, 0), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
		stripe.CanCollide = false
	end

	-- Spawn portal (west end, green) and bye portal (east end, red).
	local function portal(x, color, text)
		local folder = Instance.new("Folder")
		folder.Name = "Portal"
		for _, side in ipairs({ -1, 1 }) do
			makePart(folder, "Pillar", Vector3.new(1.4, 8, 1.4), CFrame.new(x, 4, side * 6.6), color, Enum.Material.Neon)
		end
		local beam = makePart(folder, "Beam", Vector3.new(1.4, 1.8, 14.6), CFrame.new(x, 8.4, 0), color, Enum.Material.Neon)
		makeLabel(beam, UDim2.fromOffset(200, 44), Vector3.new(0, 2.2, 0), {
			{ text = text, color = Color3.fromRGB(255, 255, 255), height = 44 },
		})
		folder.Parent = world
	end
	portal(-100, Color3.fromRGB(80, 230, 120), "SPAWN")
	portal(100, Color3.fromRGB(255, 90, 90), "BYE!")

	-- Eight bases: four north, four south.
	local bases = {}
	for i = 1, 8 do
		local isNorth = i <= 4
		local col = (i - 1) % 4
		local cx = -84 + col * 56
		local cz = isNorth and -58 or 58
		bases[i] = buildBase(world, i, cx, cz, isNorth)
	end

	-- Entrance arch + spawn, south of the conveyor.
	for _, side in ipairs({ -1, 1 }) do
		makePart(world, "ArchPillar", Vector3.new(1.6, 9.5, 1.6), CFrame.new(side * 8.5, 4.75, 20), Color3.fromRGB(255, 170, 60), Enum.Material.Smooth)
	end
	local beam = makePart(world, "ArchBeam", Vector3.new(19, 3.2, 1.6), CFrame.new(0, 10.4, 20), Color3.fromRGB(255, 170, 60), Enum.Material.Smooth)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.Parent = beam
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = "BRAINROT BUNKER"
		text.TextColor3 = Color3.fromRGB(60, 30, 90)
		text.TextScaled = true
		text.Font = Enum.Font.GothamBlack
		text.Parent = surface
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(8, 0.6, 8)
	spawn.CFrame = CFrame.new(0, 0.3, 32)
	spawn.Color = Color3.fromRGB(255, 240, 150)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = world

	-- Shop pedestals near spawn: speed, carry, rebirth.
	local function pedestal(x, z, color, title, promptText)
		local ped = makePart(world, "Pedestal", Vector3.new(3.2, 1.4, 3.2), CFrame.new(x, 0.7, z), color, Enum.Material.Smooth)
		makeLabel(ped, UDim2.fromOffset(230, 44), Vector3.new(0, 3.2, 0), {
			{ text = title, color = Color3.fromRGB(255, 255, 255), height = 44 },
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = promptText
		prompt.ObjectText = title
		prompt.MaxActivationDistance = 11
		prompt.RequiresLineOfSight = false
		prompt.Parent = ped
		return prompt
	end
	local speedPrompt = pedestal(15, 32, Color3.fromRGB(80, 180, 255), "SPEED +4 - $" .. Config.Upgrades.Speed.cost, "Buy Speed")
	local carryPrompt = pedestal(22, 26, Color3.fromRGB(255, 150, 80), "CARRY +1 - $" .. Config.Upgrades.Carry.cost, "Buy Carry")
	local rebirthPrompt = pedestal(-16, 30, Color3.fromRGB(190, 90, 255), "REBIRTH - $" .. Config.RebirthCost, "Rebirth!")

	-- Decor: palms, lamp posts, clouds.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	for _, pos in ipairs({ { -108, -30 }, { -108, 40 }, { 108, -40 }, { 108, 30 }, { -40, -108 }, { 40, -108 }, { -40, 108 }, { 40, 108 }, { 108, 100 }, { -108, -100 } }) do
		buildPalm(decor, pos[1], pos[2])
	end
	for _, pos in ipairs({ { -45, -25 }, { 45, -25 }, { -45, 25 }, { 45, 25 }, { 0, -30 }, { 0, 42 } }) do
		local polePart = makePart(decor, "LampPole", Vector3.new(0.4, 6.5, 0.4), CFrame.new(pos[1], 3.25, pos[2]), Color3.fromRGB(60, 60, 70))
		polePart.CanCollide = false
		local lamp = makePart(decor, "Lamp", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos[1], 6.9, pos[2]), Color3.fromRGB(255, 235, 160), Enum.Material.Neon, Enum.PartType.Ball)
		lamp.CanCollide = false
	end
	for i = 1, 5 do
		local cx = -90 + i * 34
		local cz = (i % 2 == 0) and -70 or 75
		local cloud = makePart(decor, "Cloud", Vector3.new(16, 2.6, 8), CFrame.new(cx, 58 + (i % 3) * 5, cz), Color3.fromRGB(255, 255, 255), Enum.Material.Smooth, Enum.PartType.Ball)
		cloud.CanCollide = false
		local puff = makePart(decor, "Cloud", Vector3.new(10, 2.2, 6), CFrame.new(cx + 6, 59 + (i % 3) * 5, cz + 1), Color3.fromRGB(255, 255, 255), Enum.Material.Smooth, Enum.PartType.Ball)
		puff.CanCollide = false
	end
	decor.Parent = world

	world.Parent = Workspace

	-- Folder all brainrot models live in.
	local models = Instance.new("Folder")
	models.Name = "BrainrotModels"
	models.Parent = Workspace

	return {
		bases = bases,
		spawnCFrame = CFrame.new(0, 2, 32),
		speedPrompt = speedPrompt,
		carryPrompt = carryPrompt,
		rebirthPrompt = rebirthPrompt,
	}
end

return WorldBuilder
