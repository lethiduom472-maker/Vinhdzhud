-- LocalScript: dat trong StarterPlayer > StarterPlayerScripts (xoa script menu cu truoc)[span_1](start_span)[span_1](end_span)
-- Phim tat (PC): M = an/hien menu, F = bat/tat bay, N = bat/tat xuyen tuong, giu chuot phai = ngam[span_2](start_span)[span_2](end_span)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local isTouch = UIS.TouchEnabled

local DEFAULT_SPEED, DEFAULT_JUMP = 16, 50

local espThemes = {
	{ name = "Do - Vang", fill = Color3.fromRGB(255, 75, 75), outline = Color3.fromRGB(255, 235, 90) },
	{ name = "Xanh duong", fill = Color3.fromRGB(60, 150, 255), outline = Color3.fromRGB(160, 225, 255) },
	{ name = "Xanh la", fill = Color3.fromRGB(60, 220, 120), outline = Color3.fromRGB(190, 255, 210) },
	{ name = "Tim", fill = Color3.fromRGB(185, 95, 255), outline = Color3.fromRGB(240, 195, 255) },
}

local uiThemes = {
	{ name = "Toi chuan", bg = Color3.fromRGB(22, 23, 30), card = Color3.fromRGB(34, 36, 46), accent = Color3.fromRGB(70, 140, 255) },
	{ name = "Xanh bien", bg = Color3.fromRGB(18, 26, 38), card = Color3.fromRGB(28, 40, 58), accent = Color3.fromRGB(56, 189, 248) },
	{ name = "Do do", bg = Color3.fromRGB(34, 20, 26), card = Color3.fromRGB(50, 30, 38), accent = Color3.fromRGB(244, 63, 94) },
}

local state = {
	speedOn = false, speed = 50,
	jumpOn = false, jump = 120,
	infJump = false,
	noclip = false,
	fly = false, flySpeed = 60, up = false, down = false,

	ignoreTeam = false,
	auraOn = false,
	auraFollow = true,
	auraUseTool = true,
	auraRange = 22,
	auraCooldown = 0.22,
	aim = false, autoAim = false, fov = 160, showFov = true, aimHeld = false,

	esp = false,
	espTag = true,
	espColorIdx = 1,
	uiThemeIdx = 1,
}

local bv
local savedCollide = {}
local espHighlights = {}
local espTags = {}
local setters = {}
local uiCards = {}
local uiFills = {}
local lastAuraHit = 0

-- Xoa UI cu neu trung
local playerGui = player:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("VinhDzMenu")
if oldGui then
	oldGui:Destroy()
end

local function getChar()
	local c = player.Character
	return c, c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

local function applyStats()
	local _, _, hum = getChar()
	if hum then
		hum.UseJumpPower = true
		hum.WalkSpeed = state.speedOn and state.speed or DEFAULT_SPEED
		hum.JumpPower = state.jumpOn and state.jump or DEFAULT_JUMP
	end
end

local function getPlayerFromModel(model)
	return Players:GetPlayerFromCharacter(model)
end

local function isValidTargetModel(model)
	local myChar = player.Character
	if not model or not model:IsA("Model") or model == myChar then
		return false
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	local targetPlayer = getPlayerFromModel(model)
	if state.ignoreTeam and targetPlayer and player.Team and targetPlayer.Team and player.Team == targetPlayer.Team then
		return false
	end

	return true, root, hum, targetPlayer
end

local function collectAllTargetModels()
	local list = {}
	local myChar = player.Character

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			table.insert(list, p.Character)
		end
	end

	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Humanoid") and desc.Parent and desc.Parent:IsA("Model") then
			local m = desc.Parent
			if m ~= myChar and not getPlayerFromModel(m) then
				table.insert(list, m)
			end
		end
	end

	return list
end

-- ===================== ESP =====================
local function clearEspForKey(key)
	local hl = espHighlights[key]
	if hl then
		hl:Destroy()
		espHighlights[key] = nil
	end
	local tag = espTags[key]
	if tag then
		if tag.gui then
			tag.gui:Destroy()
		end
		espTags[key] = nil
	end
end

local function clearAllEsp()
	for k in pairs(espHighlights) do clearEspForKey(k) end
	for k in pairs(espTags) do clearEspForKey(k) end
