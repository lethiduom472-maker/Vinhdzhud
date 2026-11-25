-- LocalScript: dat trong StarterPlayer > StarterPlayerScripts (xoa script menu cu truoc)
-- Phim tat (PC): M = an/hien menu, F = bat/tat bay, N = bat/tat xuyen tuong, Q = luot nhanh, T = khoa muc tieu, giu chuot phai = ngam

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local isTouch = UIS.TouchEnabled

local DEFAULT_SPEED, DEFAULT_JUMP = 16, 50
local DEFAULT_GRAVITY = workspace.Gravity
local DEFAULT_FOV = 70

local origLighting = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart,
	GlobalShadows = Lighting.GlobalShadows,
}

local espThemes = {
	{ name = "Do - Vang", fill = Color3.fromRGB(255, 75, 75), outline = Color3.fromRGB(255, 235, 90) },
	{ name = "Xanh duong", fill = Color3.fromRGB(60, 150, 255), outline = Color3.fromRGB(160, 225, 255) },
	{ name = "Xanh la", fill = Color3.fromRGB(60, 220, 120), outline = Color3.fromRGB(190, 255, 210) },
	{ name = "Tim", fill = Color3.fromRGB(185, 95, 255), outline = Color3.fromRGB(240, 195, 255) },
}

local fovColors = {
	{ name = "Trang", color = Color3.fromRGB(255, 255, 255) },
	{ name = "Do", color = Color3.fromRGB(255, 80, 80) },
	{ name = "Xanh la", color = Color3.fromRGB(80, 255, 130) },
	{ name = "Vang", color = Color3.fromRGB(255, 225, 80) },
}

local uiThemes = {
	{ name = "Toi chuan", bg = Color3.fromRGB(18, 20, 27), card = Color3.fromRGB(30, 33, 44), accent = Color3.fromRGB(64, 156, 255) },
	{ name = "Xanh bien", bg = Color3.fromRGB(15, 24, 36), card = Color3.fromRGB(25, 39, 58), accent = Color3.fromRGB(56, 189, 248) },
	{ name = "Do do", bg = Color3.fromRGB(29, 17, 23), card = Color3.fromRGB(45, 27, 36), accent = Color3.fromRGB(244, 63, 94) },
}

local state = {
	-- Di chuyen
	speedOn = false, speed = 50,
	sprintBoost = false, sprintSpeed = 85,
	antiSlow = false,
	jumpOn = false, jump = 120,
	infJump = false,
	noclip = false,
	fly = false, flySpeed = 60, up = false, down = false,
	freezeChar = false,
	airWalk = false,
	lowGrav = false, gravValue = 60,
	spinOn = false, spinSpeed = 12,
	savedCFrame = nil,

	-- Chien dau / Ngam / Auto ban
	ignoreTeam = false,
	playersOnly = false,
	ignoreCrouch = false,
	aim = false, autoAim = false,
	aimPartMode = "Head", -- "Head" | "HumanoidRootPart"
	aimPredict = false,
	aimSmooth = 18, fov = 160, showFov = true, fovColorIdx = 1, aimHeld = false,
	targetLockOn = false,
	lockedTargetModel = nil,
	targetLine = false,
	targetInfoHud = false,
	triggerBot = false,
	triggerCooldown = 0.14,
	triggerFovOnly = true,

	-- Hien thi
	esp = false,
	espTag = true,
	espHealth = true,
	espBox = false,
	espTracer = false,
	espMaxDist = 500,
	espFillTrans = 65,
	espColorIdx = 1,
	camFov = 70,
	fullbright = false,
	noFog = false,
	uiThemeIdx = 1,

	-- Tien ich
	antiAfk = true,
	respawnAtDeath = false,
	lastDeathCFrame = nil,
	showPerf = false,
	camLockThird = false,
	autoEquip = false,
}

local bv
local airPart
local savedCollide = {}
local espHighlights = {}
local espTags = {}
local espBoxes = {}
local espTracers = {}
local setters = {}
local uiCards = {}
local uiFills = {}
local lastTriggerShot = 0

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
		local baseSpd = state.speedOn and state.speed or DEFAULT_SPEED
		if state.sprintBoost and UIS:IsKeyDown(Enum.KeyCode.LeftShift) and not state.fly then
			baseSpd = state.sprintSpeed
		end
		hum.WalkSpeed = baseSpd
		hum.JumpPower = state.jumpOn and state.jump or DEFAULT_JUMP
	end
	workspace.Gravity = state.lowGrav and state.gravValue or DEFAULT_GRAVITY
end

local function applyLighting()
	if state.fullbright then
		Lighting.Ambient = Color3.fromRGB(200, 200, 200)
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
		Lighting.Brightness = 2
		Lighting.GlobalShadows = false
	else
		Lighting.Ambient = origLighting.Ambient
		Lighting.OutdoorAmbient = origLighting.OutdoorAmbient
		Lighting.Brightness = origLighting.Brightness
		Lighting.GlobalShadows = origLighting.GlobalShadows
	end

	if state.noFog then
		Lighting.FogStart = 1e6
		Lighting.FogEnd = 1e6
	else
		Lighting.FogStart = origLighting.FogStart
		Lighting.FogEnd = origLighting.FogEnd
	end
