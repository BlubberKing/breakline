-- SettingsClient v1.3 (v5.21: the gear is smaller (36 px) and a bit further right + down (ICON_X 212, ICON_DOWN 18); NEW setting PICTURE MODE (NO HUD): hides every other
--   ScreenGui, the Roblox core GUIs (chat / list / backpack / health ...), proximity prompts, the 3D name tags + damage numbers over players, and - in first person - your
--   hands, the gun / gadget in them and your own body, so the screen is just the world; this gear (and its panel) stays so you can switch back. It is NOT saved.)
-- (v1.2 = v5.18: the gear sits a little lower + further right (it sat right on top of the Roblox buttons) - ICON_X / ICON_DOWN; the panel is now a TALL
--   single column (CONTROLS, then AUDIO + VISUALS, then INTERFACE stacked) instead of a wide three-column strip) (v1 LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games (Lobby + Breakline), keep the two copies identical. NEW in v5.17 (GDD 5.12).
-- SETTINGS: a round gear button in the top left, right next to the Roblox chat / microphone buttons (ICON_X below: move it left / right if it overlaps
-- yours). Click it (or press ESC to close) = a long horizontal panel in the middle of the screen with three columns:
--   CONTROLS          MOUSE SENSITIVITY (the sensitivity bar), AIM SENSITIVITY, FIELD OF VIEW
--   AUDIO + VISUALS   MASTER VOLUME, SCREEN SHAKE
--   INTERFACE         DAMAGE NUMBERS on / off, SHOW FPS + PING on / off
-- plus RESET TO DEFAULTS. Changes apply at once and are saved in the profile (SettingsServer -> key Settings, attribute SettingsJson), so they follow you
-- from the lobby into every match. What reads them: GunClient (sensitivity / FOV / shake), HitFX (damage numbers), Sfx (master volume), and this script
-- (lobby mouse sensitivity, FPS readout).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")
local StarterGui = game:GetService("StarterGui")
local ProximityPromptService = game:GetService("ProximityPromptService")

local ICON_X = 212    -- left edge of the gear button in pixels (Roblox menu + chat + mic sit to its left). Bigger = further right. (v5.18: 176 -> 200, v5.21: -> 212)
local ICON_DOWN = 18  -- v5.18: pixels the gear sits BELOW the middle of the Roblox top bar. Bigger = lower. (0 = level with the Roblox buttons) (v5.21: 14 -> 18)
local BTN_SIZE = 36   -- v5.21: gear diameter in pixels (was 44)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UI = require(RS:WaitForChild("UIKit"))
local Settings = require(RS:WaitForChild("Settings"))
local K, F, new = UI.C, UI.F, UI.new
local SaveR = RS:WaitForChild("SettingsRemotes", 30) and RS.SettingsRemotes:WaitForChild("Save", 10)

local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local function tween(o, t, goal) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal):Play() end
local function gunSystemOn() return RS:FindFirstChild("MatchState") ~= nil or player:GetAttribute("InTraining") == true end

-- what the player changed (only these are saved); effective values = Settings.Get
local panelOpen = false
local saved = {}
do
	local raw = player:GetAttribute("SettingsJson")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok then saved = Settings.Clean(t) end
	end
end
player:GetAttributeChangedSignal("SettingsJson"):Connect(function()
	-- the profile loads a moment after joining: take its values unless we are in the middle of editing
	if not panelOpen then
		local raw = player:GetAttribute("SettingsJson")
		local ok, t = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw ~= "" and raw or "{}")
		if ok then saved = Settings.Clean(t) end
	end
end)