end

local function applyEspToModel(model)
	local ok, root, _, targetPlayer = isValidTargetModel(model)
	if not state.esp or not ok then
		clearEspForKey(model)
		return
	end
	clearEspForKey(model)

	local theme = espThemes[state.espColorIdx]
	local hl = Instance.new("Highlight")
	hl.Name = "EspHighlight"
	hl.Adornee = model
	hl.FillColor = theme.fill
	hl.OutlineColor = theme.outline
	hl.FillTransparency = 0.65
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = model
	espHighlights[model] = hl

	local anchor = model:FindFirstChild("Head") or root
	if anchor then
		local bb = Instance.new("BillboardGui")
		bb.Name = "EspTag"
		bb.Adornee = anchor
		bb.Size = UDim2.fromOffset(180, 34)
		bb.StudsOffset = Vector3.new(0, 2.6, 0)
		bb.AlwaysOnTop = true
		bb.Enabled = state.espTag
		bb.Parent = model

		local displayName = targetPlayer and targetPlayer.DisplayName or model.Name
		local txt = Instance.new("TextLabel")
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundTransparency = 1
		txt.Font = Enum.Font.GothamBold
		txt.TextSize = 13
		txt.TextColor3 = theme.outline
		txt.TextStrokeTransparency = 0.25
		txt.TextStrokeColor3 = Color3.new(0, 0, 0)
		txt.Text = displayName
		txt.Parent = bb

		espTags[model] = { gui = bb, label = txt, root = root, name = displayName }
	end
end

local function refreshEspColors()
	local theme = espThemes[state.espColorIdx]
	for _, hl in pairs(espHighlights) do
		if hl and hl.Parent then
			hl.FillColor = theme.fill
			hl.OutlineColor = theme.outline
		end
	end
	for _, tag in pairs(espTags) do
		if tag and tag.label then tag.label.TextColor3 = theme.outline end
		if tag and tag.gui then tag.gui.Enabled = state.esp and state.espTag end
	end
end

local function syncEspTargets()
	if not state.esp then
		clearAllEsp()
		return
	end

	local validSet = {}
	for _, m in ipairs(collectAllTargetModels()) do
		if isValidTargetModel(m) then
			validSet[m] = true
			if not espHighlights[m] then
				applyEspToModel(m)
			end
		end
	end

	for k in pairs(espHighlights) do
		if not validSet[k] then
			clearEspForKey(k)
		end
	end
end

local function setEsp(on)
	state.esp = on
	if on then
		syncEspTargets()
	else
		clearAllEsp()
	end
	if setters.esp then setters.esp(on) end
end

-- ===================== NOCLIP & FLY =====================
local function setNoclip(on)
	state.noclip = on
	local char = player.Character
	if not on and char then
		for part, canCollide in pairs(savedCollide) do
			if part and part.Parent then
				part.CanCollide = canCollide
			end
		end
		table.clear(savedCollide)
	end
	if setters.noclip then setters.noclip(on) end
end

local function setFly(on)
	local _, hrp, hum = getChar()
	if not hrp or not hum then return end
	state.fly = on
	if on then
		if not bv then
			bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			bv.Velocity = Vector3.zero
			bv.Parent = hrp
		end
		hum.PlatformStand = true
	else
		if bv then
			bv:Destroy()
			bv = nil
		end
		hum.PlatformStand = false
		state.up, state.down = false, false
	end
	if setters.fly then setters.fly(on) end
end

-- ===================== AUTO KILL / TOOL =====================
local function getAuraTarget(myHrp)
	if not myHrp then return nil end
	local bestRoot, bestDist = nil, state.auraRange

	for _, m in ipairs(collectAllTargetModels()) do
		local ok, targetRoot = isValidTargetModel(m)
		if ok and targetRoot then
			local dist = (targetRoot.Position - myHrp.Position).Magnitude
			if dist <= bestDist then
				bestDist = dist
				bestRoot = targetRoot
			end
		end
	end

	return bestRoot
end

local function useEquippedOrBackpackTool(char, hum)
	if not char or not hum then return end
	local tool = char:FindFirstChildOfClass("Tool")
	if not tool then
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			tool = backpack:FindFirstChildOfClass("Tool")
			if tool then
				hum:EquipTool(tool)
			end
		end
	end
	if tool and tool:IsA("Tool") and tool.Parent == char then
		pcall(function()
			tool:Activate()
		end)
	end