end

local function getPlayerFromModel(model)
	return Players:GetPlayerFromCharacter(model)
end

local function isValidTargetModel(model)
	local myChar, myHrp = getChar()
	if not model or not model:IsA("Model") or model == myChar then
		return false
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not hum or not root or hum.Health <= 0 then
		return false
	end

	if myHrp and (root.Position - myHrp.Position).Magnitude > state.espMaxDist then
		return false
	end

	if state.ignoreCrouch and hum.HipHeight < 1.2 then
		return false
	end

	local targetPlayer = getPlayerFromModel(model)
	if state.playersOnly and not targetPlayer then
		return false
	end

	if state.ignoreTeam and targetPlayer and player.Team and targetPlayer.Team and player.Team == targetPlayer.Team then
		return false
	end

	return true, root, hum, targetPlayer
end

local cachedTargets = {}
local lastTargetScan = 0

local function collectAllTargetModels(forceScan)
	local now = os.clock()
	if not forceScan and (now - lastTargetScan) < 0.35 and #cachedTargets > 0 then
		return cachedTargets
	end
	lastTargetScan = now

	local list = {}
	local seen = {}
	local myChar = player.Character

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and not seen[p.Character] then
			seen[p.Character] = true
			table.insert(list, p.Character)
		end
	end

	if not state.playersOnly then
		for _, desc in ipairs(workspace:GetDescendants()) do
			if desc:IsA("Humanoid") and desc.Parent and desc.Parent:IsA("Model") then
				local m = desc.Parent
				if m ~= myChar and not seen[m] and not getPlayerFromModel(m) then
					seen[m] = true
					table.insert(list, m)
				end
			end
		end
	end

	cachedTargets = list
	return cachedTargets
end

-- ===================== UI ROOT =====================
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