local gui = new("ScreenGui", { Name = "SettingsGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 95, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
	player:WaitForChild("PlayerGui"))

-- ======================================================================================
-- the gear button (top left, next to the Roblox chat + mic buttons)
-- ======================================================================================
-- v1.2: the gear no longer depends on the place's GuiInset (it read a different value in the match place, so the gear landed somewhere else than in the lobby).
-- Both places now use the same fixed top-bar height, so the gear is in exactly the same spot everywhere.
local inset = 58
local BTN = BTN_SIZE
local btn = new("TextButton", { Name = "GearButton", Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(ICON_X, math.floor((inset - BTN) / 2) + ICON_DOWN), Size = UDim2.fromOffset(BTN, BTN),
	BackgroundColor3 = rgb(18, 19, 24), BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 5 }, gui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, btn)
local btnStroke = new("UIStroke", { Color = rgb(150, 154, 166), Thickness = 1.5, Transparency = 0.2 }, btn)
local gearTeeth = {}
do
	local g = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundTransparency = 1, ZIndex = 6 }, btn)
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), BackgroundTransparency = 1, ZIndex = 6 }, g)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	local rs = new("UIStroke", { Color = K.text, Thickness = math.max(3, BTN * 0.1), Transparency = 0 }, ring)
	table.insert(gearTeeth, rs)
	for i = 0, 7 do
		local a = math.rad(i * 45)
		local tooth = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.sin(a) * BTN * 0.255, 0.5, -math.cos(a) * BTN * 0.255),
			Size = UDim2.fromOffset(math.max(4, BTN * 0.13), math.max(5, BTN * 0.17)), Rotation = i * 45, BackgroundColor3 = K.text, BorderSizePixel = 0, ZIndex = 6 }, g)
		new("UICorner", { CornerRadius = UDim.new(0, 1) }, tooth)
		table.insert(gearTeeth, tooth)
	end
	local spin = 0
	btn.MouseEnter:Connect(function()
		tween(btn, 0.14, { BackgroundColor3 = K.red })
		tween(btnStroke, 0.14, { Color = K.redHi })
		spin += 45
		tween(g, 0.35, { Rotation = spin })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.14, { BackgroundColor3 = rgb(18, 19, 24) })
		tween(btnStroke, 0.14, { Color = rgb(150, 154, 166) })
	end)
end
local statsLbl = new("TextLabel", { Name = "Stats", BackgroundTransparency = 1, Position = UDim2.fromOffset(ICON_X + BTN + 10, math.floor((inset - BTN) / 2) + ICON_DOWN), Size = UDim2.fromOffset(230, BTN),
	Text = "", TextSize = 15, FontFace = F.MB, TextColor3 = K.text, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 5 }, gui)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.35 }, statsLbl)

-- ======================================================================================
-- the panel
-- ======================================================================================
local overlay = new("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 20 }, gui)
local modal = new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Visible = false }, gui)
local blocker = new("TextButton", { Name = "Blocker", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20 }, overlay)
local canvas = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1, ZIndex = 21 }, overlay)
local cScale = new("UIScale", {}, canvas)
local function rescale()
	local vp = camera.ViewportSize
	cScale.Scale = math.max(0.35, math.min(vp.X / 1920, vp.Y / 1080))
end
rescale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

-- v5.18: TALL single column (was a 1560 x 580 strip with three columns). The height follows the rows (computed below).
local PW = 660
local SEC_H, SLIDER_H, TOGGLE_H, SEC_GAP = 38, 96, 66, 12
local PH = 116
do
	local cols = {}
	for _, d in Settings.LIST do cols[d.col] = cols[d.col] or {} table.insert(cols[d.col], d) end
	for c = 1, 3 do
		if cols[c] then
			PH += SEC_H
			for _, d in cols[c] do PH += (d.kind == "slider") and SLIDER_H or TOGGLE_H end
			PH += SEC_GAP
		end
	end
	PH += 84
end
local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 540), Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = rgb(10, 11, 14),
	BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 22, Active = true }, canvas)
