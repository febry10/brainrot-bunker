-- CharacterFactory.luau (server ModuleScript)
-- Builds one brainrot as a Model of anchored Parts: a rarity-colored disc,
-- a blocky body and head, two eyes on its +X face (it walks toward +X), one
-- signature prop, and a BillboardGui label (name / rarity / $ per second).
-- The model's pivot sits at the bottom of the disc, so PivotTo places it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local CharacterFactory = {}

local function makePart(name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	return part
end

-- Prop builders: each adds its parts to the model. ctx carries the colors
-- and the anchor positions of the standard body (see Build below).
local PROP_BUILDERS = {
	mustache = function(model, ctx)
		local mo = makePart("Mustache", Vector3.new(0.16, 0.28, 1.15), CFrame.new(0.88, 3.22, 0), Color3.fromRGB(235, 235, 235))
		mo.Parent = model
	end,
	antenna = function(model, ctx)
		local stick = makePart("Antenna", Vector3.new(0.12, 1.1, 0.12), CFrame.new(0, 4.95, 0), Color3.fromRGB(60, 60, 60))
		stick.Parent = model
		local tip = makePart("AntennaTip", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 5.6, 0), ctx.accent, Enum.Material.Neon, Enum.PartType.Ball)
		tip.Parent = model
	end,
	scarf = function(model, ctx)
		local scarf = makePart("Scarf", Vector3.new(2.0, 0.4, 2.0),
			CFrame.new(0, 2.82, 0), ctx.accent, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		scarf.Parent = model
	end,
	wings = function(model, ctx)
		for _, side in ipairs({ -1, 1 }) do
			local wing = makePart("Wing", Vector3.new(0.16, 1.3, 1.7),
				CFrame.new(-0.95, 2.3, side * 0.95) * CFrame.Angles(math.rad(side * 18), 0, math.rad(-14)), ctx.accent)
			wing.Parent = model
		end
	end,
	chili = function(model, ctx)
		local chili = makePart("Chili", Vector3.new(0.55, 1.15, 0.55),
			CFrame.new(0.45, 4.75, 0.55) * CFrame.Angles(0, 0, math.rad(28)), Color3.fromRGB(225, 40, 35), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		chili.Parent = model
		local stem = makePart("ChiliStem", Vector3.new(0.2, 0.45, 0.2), CFrame.new(0.22, 5.3, 0.55), Color3.fromRGB(60, 170, 60))
		stem.Parent = model
	end,
	ears = function(model, ctx)
		for _, side in ipairs({ -1, 1 }) do
			local ear = Instance.new("WedgePart")
			ear.Name = "Ear"
			ear.Size = Vector3.new(0.7, 0.8, 0.35)
			ear.CFrame = CFrame.new(0, 4.65, side * 0.55) * CFrame.Angles(0, side > 0 and 0 or math.rad(180), 0)
			ear.Color = ctx.body
			ear.Material = Enum.Material.SmoothPlastic
			ear.Anchored = true
			ear.CanCollide = false
			ear.CanQuery = false
			ear.Parent = model
		end
	end,
	horns = function(model, ctx)
		for _, side in ipairs({ -1, 1 }) do
			local horn = makePart("Horn", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 4.62, side * 0.62), ctx.accent, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			horn.Parent = model
		end
	end,
	crown = function(model, ctx)
		local band = makePart("Crown", Vector3.new(1.25, 0.5, 1.25), CFrame.new(0, 4.68, 0), Color3.fromRGB(255, 205, 50), Enum.Material.Metal)
		band.Parent = model
		for _, dz in ipairs({ -0.45, 0.45 }) do
			for _, dx in ipairs({ -0.45, 0.45 }) do
				local spike = makePart("CrownSpike", Vector3.new(0.28, 0.5, 0.28), CFrame.new(dx, 5.1, dz), Color3.fromRGB(255, 205, 50), Enum.Material.Metal)
				spike.Parent = model
			end
		end
	end,
	halo = function(model, ctx)
		local halo = makePart("Halo", Vector3.new(1.7, 0.14, 1.7),
			CFrame.new(0, 4.95, 0), Color3.fromRGB(255, 225, 90), Enum.Material.Neon, Enum.PartType.Cylinder)
		halo.Parent = model
	end,
	glasses = function(model, ctx)
		for _, side in ipairs({ -1, 1 }) do
			local lens = makePart("Lens", Vector3.new(0.1, 0.55, 0.55), CFrame.new(0.87, 3.72, side * 0.42), Color3.fromRGB(30, 30, 40), Enum.Material.Glass)
			lens.Parent = model
		end
		local bridge = makePart("GlassesBridge", Vector3.new(0.1, 0.12, 0.35), CFrame.new(0.87, 3.78, 0), Color3.fromRGB(30, 30, 40))
		bridge.Parent = model
	end,
	cap = function(model, ctx)
		local top = makePart("Cap", Vector3.new(1.85, 0.32, 1.85),
			CFrame.new(0, 4.52, 0), ctx.accent, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		top.Parent = model
		local brim = makePart("CapBrim", Vector3.new(0.9, 0.12, 1.3), CFrame.new(1.15, 4.42, 0), ctx.accent)
		brim.Parent = model
	end,
	cane = function(model, ctx)
		local cane = makePart("Cane", Vector3.new(0.16, 2.6, 0.16), CFrame.new(0.3, 1.3, 1.25), Color3.fromRGB(120, 80, 45))
		cane.Parent = model
	end,
}

-- Build(entry, mutation) -> model, recordVisuals { root, body, head }
-- The caller wraps the model in a brainrot record and moves it around.
function CharacterFactory.Build(entry, mutation)
	local income = Config.IncomeFor(entry, mutation)
	local displayName = Config.DisplayName(entry, mutation)
	local rarityColor = Config.RarityColor(entry.rarity)

	local bodyColor = entry.body
	local headColor = entry.head
	local accentColor = entry.accent
	local bodyMaterial = Enum.Material.SmoothPlastic
	local discColor = rarityColor
	if mutation == "Gold" then
		bodyColor = Color3.fromRGB(255, 205, 50)
		headColor = Color3.fromRGB(255, 215, 80)
		bodyMaterial = Enum.Material.Metal
		discColor = Color3.fromRGB(255, 205, 50)
	elseif mutation == "Rainbow" then
		bodyColor = Color3.fromRGB(255, 90, 200)
		headColor = Color3.fromRGB(120, 220, 255)
		bodyMaterial = Enum.Material.Neon
		discColor = Color3.fromRGB(255, 90, 200)
	end

	local model = Instance.new("Model")
	model.Name = "Brainrot_" .. entry.id

	-- Invisible pivot anchor at the model's origin (bottom of the disc).
	local root = makePart("Root", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.2, 0), Color3.fromRGB(0, 0, 0))
	root.Transparency = 1
	root.Parent = model

	local disc = makePart("Disc", Vector3.new(2.7, 0.3, 2.7),
		CFrame.new(0, 0.15, 0), discColor, Enum.Material.Neon, Enum.PartType.Cylinder)
	disc.Parent = model

	local body = makePart("Body", Vector3.new(2.2, 2.5, 1.5), CFrame.new(0, 1.55, 0), bodyColor, bodyMaterial)
	body.Parent = model

	local head = makePart("Head", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, 3.62, 0), headColor, bodyMaterial)
	head.Parent = model

	-- Eyes on the +X face.
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Vector3.new(0.14, 0.38, 0.38), CFrame.new(0.87, 3.78, side * 0.4), Color3.fromRGB(20, 20, 25), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		eye.Parent = model
	end
	local mouth = makePart("Mouth", Vector3.new(0.12, 0.16, 0.7), CFrame.new(0.87, 3.3, 0), Color3.fromRGB(120, 40, 40))
	mouth.Parent = model

	local propBuilder = PROP_BUILDERS[entry.prop]
	if propBuilder then
		propBuilder(model, { body = bodyColor, head = headColor, accent = accentColor })
	end

	-- Spawn spectacle: Epic and rarer brainrots carry a permanent pillar of
	-- light and sparkles, so a screenshot anywhere catches the drama; mutated
	-- ones sparkle too, and Rainbow ones glow with a real point light.
	local rarityRank = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythic = 5 }
	if rarityRank[entry.rarity] >= 3 then
		local beam = makePart("SpawnBeam", Vector3.new(1.4, 30, 1.4), CFrame.new(0, 15, 0), rarityColor, Enum.Material.Neon)
		beam.Transparency = 0.6
		beam.CanQuery = false
		beam.Parent = model
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = rarityColor
		sparkles.Parent = body
	end
	if mutation ~= "None" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Config.Mutations[mutation].color
		sparkles.Parent = body
	end
	if mutation == "Rainbow" then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 90, 200)
		light.Range = 14
		light.Brightness = 2
		light.Parent = head
	end

	-- Floating label: name (rarity color), then "RARITY - $X/s". Bigger for
	-- rarer brainrots, and readable from further away.
	local labelMul = Config.RarityLabelMul[entry.rarity] or 1
	local scale = Config.RarityScale[entry.rarity] or 1
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(math.floor(230 * labelMul), math.floor(64 * labelMul))
	billboard.StudsOffset = Vector3.new(0, 2.6 * scale, 0)
	billboard.MaxDistance = 120
	billboard.AlwaysOnTop = false

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = billboard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, math.floor(34 * labelMul))
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = displayName
	nameLabel.TextColor3 = (mutation ~= "None") and Config.Mutations[mutation].color or rarityColor
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Parent = billboard

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Size = UDim2.new(1, 0, 0, math.floor(26 * labelMul))
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = string.upper(entry.rarity) .. "  -  $" .. income .. "/s"
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.TextStrokeTransparency = 0.35
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.Parent = billboard

	billboard.Parent = head

	model.PrimaryPart = root

	-- Rarer brainrots are built bigger (presentation only; the pivot stays
	-- at the bottom of the disc, so PivotTo placement is unchanged).
	if scale ~= 1 then
		model:ScaleTo(scale)
	end

	return model, { root = root, body = body, head = head }
end

return CharacterFactory