local function addStroke(o, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(255, 225, 95)
	s.Thickness = thickness or 1.2
	s.Transparency = transparency or 0.4
	s.Parent = o
	return s
end

-- ===================== ESP & VISUAL OVERLAYS =====================
local function clearEspForKey(key)
	if espHighlights[key] then espHighlights[key]:Destroy(); espHighlights[key] = nil end
	if espTags[key] then
		if espTags[key].gui then espTags[key].gui:Destroy() end
		espTags[key] = nil
	end
	if espBoxes[key] then espBoxes[key]:Destroy(); espBoxes[key] = nil end
	if espTracers[key] then espTracers[key]:Destroy(); espTracers[key] = nil end
end

local function clearAllEsp()
	for k in pairs(espHighlights) do clearEspForKey(k) end
	for k in pairs(espTags) do clearEspForKey(k) end
	for k in pairs(espBoxes) do clearEspForKey(k) end
	for k in pairs(espTracers) do clearEspForKey(k) end
end

local function applyEspToModel(model)
	local ok, root, hum, targetPlayer = isValidTargetModel(model)
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
	hl.FillTransparency = state.espFillTrans / 100
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = model
	espHighlights[model] = hl

	local box = Instance.new("SelectionBox")
	box.Name = "EspBox"
	box.Adornee = model
	box.Color3 = theme.outline
	box.LineThickness = 0.03
	box.SurfaceTransparency = 1
	box.Visible = state.espBox
	box.Parent = model
	espBoxes[model] = box

	local tracer = Instance.new("Frame")
	tracer.AnchorPoint = Vector2.new(0.5, 0.5)
	tracer.BackgroundColor3 = theme.outline
	tracer.BorderSizePixel = 0
	tracer.Visible = false
	tracer.Parent = gui
	espTracers[model] = tracer

	local anchor = model:FindFirstChild("Head") or root
	if anchor then
		local bb = Instance.new("BillboardGui")
		bb.Name = "EspTag"
		bb.Adornee = anchor
		bb.Size = UDim2.fromOffset(210, 36)
		bb.StudsOffset = Vector3.new(0, 2.7, 0)
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

		espTags[model] = { gui = bb, label = txt, root = root, hum = hum, name = displayName }
	end
end

local function refreshEspColors()
	local theme = espThemes[state.espColorIdx]
	for _, hl in pairs(espHighlights) do
		if hl and hl.Parent then
			hl.FillColor = theme.fill
			hl.OutlineColor = theme.outline
			hl.FillTransparency = state.espFillTrans / 100
		end
	end
	for _, box in pairs(espBoxes) do
		if box and box.Parent then
			box.Color3 = theme.outline
			box.Visible = state.esp and state.espBox
		end
	end
	for _, tr in pairs(espTracers) do
		if tr and tr.Parent then
			tr.BackgroundColor3 = theme.outline
			if not (state.esp and state.espTracer) then tr.Visible = false end
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
	for _, m in ipairs(collectAllTargetModels(true)) do
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
	if on then syncEspTargets() else clearAllEsp() end
	if setters.esp then setters.esp(on) end
end

-- ===================== NOCLIP, FLY, FREEZE, AIRWALK, TRIGGER =====================
local function setNoclip(on)
	state.noclip = on
	local char = player.Character
	if not on and char then
		for part, canCollide in pairs(savedCollide) do
			if part and part.Parent then part.CanCollide = canCollide end
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
		if bv then bv:Destroy(); bv = nil end
		hum.PlatformStand = false
		state.up, state.down = false, false
	end
	if setters.fly then setters.fly(on) end
end

local function setFreeze(on)
	state.freezeChar = on
	local _, hrp = getChar()
	if hrp then hrp.Anchored = on end
	if setters.freezeChar then setters.freezeChar(on) end
end

local function setAirWalk(on)
	state.airWalk = on
	if on then
		if not airPart then
			airPart = Instance.new("Part")
			airPart.Name = "VinhAirPlatform"
			airPart.Anchored = true
			airPart.CanCollide = true
			airPart.Transparency = 0.72
			airPart.Material = Enum.Material.Neon
			airPart.Color = Color3.fromRGB(64, 156, 255)
			airPart.Size = Vector3.new(10, 1, 10)
			airPart.Parent = workspace
		end
	else
		if airPart then airPart:Destroy(); airPart = nil end
	end
	if setters.airWalk then setters.airWalk(on) end
end

local function doDash()
	local _, hrp = getChar()
	local camera = workspace.CurrentCamera
	if hrp and camera and not state.freezeChar then
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.05 then
			hrp.CFrame = hrp.CFrame + flat.Unit * 18
		end
	end
end

local function triggerFireOnce()
	local char, _, hum = getChar()
	if not char or not hum or hum.Health <= 0 then return end

	local tool = char:FindFirstChildOfClass("Tool")
	if not tool and state.autoEquip then
		local bp = player:FindFirstChildOfClass("Backpack")
		tool = bp and bp:FindFirstChildOfClass("Tool")
		if tool then hum:EquipTool(tool) end
	end

	if tool and tool:IsA("Tool") and tool.Parent == char then
		pcall(function() tool:Activate() end)
	end
end

local function applyFpsBoost()
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
			obj.Enabled = false
		elseif obj:IsA("BasePart") then
			obj.Material = Enum.Material.SmoothPlastic
		end
	end
end

local function resetAll()
	state.speedOn = false
	state.sprintBoost = false
	state.antiSlow = false
	state.jumpOn = false
	state.infJump = false
	state.lowGrav = false
	state.spinOn = false
	state.ignoreTeam = false
	state.playersOnly = false
	state.ignoreCrouch = false
	state.aim = false
	state.autoAim = false
	state.aimPredict = false
	state.targetLockOn = false
	state.lockedTargetModel = nil
	state.targetLine = false
	state.targetInfoHud = false
	state.triggerBot = false
	state.aimHeld = false
	state.fullbright = false
	state.noFog = false
	state.camFov = DEFAULT_FOV
	state.respawnAtDeath = false
	state.showPerf = false
	state.camLockThird = false
	state.autoEquip = false

	setFreeze(false)
	setAirWalk(false)
	setFly(false)
	setNoclip(false)
	setEsp(false)
	applyStats()
	applyLighting()

	local camera = workspace.CurrentCamera
	if camera then camera.FieldOfView = DEFAULT_FOV end
	player.CameraMode = Enum.CameraMode.Classic

	for _, key in ipairs({
		"speedOn", "sprintBoost", "antiSlow", "jumpOn", "infJump", "lowGrav", "spinOn",
		"ignoreTeam", "playersOnly", "ignoreCrouch", "aim", "autoAim", "aimPredict",
		"targetLockOn", "targetLine", "targetInfoHud", "triggerBot", "fullbright", "noFog",
		"respawnAtDeath", "showPerf", "camLockThird", "autoEquip"
	}) do
		if setters[key] then setters[key](false) end
	end
end

local function bindDeathHook(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then state.lastDeathCFrame = hrp.CFrame end
		end)
	end
end

if player.Character then bindDeathHook(player.Character) end

player.CharacterAdded:Connect(function(char)
	bindDeathHook(char)
	state.fly = false
	state.noclip = false
	state.freezeChar = false
	bv = nil
	table.clear(savedCollide)
	if setters.fly then setters.fly(false) end
	if setters.noclip then setters.noclip(false) end
	if setters.freezeChar then setters.freezeChar(false) end
	task.wait(0.35)
	applyStats()
	if state.respawnAtDeath and state.lastDeathCFrame then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.CFrame = state.lastDeathCFrame + Vector3.new(0, 3, 0) end
	end
end)

player.Idled:Connect(function()
	if state.antiAfk then
		local vu = game:GetService("VirtualUser")
		pcall(function()
			vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
			task.wait(0.1)
			vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		end)
	end
end)

-- ===================== HUD PHU =====================
local circle = Instance.new("Frame")
circle.AnchorPoint = Vector2.new(0.5, 0.5)
circle.Position = UDim2.fromScale(0.5, 0.5)
circle.Size = UDim2.fromOffset(state.fov * 2, state.fov * 2)
circle.BackgroundTransparency = 1
circle.Visible = false
circle.Parent = gui
corner(circle, 9999)
local fovStroke = addStroke(circle, fovColors[1].color, 0.25, 1.5)

local targetLineFrame = Instance.new("Frame")
targetLineFrame.AnchorPoint = Vector2.new(0.5, 0.5)
targetLineFrame.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
targetLineFrame.BorderSizePixel = 0
targetLineFrame.Visible = false
targetLineFrame.Parent = gui

local targetHud = Instance.new("TextLabel")
targetHud.AnchorPoint = Vector2.new(0.5, 0)
targetHud.Position = UDim2.new(0.5, 0, 0, 12)
targetHud.Size = UDim2.fromOffset(270, 30)
targetHud.BackgroundColor3 = uiThemes[1].card
targetHud.BackgroundTransparency = 0.15
targetHud.TextColor3 = Color3.fromRGB(255, 225, 95)
targetHud.Font = Enum.Font.GothamBold
targetHud.TextSize = 13
targetHud.Text = "Muc tieu: Khong co"
targetHud.Visible = false
targetHud.Parent = gui
corner(targetHud, 8)
addStroke(targetHud, Color3.fromRGB(255, 225, 95), 0.55, 1)

local perfHud = Instance.new("TextLabel")
perfHud.Position = UDim2.new(0, 12, 0, 12)
perfHud.Size = UDim2.fromOffset(180, 28)
perfHud.BackgroundColor3 = uiThemes[1].card
perfHud.BackgroundTransparency = 0.2
perfHud.TextColor3 = Color3.fromRGB(120, 240, 160)
perfHud.Font = Enum.Font.GothamBold
perfHud.TextSize = 12
perfHud.Text = "FPS: 60 | Ping: 0ms"
perfHud.Visible = false
perfHud.Parent = gui
corner(perfHud, 8)
addStroke(perfHud, Color3.fromRGB(120, 240, 160), 0.6, 1)

-- ===================== MENU CHINH (UI GỌN ĐẸP) =====================
local MENU_W, MENU_H = 336, 404

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.fromOffset(118, 38)
toggleBtn.Position = UDim2.new(0, 12, 0.5, -19)
toggleBtn.BackgroundColor3 = uiThemes[1].card
toggleBtn.TextColor3 = Color3.fromRGB(255, 225, 95)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.Text = "VINHDZ"
toggleBtn.Parent = gui
corner(toggleBtn, 10)
addStroke(toggleBtn, Color3.fromRGB(255, 225, 95), 0.35, 1.4)

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(MENU_W, MENU_H)
frame.Position = UDim2.new(0, 140, 0.5, -MENU_H / 2)
frame.BackgroundColor3 = uiThemes[1].bg
frame.Active = true
frame.ClipsDescendants = true
frame.Parent = gui
corner(frame, 14)
addStroke(frame, Color3.fromRGB(255, 225, 95), 0.45, 1.4)

-- Top bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 42)
topBar.BackgroundColor3 = uiThemes[1].card
topBar.BorderSizePixel = 0
topBar.Parent = frame