new("UIStroke", { Color = K.line2, Thickness = 1.5, Transparency = 0.1 }, panel)
local pScale = new("UIScale", { Scale = 1 }, panel)
new("Frame", { Size = UDim2.fromOffset(PW, 4), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 23 }, panel)
local function label(parent, text, size, x, y, w, h, font, color, align, z)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font, TextColor3 = color, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		TextXAlignment = align or Enum.TextXAlignment.Left, ZIndex = z or 24 }, parent)
end
label(panel, "SETTINGS", 52, 44, 24, 500, 64, F.H, K.text)
local closeBtn = UI.CloseButton(panel, "CLOSE", { Position = UDim2.fromOffset(PW - 152 - 36, 34), ZIndex = 30 })
local savedLbl = label(panel, "", 14, PW - 152 - 36 - 220, 46, 200, 20, F.MB, K.green, Enum.TextXAlignment.Right)
new("Frame", { Position = UDim2.fromOffset(44, 100), Size = UDim2.fromOffset(PW - 88, 1), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = 23 }, panel)

local COLS = { { name = "CONTROLS" }, { name = "AUDIO + VISUALS" }, { name = "INTERFACE" } }
local COL_W = PW - 88
-- v5.18: the sections are stacked: each one gets its title row, then its settings, then a thin divider
local secY = {} -- col -> y of its first row
do
	local y = 116
	local byCol = {}
	for _, d in Settings.LIST do byCol[d.col] = (byCol[d.col] or 0) + ((d.kind == "slider") and SLIDER_H or TOGGLE_H) end
	for i, c in COLS do
		if byCol[i] then
			if i > 1 then new("Frame", { Position = UDim2.fromOffset(44, y - SEC_GAP / 2 - 1), Size = UDim2.fromOffset(COL_W, 1), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = 23 }, panel) end
			label(panel, c.name, 22, 44, y, COL_W, 28, F.H, K.redHi)
			secY[i] = y + SEC_H
			y += SEC_H + byCol[i] + SEC_GAP
		end
	end
end

local widgets = {} -- key -> { refresh = fn }
local dragging -- the slider being dragged
local pending = false

local session = {} -- v5.21: the settings that are NOT saved (PICTURE MODE): off every time you join
local function effective(key)
	local d0 = Settings.ByKey[key]
	if d0 and d0.session then
		local sv = session[key]
		if sv ~= nil then return sv end
		return d0.default
	end
	local v = saved[key]
	if v ~= nil then return v end
	local d = Settings.ByKey[key]
	if key == "Sens" then return Settings.DEFAULT_SENS end
	return d.default
end

local function pushSave()
	if pending then return end
	pending = true
	task.delay(0.5, function()
		pending = false
		if SaveR then SaveR:FireServer(saved) end
		savedLbl.Text = "SAVED"
		task.delay(1.6, function() if savedLbl.Text == "SAVED" then savedLbl.Text = "" end end)
	end)
end
local applyAll
local function changed(skipSave)
	pcall(function() player:SetAttribute("SettingsJson", HttpService:JSONEncode(saved)) end) -- local copy at once; the server sets the same text a moment later
	applyAll()
	if not skipSave then pushSave() end
end

