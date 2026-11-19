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
	local board = makePart(parent, name, size, cframe, boardColor, Enum.Material.Smooth)
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

-- 3x5 pixel glyphs for the floating entrance letters.
local GLYPHS = {
	B = { "##.", "#.#", "##.", "#.#", "##." },
	R = { "##.", "#.#", "##.", "#.#", "#.#" },
	A = { ".#.", "#.#", "###", "#.#", "#.#" },
	I = { "###", ".#.", ".#.", ".#.", "###" },
	N = { "#.#", "###", "###", "#.#", "#.#" },
	O = { ".#.", "#.#", "#.#", "#.#", ".#." },
	T = { "###", ".#.", ".#.", ".#.", ".#." },
	U = { "#.#", "#.#", "#.#", "#.#", "###" },
	K = { "#.#", "#.#", "##.", "#.#", "#.#" },
	E = { "###", "#..", "##.", "#..", "###" },
}

-- Builds one word of chunky neon block letters floating in the air.
-- Returns the x just past the word's last letter.
local function buildFloatingWord(parent, word, startX, baseY, z, color)
	local block = 0.85
	local pitch = block + 0.16
	local x = startX
	for i = 1, #word do
		local glyph = GLYPHS[string.sub(word, i, i)]
		if glyph then
			for row = 1, 5 do
				local line = glyph[row]
				for col = 1, 3 do
					if string.sub(line, col, col) == "#" then
						local px = makePart(parent, "LetterPixel",
							Vector3.new(block, block, 0.6),
							CFrame.new(x + (col - 1) * pitch, baseY + (5 - row) * pitch, z),
							color, Enum.Material.Neon)
						px.CanCollide = false
						px.CanQuery = false
						px.CastShadow = false
					end
				end
			end
			x += 3 * pitch + 0.55
		end
	end
	return x
end

-- Low fence around the island edge (gap at the south entrance), so the
-- plaza reads as a bounded arena in screenshots.
local function buildFence(parent)
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	local postColor = Color3.fromRGB(120, 85, 50)
	local railColor = Color3.fromRGB(245, 245, 245)
	local edge = 117
	local function post(x, z)
		local p = makePart(fence, "FencePost", Vector3.new(0.55, 3, 0.55), CFrame.new(x, 1.5, z), postColor, Enum.Material.Wood)
		p.CanCollide = false
		p.CastShadow = false
	end
	local function railX(z, x1, x2)
		for _, y in ipairs({ 1.2, 2.4 }) do
			local r = makePart(fence, "FenceRail", Vector3.new(x2 - x1, 0.32, 0.32), CFrame.new((x1 + x2) / 2, y, z), railColor)
			r.CanCollide = false
			r.CastShadow = false
		end
	end
	local function railZ(x, z1, z2)
		for _, y in ipairs({ 1.2, 2.4 }) do
			local r = makePart(fence, "FenceRail", Vector3.new(0.32, 0.32, z2 - z1), CFrame.new(x, y, (z1 + z2) / 2), railColor)
			r.CanCollide = false
			r.CastShadow = false
		end
	end
	for x = -edge, edge, 13 do
		post(x, -edge)
		if math.abs(x) > 10 then
			post(x, edge)
		end
		post(-edge, x)
		post(edge, x)
	end
	railX(-edge, -edge, edge)
	railX(edge, -edge, -11)
	railX(edge, 11, edge)
	railZ(-edge, -edge, edge)
	railZ(edge, -edge, edge)
	fence.Parent = parent
end

-- The big scoreboard north of the conveyor, facing the spawn hero view:
-- the whole cast in rarity colors with prices and income.
local function buildPriceBoard(parent)
	local board = makePart(parent, "PriceBoard", Vector3.new(36, 14.5, 0.8), CFrame.new(0, 8.6, -22), Color3.fromRGB(28, 24, 52), Enum.Material.Smooth)
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

	-- Colored zone dressing: a lighter carpet runner down the middle and
	-- neon-topped corner posts, so each base reads as its owner's territory.
	local carpet = makePart(baseFolder, "Carpet", Vector3.new(11, 0.14, 27), CFrame.new(cx, 0.27, cz),
		color:Lerp(Color3.fromRGB(255, 255, 255), 0.38), Enum.Material.Smooth)
	carpet.CanCollide = false
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local post = makePart(baseFolder, "CornerPost", Vector3.new(0.7, 3.6, 0.7),
				CFrame.new(cx + sx * 17.6, 1.8, cz + sz * 13.6), color)
			post.CanCollide = false
			local ball = makePart(baseFolder, "CornerBall", Vector3.new(1.25, 1.25, 1.25),
				CFrame.new(cx + sx * 17.6, 4.1, cz + sz * 13.6), color, Enum.Material.Neon, Enum.PartType.Ball)
			ball.CanCollide = false
		end
	end

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

	-- Owner sign on a pole at the back: a solid backing board in the base
	-- color with a big billboard, readable across the plaza.
	local pole = makePart(baseFolder, "SignPole", Vector3.new(0.5, 8.6, 0.5), CFrame.new(cx - 15, 4.3, backZ), Color3.fromRGB(70, 70, 80))
	pole.CanCollide = false
	local signBoard = makePart(baseFolder, "SignBoard", Vector3.new(11.5, 4, 0.5), CFrame.new(cx - 15, 9.4, backZ), Color3.fromRGB(32, 28, 52), Enum.Material.Smooth)
	signBoard.CanCollide = false
	local signTrim = makePart(baseFolder, "SignTrim", Vector3.new(12.1, 0.5, 0.55), CFrame.new(cx - 15, 11.55, backZ), color, Enum.Material.Neon)
	signTrim.CanCollide = false
	local signLabels = makeLabel(signBoard, UDim2.fromOffset(430, 128), Vector3.new(0, 0.3, 0), {
		{ text = "EMPTY BASE", color = color, height = 68 },
		{ text = "", color = Color3.fromRGB(120, 230, 255), height = 48 },
	}, 230)

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

	-- Arena dressing: perimeter fence, the cast price scoreboard behind the
	-- conveyor, and two hype boards flanking the lane.
	buildFence(world)
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

	-- Floating neon block letters over the entrance arch: the hero shot.
	local afterFirst = buildFloatingWord(world, "BRAINROT", -25.7, 13.8, 20, Color3.fromRGB(255, 190, 60))
	buildFloatingWord(world, "BUNKER", afterFirst + 2.2, 13.8, 20, Color3.fromRGB(255, 110, 200))

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
	for _, pos in ipairs({ { -108, -30 }, { -108, 40 }, { 108, -40 }, { 108, 30 }, { -40, -108 }, { 40, -108 }, { -40, 108 }, { 40, 108 }, { 108, 100 }, { -108, -100 }, { -70, -100 }, { 70, 100 }, { -95, 85 }, { 95, -85 }, { -60, 112 }, { 60, -112 }, { -112, 70 }, { 112, -70 } }) do
		buildPalm(decor, pos[1], pos[2])
	end
	for _, pos in ipairs({ { -45, -25 }, { 45, -25 }, { -45, 25 }, { 45, 25 }, { 0, -30 }, { 0, 42 }, { -90, -18 }, { 90, 18 }, { -20, -95 }, { 20, 95 }, { -100, -95 }, { 100, 95 } }) do
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