local header = Instance.new("TextButton")
header.Size = UDim2.new(1, -76, 1, 0)
header.Position = UDim2.new(0, 12, 0, 0)
header.BackgroundTransparency = 1
header.Text = "VINHDZ HUB"
header.TextColor3 = Color3.fromRGB(255, 225, 95)
header.Font = Enum.Font.GothamBold
header.TextSize = 15
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = topBar

local miniBtn = Instance.new("TextButton")
miniBtn.Size = UDim2.fromOffset(28, 28)
miniBtn.Position = UDim2.new(1, -66, 0.5, -14)
miniBtn.BackgroundColor3 = Color3.fromRGB(58, 64, 82)
miniBtn.TextColor3 = Color3.new(1, 1, 1)
miniBtn.Font = Enum.Font.GothamBold
miniBtn.TextSize = 15
miniBtn.Text = "-"
miniBtn.Parent = topBar
corner(miniBtn, 7)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(185, 62, 68)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.Text = "X"
closeBtn.Parent = topBar
corner(closeBtn, 7)
closeBtn.MouseButton1Click:Connect(function() frame.Visible = false end)

local minimized = false
miniBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	frame.Size = minimized and UDim2.fromOffset(MENU_W, 42) or UDim2.fromOffset(MENU_W, MENU_H)
	miniBtn.Text = minimized and "+" or "-"
end)

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
tabBar.Size = UDim2.new(1, -16, 0, 32)
tabBar.Position = UDim2.new(0, 8, 0, 48)
tabBar.BackgroundTransparency = 1
tabBar.Parent = frame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 5)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Parent = tabBar

local pages = {}
local tabButtons = {}
local activeTab = "Chien dau"