local rowY = {}
for _, d in Settings.LIST do
	local col = d.col
	rowY[col] = rowY[col] or secY[col] or 160
	local y = rowY[col]
	local x = 44
	label(panel, d.name, 22, x, y, COL_W - 130, 28, F.H, K.text)
	label(panel, d.note or "", 12, x, y + 30, COL_W, 18, F.M, K.mute)
	if d.kind == "slider" then
		local val = label(panel, "", 26, x + COL_W - 130, y - 4, 130, 34, F.H, K.redHi, Enum.TextXAlignment.Right)
		local track = new("Frame", { Position = UDim2.fromOffset(x, y + 66), Size = UDim2.fromOffset(COL_W, 8), BackgroundColor3 = K.panel3, BorderSizePixel = 0, ZIndex = 24 }, panel)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 25 }, track)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
		local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 27 }, track)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
		new("UIStroke", { Color = K.red, Thickness = 3 }, knob)
		-- the default tick
		local dv = (d.key == "Sens") and Settings.DEFAULT_SENS or d.default
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((dv - d.min) / (d.max - d.min), 0, 0.5, 0), Size = UDim2.fromOffset(2, 18), BackgroundColor3 = K.dim, BorderSizePixel = 0, ZIndex = 26 }, track)
		local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(x - 14, y + 44), Size = UDim2.fromOffset(COL_W + 28, 52), ZIndex = 30 }, panel)
		local function show()
			local v = effective(d.key)
			local f = (v - d.min) / (d.max - d.min)
			fill.Size = UDim2.fromScale(f, 1)
			knob.Position = UDim2.new(f, 0, 0.5, 0)
			val.Text = string.format(d.fmt, v * (d.scale or 1))
		end
		local function setFromX(px)
			local f = math.clamp((px - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
			local v = d.min + f * (d.max - d.min)
			v = math.floor(v / d.step + 0.5) * d.step
			saved[d.key] = math.clamp(v, d.min, d.max)
			show()
			changed()
		end
		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = { setFromX = setFromX }
				setFromX(input.UserInputType == Enum.UserInputType.Touch and input.Position.X or UIS:GetMouseLocation().X)
			end
		end)
		widgets[d.key] = { refresh = show }
		rowY[col] += SLIDER_H
	else
		local sw = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x + COL_W - 86, y), Size = UDim2.fromOffset(86, 40), BackgroundColor3 = K.panel3, BorderSizePixel = 0, ZIndex = 25 }, panel)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, sw)
		local swSt = new("UIStroke", { Color = K.line2, Thickness = 1.5 }, sw)
		local kn = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 26 }, sw)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, kn)
		local onT = label(sw, "ON", 15, 10, 0, 40, 40, F.H, WHITE, Enum.TextXAlignment.Center, 26)
		local function show()
			local on = effective(d.key) == true
			tween(sw, 0.14, { BackgroundColor3 = on and K.red or K.panel3 })
			tween(swSt, 0.14, { Color = on and K.redHi or K.line2 })
			tween(kn, 0.14, { Position = on and UDim2.new(1, -35, 0.5, 0) or UDim2.new(0, 5, 0.5, 0) })
			onT.Text = on and "ON" or "OFF"
			onT.Position = on and UDim2.fromOffset(8, 0) or UDim2.fromOffset(40, 0)
		end
		sw.MouseButton1Click:Connect(function()
			local nv = not (effective(d.key) == true)
			if d.session then session[d.key] = nv else saved[d.key] = nv end
			show()
			changed(d.session == true)
		end)
		widgets[d.key] = { refresh = show }
		rowY[col] += TOGGLE_H
	end
end

-- RESET TO DEFAULTS
local reset = new("TextButton", { Text = "RESET TO DEFAULTS", AutoButtonColor = false, Position = UDim2.fromOffset(44, PH - 78), Size = UDim2.fromOffset(300, 48),
	BackgroundColor3 = K.panel2, BorderSizePixel = 0, TextSize = 20, FontFace = F.H, TextColor3 = K.text, ZIndex = 25 }, panel)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, reset)
local rSt = new("UIStroke", { Color = K.line2, Thickness = 1.5 }, reset)
reset.MouseEnter:Connect(function()
	tween(reset, 0.12, { BackgroundColor3 = K.red })
	tween(rSt, 0.12, { Color = K.redHi })
end)
reset.MouseLeave:Connect(function()
	tween(reset, 0.12, { BackgroundColor3 = K.panel2 })
	tween(rSt, 0.12, { Color = K.line2 })
end)
reset.MouseButton1Click:Connect(function()
	saved = {}
	session = {}
	for _, w in widgets do w.refresh() end
	changed()
end)
label(panel, "Saved + used in every match.", 13, 362, PH - 64, PW - 400, 20, F.B, K.mute)

-- slider dragging (global, so the knob keeps following outside the track)
UIS.InputChanged:Connect(function(input)
	if not dragging then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragging.setFromX(UIS:GetMouseLocation().X)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		dragging.setFromX(input.Position.X)
	end
end)
UIS.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then dragging = nil end
end)