end

local function resetAll()
	state.speedOn = false
	state.jumpOn = false
	state.infJump = false
	state.ignoreTeam = false
	state.auraOn = false
	state.aim = false
	state.autoAim = false
	state.aimHeld = false
	setFly(false)
	setNoclip(false)
	setEsp(false)
	applyStats()

	for _, key in ipairs({ "speedOn", "jumpOn", "infJump", "ignoreTeam", "auraOn", "aim", "autoAim" }) do
		if setters[key] then setters[key](false) end
	end
end

player.CharacterAdded:Connect(function()
	state.fly = false
	state.noclip = false
	bv = nil
	table.clear(savedCollide)
	if setters.fly then setters.fly(false) end
	if setters.noclip then setters.noclip(false) end
	task.wait(0.4)
	applyStats()
end)

-- ===================== UI MOI (CHIA TAB GON GANG) =====================
local gui = Instance.new("ScreenGui")
gui.Name = "VinhDzMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = o
	return c
end

local function addStroke(o, color, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255, 225, 95)
	s.Thickness = 1.5
	s.Transparency = transparency or 0.4
	s.Parent = o
	return s
end

-- Vong FOV
local circle = Instance.new("Frame")
circle.AnchorPoint = Vector2.new(0.5, 0.5)
circle.Position = UDim2.fromScale(0.5, 0.5)
circle.Size = UDim2.fromOffset(state.fov * 2, state.fov * 2)
circle.BackgroundTransparency = 1
circle.Visible = false
circle.Parent = gui
corner(circle, 9999)
addStroke(circle, Color3.fromRGB(255, 255, 255), 0.25)

-- Nut mo menu
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(114, 36)
toggleBtn.Position = UDim2.new(0, 12, 0.5, -18)
toggleBtn.BackgroundColor3 = uiThemes[1].card
toggleBtn.TextColor3 = Color3.fromRGB(255, 225, 95)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.Text = "👑VINHDZ👑"
toggleBtn.Parent = gui
corner(toggleBtn, 10)
addStroke(toggleBtn, Color3.fromRGB(255, 225, 95), 0.35)

-- Khung chinh
local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(290, 350)
frame.Position = UDim2.new(0, 136, 0.5, -175)
frame.BackgroundColor3 = uiThemes[1].bg
frame.Active = true
frame.Parent = gui
corner(frame, 12)
addStroke(frame, Color3.fromRGB(255, 225, 95), 0.45)

-- Header keo tha
local header = Instance.new("TextButton")
header.Size = UDim2.new(1, -40, 0, 36)
header.Position = UDim2.new(0, 8, 0, 0)
header.BackgroundTransparency = 1
header.Text = "👑VINHDZ👑"
header.TextColor3 = Color3.fromRGB(255, 225, 95)
header.Font = Enum.Font.GothamBold
header.TextSize = 15
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(175, 65, 65)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Text = "X"
closeBtn.Parent = frame
corner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() frame.Visible = false end)

do
	local dragging, dragStart, startPos
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- Thanh Tab
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 30)
tabBar.Position = UDim2.new(0, 8, 0, 38)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Parent = tabBar

local pages = {}
local tabButtons = {}
local activeTab = "Chien dau"

local function createPage(name)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -14, 1, -78)
	scroll.Position = UDim2.new(0, 7, 0, 72)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Visible = (name == activeTab)
	scroll.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 7)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	pages[name] = { scroll = scroll, order = 0 }

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.32, 0, 1, 0)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = name
	btn.Parent = tabBar
	corner(btn, 6)
	tabButtons[name] = btn

	btn.MouseButton1Click:Connect(function()
		activeTab = name
		for tabName, page in pairs(pages) do
			page.scroll.Visible = (tabName == activeTab)
		end
		local t = uiThemes[state.uiThemeIdx]
		for tabName, b in pairs(tabButtons) do
			b.BackgroundColor3 = (tabName == activeTab) and t.accent or t.card
		end
	end)

	return pages[name]
end

local pageCombat = createPage("Chien dau")
local pageMove = createPage("Di chuyen")
local pageVisual = createPage("Hien thi")

