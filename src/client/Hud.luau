-- Hud.luau (client ModuleScript)
-- The ScreenGui, designed mobile-first: exactly five top-level elements -
-- TopBar, CastPanel, ButtonsFrame, WaveBanner, Notify. The TopBar is
-- compact and width-capped at the top centre (clear of Roblox's top-left
-- menu); the cast & price list lives in a TOGGLEABLE panel on the right
-- (the CAST button in ButtonsFrame opens/closes it, and it starts closed
-- on narrow viewports); the action buttons sit in their own frame below
-- the panel's spot so they can never cover the price rows. A UIScale
-- shrinks the whole HUD proportionally on small screens. The HUD only
-- displays what the server sends and forwards button presses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
	button.Size = UDim2.new(1, 0, 0, 40)
	button.BackgroundColor3 = color
	button.BackgroundTransparency = 0.15
	button.Text = text
	button.TextSize = 15
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.5
	button.Font = Enum.Font.GothamBlack
	button.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.7
	stroke.Thickness = 1
	stroke.Parent = button
	button.Parent = parent
	return button
end

local function panelStroke(parent, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.3
	stroke.Thickness = 2
	stroke.Parent = parent
	return stroke
end

function Hud.Start(player, remotes)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Proportional shrink on small screens: the whole HUD scales with the
	-- viewport (never below 0.62, never above 1), so a phone keeps the
	-- same layout relationships as a desktop monitor.
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = gui
	local camera = Workspace.CurrentCamera
	local function updateScale()
		if not camera then
			return
		end
		local vs = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(vs.X / 1280, vs.Y / 720), 0.62, 1)
	end
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()

	-- Top centre, compact: title, money, income, carrying+next on one
	-- slim line, quest. Width follows the screen (44%) capped at 560px so
	-- it can never stretch into the right-hand column.
	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 8)
	top.Size = UDim2.new(0.44, 0, 0, 120)
	local topConstraint = Instance.new("UISizeConstraint")
	topConstraint.MinSize = Vector2.new(300, 120)
	topConstraint.MaxSize = Vector2.new(560, 120)
	topConstraint.Parent = top
	top.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
	top.BackgroundTransparency = 0.25
	top.BorderSizePixel = 0
	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = UDim.new(0, 14)
	topCorner.Parent = top
	panelStroke(top, Color3.fromRGB(255, 210, 90))
	top.Parent = gui

	makeLabel(top, "Title", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), nil,
		"BRAINROT BUNKER", 17, Color3.fromRGB(255, 210, 90), Enum.Font.GothamBlack)
	local moneyLabel = makeLabel(top, "Money", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 22), nil,
		"$" .. commafy(Config.StartMoney), 32, Color3.fromRGB(140, 255, 140), Enum.Font.GothamBlack)
	local moneyScale = Instance.new("UIScale")
	moneyScale.Parent = moneyLabel
	local incomeLabel = makeLabel(top, "Income", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 58), nil,
		"+$0/s", 15, Color3.fromRGB(160, 230, 255))
	local carryNextLabel = makeLabel(top, "CarryNext", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 80), nil,
		"Hands empty - buy a brainrot!", 13, Color3.fromRGB(255, 190, 220))
	local questLabel = makeLabel(top, "Quest", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 100), nil,
		"", 13, Color3.fromRGB(255, 220, 120))
	local dayLabel = makeLabel(top, "DayPhase", UDim2.new(0, 170, 0, 18), UDim2.new(1, -8, 0, 2), Vector2.new(1, 0),
		"DAY", 12, Color3.fromRGB(160, 230, 255))
	dayLabel.TextXAlignment = Enum.TextXAlignment.Right
	-- Floating "+$X" gain popup over the money line (income feedback).
	local gainLabel = makeLabel(top, "Gain", UDim2.new(0, 170, 0, 26), UDim2.new(1, -10, 0, 28), Vector2.new(1, 0),
		"", 20, Color3.fromRGB(170, 255, 170), Enum.Font.GothamBlack)
	gainLabel.TextXAlignment = Enum.TextXAlignment.Right
	gainLabel.Visible = false

	-- Top right: the cast & price list, toggleable (see the CAST button
	-- in ButtonsFrame below). Starts closed on narrow viewports so it
	-- never eats a phone screen; open on wide ones.
	local panel = Instance.new("Frame")
	panel.Name = "CastPanel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -10, 0, 10)
	panel.Size = UDim2.fromOffset(252, 296)
	panel.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Visible = not camera or camera.ViewportSize.X >= 900
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 14)
	panelCorner.Parent = panel
	panelStroke(panel, Color3.fromRGB(255, 210, 90))
	panel.Parent = gui

	local castTitle = makeLabel(panel, "CastTitle", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 4), nil,
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
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = entry.name .. "  $" .. commafy(entry.cost) .. "  +" .. entry.income .. "/s"
		row.TextSize = 14
		row.TextColor3 = Config.RarityColor(entry.rarity)
		row.Font = Enum.Font.GothamBold
		row.Parent = scroll
	end

	-- Right column, directly below the cast panel's spot: the CAST toggle
	-- plus the action buttons in their own frame, so they can never cover
	-- the price list rows.
	local buttons = Instance.new("Frame")
	buttons.Name = "ButtonsFrame"
	buttons.AnchorPoint = Vector2.new(1, 0)
	buttons.Position = UDim2.new(1, -10, 0, 314)
	buttons.Size = UDim2.fromOffset(200, 270)
	buttons.BackgroundTransparency = 1
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Vertical
	buttonLayout.Padding = UDim.new(0, 6)
	buttonLayout.Parent = buttons
	buttons.Parent = gui

	local castToggle = makeButton(buttons, "CastToggle", "SHOW CAST", Color3.fromRGB(90, 90, 120))
	local function syncCastToggle()
		castToggle.Text = panel.Visible and "HIDE CAST" or "SHOW CAST"
	end
	syncCastToggle()
	castToggle.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		syncCastToggle()
	end)

	local lockButton = makeButton(buttons, "LockButton", "LOCK BASE (L)", Color3.fromRGB(60, 160, 90))
	local rebirthButton = makeButton(buttons, "RebirthButton", "REBIRTH (R)", Color3.fromRGB(150, 70, 220))
	local speedButton = makeButton(buttons, "SpeedButton", "SPEED +4  $" .. commafy(Config.Upgrades.Speed.cost), Color3.fromRGB(60, 130, 220))
	local carryButton = makeButton(buttons, "CarryButton", "CARRY 2  $" .. commafy(Config.Upgrades.Carry.cost), Color3.fromRGB(220, 130, 50))
	local fuseButton = makeButton(buttons, "FuseButton", "FUSE 3 -> 1 UP (F)", Color3.fromRGB(200, 60, 140))

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
	fuseButton.MouseButton1Click:Connect(function()
		clientAction:FireServer("Fuse")
	end)

	-- Bottom centre: one-line feedback.
	local notifyLabel = makeLabel(gui, "Notify", UDim2.new(0, 700, 0, 34), UDim2.new(0.5, 0, 1, -64), Vector2.new(0.5, 1),
		"", 20, Color3.fromRGB(255, 240, 160), Enum.Font.GothamBlack)
	notifyLabel.Visible = false

	-- Centre: the tsunami banner.
	local banner = makeLabel(gui, "WaveBanner", UDim2.new(0, 720, 0, 64), UDim2.new(0.5, 0, 0, 196), Vector2.new(0.5, 0),
		"", 40, Color3.fromRGB(255, 90, 90), Enum.Font.GothamBlack)
	banner.Visible = false

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Server -> client wiring.
	local lastMoney = nil
	local gainTween = nil
	local pulseTween = nil
	remotes:WaitForChild("StateUpdate").OnClientEvent:Connect(function(state)
		moneyLabel.Text = "$" .. commafy(state.money)
		incomeLabel.Text = "+$" .. commafy(state.income) .. "/s    Rebirths: " .. state.rebirths .. " (x" .. state.multiplier .. ")"
		if state.questLine ~= nil then
			questLabel.Text = state.questLine
		end
		if state.dexCount ~= nil then
			castTitle.Text = "CAST & PRICES  -  DEX " .. state.dexCount .. "/" .. #Config.Cast
		end
		if state.isNight then
			dayLabel.Text = "NIGHT - MUTATIONS UP!"
			dayLabel.TextColor3 = Color3.fromRGB(255, 150, 220)
		else
			dayLabel.Text = "DAY"
			dayLabel.TextColor3 = Color3.fromRGB(160, 230, 255)
		end

		-- One slim line: what you carry, then the next brainrot to afford
		-- (the cheapest cast member above your money, in its rarity color).
		local carryText
		if state.carrying > 0 then
			carryText = "Carrying " .. state.carrying .. "/" .. state.capacity .. ": " .. state.carryName
		else
			carryText = "Hands empty - buy a brainrot!"
		end
		local nextEntry = nil
		for _, entry in ipairs(Config.Cast) do
			if entry.cost > state.money and (nextEntry == nil or entry.cost < nextEntry.cost) then
				nextEntry = entry
			end
		end
		if nextEntry then
			carryNextLabel.Text = carryText .. "   |   NEXT: " .. nextEntry.name .. "  $" .. commafy(nextEntry.cost)
				.. "  (need $" .. commafy(nextEntry.cost - state.money) .. " more)"
			carryNextLabel.TextColor3 = Config.RarityColor(nextEntry.rarity)
		else
			carryNextLabel.Text = carryText .. "   |   NEXT: You can afford them all - go Mythic hunting!"
			carryNextLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
		end

		-- Income feedback: when money rises, pop a floating "+$X" over the
		-- money line and pulse the money text.
		if lastMoney ~= nil and state.money > lastMoney then
			local delta = state.money - lastMoney
			if gainTween then
				gainTween:Cancel()
			end
			if pulseTween then
				pulseTween:Cancel()
			end
			gainLabel.Text = "+$" .. commafy(delta)
			gainLabel.Position = UDim2.new(1, -10, 0, 32)
			gainLabel.TextTransparency = 0
			gainLabel.TextStrokeTransparency = 0.4
			gainLabel.Visible = true
			gainTween = TweenService:Create(gainLabel, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(1, -10, 0, 6),
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			gainTween:Play()
			gainTween.Completed:Connect(function()
				gainLabel.Visible = false
			end)
			moneyScale.Scale = 1
			pulseTween = TweenService:Create(moneyScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
				Scale = 1.13,
			})
			pulseTween:Play()
		end
		lastMoney = state.money
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

	-- Server announcements (giant events) reuse the big centre banner.
	local announceToken = 0
	remotes:WaitForChild("Announce").OnClientEvent:Connect(function(text)
		announceToken += 1
		local token = announceToken
		banner.Text = text
		banner.TextColor3 = Color3.fromRGB(255, 205, 50)
		banner.Visible = true
		task.delay(4, function()
			if announceToken == token then
				banner.Visible = false
				banner.TextColor3 = Color3.fromRGB(255, 90, 90)
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