-- ======================================================================================
-- open / close
-- ======================================================================================
local function setOpen(on)
	if on == panelOpen then return end
	panelOpen = on
	dragging = nil
	if on then
		for _, w in widgets do w.refresh() end
		overlay.Visible = true
		modal.Visible = true
		player:SetAttribute("SettingsOpen", true)
		if gunSystemOn() then player:SetAttribute("GunMenuOpen", true) end -- guns / gadgets ignore clicks meanwhile, the cursor shows
		pScale.Scale = 0.92
		tween(pScale, 0.2, { Scale = 1 })
		tween(overlay, 0.18, { BackgroundTransparency = 0.5 })
	else
		modal.Visible = false
		player:SetAttribute("SettingsOpen", nil)
		if gunSystemOn() and player:GetAttribute("TrainingMenu") ~= true and player:GetAttribute("PoseWheelOpen") ~= true then player:SetAttribute("GunMenuOpen", nil) end
		tween(overlay, 0.14, { BackgroundTransparency = 1 })
		task.delay(0.15, function() if not panelOpen then overlay.Visible = false end end)
		if SaveR and pending == false then SaveR:FireServer(saved) end
	end
end
btn.MouseButton1Click:Connect(function() setOpen(not panelOpen) end)
blocker.MouseButton1Click:Connect(function() setOpen(false) end)
closeBtn.MouseButton1Click:Connect(function() setOpen(false) end)
UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Escape and panelOpen then setOpen(false) end
end)

-- ======================================================================================
-- applying the settings
-- ======================================================================================
local setPicture -- defined below
function applyAll()
	local S = Settings.Get(player)
	local g = Settings.Master()
	if g then g.Volume = S.Volume end
	local pictureOn = session.PictureMode == true
	statsLbl.Visible = S.ShowStats == true and not pictureOn
	if setPicture then setPicture(pictureOn) end
end

-- ======================================================================================
-- PICTURE MODE (v5.21): nothing on the screen but the world (and this gear). Nothing is destroyed - every thing we switch off is remembered and put back.
--   * every other ScreenGui in PlayerGui (and the 3D prompt guis there), re-checked every frame so a script that turns its gui back on is overruled,
--   * the Roblox core GUIs (chat window, player list, backpack, health, emotes, self view) + proximity prompts,
--   * the 3D name tags / damage numbers over characters and in ClientFX (BillboardGuis),
--   * first person: the viewmodel in the camera (hands, gun, gadget, sleeves) and your own body parts (LocalTransparencyModifier).
-- ======================================================================================
local playerGui = player:WaitForChild("PlayerGui")
local pic = { on = false, guis = {}, bills = {}, vm = {}, core = nil, prompts = nil, conn = nil, bind = false }
local CORE_TYPES = { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu, Enum.CoreGuiType.Health, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.SelfView }
local ENABLED_CLASSES = { "ParticleEmitter", "Beam", "Trail", "PointLight", "SpotLight", "SurfaceLight", "Highlight", "Fire", "Smoke", "Sparkles" }

local function hideGuis()
	for _, g in playerGui:GetChildren() do
		if g ~= gui then
			if g:IsA("ScreenGui") or g:IsA("BillboardGui") then
				if pic.guis[g] == nil then pic.guis[g] = g.Enabled end
				if g.Enabled then g.Enabled = false end
			end
		end
	end
end

local function hideBill(b)
	if not b:IsA("BillboardGui") then return end
	local m = b:FindFirstAncestorOfClass("Model")
	local overChar = m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
	if overChar or b:FindFirstAncestor("ClientFX") ~= nil then
		if pic.bills[b] == nil then pic.bills[b] = b.Enabled end
		b.Enabled = false
	end
end