local function createPage(name)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -92)
	scroll.Position = UDim2.new(0, 8, 0, 86)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(130, 140, 170)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Visible = (name == activeTab)
	scroll.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = scroll

	pages[name] = { scroll = scroll, order = 0 }

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.24, -2, 1, 0)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = name
	btn.Parent = tabBar
	corner(btn, 7)
	tabButtons[name] = btn

	btn.MouseButton1Click:Connect(function()
		if minimized then
			minimized = false
			frame.Size = UDim2.fromOffset(MENU_W, MENU_H)
			miniBtn.Text = "-"
		end
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
local pageUtil = createPage("Tien ich")

local function applyUiTheme()
	local t = uiThemes[state.uiThemeIdx]
	frame.BackgroundColor3 = t.bg
	topBar.BackgroundColor3 = t.card
	toggleBtn.BackgroundColor3 = t.card
	targetHud.BackgroundColor3 = t.card
	perfHud.BackgroundColor3 = t.card
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
	corner(b, 7)

	local on = initialOn or false
	local function refresh()
		b.Text = text and (text .. ": " .. (on and "BAT" or "TAT")) or (on and "BAT" or "TAT")
		b.BackgroundColor3 = on and Color3.fromRGB(42, 158, 92) or Color3.fromRGB(62, 66, 82)
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
	row.Size = UDim2.new(1, -6, 0, 34)
	row.BackgroundTransparency = 1
	row.LayoutOrder = nextOrder(page)
	row.Parent = page.scroll
	return makeToggleButton(row, UDim2.new(1, 0, 1, 0), nil, onChange, text, initialOn)
end

local function makeActionRow(page, text, color, onClick)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 34)
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
	corner(b, 7)

	b.MouseButton1Click:Connect(function() onClick(b) end)
	return b
end

