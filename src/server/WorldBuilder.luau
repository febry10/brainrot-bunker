-- WorldBuilder.luau (server ModuleScript)
-- The world's static geometry -- the island, the market-street conveyor,
-- the old-time village, the eight base plots, the hero letters, the decor
-- -- is BAKED INTO THE PLACE FILE (Rojo JSON models under models/, mapped
-- to Workspace.World), so it is visible in Studio before any script runs
-- and can never vanish to a runtime error. This module wires only the
-- DYNAMIC layer on top of it: display pads, owner-sign and portal labels,
-- shop prompts, the cast price board and the entrance arch text. It
-- returns the geometry refs the services need (base pads/signs/lock
-- parts, shop prompts, spawn CFrame) -- the same contract as before.

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

local function makeLabel(parent, size, offset, lines, maxDistance)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = size
	billboard.StudsOffset = offset
	billboard.MaxDistance = maxDistance or 160
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

local function commafy(n)
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end

-- A freestanding board part with the same text on both large faces
-- (SurfaceGui), so it reads from either side. lines: {text, color, size}.
local function makeSignBoard(parent, name, size, cframe, boardColor, lines)
	local board = makePart(parent, name, size, cframe, boardColor, Enum.Material.SmoothPlastic)
	board.CanCollide = false
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.PixelsPerStud = 40
		surface.LightInfluence = 0
		surface.Parent = board
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.Parent = surface
		for _, spec in ipairs(lines) do
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 0, spec.size)
			label.BackgroundTransparency = 1
			label.Text = spec.text
			label.TextColor3 = spec.color
			label.TextScaled = true
			label.Font = Enum.Font.GothamBlack
			label.Parent = surface
		end
	end
	return board
end