local function applyUiTheme()
	local t = uiThemes[state.uiThemeIdx]
	frame.BackgroundColor3 = t.bg
	toggleBtn.BackgroundColor3 = t.card
	for tabName, b in pairs(tabButtons) do
		b.BackgroundColor3 = (tabName == activeTab) and t.accent or t.card
	end
	for _, card in ipairs(uiCards) do
		if card and card.Parent then card.BackgroundColor3 = t.card end
	end
	for _, fill in ipairs(uiFills) do
		if fill and fill.Parent then fill.BackgroundColor3 = t.accent end
	end
end

local function nextOrder(page)
	page.order += 1
	return page.order
end

local function makeToggleButton(parent, size, pos, onChange, text, initialOn)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos or UDim2.new()
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	corner(b, 6)

	local on = initialOn or false
	local function refresh()
		b.Text = text and (text .. ": " .. (on and "BAT" or "TAT")) or (on and "BAT" or "TAT")
		b.BackgroundColor3 = on and Color3.fromRGB(46, 160, 90) or Color3.fromRGB(75, 78, 92)
	end
	refresh()

	b.MouseButton1Click:Connect(function()
		on = not on
		refresh()
		onChange(on)
	end)

	return function(v)
		on = v
		refresh()
	end
end

local function makeToggleRow(page, text, onChange, initialOn)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 32)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder(page)
	row.Parent = page.scroll
	return makeToggleButton(row, UDim2.new(1, 0, 1, 0), nil, onChange, text, initialOn)
end

local function makeActionRow(page, text, color, onClick)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 32)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder(page)
	row.Parent = page.scroll

	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 1, 0)
	b.BackgroundColor3 = color
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.Text = text
	b.Parent = row
	corner(b, 6)

	b.MouseButton1Click:Connect(function() onClick(b) end)
	return b
end