local function hideVm(inst)
	if inst:IsA("BasePart") then
		if pic.vm[inst] == nil then pic.vm[inst] = { k = "ltm" } end
		if inst.LocalTransparencyModifier < 1 then inst.LocalTransparencyModifier = 1 end
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		if pic.vm[inst] == nil then pic.vm[inst] = { k = "tr", v = inst.Transparency } end
		if inst.Transparency < 1 then inst.Transparency = 1 end
	else
		for _, cn in ENABLED_CLASSES do
			if inst:IsA(cn) then
				if pic.vm[inst] == nil then pic.vm[inst] = { k = "en", v = inst.Enabled } end
				if inst.Enabled then inst.Enabled = false end
				return
			end
		end
	end
end

local function firstPerson()
	local ch = player.Character
	local head = ch and ch:FindFirstChild("Head")
	return head ~= nil and (camera.CFrame.Position - head.Position).Magnitude < 2.2
end

local function pictureStep()
	hideGuis()
	for _, d in camera:GetDescendants() do hideVm(d) end -- the first-person hands + gun + gadget live in the camera
	if firstPerson() then
		local ch = player.Character
		if ch then for _, d in ch:GetDescendants() do if d:IsA("BasePart") then hideVm(d) end end end
	end
end

local function restoreVm()
	for inst, m in pic.vm do
		if inst.Parent then
			if m.k == "ltm" then inst.LocalTransparencyModifier = 0
			elseif m.k == "tr" then inst.Transparency = m.v
			elseif m.k == "en" then inst.Enabled = m.v end
		end
	end
	pic.vm = {}
end

function setPicture(on)
	if on == pic.on then return end
	pic.on = on
	if on then
		-- core GUIs + prompts
		pic.core = {}
		for _, t in CORE_TYPES do
			local ok, v = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, t)
			pic.core[t] = ok and v or false
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false)
		end
		pic.prompts = ProximityPromptService.Enabled
		pcall(function() ProximityPromptService.Enabled = false end)
		-- 3D name tags / damage numbers
		for _, d in workspace:GetDescendants() do hideBill(d) end
		pic.conn = workspace.DescendantAdded:Connect(hideBill)
		RunService:BindToRenderStep("BreaklinePictureMode", Enum.RenderPriority.Last.Value + 5, pictureStep)
		pic.bind = true
		pictureStep()
	else
		if pic.bind then pcall(function() RunService:UnbindFromRenderStep("BreaklinePictureMode") end) pic.bind = false end
		if pic.conn then pic.conn:Disconnect() pic.conn = nil end
		for g, was in pic.guis do if g.Parent then g.Enabled = was end end
		pic.guis = {}
		for b, was in pic.bills do if b.Parent then b.Enabled = was end end
		pic.bills = {}
		restoreVm()
		if pic.core then
			for t, was in pic.core do pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, was) end
			pic.core = nil
		end
		if pic.prompts ~= nil then pcall(function() ProximityPromptService.Enabled = pic.prompts end) pic.prompts = nil end
	end
end

applyAll()
player:GetAttributeChangedSignal("SettingsJson"):Connect(applyAll)

-- lobby: the player's own mouse sensitivity (matches + the training zone use GunClient, which reads the same setting)
RunService.Heartbeat:Connect(function()
	if gunSystemOn() then return end
	local s = Settings.Get(player).Sens
	if type(s) == "number" and UIS.MouseDeltaSensitivity ~= s then UIS.MouseDeltaSensitivity = s end
end)

-- FPS + ping readout
local frames, acc = 0, 0
RunService.RenderStepped:Connect(function(dt)
	frames += 1
	acc += dt
	if acc < 0.5 then return end
	local fps = math.floor(frames / acc + 0.5)
	frames, acc = 0, 0
	if not statsLbl.Visible then return end
	local ping = 0
	pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
	statsLbl.Text = ("%d FPS   %d MS"):format(fps, ping)
	statsLbl.TextColor3 = fps >= 55 and K.text or (fps >= 30 and K.gold or K.redHi)
end)