-- The big scoreboard north of the conveyor, facing the spawn hero view:
-- the whole cast in rarity colors with prices and income.
local function buildPriceBoard(parent)
	local board = makePart(parent, "PriceBoard", Vector3.new(36, 14.5, 0.8), CFrame.new(0, 8.6, -22), Color3.fromRGB(28, 24, 52), Enum.Material.SmoothPlastic)
	board.CanCollide = false
	for _, dz in ipairs({ -15, 15 }) do
		local leg = makePart(parent, "PriceBoardLeg", Vector3.new(1.2, 3.4, 1.2), CFrame.new(dz, 1.7, -22), Color3.fromRGB(70, 70, 85))
		leg.CanCollide = false
	end

	local sorted = {}
	for _, entry in ipairs(Config.Cast) do
		table.insert(sorted, entry)
	end
	table.sort(sorted, function(a, b)
		return a.cost < b.cost
	end)

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.PixelsPerStud = 40
		surface.LightInfluence = 0
		surface.Parent = board

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 64)
		title.Position = UDim2.new(0, 0, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = "CAST & PRICES"
		title.TextColor3 = Color3.fromRGB(255, 210, 90)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBlack
		title.Parent = surface

		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.Size = UDim2.new(1, 0, 0, 34)
		sub.Position = UDim2.new(0, 0, 0, 74)
		sub.BackgroundTransparency = 1
		sub.Text = "MUTATIONS: GOLD x5   -   RAINBOW x10"
		sub.TextColor3 = Color3.fromRGB(160, 230, 255)
		sub.TextScaled = true
		sub.Font = Enum.Font.GothamBold
		sub.Parent = surface

		for col = 0, 1 do
			local column = Instance.new("Frame")
			column.Name = "Col" .. col
			column.BackgroundTransparency = 1
			column.Position = UDim2.new(col * 0.5 + 0.015, 0, 0, 122)
			column.Size = UDim2.new(0.47, 0, 0, 420)
			local layout = Instance.new("UIListLayout")
			layout.FillDirection = Enum.FillDirection.Vertical
			layout.Padding = UDim.new(0, 4)
			layout.Parent = column
			column.Parent = surface
			for i = col * 7 + 1, col * 7 + 7 do
				local entry = sorted[i]
				if entry then
					local row = Instance.new("TextLabel")
					row.Size = UDim2.new(1, 0, 0, 52)
					row.BackgroundTransparency = 1
					row.TextXAlignment = Enum.TextXAlignment.Left
					row.Text = entry.name .. "  $" .. commafy(entry.cost) .. "  +" .. entry.income .. "/s"
					row.TextColor3 = Config.RarityColor(entry.rarity)
					row.TextScaled = true
					row.Font = Enum.Font.GothamBold
					row.Parent = column
				end
			end
		end
	end
end

-- Wires one static base plot (Workspace.World.Bases.Base<index>) with its
-- dynamic layer: the six display pads, the owner sign labels and the lock
-- label. Layout math matches the baked plot exactly: north bases (1-4)
-- sit at z=-58 and face +Z toward the plaza; south bases face -Z.
local function assembleBase(world, index)
	local isNorth = index <= 4
	local col = (index - 1) % 4
	local cx = -84 + col * 56
	local cz = isNorth and -58 or 58
	local faceAngle = isNorth and math.rad(-90) or math.rad(90)
	local color = BASE_COLORS[index]

	local baseFolder = world:WaitForChild("Bases"):WaitForChild("Base" .. index)
	local floor = baseFolder:WaitForChild("Floor")
	local signBoard = baseFolder:WaitForChild("SignBoard")
	local lockPad = baseFolder:WaitForChild("LockPad")
	local lockWall = baseFolder:WaitForChild("LockWall")

	-- Six display pads, 3 x 2.
	local pads = {}
	local padColor = Color3.fromRGB(245, 245, 245)
	for row, dz in ipairs({ -6.5, 6.5 }) do
		for pcol, dx in ipairs({ -11, 0, 11 }) do
			local padPart = makePart(baseFolder, "Pad", Vector3.new(7, 0.4, 7), CFrame.new(cx + dx, 0.4, cz + dz), padColor, Enum.Material.Neon)
			padPart.CanCollide = false
			pads[(row - 1) * 3 + pcol] = { part = padPart, pos = Vector3.new(cx + dx, 0.6, cz + dz) }
		end
	end

	-- Owner sign labels on the baked sign board at the back of the plot.
	local signLabels = makeLabel(signBoard, UDim2.fromOffset(430, 128), Vector3.new(0, 0.3, 0), {
		{ text = "EMPTY BASE", color = color, height = 68 },
		{ text = "", color = Color3.fromRGB(120, 230, 255), height = 48 },
	}, 230)

	-- "LOCK" label floating over the baked lock pad.
	makeLabel(lockPad, UDim2.fromOffset(120, 36), Vector3.new(0, 2.4, 0), {
		{ text = "LOCK", color = Color3.fromRGB(255, 255, 255), height = 36 },
	})

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
	-- The baked static world (models/ -> Workspace.World).
	local world = Workspace:WaitForChild("World")

	-- Portal captions on the baked conveyor portal beams.
	local conveyor = world:WaitForChild("Conveyor")
	makeLabel(conveyor:WaitForChild("SpawnPortal"):WaitForChild("Beam"), UDim2.fromOffset(200, 44), Vector3.new(0, 2.2, 0), {
		{ text = "SPAWN", color = Color3.fromRGB(255, 255, 255), height = 44 },
	})
	makeLabel(conveyor:WaitForChild("ByePortal"):WaitForChild("Beam"), UDim2.fromOffset(200, 44), Vector3.new(0, 2.2, 0), {
		{ text = "BYE!", color = Color3.fromRGB(255, 255, 255), height = 44 },
	})

	-- Eight bases: four north, four south.
	local bases = {}
	for i = 1, 8 do
		bases[i] = assembleBase(world, i)
	end

	-- Hype boards: the cast price scoreboard behind the conveyor and two
	-- flank boards by the lane (SurfaceGui text stays dynamic by design).
	buildPriceBoard(world)
	makeSignBoard(world, "MutationBoard", Vector3.new(17, 6.5, 0.6),
		CFrame.new(-64, 3.25, -13.5) * CFrame.Angles(0, math.rad(18), 0), Color3.fromRGB(32, 28, 52), {
			{ text = "MUTATIONS!", color = Color3.fromRGB(255, 210, 90), size = 92 },
			{ text = "GOLD x5 - RAINBOW x10", color = Color3.fromRGB(120, 230, 255), size = 62 },
		})
	makeSignBoard(world, "StealBoard", Vector3.new(17, 6.5, 0.6),
		CFrame.new(64, 3.25, 13.5) * CFrame.Angles(0, math.rad(-18), 0), Color3.fromRGB(32, 28, 52), {
			{ text = "STEAL & LOCK!", color = Color3.fromRGB(255, 110, 110), size = 92 },
			{ text = "Guard your bunker!", color = Color3.fromRGB(255, 255, 255), size = 62 },
		})

	-- Entrance arch over the spawn (the floating BRAINROT BUNKER block
	-- letters above it are baked into the place file).
	for _, side in ipairs({ -1, 1 }) do
		makePart(world, "ArchPillar", Vector3.new(1.6, 9.5, 1.6), CFrame.new(side * 8.5, 4.75, 20), Color3.fromRGB(255, 170, 60), Enum.Material.SmoothPlastic)
	end
	local beam = makePart(world, "ArchBeam", Vector3.new(19, 3.2, 1.6), CFrame.new(0, 10.4, 20), Color3.fromRGB(255, 170, 60), Enum.Material.SmoothPlastic)
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

	-- Shop prompts on the baked pedestals near spawn: speed, carry, rebirth.
	local plaza = world:WaitForChild("Plaza")
	local function pedestal(partName, title, promptText)
		local ped = plaza:WaitForChild(partName)
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
	local speedPrompt = pedestal("SpeedPedestal", "SPEED +4 - $" .. Config.Upgrades.Speed.cost, "Buy Speed")
	local carryPrompt = pedestal("CarryPedestal", "CARRY +1 - $" .. Config.Upgrades.Carry.cost, "Buy Carry")
	local rebirthPrompt = pedestal("RebirthPedestal", "REBIRTH - $" .. Config.RebirthCost, "Rebirth!")
	local fusionPrompt = pedestal("FusionPedestal", "FUSION - 3 = 1 TIER UP!", "Fuse!")

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
		fusionPrompt = fusionPrompt,
	}
end

return WorldBuilder
