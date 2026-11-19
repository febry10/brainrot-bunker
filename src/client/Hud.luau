-- Hud.luau (client ModuleScript)
-- The ScreenGui: money + income at the top centre (kept clear of Roblox's
-- own top-left menu), the cast & price list on the right, action buttons
-- bottom-right, a notify line, and the big tsunami countdown banner.
-- It only displays what the server sends and forwards button presses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Hud = {}

local function commafy(n)
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end

local function makeLabel(parent, name, size, position, anchor, text, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	if anchor then
		label.AnchorPoint = anchor
	end
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Font = font or Enum.Font.GothamBold
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = color
	button.Text = text
	button.TextSize = 17
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.5
	button.Font = Enum.Font.GothamBlack
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	button.Parent = parent
	return button
end

function Hud.Start(player, remotes)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	-- Top centre: title, money, income, rebirths, carrying.
	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.fromOffset(430, 118)
	top.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
	top.BackgroundTransparency = 0.25
	top.BorderSizePixel = 0
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 14)
	topCorner.Parent = top
	top.Parent = gui

	makeLabel(top, "Title", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 2), nil,
		"BRAINROT BUNKER", 20, Color3.fromRGB(255, 210, 90), Enum.Font.GothamBlack)
	local moneyLabel = makeLabel(top, "Money", UDim2.new(1, 0, 0, 38), UDim2.new(0, 0, 0, 26), nil,
		"$" .. commafy(Config.StartMoney), 34, Color3.fromRGB(140, 255, 140), Enum.Font.GothamBlack)
	local incomeLabel = makeLabel(top, "Income", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 64), nil,
		"+$0/s", 19, Color3.fromRGB(160, 230, 255))
	local carryLabel = makeLabel(top, "Carrying", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 90), nil,
		"Hands empty - buy a brainrot!", 15, Color3.fromRGB(255, 190, 220))

	-- Top right: the cast & price list.
	local panel = Instance.new("Frame")
	panel.Name = "CastPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -10, 0, 10)
	panel.Size = UDim2.fromOffset(252, 296)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel
	panel.Parent = gui

	makeLabel(panel, "CastTitle", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 4), nil,
		"CAST & PRICES", 18, Color3.fromRGB(255, 210, 90), Enum.Font.GothamBlack)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CastScroll"
	scroll.Position = UDim2.new(0, 8, 0, 36)
	scroll.Size = UDim2.new(1, -16, 1, -44)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = scroll
	scroll.Parent = panel

	local sorted = {}
	for _, entry in ipairs(Config.Cast) do
		table.insert(sorted, entry)
	end
	table.sort(sorted, function(a, b)
		return a.cost < b.cost
	end)
	for _, entry in ipairs(sorted) do
		local row = Instance.new("TextLabel")
		row.Name = "Row_" .. entry.id
		row.Size = UDim2.new(1, 0, 0, 20)
		row.BackgroundTransparency = 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = entry.name .. "  $" .. commafy(entry.cost) .. "  +" .. entry.income .. "/s"
		row.TextSize = 13
		row.TextColor3 = Config.RarityColor(entry.rarity)
		row.Font = Enum.Font.GothamBold
		row.Parent = scroll
	end

	-- Bottom right: action buttons.
	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.AnchorPoint = Vector2.new(1, 1)
	buttons.Position = UDim2.new(1, -10, 1, -10)
	buttons.Size = UDim2.fromOffset(188, 192)
	buttons.BackgroundTransparency = 1
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Vertical
	buttonLayout.Padding = UDim.new(0, 6)
	buttonLayout.Parent = buttons
	buttons.Parent = gui

	local lockButton = makeButton(buttons, "LockButton", "LOCK BASE (L)", Color3.fromRGB(60, 160, 90))
	local rebirthButton = makeButton(buttons, "RebirthButton", "REBIRTH (R)", Color3.fromRGB(150, 70, 220))
	local speedButton = makeButton(buttons, "SpeedButton", "SPEED +4  $" .. commafy(Config.Upgrades.Speed.cost), Color3.fromRGB(60, 130, 220))
	local carryButton = makeButton(buttons, "CarryButton", "CARRY 2  $" .. commafy(Config.Upgrades.Carry.cost), Color3.fromRGB(220, 130, 50))

	local clientAction = remotes:WaitForChild("ClientAction")
	lockButton.MouseButton1Click:Connect(function()
		clientAction:FireServer("Lock")
	end)
	rebirthButton.MouseButton1Click:Connect(function()
		clientAction:FireServer("Rebirth")
	end)
	speedButton.MouseButton1Click:Connect(function()
		clientAction:FireServer("BuySpeed")
	end)
	carryButton.MouseButton1Click:Connect(function()
		clientAction:FireServer("BuyCarry")
	end)

	-- Bottom centre: one-line feedback.
	local notifyLabel = makeLabel(gui, "Notify", UDim2.new(0, 700, 0, 34), UDim2.new(0.5, 0, 1, -64), Vector2.new(0.5, 1),
		"", 20, Color3.fromRGB(255, 240, 160), Enum.Font.GothamBlack)
	notifyLabel.Visible = false

	-- Centre: the tsunami banner.
	local banner = makeLabel(gui, "WaveBanner", UDim2.new(0, 760, 0, 64), UDim2.new(0.5, 0, 0, 140), Vector2.new(0.5, 0),
		"", 40, Color3.fromRGB(255, 90, 90), Enum.Font.GothamBlack)
	banner.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Server -> client wiring.
	remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(state)
		moneyLabel.Text = "$" .. commafy(state.money)
		incomeLabel.Text = "+$" .. commafy(state.income) .. "/s    Rebirths: " .. state.rebirths .. " (x" .. state.multiplier .. ")"
		if state.carrying > 0 then
			carryLabel.Text = "Carrying " .. state.carrying .. "/" .. state.capacity .. ": " .. state.carryName
		else
			carryLabel.Text = "Hands empty - buy a brainrot!"
		end
	end)

	local notifyToken = 0
	remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text)
		notifyToken += 1
		local token = notifyToken
		notifyLabel.Text = text
		notifyLabel.Visible = true
		task.delay(2.6, function()
			if notifyToken == token then
				notifyLabel.Visible = false
			end
		end)
	end)

	remotes:WaitForChild("WaveWarning").OnClientEvent:Connect(function(seconds)
		task.spawn(function()
			for i = seconds, 1, -1 do
				banner.Text = "TSUNAMI GELOMBANG OTAK IN " .. i .. " - GET TO A BASE!"
				banner.Visible = true
				task.wait(1)
			end
			banner.Text = "TSUNAMI!"
			task.wait(1.2)
			banner.Visible = false
		end)
	end)
end

return Hud