local function makeSliderBlock(page, title, minV, maxV, init, onValue, onToggle, suffix)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -6, 0, 62)
	f.BackgroundColor3 = uiThemes[state.uiThemeIdx].card
	f.LayoutOrder = nextOrder(page)
	f.Parent = page.scroll
	corner(f, 8)
	table.insert(uiCards, f)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.65, 0, 0, 26)
	lbl.Position = UDim2.new(0, 10, 0, 2)
	lbl.BackgroundTransparency = 1
	lbl.Text = title .. ": " .. init .. (suffix or "")
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f

	local toggleSetter
	if onToggle then
		toggleSetter = makeToggleButton(f, UDim2.fromOffset(56, 22), UDim2.new(1, -64, 0, 4), onToggle)
	end

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -26, 0, 8)
	track.Position = UDim2.new(0, 13, 0, 43)
	track.BackgroundColor3 = Color3.fromRGB(68, 70, 84)
	track.Parent = f
	corner(track, 4)

	local a0 = (init - minV) / (maxV - minV)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(a0, 0, 1, 0)
	fill.BackgroundColor3 = uiThemes[state.uiThemeIdx].accent
	fill.Parent = track
	corner(fill, 4)
	table.insert(uiFills, fill)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(16, 16)
	knob.Position = UDim2.new(a0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = track
	corner(knob, 8)

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.new(1, 0, 0, 28)
	hit.Position = UDim2.new(0, 0, 0, 32)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Parent = f

	local dragging = false
	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v = math.floor(minV + (maxV - minV) * a + 0.5)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		lbl.Text = title .. ": " .. v .. (suffix or "")
		onValue(v)
	end

	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			page.scroll.ScrollingEnabled = false
			setFromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			setFromX(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
			page.scroll.ScrollingEnabled = true
		end
	end)

	return toggleSetter
end

-- ===== TAB CHIEN DAU =====
setters.auraOn = makeToggleRow(pageCombat, "Auto Kill tat ca (Tool)", function(on) state.auraOn = on end)
setters.ignoreTeam = makeToggleRow(pageCombat, "Bo qua cung team", function(on)
	state.ignoreTeam = on
	if state.esp then syncEspTargets() end
end)
makeToggleRow(pageCombat, "Tu rut & kich hoat Tool", function(on) state.auraUseTool = on end, true)
makeToggleRow(pageCombat, "Tu bam muc tieu", function(on) state.auraFollow = on end, true)
makeSliderBlock(pageCombat, "Tam Auto Kill", 5, 50, state.auraRange, function(v) state.auraRange = v end, nil, "m")
makeSliderBlock(pageCombat, "Nhip danh (ms)", 80, 1000, math.floor(state.auraCooldown * 1000), function(v)
	state.auraCooldown = v / 1000
end, nil, "ms")
setters.aim = makeToggleRow(pageCombat, "Ho tro ngam", function(on) state.aim = on end)
setters.autoAim = makeToggleRow(pageCombat, "Auto ngam lien tuc", function(on) state.autoAim = on end)
makeSliderBlock(pageCombat, "Vong FOV ngam", 50, 400, state.fov, function(v)
	state.fov = v
	circle.Size = UDim2.fromOffset(v * 2, v * 2)
end)

-- ===== TAB DI CHUYEN =====
setters.speedOn = makeSliderBlock(pageMove, "Toc do chay", 16, 200, state.speed,
	function(v) state.speed = v applyStats() end,
	function(on) state.speedOn = on applyStats() end)
setters.jumpOn = makeSliderBlock(pageMove, "Do cao nhay", 50, 300, state.jump,
	function(v) state.jump = v applyStats() end,
	function(on) state.jumpOn = on applyStats() end)
setters.infJump = makeToggleRow(pageMove, "Nhay vo han", function(on) state.infJump = on end)
setters.noclip = makeToggleRow(pageMove, "Xuyen tuong (N)", function(on) setNoclip(on) end)
setters.fly = makeToggleRow(pageMove, "Bay (F / joystick)", function(on) setFly(on) end)
makeSliderBlock(pageMove, "Toc do bay", 10, 200, state.flySpeed, function(v) state.flySpeed = v end)

-- ===== TAB HIEN THI =====
setters.esp = makeToggleRow(pageVisual, "ESP tat ca muc tieu", function(on) setEsp(on) end)
makeToggleRow(pageVisual, "Ten + Khoang cach ESP", function(on)
	state.espTag = on
	refreshEspColors()
end, true)
makeActionRow(pageVisual, "Mau ESP: " .. espThemes[1].name, Color3.fromRGB(65, 95, 145), function(btn)
	state.espColorIdx = (state.espColorIdx % #espThemes) + 1
	btn.Text = "Mau ESP: " .. espThemes[state.espColorIdx].name
	refreshEspColors()
end)
makeToggleRow(pageVisual, "Hien vong FOV", function(on) state.showFov = on end, true)
makeActionRow(pageVisual, "Mau giao dien: " .. uiThemes[1].name, Color3.fromRGB(70, 75, 95), function(btn)
	state.uiThemeIdx = (state.uiThemeIdx % #uiThemes) + 1
	btn.Text = "Mau giao dien: " .. uiThemes[state.uiThemeIdx].name
	applyUiTheme()
end)
makeActionRow(pageVisual, "Reset tat ca ve mac dinh", Color3.fromRGB(175, 65, 65), resetAll)

applyUiTheme()
toggleBtn.MouseButton1Click:Connect(function() frame.Visible = not frame.Visible end)

-- ===== NUT CAM UNG MOBILE =====
local function holdButton(text, pos, color, key)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(66, 66)
	b.Position = pos
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.25
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.Text = text
	b.Visible = false
	b.Parent = gui
	corner(b, 33)

	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			state[key] = true
		end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			state[key] = false
		end
	end)
	return b
end

local upBtn = holdButton("LEN", UDim2.new(1, -86, 1, -260), Color3.fromRGB(60, 120, 220), "up")
local downBtn = holdButton("XUONG", UDim2.new(1, -86, 1, -184), Color3.fromRGB(60, 120, 220), "down")
local aimBtn = holdButton("NGAM", UDim2.new(1, -168, 1, -184), Color3.fromRGB(210, 70, 70), "aimHeld")

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then
		frame.Visible = not frame.Visible
	elseif input.KeyCode == Enum.KeyCode.F then
		setFly(not state.fly)
	elseif input.KeyCode == Enum.KeyCode.N then
		setNoclip(not state.noclip)
	end
end)

UIS.JumpRequest:Connect(function()
	if state.infJump and not state.fly then
		local _, _, hum = getChar()
		if hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

-- ===== VONG LAP CHINH =====
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getTarget()
	local center = camera.ViewportSize / 2
	local best, bestDist = nil, state.fov
	local myChar = player.Character

	for _, m in ipairs(collectAllTargetModels()) do
		local ok, root = isValidTargetModel(m)
		if ok and root then
			local aimPart = m:FindFirstChild("Head") or root
			local pos, onScreen = camera:WorldToViewportPoint(aimPart.Position)
			if onScreen then
				local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
				if d < bestDist then
					rayParams.FilterDescendantsInstances = { myChar, m }
					local blocked = workspace:Raycast(camera.CFrame.Position, aimPart.Position - camera.CFrame.Position, rayParams)
					if not blocked then
						best, bestDist = aimPart, d
					end
				end
			end
		end
	end

	return best
end

local lastEspSync = 0

RunService.RenderStepped:Connect(function(dt)
	local char, myHrp, hum = getChar()
	local now = os.clock()

	-- Cap nhat danh sach ESP dinh ky de bat ca NPC moi spawn
	if state.esp and now - lastEspSync >= 0.5 then
		lastEspSync = now
		syncEspTargets()
	end

	-- Cap nhat khoang cach ESP
	if state.esp and state.espTag then
		local origin = myHrp and myHrp.Position or camera.CFrame.Position
		for model, tag in pairs(espTags) do
			local ok, root = isValidTargetModel(model)
			if ok and root and tag.label then
				local dist = math.floor((root.Position - origin).Magnitude + 0.5)
				tag.label.Text = string.format("%s [%dm]", tag.name, dist)
			end
		end
	end

	-- Auto Kill dung Tool (ap dung tat ca muc tieu)
	if state.auraOn and char and myHrp and hum and hum.Health > 0 then
		local auraTargetRoot = getAuraTarget(myHrp)
		if auraTargetRoot then
			local toTarget = auraTargetRoot.Position - myHrp.Position
			local flatOffset = Vector3.new(toTarget.X, 0, toTarget.Z)
			local distFlat = flatOffset.Magnitude

			if distFlat > 0.05 then
				local lookPos = Vector3.new(auraTargetRoot.Position.X, myHrp.Position.Y, auraTargetRoot.Position.Z)
				myHrp.CFrame = myHrp.CFrame:Lerp(CFrame.lookAt(myHrp.Position, lookPos), 1 - math.exp(-22 * dt))
			end

			if state.auraFollow and distFlat > 4.5 then
				hum:Move(flatOffset.Unit, false)
			end

			if state.auraUseTool and now - lastAuraHit >= state.auraCooldown then
				lastAuraHit = now
				useEquippedOrBackpackTool(char, hum)
			end
		end
	end

	-- Xuyen tuong
	if char and (state.noclip or state.fly) then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				if savedCollide[part] == nil then
					savedCollide[part] = part.CanCollide
				end
				part.CanCollide = false
			end
		end
	elseif next(savedCollide) ~= nil then
		for part, canCollide in pairs(savedCollide) do
			if part and part.Parent then
				part.CanCollide = canCollide
			end
		end
		table.clear(savedCollide)
	end

	-- Bay
	if state.fly and bv and hum then
		local move = hum.MoveDirection
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local fwd = flat.Magnitude > 0 and move:Dot(flat.Unit) or 0
		local vel = move * state.flySpeed + Vector3.new(0, look.Y * fwd * state.flySpeed, 0)

		if UIS:IsKeyDown(Enum.KeyCode.Space) or state.up then vel += Vector3.yAxis * state.flySpeed end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) or state.down then vel -= Vector3.yAxis * state.flySpeed end
		bv.Velocity = vel
	end

	upBtn.Visible = isTouch and state.fly
	downBtn.Visible = isTouch and state.fly
	aimBtn.Visible = isTouch and state.aim and not state.autoAim
	circle.Visible = state.aim and state.showFov

	local shouldAim = state.aim and (
		state.autoAim
		or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		or state.aimHeld
	)

	if shouldAim then
		local aimPart = getTarget()
		if aimPart then
			local target = CFrame.lookAt(camera.CFrame.Position, aimPart.Position)
			camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-18 * dt))
		end
	end
end)

task.defer(applyStats)