local function makeSliderBlock(page, title, minV, maxV, init, onValue, onToggle, suffix)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -6, 0, 64)
	f.BackgroundColor3 = uiThemes[state.uiThemeIdx].card
	f.LayoutOrder = nextOrder(page)
	f.Parent = page.scroll
	corner(f, 9)
	table.insert(uiCards, f)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.66, 0, 0, 26)
	lbl.Position = UDim2.new(0, 12, 0, 3)
	lbl.BackgroundTransparency = 1
	lbl.Text = title .. ": " .. init .. (suffix or "")
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 13
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f

	local toggleSetter
	if onToggle then
		toggleSetter = makeToggleButton(f, UDim2.fromOffset(58, 22), UDim2.new(1, -68, 0, 5), onToggle)
	end

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -28, 0, 8)
	track.Position = UDim2.new(0, 14, 0, 44)
	track.BackgroundColor3 = Color3.fromRGB(64, 68, 84)
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
	hit.Size = UDim2.new(1, 0, 0, 30)
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
setters.ignoreTeam = makeToggleRow(pageCombat, "Bo qua cung team", function(on)
	state.ignoreTeam = on
	if state.esp then syncEspTargets() end
end)
setters.playersOnly = makeToggleRow(pageCombat, "Chi muc tieu nguoi choi", function(on)
	state.playersOnly = on
	collectAllTargetModels(true)
	if state.esp then syncEspTargets() end
end)
setters.ignoreCrouch = makeToggleRow(pageCombat, "Bo qua muc tieu ngoi", function(on) state.ignoreCrouch = on end)
setters.aim = makeToggleRow(pageCombat, "Ho tro ngam", function(on) state.aim = on end)
setters.autoAim = makeToggleRow(pageCombat, "Auto ngam lien tuc", function(on) state.autoAim = on end)
setters.triggerBot = makeToggleRow(pageCombat, "Auto ban khi co dich", function(on) state.triggerBot = on end)
makeToggleRow(pageCombat, "Chi auto ban trong FOV", function(on) state.triggerFovOnly = on end, true)
makeSliderBlock(pageCombat, "Nhip auto ban (ms)", 50, 800, math.floor(state.triggerCooldown * 1000), function(v)
	state.triggerCooldown = v / 1000
end, nil, "ms")
setters.targetLockOn = makeToggleRow(pageCombat, "Khoa muc tieu (Phim T)", function(on)
	state.targetLockOn = on
	if not on then state.lockedTargetModel = nil end
end)
makeActionRow(pageCombat, "Diem ngam: Dau", Color3.fromRGB(65, 95, 145), function(btn)
	if state.aimPartMode == "Head" then
		state.aimPartMode = "HumanoidRootPart"
		btn.Text = "Diem ngam: Than"
	else
		state.aimPartMode = "Head"
		btn.Text = "Diem ngam: Dau"
	end
end)
setters.aimPredict = makeToggleRow(pageCombat, "Du doan huong di chuyen", function(on) state.aimPredict = on end)
setters.targetLine = makeToggleRow(pageCombat, "Duong ke toi muc tieu", function(on)
	state.targetLine = on
	if not on then targetLineFrame.Visible = false end
end)
setters.targetInfoHud = makeToggleRow(pageCombat, "Hien thong tin muc tieu", function(on)
	state.targetInfoHud = on
	targetHud.Visible = on
end)
makeSliderBlock(pageCombat, "Do muot ngam", 4, 40, state.aimSmooth, function(v) state.aimSmooth = v end)
makeSliderBlock(pageCombat, "Vong FOV ngam", 50, 400, state.fov, function(v)
	state.fov = v
	circle.Size = UDim2.fromOffset(v * 2, v * 2)
end)
makeActionRow(pageCombat, "Mau vong FOV: " .. fovColors[1].name, Color3.fromRGB(70, 75, 95), function(btn)
	state.fovColorIdx = (state.fovColorIdx % #fovColors) + 1
	btn.Text = "Mau vong FOV: " .. fovColors[state.fovColorIdx].name
	fovStroke.Color = fovColors[state.fovColorIdx].color
end)

-- ===== TAB DI CHUYEN =====
setters.speedOn = makeSliderBlock(pageMove, "Toc do chay", 16, 200, state.speed,
	function(v) state.speed = v applyStats() end,
	function(on) state.speedOn = on applyStats() end)
setters.sprintBoost = makeSliderBlock(pageMove, "Chay nhanh (Shift)", 30, 250, state.sprintSpeed,
	function(v) state.sprintSpeed = v applyStats() end,
	function(on) state.sprintBoost = on applyStats() end)
setters.antiSlow = makeToggleRow(pageMove, "Chong giam toc do", function(on) state.antiSlow = on end)
setters.jumpOn = makeSliderBlock(pageMove, "Do cao nhay", 50, 300, state.jump,
	function(v) state.jump = v applyStats() end,
	function(on) state.jumpOn = on applyStats() end)
setters.infJump = makeToggleRow(pageMove, "Nhay vo han", function(on) state.infJump = on end)
setters.noclip = makeToggleRow(pageMove, "Xuyen tuong (N)", function(on) setNoclip(on) end)
setters.fly = makeToggleRow(pageMove, "Bay (F / joystick)", function(on) setFly(on) end)
makeSliderBlock(pageMove, "Toc do bay", 10, 200, state.flySpeed, function(v) state.flySpeed = v end)
setters.airWalk = makeToggleRow(pageMove, "Di bo tren khong", function(on) setAirWalk(on) end)
setters.freezeChar = makeToggleRow(pageMove, "Dong bang nhan vat", function(on) setFreeze(on) end)
setters.lowGrav = makeSliderBlock(pageMove, "Trong luc thap", 10, 196, state.gravValue,
	function(v) state.gravValue = v applyStats() end,
	function(on) state.lowGrav = on applyStats() end)
setters.spinOn = makeSliderBlock(pageMove, "Xoay nhan vat", 2, 40, state.spinSpeed,
	function(v) state.spinSpeed = v end,
	function(on) state.spinOn = on end)
makeActionRow(pageMove, "Luot nhanh ve phia truoc (Q)", Color3.fromRGB(56, 130, 210), doDash)
makeActionRow(pageMove, "Luu vi tri hien tai", Color3.fromRGB(46, 150, 110), function(btn)
	local _, hrp = getChar()
	if hrp then
		state.savedCFrame = hrp.CFrame
		btn.Text = "Da luu vi tri!"
		task.delay(1, function() if btn then btn.Text = "Luu vi tri hien tai" end end)
	end
end)
makeActionRow(pageMove, "Dich chuyen toi vi tri da luu", Color3.fromRGB(95, 110, 185), function()
	local _, hrp = getChar()
	if hrp and state.savedCFrame then
		hrp.CFrame = state.savedCFrame + Vector3.new(0, 2, 0)
	end
end)

-- ===== TAB HIEN THI =====
setters.esp = makeToggleRow(pageVisual, "ESP tat ca muc tieu", function(on) setEsp(on) end)
makeToggleRow(pageVisual, "Ten + Khoang cach ESP", function(on)
	state.espTag = on
	refreshEspColors()
end, true)
makeToggleRow(pageVisual, "Hien mau tren ESP", function(on)
	state.espHealth = on
end, true)
makeToggleRow(pageVisual, "Khung hop ESP (Box)", function(on)
	state.espBox = on
	refreshEspColors()
end)
makeToggleRow(pageVisual, "Tia dan huong ESP (Tracer)", function(on)
	state.espTracer = on
	refreshEspColors()
end)
makeSliderBlock(pageVisual, "Tam hien ESP", 50, 2000, state.espMaxDist, function(v)
	state.espMaxDist = v
	if state.esp then syncEspTargets() end
end, nil, "m")
makeSliderBlock(pageVisual, "Do mo phu ESP", 0, 95, state.espFillTrans, function(v)
	state.espFillTrans = v
	refreshEspColors()
end, nil, "%")
makeActionRow(pageVisual, "Mau ESP: " .. espThemes[1].name, Color3.fromRGB(65, 95, 145), function(btn)
	state.espColorIdx = (state.espColorIdx % #espThemes) + 1
	btn.Text = "Mau ESP: " .. espThemes[state.espColorIdx].name
	refreshEspColors()
end)
makeToggleRow(pageVisual, "Hien vong FOV", function(on) state.showFov = on end, true)
makeSliderBlock(pageVisual, "Goc nhin Camera FOV", 50, 120, state.camFov, function(v)
	state.camFov = v
	local cam = workspace.CurrentCamera
	if cam then cam.FieldOfView = v end
end)
setters.fullbright = makeToggleRow(pageVisual, "Sang toan ban do", function(on)
	state.fullbright = on
	applyLighting()
end)
setters.noFog = makeToggleRow(pageVisual, "Xoa suong mu", function(on)
	state.noFog = on
	applyLighting()
end)
makeActionRow(pageVisual, "Mau giao dien: " .. uiThemes[1].name, Color3.fromRGB(70, 75, 95), function(btn)
	state.uiThemeIdx = (state.uiThemeIdx % #uiThemes) + 1
	btn.Text = "Mau giao dien: " .. uiThemes[state.uiThemeIdx].name
	applyUiTheme()
end)

-- ===== TAB TIEN ICH =====
makeToggleRow(pageUtil, "Chong AFK tu dong", function(on) state.antiAfk = on end, true)
setters.respawnAtDeath = makeToggleRow(pageUtil, "Hoi sinh tai cho chet", function(on) state.respawnAtDeath = on end)
setters.showPerf = makeToggleRow(pageUtil, "Hien FPS & Ping", function(on)
	state.showPerf = on
	perfHud.Visible = on
end)
setters.camLockThird = makeToggleRow(pageUtil, "Khoa goc nhin thu 3", function(on)
	state.camLockThird = on
	player.CameraMode = Enum.CameraMode.Classic
	if on then
		player.CameraMinZoomDistance = 8
	else
		player.CameraMinZoomDistance = 0.5
	end
end)
setters.autoEquip = makeToggleRow(pageUtil, "Tu trang bi Tool trong tui", function(on) state.autoEquip = on end)
makeActionRow(pageUtil, "Giam hieu ung / Tang FPS", Color3.fromRGB(56, 145, 130), applyFpsBoost)
makeActionRow(pageUtil, "Reset tat ca ve mac dinh", Color3.fromRGB(175, 65, 65), resetAll)

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

local dashBtn = Instance.new("TextButton")
dashBtn.Size = UDim2.fromOffset(66, 66)
dashBtn.Position = UDim2.new(1, -168, 1, -260)
dashBtn.BackgroundColor3 = Color3.fromRGB(56, 130, 210)
dashBtn.BackgroundTransparency = 0.25
dashBtn.TextColor3 = Color3.new(1, 1, 1)
dashBtn.Font = Enum.Font.GothamBold
dashBtn.TextSize = 14
dashBtn.Text = "LUOT"
dashBtn.Visible = isTouch
dashBtn.Parent = gui
corner(dashBtn, 33)
dashBtn.MouseButton1Click:Connect(doDash)

-- ===== TIM MUC TIEU & PHIM TAT =====
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getAimPartFromModel(model, root)
	if state.aimPartMode == "Head" then
		return model:FindFirstChild("Head") or root
	end
	return root
end

local function getTarget()
	local camera = workspace.CurrentCamera
	if not camera then return nil, nil end

	if state.targetLockOn and state.lockedTargetModel then
		local ok, root = isValidTargetModel(state.lockedTargetModel)
		if ok and root then
			return getAimPartFromModel(state.lockedTargetModel, root), state.lockedTargetModel
		else
			state.lockedTargetModel = nil
		end
	end

	local center = camera.ViewportSize / 2
	local best, bestModel, bestDist = nil, nil, state.fov
	local myChar = player.Character

	for _, m in ipairs(collectAllTargetModels()) do
		local ok, root = isValidTargetModel(m)
		if ok and root then
			local aimPart = getAimPartFromModel(m, root)
			local pos, onScreen = camera:WorldToViewportPoint(aimPart.Position)
			if onScreen then
				local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
				if d < bestDist then
					rayParams.FilterDescendantsInstances = { myChar, m }
					local blocked = workspace:Raycast(camera.CFrame.Position, aimPart.Position - camera.CFrame.Position, rayParams)
					if not blocked then
						best, bestModel, bestDist = aimPart, m, d
					end
				end
			end
		end
	end

	return best, bestModel
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.M then
		frame.Visible = not frame.Visible
	elseif input.KeyCode == Enum.KeyCode.F then
		setFly(not state.fly)
	elseif input.KeyCode == Enum.KeyCode.N then
		setNoclip(not state.noclip)
	elseif input.KeyCode == Enum.KeyCode.Q then
		doDash()
	elseif input.KeyCode == Enum.KeyCode.T and state.targetLockOn then
		if state.lockedTargetModel then
			state.lockedTargetModel = nil
		else
			local _, m = getTarget()
			state.lockedTargetModel = m
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift and state.sprintBoost then
		applyStats()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift and state.sprintBoost then
		applyStats()
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
local lastEspSync = 0
local lastPerfUpdate = 0
local frameCounter = 0

RunService.RenderStepped:Connect(function(dt)
	local camera = workspace.CurrentCamera
	local char, myHrp, hum = getChar()
	local now = os.clock()

	frameCounter += 1
	if state.showPerf and now - lastPerfUpdate >= 0.5 then
		local fps = math.floor(frameCounter / (now - lastPerfUpdate) + 0.5)
		frameCounter = 0
		lastPerfUpdate = now
		local ping = 0
		pcall(function()
			ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5)
		end)
		perfHud.Text = string.format("FPS: %d | Ping: %dms", fps, ping)
	end

	if hum and hum.Health > 0 then
		if state.antiSlow then
			local targetSpd = state.speedOn and state.speed or DEFAULT_SPEED
			if hum.WalkSpeed < targetSpd then hum.WalkSpeed = targetSpd end
		end
		if state.autoEquip and char and not char:FindFirstChildOfClass("Tool") then
			local bp = player:FindFirstChildOfClass("Backpack")
			local tool = bp and bp:FindFirstChildOfClass("Tool")
			if tool then hum:EquipTool(tool) end
		end
	end

	if state.airWalk and airPart and myHrp then
		airPart.Position = Vector3.new(myHrp.Position.X, myHrp.Position.Y - 3.5, myHrp.Position.Z)
	end
	if state.spinOn and myHrp and not state.freezeChar then
		myHrp.CFrame = myHrp.CFrame * CFrame.Angles(0, math.rad(state.spinSpeed), 0)
	end

	if state.esp and now - lastEspSync >= 0.5 then
		lastEspSync = now
		syncEspTargets()
	end

	if state.esp then
		local origin = myHrp and myHrp.Position or (camera and camera.CFrame.Position or Vector3.zero)
		local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
		local tracerStart = Vector2.new(vp.X / 2, vp.Y)

		for model, tag in pairs(espTags) do
			local ok, root, tHum = isValidTargetModel(model)
			if ok and root then
				if state.espTag and tag.label then
					local dist = math.floor((root.Position - origin).Magnitude + 0.5)
					if state.espHealth and tHum then
						tag.label.Text = string.format("%s [%dm] | %d HP", tag.name, dist, math.floor(tHum.Health + 0.5))
					else
						tag.label.Text = string.format("%s [%dm]", tag.name, dist)
					end
				end

				local tr = espTracers[model]
				if tr and state.espTracer and camera then
					local pos, onScreen = camera:WorldToViewportPoint(root.Position)
					if onScreen and pos.Z > 0 then
						local p2 = Vector2.new(pos.X, pos.Y)
						local delta = p2 - tracerStart
						local mid = (tracerStart + p2) / 2
						tr.Visible = true
						tr.Position = UDim2.fromOffset(mid.X, mid.Y)
						tr.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
						tr.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					else
						tr.Visible = false
					end
				elseif tr then
					tr.Visible = false
				end
			end
		end
	end

	if char and (state.noclip or state.fly) then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				if savedCollide[part] == nil then savedCollide[part] = part.CanCollide end
				part.CanCollide = false
			end
		end
	elseif next(savedCollide) ~= nil then
		for part, canCollide in pairs(savedCollide) do
			if part and part.Parent then part.CanCollide = canCollide end
		end
		table.clear(savedCollide)
	end

	if state.fly and bv and hum and camera then
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

	local aimPart, aimModel = getTarget()

	if state.targetInfoHud then
		if aimModel then
			local _, _, tHum, tPlr = isValidTargetModel(aimModel)
			local tName = tPlr and tPlr.DisplayName or aimModel.Name
			local hp = tHum and math.floor(tHum.Health + 0.5) or 0
			targetHud.Text = string.format("Muc tieu: %s (%d HP)", tName, hp)
		else
			targetHud.Text = "Muc tieu: Khong co"
		end
	end

	if state.targetLine and aimPart and camera then
		local pos, onScreen = camera:WorldToViewportPoint(aimPart.Position)
		if onScreen and pos.Z > 0 then
			local startP = camera.ViewportSize / 2
			local endP = Vector2.new(pos.X, pos.Y)
			local delta = endP - startP
			local mid = (startP + endP) / 2
			targetLineFrame.Visible = true
			targetLineFrame.Position = UDim2.fromOffset(mid.X, mid.Y)
			targetLineFrame.Size = UDim2.fromOffset(delta.Magnitude, 2)
			targetLineFrame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		else
			targetLineFrame.Visible = false
		end
	else
		targetLineFrame.Visible = false
	end

	local shouldAim = state.aim and (
		state.autoAim
		or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		or state.aimHeld
	)

	if shouldAim and camera and aimPart then
		local aimPos = aimPart.Position
		if state.aimPredict then
			aimPos += aimPart.AssemblyLinearVelocity * 0.12
		end
		local target = CFrame.lookAt(camera.CFrame.Position, aimPos)
		camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-state.aimSmooth * dt))
	end

	if state.triggerBot and aimPart and camera and (now - lastTriggerShot >= state.triggerCooldown) then
		local canShoot = true
		if state.triggerFovOnly then
			local pos, onScreen = camera:WorldToViewportPoint(aimPart.Position)
			if not onScreen or pos.Z <= 0 then
				canShoot = false
			else
				local center = camera.ViewportSize / 2
				local dist2D = (Vector2.new(pos.X, pos.Y) - center).Magnitude
				if dist2D > state.fov then canShoot = false end
			end
		end

		if canShoot then
			lastTriggerShot = now
			triggerFireOnce()
		end
	end
end)

task.defer(function()
	applyStats()
	applyLighting()
end)
