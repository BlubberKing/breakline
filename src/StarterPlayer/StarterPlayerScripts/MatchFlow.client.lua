-- MatchFlow v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only.
-- Everything that happens around the match, driven by ReplicatedStorage.MatchState.Phase (set by MatchServer):
--   Pregame   (20 s)  you + teammates stand side by side, loadout dock at the bottom (changeable), clock on top, big numbers flash for 5..1
--   Warp      (9 s)   fade to black -> your soul lights up and flies to a small white door -> flash -> you + teammates run in to the spawn
--   Countdown (3 s)   3 - 2 - 1 on the real map, everybody frozen on their spawn
--   Playing           "GO", then the normal match
--   Result    (3.5 s) cutscene: the winning team celebrates in the middle of the screen
--   Summary           stats + soul multipliers pop in one by one, souls count up, CONTINUE (auto after 15 s) -> lobby
-- All 3D scenes are drawn inside ViewportFrames (black void), except the run-in shot, which is the real map with local-only figures.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UI = require(RS:WaitForChild("UIKit"))
local Skins = require(RS:WaitForChild("Skins"))
local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local C = require(RS:WaitForChild("MatchConfig"))
local TimeScale = require(RS:WaitForChild("TimeScale"))
local Sfx = require(RS:WaitForChild("Sfx"))
local GunModels = RS:FindFirstChild("GunModels") and require(RS.GunModels) or nil
local State = RS:WaitForChild("MatchState")
local Remotes = RS:WaitForChild("MatchRemotes")
local LoadoutR = Remotes:WaitForChild("PregameLoadout")
local ResultR = Remotes:WaitForChild("MatchResult")
local ContinueR = Remotes:WaitForChild("Continue")

local K, F, new, tween = UI.C, UI.F, UI.new, UI.tween
local rgb = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local rng = Random.new()
local function sfx(name) pcall(Sfx.Play, name) end
local function serverNow() return workspace:GetServerTimeNow() end
local function teamColor(t) return t and t.TeamColor.Color or K.red end

local QUICK = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- ================= root gui =================
local gui = new("ScreenGui", { Name = "MatchFlow", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 500,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
-- a button with Modal = true frees the mouse while it is visible (the game locks the mouse for first person)
local modal = new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Visible = false }, gui)
local fade = new("Frame", { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 200, Active = false }, gui)
local flash = new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 210, Active = false }, gui)

-- 1920 x 1080 canvas that is scaled to fit the screen (for 2D layouts)
local function makeCanvas(parent, z)
	local cv = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080),
		BackgroundTransparency = 1, ZIndex = z or 10 }, parent)
	local us = new("UIScale", {}, cv)
	local function fit()
		local v = camera.ViewportSize
		us.Scale = math.max(0.3, math.min(v.X / 1920, v.Y / 1080))
	end
	fit()
	cv:GetPropertyChangedSignal("Parent"):Connect(fit)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	return cv, us
end

-- ================= screen / phase bookkeeping =================
local screens = {}
local function track(inst) table.insert(screens, inst) return inst end
local function killScreens()
	for _, s in screens do if s.Parent then s:Destroy() end end
	table.clear(screens)
end
local renderFns = {}
RunService.RenderStepped:Connect(function(dt)
	for _, fn in renderFns do fn(dt) end
end)

local phaseToken, lastPhase = 0, nil
local function alive(token) return token == phaseToken end

local function setModal(on) modal.Visible = on end

-- ---- world helpers used by the run-in shot ----
local hiddenGuis, warpFolder = {}, nil
local function hideGuis()
	for _, g in player.PlayerGui:GetChildren() do
		if g:IsA("ScreenGui") and g ~= gui and g.Name ~= "LoadingScreen" and g.Enabled then
			hiddenGuis[g] = true
			g.Enabled = false
		end
	end
end
local function setOthersHidden(hide)
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			for _, d in p.Character:GetDescendants() do
				if d:IsA("BasePart") then d.LocalTransparencyModifier = hide and 1 or 0 end
			end
		end
	end
end
local warpActive = false
local function restoreWorld()
	if warpActive then
		warpActive = false
		setOthersHidden(false)
	end
	for g in hiddenGuis do if g.Parent then g.Enabled = true end end
	table.clear(hiddenGuis)
	if warpFolder then warpFolder:Destroy() warpFolder = nil end
	if camera.CameraType == Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end
end

-- ================= helpers: people + scenes =================
local function skinOf(p) return p:GetAttribute("Skin") or Skins.Default end
local function teamMembers()
	local list = {}
	local t = player.Team
	if t and t.Name ~= "Lobby" then
		for _, p in Players:GetPlayers() do
			if p ~= player and p.Team == t then table.insert(list, p) end
		end
	end
	table.sort(list, function(a, b) return a.UserId < b.UserId end)
	table.insert(list, 1, player)
	while #list > 3 do table.remove(list) end
	return list
end

local function parseLoadout()
	local l = { Weapon = Catalog.DefaultWeapon, Move = "", Gadgets = { "", "", "" }, Reserve = { "", "", "" } }
	local raw = player:GetAttribute("LoadoutJson")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			if type(t.Weapon) == "string" and Catalog.Is(t.Weapon, "weapon") then l.Weapon = t.Weapon end
			if type(t.Move) == "string" then l.Move = t.Move end
			for i = 1, 3 do
				if type(t.Gadgets) == "table" and type(t.Gadgets[i]) == "string" then l.Gadgets[i] = t.Gadgets[i] end
				if type(t.Reserve) == "table" and type(t.Reserve[i]) == "string" then l.Reserve[i] = t.Reserve[i] end
			end
		end
	end
	return l
end
local loadout = parseLoadout()
player:GetAttributeChangedSignal("LoadoutJson"):Connect(function() loadout = parseLoadout() end)
local function weaponOf(p)
	if p == player then return loadout.Weapon end
	return p:GetAttribute("Weapon") or Catalog.DefaultWeapon
end

-- ViewportFrame scene: returns { vp, cam, world }
local function newScene(parent, z, transparent)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(3, 4, 6), BackgroundTransparency = transparent and 1 or 0,
		Ambient = rgb(140, 142, 150), LightColor = rgb(255, 250, 244), LightDirection = Vector3.new(-0.4, -0.8, -0.5), ZIndex = z or 2, BorderSizePixel = 0 }, parent)
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	vp.CurrentCamera = cam
	local world = new("Model", { Name = "World" }, vp)
	return { vp = vp, cam = cam, world = world }
end

local function part(parent, size, cf, color, neon, transp, shape)
	return new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Size = size, CFrame = cf, Color = color,
		Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Transparency = transp or 0, Shape = shape or Enum.PartType.Block,
		TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, parent)
end
local function addStars(parent, n, spread, center, depth)
	for _ = 1, n do
		local s = rng:NextNumber(0.08, 0.3)
		local p = center + Vector3.new(rng:NextNumber(-spread, spread), rng:NextNumber(-spread * 0.6, spread * 0.6), rng:NextNumber(-depth, 0))
		part(parent, Vector3.new(s, s, s), CFrame.new(p), rng:NextNumber() < 0.25 and rgb(150, 200, 240) or rgb(214, 216, 222), true, rng:NextNumber(0.1, 0.6), Enum.PartType.Ball)
	end
end
local function discUnder(parent, pos, color, radius)
	-- dark disc with a glowing rim under a figure's feet (cylinders lie along X, so turn them upright)
	local up = CFrame.Angles(0, 0, math.rad(90))
	part(parent, Vector3.new(0.12, radius * 2 + 0.5, radius * 2 + 0.5), CFrame.new(pos + Vector3.new(0, -0.5, 0)) * up, color, true, 0.05, Enum.PartType.Cylinder)
	part(parent, Vector3.new(0.5, radius * 2, radius * 2), CFrame.new(pos + Vector3.new(0, -0.3, 0)) * up, rgb(18, 19, 24), false, 0, Enum.PartType.Cylinder)
end
local function project(cam, size, world)
	local p = cam.CFrame:PointToObjectSpace(world)
	if p.Z >= 0 then return nil end
	local t = math.tan(math.rad(cam.FieldOfView / 2))
	local x = p.X / (-p.Z * t * (size.X / size.Y))
	local y = p.Y / (-p.Z * t)
	return Vector2.new((x + 1) / 2 * size.X, (1 - y) / 2 * size.Y)
end
local function faceDir(pos, dir) -- figures face their local +Z: this makes +Z point along dir
	return CFrame.lookAt(pos, pos - dir)
end

local function label(parent, text, size, font, color, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font or F.H, TextColor3 = color or K.text }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end

-- gun picture (real GunModels part list in a small ViewportFrame, side view)
local function gunPicture(parent, weaponId)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 158), LightColor = rgb(255, 252, 246),
		LightDirection = Vector3.new(-0.5, -1, -0.3) }, parent)
	if not GunModels then return vp end
	local ok, desc = pcall(GunModels.Describe, weaponId, "Iron")
	if not ok or not desc then return vp end
	local model = new("Model", {}, vp)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = (d.Glow and K.red) or d.Color,
				Material = d.Material or Enum.Material.SmoothPlastic, Transparency = d.Transparency or 0 }, model)
			if d.Shape then p.Shape = d.Shape end
			local half = d.Size / 2
			minV, maxV = minV:Min(d.CF.Position - half), maxV:Max(d.CF.Position + half)
		end
	end
	local center = (minV + maxV) / 2
	local len = math.max(maxV.Z - minV.Z, (maxV.Y - minV.Y) * 2.2)
	local cam = new("Camera", { FieldOfView = 16 }, vp)
	local dist = (len / 2) / math.tan(math.rad(8)) / 2.2 + 1
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist, dist * 0.08, 0), center)
	vp.CurrentCamera = cam
	return vp
end

-- big centered text that pops in and fades (countdown numbers, GO)
local function popText(text, color, size, hold)
	local cv = makeCanvas(gui, 20)
	local l = label(cv, text, size, F.H, color, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(900, size * 1.2),
		ZIndex = 20 })
	new("UIStroke", { Color = BLACK, Thickness = 4, Transparency = 0.35 }, l)
	local us = new("UIScale", { Scale = 1.8 }, l)
	l.TextTransparency = 1
	tween(us, POP, { Scale = 1 })
	tween(l, TweenInfo.new(0.12), { TextTransparency = 0 })
	task.delay(hold or 0.55, function()
		tween(l, TweenInfo.new(0.3), { TextTransparency = 1 })
		tween(us, TweenInfo.new(0.3), { Scale = 0.85 })
		task.delay(0.35, function() cv:Destroy() end)
	end)
end

-- ======================================================================================
-- PREGAME
-- ======================================================================================
local SLOT_X = { [1] = { 0 }, [2] = { -3.4, 3.4 }, [3] = { 0, -5.6, 5.6 } }
local PICK_TITLES = { move = "MOVEMENT", weapon = "PRIMARY", gadget = "GADGET", reserve = "RESERVE" }

local function runPregame(token)
	killScreens()
	local endsAt = State:GetAttribute("PhaseEnds") or (serverNow() + C.PREGAME_TIME)
	local myCol = teamColor(player.Team)

	local root = track(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(5, 6, 9), BorderSizePixel = 0, ZIndex = 1 }, gui))
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(12, 14, 22), rgb(3, 4, 6)) }, root)

	-- huge flashing numbers behind the squad for the last 5 seconds
	local bigNum = label(root, "", 700, F.H, myCol, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1100, 800),
		TextTransparency = 1, ZIndex = 2 })
	local bigScale = new("UIScale", { Scale = 1 }, bigNum)

	local scene = newScene(root, 3, true)
	scene.cam.FieldOfView = 34
	local cam = scene.cam
	local baseCam = Vector3.new(0, 4.2, 28)
	addStars(scene.world, 160, 60, Vector3.new(0, 4, -30), 40)
	local figs, figKey = {}, ""

	local cv = makeCanvas(root, 6)

	-- name tags
	local tags = {}
	local function rebuildFigures()
		for _, f in figs do f.fig:Destroy() end
		for _, t in tags do t:Destroy() end
		table.clear(figs); table.clear(tags)
		for _, m in scene.world:GetChildren() do if m.Name == "Pad" then m:Destroy() end end
		local members = teamMembers()
		local xs = SLOT_X[#members]
		for i, m in members do
			local pos = Vector3.new(xs[i], 0, i == 1 and 1.2 or -0.6)
			local pad = new("Model", { Name = "Pad" }, scene.world)
			discUnder(pad, pos, m == player and myCol or myCol:Lerp(WHITE, 0.35), 2.6)
			local fig = Skins.NewFigure(scene.world, skinOf(m), { weapon = weaponOf(m), camPos = baseCam })
			fig:SetRoot(CFrame.new(pos) * CFrame.Angles(0, math.rad((i == 1 and 0) or (xs[i] < 0 and 14 or -14)), 0))
			table.insert(figs, { fig = fig, player = m, pos = pos })
			local tag = label(cv, string.upper(m.DisplayName), 26, F.H, m == player and K.text or K.dim,
				{ AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(360, 34) })
			new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.4 }, tag)
			table.insert(tags, tag)
		end
	end
	local function currentKey()
		local k = {}
		for _, m in teamMembers() do table.insert(k, m.UserId .. skinOf(m) .. weaponOf(m)) end
		return table.concat(k, "|")
	end

	-- ---- clock ----
	local clock = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 34), Size = UDim2.fromOffset(190, 118),
		BackgroundColor3 = K.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 8 }, cv)
	local clockStroke = new("UIStroke", { Color = K.line2, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, clock)
	label(clock, "DEPLOYING IN", 15, F.M, K.dim, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 18), ZIndex = 9 })
	local clockNum = label(clock, tostring(C.PREGAME_TIME), 74, F.H, K.text, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 78), ZIndex = 9 })
	local clockScale = new("UIScale", { Scale = 1 }, clockNum)
	local barBg = new("Frame", { Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = 9 }, clock)
	local barFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = myCol, BorderSizePixel = 0, ZIndex = 10 }, barBg)
	label(cv, "CHOOSE YOUR LOADOUT", 18, F.M, K.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 162), Size = UDim2.fromOffset(500, 24), ZIndex = 8 })
	-- team strip top left
	do
		local t = player.Team
		new("Frame", { Position = UDim2.fromOffset(56, 44), Size = UDim2.fromOffset(4, 54), BackgroundColor3 = myCol, BorderSizePixel = 0, ZIndex = 8 }, cv)
		label(cv, "MATCH STARTING", 15, F.M, K.dim, { Position = UDim2.fromOffset(74, 42), Size = UDim2.fromOffset(300, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
		label(cv, t and (t.Name:upper() .. " TEAM") or "SPECTATING", 40, F.H, myCol, { Position = UDim2.fromOffset(74, 58), Size = UDim2.fromOffset(500, 44),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
	end

	-- ---- loadout dock ----
	local SQ, GAP, GGAP = 92, 12, 40
	local dockY = 905
	local defs = {
		{ kind = "move", idx = 1, tag = "MOVE", group = 1 },
		{ kind = "weapon", idx = 1, tag = "PRIMARY", group = 2 },
		{ kind = "gadget", idx = 1, tag = "2", group = 3 }, { kind = "gadget", idx = 2, tag = "3", group = 3 }, { kind = "gadget", idx = 3, tag = "4", group = 3 },
		{ kind = "reserve", idx = 1, tag = "R1", group = 4 }, { kind = "reserve", idx = 2, tag = "R2", group = 4 }, { kind = "reserve", idx = 3, tag = "R3", group = 4 },
	}
	local totalW = 0
	for i, d in defs do
		if i > 1 then totalW += (d.group == defs[i - 1].group) and GAP or GGAP end
		totalW += SQ
	end
	local x = 960 - totalW / 2
	local tiles = {}
	local pickerFrame, pickerKey
	local selected

	local function itemAt(kind, idx)
		if kind == "weapon" then return loadout.Weapon
		elseif kind == "move" then return loadout.Move
		elseif kind == "gadget" then return loadout.Gadgets[idx]
		else return loadout.Reserve[idx] end
	end
	local function paintTile(t)
		for _, c in t.content:GetChildren() do c:Destroy() end
		local id = itemAt(t.kind, t.idx)
		local it = id ~= "" and Catalog.ById[id] or nil
		if it and it.kind == "weapon" then
			gunPicture(t.content, it.id)
		elseif it then
			label(t.content, it.glyph, 30, F.H, it.color, { Size = UDim2.new(1, 0, 0.7, 0) })
		else
			label(t.content, "+", 34, F.H, K.mute, { Size = UDim2.new(1, 0, 0.7, 0) })
		end
		t.name.Text = it and string.upper(it.name) or "EMPTY"
		t.name.TextColor3 = it and K.text or K.mute
	end
	local function paintAll()
		for _, t in tiles do
			paintTile(t)
			t.stroke.Color = (selected == t) and K.red or K.line2
			t.stroke.Thickness = (selected == t) and 2 or 1
		end
	end
	local function applyItem(kind, idx, id)
		if kind == "weapon" then loadout.Weapon = id
		elseif kind == "move" then loadout.Move = id
		elseif kind == "gadget" then loadout.Gadgets[idx] = id
		else loadout.Reserve[idx] = id end
		LoadoutR:FireServer({ Weapon = loadout.Weapon, Move = loadout.Move, Gadgets = table.clone(loadout.Gadgets), Reserve = table.clone(loadout.Reserve) })
		paintAll()
	end
	local function closePicker()
		if pickerFrame then pickerFrame:Destroy() pickerFrame = nil end
		selected = nil
		paintAll()
	end
	local function openPicker(t)
		local same = selected == t
		closePicker()
		if same then return end
		selected = t
		paintAll()
		local items = {}
		if t.kind == "weapon" then for _, it in Catalog.Weapons do table.insert(items, it) end
		elseif t.kind == "move" then for _, it in Catalog.Moves do table.insert(items, it) end
		elseif t.kind == "gadget" then for _, it in Catalog.Gadgets do table.insert(items, it) end
		else
			for _, it in Catalog.Gadgets do table.insert(items, it) end
			for _, it in Catalog.Weapons do table.insert(items, it) end
		end
		local CW, CH = 118, 142
		local w = math.min(1500, #items * (CW + 10) + 40 + (t.kind ~= "weapon" and (CW + 10) or 0))
		pickerFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(960, dockY - 52), Size = UDim2.fromOffset(w, CH + 74),
			BackgroundColor3 = K.panel, BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 12 }, cv)
		new("UIStroke", { Color = K.line2, Thickness = 1 }, pickerFrame)
		new("Frame", { Size = UDim2.fromOffset(3, CH + 74), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 13 }, pickerFrame)
		label(pickerFrame, PICK_TITLES[t.kind] .. ((t.kind == "gadget" or t.kind == "reserve") and ("  /  SLOT " .. t.idx) or ""), 22, F.H, K.text,
			{ Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(500, 28), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 13 })
		local sf = new("ScrollingFrame", { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, CH + 16), BackgroundTransparency = 1, BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(#items * (CW + 10) + (t.kind ~= "weapon" and (CW + 10) or 0), 0), ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.X,
			ZIndex = 13 }, pickerFrame)
		local ix = 0
		local function card(it)
			local b = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(ix, 0), Size = UDim2.fromOffset(CW, CH),
				BackgroundColor3 = K.panel2, BorderSizePixel = 0, ZIndex = 14 }, sf)
			local cur = itemAt(t.kind, t.idx)
			local st = new("UIStroke", { Color = (it and it.id == cur or (not it and cur == "")) and K.red or K.line, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
			local art = new("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 78), BackgroundTransparency = 1, ZIndex = 15 }, b)
			if it and it.kind == "weapon" then gunPicture(art, it.id)
			elseif it then label(art, it.glyph, 34, F.H, it.color, { Size = UDim2.fromScale(1, 1), ZIndex = 15 })
			else label(art, "NONE", 22, F.H, K.mute, { Size = UDim2.fromScale(1, 1), ZIndex = 15 }) end
			label(b, it and string.upper(it.name) or "EMPTY", 16, F.H, K.text, { Position = UDim2.fromOffset(4, 92), Size = UDim2.new(1, -8, 0, 22), ZIndex = 15 })
			label(b, it and it.sub or "clear slot", 12, F.M, K.dim, { Position = UDim2.fromOffset(4, 114), Size = UDim2.new(1, -8, 0, 18), ZIndex = 15 })
			b.MouseEnter:Connect(function() tween(b, QUICK, { BackgroundColor3 = K.panel3 }) end)
			b.MouseLeave:Connect(function() tween(b, QUICK, { BackgroundColor3 = K.panel2 }) end)
			b.MouseButton1Click:Connect(function()
				applyItem(t.kind, t.idx, it and it.id or "")
				closePicker()
			end)
			ix += CW + 10
		end
		if t.kind ~= "weapon" then card(nil) end
		for _, it in items do card(it) end
	end

	-- group captions + tiles
	local groupX = {}
	for i, d in defs do
		if i > 1 then x += (d.group == defs[i - 1].group) and GAP or GGAP end
		local btn = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, dockY), Size = UDim2.fromOffset(SQ, SQ),
			BackgroundColor3 = K.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 8 }, cv)
		local stroke = new("UIStroke", { Color = K.line2, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
		local content = new("Frame", { Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 1, -22), BackgroundTransparency = 1, ZIndex = 9 }, btn)
		local nameL = label(btn, "", 12, F.M, K.text, { Position = UDim2.new(0, 2, 1, -20), Size = UDim2.new(1, -4, 0, 18), ZIndex = 9 })
		label(btn, d.tag, 12, F.MB, K.dim, { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(40, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10 })
		local t = { kind = d.kind, idx = d.idx, btn = btn, stroke = stroke, content = content, name = nameL }
		table.insert(tiles, t)
		btn.MouseEnter:Connect(function() tween(btn, QUICK, { BackgroundColor3 = K.panel3 }) end)
		btn.MouseLeave:Connect(function() tween(btn, QUICK, { BackgroundColor3 = K.panel }) end)
		btn.MouseButton1Click:Connect(function() openPicker(t) end)
		groupX[d.group] = groupX[d.group] or { x, x }
		groupX[d.group][2] = x + SQ
		x += SQ -- next tile starts after this one (this was missing: every tile used to land on the same spot)
	end
	local CAPTIONS = { "MOVEMENT", "WEAPON", "GADGETS", "RESERVE" }
	for g, r in groupX do
		label(cv, CAPTIONS[g], 13, F.MB, K.mute, { Position = UDim2.fromOffset(r[1], dockY - 24), Size = UDim2.fromOffset(r[2] - r[1], 18), ZIndex = 8 })
	end
	paintAll()
	setModal(true)

	-- fade in from black
	fade.BackgroundTransparency = 0
	tween(fade, TweenInfo.new(0.6), { BackgroundTransparency = 1 })

	rebuildFigures()
	figKey = currentKey()
	local lastLeft, keyTimer = nil, 0
	local t0 = os.clock()
	renderFns.pregame = function(dt)
		local t = os.clock() - t0
		-- camera drift
		cam.CFrame = CFrame.lookAt(baseCam + Vector3.new(math.sin(t * 0.35) * 0.9, math.sin(t * 0.5) * 0.15, 0), Vector3.new(0, 3.6, 0))
		for _, f in figs do f.fig:Update(t, dt) end
		local vs = scene.vp.AbsoluteSize
		for i, f in figs do
			local sp = project(cam, vs, f.pos + Vector3.new(0, f.fig.HeadTop + 0.9, 0))
			if sp and tags[i] then
				local c = (sp - cv.AbsolutePosition) / cv.UIScale.Scale
				tags[i].Position = UDim2.fromOffset(c.X, c.Y)
			end
		end
		keyTimer += dt
		if keyTimer > 0.4 then
			keyTimer = 0
			local k = currentKey()
			if k ~= figKey then figKey = k rebuildFigures() end
		end
		-- clock
		local remain = math.max(0, endsAt - serverNow())
		local left = math.ceil(remain)
		clockNum.Text = tostring(left)
		barFill.Size = UDim2.fromScale(math.clamp(remain / C.PREGAME_TIME, 0, 1), 1)
		if left ~= lastLeft then
			lastLeft = left
			if left <= 5 and left >= 1 then
				sfx("Countdown")
				clockNum.TextColor3 = K.redHi
				clockStroke.Color = K.red
				barFill.BackgroundColor3 = K.red
				clockScale.Scale = 1.35
				tween(clockScale, POP, { Scale = 1 })
				-- flashing background number
				bigNum.Text = tostring(left)
				bigNum.TextTransparency = 0.62
				bigScale.Scale = 1.18
				tween(bigNum, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0.94 })
				tween(bigScale, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.92 })
				if left <= 3 then closePicker() end
			end
		end
	end
end

-- ======================================================================================
-- WARP: black -> soul flies to a door -> flash -> run-in on the real map
-- ======================================================================================
local function runWarp(token)
	local ends = State:GetAttribute("PhaseEnds") or (serverNow() + C.WARP_TIME)
	local startT = ends - C.WARP_TIME
	local function T() return serverNow() - startT end
	local function waitUntil(t)
		while T() < t do
			if not alive(token) then return false end
			task.wait()
		end
		return alive(token)
	end
	local myCol = teamColor(player.Team)

	-- 1) fade the pre-game screen out
	renderFns.pregame = nil
	setModal(false)
	tween(fade, TweenInfo.new(0.55), { BackgroundTransparency = 0 })
	if not waitUntil(0.6) then return end
	killScreens()

	-- 2) the soul flight
	local root = track(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 1 }, gui))
	local scene = newScene(root, 2, false)
	scene.vp.BackgroundColor3 = BLACK
	scene.vp.Ambient = rgb(30, 32, 40)
	local cam, world = scene.cam, scene.world
	local DOOR_Z = 420
	-- the door: small, white, lit
	do
		local dz = -DOOR_Z
		part(world, Vector3.new(0.7, 11, 0.7), CFrame.new(-3.6, 5.5, dz), WHITE, true)
		part(world, Vector3.new(0.7, 11, 0.7), CFrame.new(3.6, 5.5, dz), WHITE, true)
		part(world, Vector3.new(8, 0.7, 0.7), CFrame.new(0, 11, dz), WHITE, true)
		part(world, Vector3.new(6.6, 10.4, 0.3), CFrame.new(0, 5.2, dz - 0.2), rgb(255, 252, 240), true, 0.05)
		part(world, Vector3.new(26, 0.2, 40), CFrame.new(0, 0, dz + 14), rgb(210, 235, 255), true, 0.7)
	end
	-- dust for the sense of speed
	for _ = 1, 320 do
		local s = rng:NextNumber(0.15, 0.55)
		part(world, Vector3.new(s, s, s), CFrame.new(rng:NextNumber(-70, 70), rng:NextNumber(-30, 45), rng:NextNumber(-DOOR_Z - 10, 30)),
			rng:NextNumber() < 0.3 and K.soul or rgb(200, 205, 215), true, rng:NextNumber(0.2, 0.7), Enum.PartType.Ball)
	end
	-- the soul: bright core + two soft halos
	local core = part(world, Vector3.new(1, 1, 1), CFrame.new(0, 0, 0), WHITE, true, 0, Enum.PartType.Ball)
	local halo1 = part(world, Vector3.new(2, 2, 2), CFrame.new(0, 0, 0), K.soul, true, 0.75, Enum.PartType.Ball)
	local halo2 = part(world, Vector3.new(4, 4, 4), CFrame.new(0, 0, 0), K.soul, true, 0.9, Enum.PartType.Ball)
	local trail = {}
	local function soulAt(u)
		local z = -DOOR_Z * (u ^ 1.8)
		local amp = (1 - u) ^ 1.5
		return Vector3.new(math.sin(u * 11) * 9 * amp, math.sin(u * 8 + 1) * 4 * amp + 0.3 * (1 - amp), z)
	end
	local FLY0, FLY1 = 0.9, 4.3
	local camPos = Vector3.new(0, 14, 28)
	-- start from black: the soul "lights up" first
	core.Transparency, halo1.Transparency, halo2.Transparency = 1, 1, 1
	fade.BackgroundTransparency = 0
	tween(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
	local lastTrail = 0
	renderFns.warp = function(dt)
		local t = T()
		local light = math.clamp((t - 0.7) / 0.9, 0, 1) -- 0..1 the soul ignites
		local u = math.clamp((t - FLY0) / (FLY1 - FLY0), 0, 1)
		local pos = soulAt(u)
		local pulse = 1 + 0.12 * math.sin(t * 14)
		local s = (0.4 + 1.1 * light) * pulse
		core.Size, halo1.Size, halo2.Size = Vector3.one * s, Vector3.one * s * 2.3, Vector3.one * s * 4.2
		core.CFrame, halo1.CFrame, halo2.CFrame = CFrame.new(pos), CFrame.new(pos), CFrame.new(pos)
		core.Transparency = 1 - light
		halo1.Transparency = 1 - 0.25 * light
		halo2.Transparency = 1 - 0.1 * light
		-- trail
		if u > 0 and t - lastTrail > 0.012 then
			lastTrail = t
			local p = part(world, Vector3.one * s * 0.8, CFrame.new(pos), rng:NextNumber() < 0.5 and K.soul or K.soulPale, true, 0.2, Enum.PartType.Ball)
			table.insert(trail, { p = p, born = t, size = s * 0.8 })
		end
		for i = #trail, 1, -1 do
			local tr = trail[i]
			local a = (t - tr.born) / 0.7
			if a >= 1 then tr.p:Destroy() table.remove(trail, i)
			else tr.p.Size = Vector3.one * tr.size * (1 - a); tr.p.Transparency = 0.2 + 0.8 * a end
		end
		-- camera follows from above and behind
		local target = pos + Vector3.new(0, 15 - 6 * u, 26 - 4 * u)
		camPos = camPos:Lerp(target, 1 - math.exp(-dt * 7))
		cam.FieldOfView = 58 + 26 * (u ^ 1.5)
		cam.CFrame = CFrame.lookAt(camPos, pos + Vector3.new(0, 0, -20 - 30 * u))
	end
	if not waitUntil(FLY1 + 0.05) then return end

	-- 3) flash, then the real map
	tween(flash, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
	if not waitUntil(FLY1 + 0.3) then return end
	renderFns.warp = nil
	killScreens()
	fade.BackgroundTransparency = 1

	local members = teamMembers()
	warpFolder = new("Folder", { Name = "WarpFX" }, workspace)
	local figs = {}
	local floorParams = RaycastParams.new()
	floorParams.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { warpFolder }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	floorParams.FilterDescendantsInstances = ignore
	local RUN_LEN, RUN_TIME = 38, 2.1
	-- everybody runs the SAME way: forward, from behind, side by side, towards the spot where they spawn.
	-- "forward" = the way the squad spawns facing (average of the members, so all lanes are parallel)
	local entries, sumFwd = {}, Vector3.zero
	for _, m in members do
		local ch = m.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart")
		if r then
			local lv = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
			if lv.Magnitude > 0.01 then sumFwd += lv.Unit end
			table.insert(entries, { m = m, r = r })
		end
	end
	local commonFwd = sumFwd.Magnitude > 0.01 and sumFwd.Unit or Vector3.new(0, 0, -1)
	for i, en in entries do
		local r = en.r
		local hit = workspace:Raycast(r.Position, Vector3.new(0, -14, 0), floorParams)
		local floorY = hit and hit.Position.Y or (r.Position.Y - 4.4)
		local endPos = Vector3.new(r.Position.X, floorY, r.Position.Z)
		local fig = Skins.NewFigure(warpFolder, skinOf(en.m), { weapon = weaponOf(en.m), still = true })
		table.insert(figs, { fig = fig, endPos = endPos, fwd = commonFwd, delay = (i - 1) * 0.06, landed = false })
	end
	if #figs == 0 then
		-- no characters yet: just reveal the map
		tween(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		waitUntil(C.WARP_TIME)
		restoreWorld()
		return
	end
	warpActive = true
	hideGuis()
	camera.CameraType = Enum.CameraType.Scriptable
	local avgFwd = commonFwd
	local RUN0 = 4.75
	local function centroid(timeNow)
		local c = Vector3.zero
		for _, f in figs do
			local p = math.clamp((timeNow - RUN0 - f.delay) / RUN_TIME, 0, 1)
			local e = 1 - (1 - p) ^ 1.6
			c += f.endPos - f.fwd * RUN_LEN * (1 - e)
		end
		return c / #figs
	end
	local c0 = centroid(RUN0)
	local camP = c0 - avgFwd * 15 + Vector3.new(0, 7, 0)
	local function landRing(pos)
		local up = CFrame.Angles(0, 0, math.rad(90))
		local ring = part(warpFolder, Vector3.new(0.25, 3, 3), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * up, myCol, true, 0.1, Enum.PartType.Cylinder)
		tween(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.25, 26, 26), Transparency = 1 })
		task.delay(0.6, function() ring:Destroy() end)
	end
	-- light beams where each figure arrives from
	for _, f in figs do
		local sp = f.endPos - f.fwd * RUN_LEN
		local beam = part(warpFolder, Vector3.new(3, 90, 3), CFrame.new(sp + Vector3.new(0, 45, 0)), WHITE, true, 0.1)
		tween(beam, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Size = Vector3.new(0.4, 90, 0.4) })
		task.delay(1, function() beam:Destroy() end)
	end

	local hideTimer = 0
	renderFns.warp = function(dt)
		local t = T()
		hideTimer += dt
		setOthersHidden(true)
		for _, f in figs do
			local p = math.clamp((t - RUN0 - f.delay) / RUN_TIME, 0, 1)
			local e = 1 - (1 - p) ^ 1.6
			local pos = f.endPos - f.fwd * RUN_LEN * (1 - e)
			local running = p > 0 and p < 1
			local bob = running and math.abs(math.sin((t - RUN0) * 15)) * 0.35 or 0
			local lean = running and 0.26 * (1 - p ^ 3) or 0
			f.fig.run = running and 1 or 0
			f.fig.runPhase = (t - RUN0) * 15
			f.fig:SetRoot(faceDir(pos + Vector3.new(0, bob, 0), f.fwd) * CFrame.Angles(lean, 0, 0))
			f.fig:Update(t, dt)
			if p >= 1 and not f.landed then
				f.landed = true
				landRing(f.endPos)
			end
		end
		local cNow = centroid(t)
		local drift = math.clamp((t - (RUN0 + RUN_TIME)) / 1.5, 0, 1)
		local target = cNow - avgFwd * (15 - 4 * drift) + Vector3.new(0, 7 - 2.2 * drift, 0)
		camP = camP:Lerp(target, 1 - math.exp(-dt * 4))
		camera.CFrame = CFrame.lookAt(camP, cNow + avgFwd * 12 + Vector3.new(0, 3.2, 0))
		camera.FieldOfView = 68 - 8 * drift
	end
	tween(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })

	-- 4) final flash cut back to the normal first-person view
	if not waitUntil(C.WARP_TIME - 0.28) then return end
	tween(flash, TweenInfo.new(0.2), { BackgroundTransparency = 0 })
	if not waitUntil(C.WARP_TIME - 0.05) then return end
	renderFns.warp = nil
	restoreWorld()
	tween(flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
end

-- ======================================================================================
-- COUNTDOWN + GO
-- ======================================================================================
local function runCountdown(token)
	local ends = State:GetAttribute("PhaseEnds") or (serverNow() + C.COUNTDOWN_TIME)
	local lastN
	renderFns.countdown = function()
		local n = math.ceil(ends - serverNow())
		if n ~= lastN and n >= 1 and n <= 9 then
			lastN = n
			sfx("Countdown")
			popText(tostring(n), n == 1 and K.redHi or WHITE, 260, 0.8)
		end
	end
	task.delay(math.max(0.1, ends - serverNow() + 0.5), function() if alive(token) then renderFns.countdown = nil end end)
end

local function runGo(token)
	renderFns.countdown = nil
	if lastPhase == "Playing" then popText("GO", K.green, 240, 0.55) end
end

-- ======================================================================================
-- SLOW MOTION: the round was just decided. Everything (movement, shooting, falling) runs at a crawl for C.SLOWMO_TIME.
-- The slowing itself is done by TimeScale (Movement, GunClient, MatchServer gravity); this only dresses the screen.
-- ======================================================================================
local slowFx
local function stopSlowFx()
	renderFns.slowmo = nil
	if slowFx then slowFx:Destroy() slowFx = nil end
end
local function runSlowMo(token)
	stopSlowFx()
	slowFx = Instance.new("ColorCorrectionEffect")
	slowFx.Name = "SlowMoFX"
	slowFx.Parent = game:GetService("Lighting")
	-- cinematic bars slide in
	local root = track(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, gui))
	local top = new("Frame", { Size = UDim2.new(1, 0, 0.11, 0), Position = UDim2.fromScale(0, -0.11), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 5 }, root)
	local bot = new("Frame", { Size = UDim2.new(1, 0, 0.11, 0), Position = UDim2.fromScale(0, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 5 }, root)
	local slide = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	tween(top, slide, { Position = UDim2.fromScale(0, 0) })
	tween(bot, slide, { Position = UDim2.fromScale(0, 0.89) })
	-- a short white "hit" at the moment of impact
	flash.BackgroundTransparency = 0.55
	tween(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	sfx("Notify")
	renderFns.slowmo = function()
		if not alive(token) then return end
		local ts = TimeScale.Get()
		local k = math.clamp((1 - ts) / (1 - C.SLOWMO_SCALE), 0, 1) -- 0 normal .. 1 full slow motion
		slowFx.Saturation = -0.75 * k
		slowFx.Contrast = 0.18 * k
		slowFx.Brightness = -0.05 * k
		slowFx.TintColor = Color3.new(1, 1, 1):Lerp(rgb(200, 215, 255), k)
	end
end

-- ======================================================================================
-- RESULT: the winning team sits on thrones (5 s, no confetti)
-- ======================================================================================
local function buildThrone(world, pos, col, big)
	local stone, dark = rgb(34, 36, 44), rgb(18, 19, 24)
	local w = big and 1.12 or 1
	local top = big and 1.0 or 0 -- the middle throne sits on a higher step
	local function P(size, cf, color, neon, transp) return part(world, size, cf, color, neon, transp) end
	-- dais
	P(Vector3.new(9.6 * w, 0.6, 9.6), CFrame.new(pos + Vector3.new(0, 0.3 - 0.6, 0.6)), dark)
	P(Vector3.new(9.8 * w, 0.12, 9.8), CFrame.new(pos + Vector3.new(0, -0.3, 0.6)), col, true, 0.15)
	if top > 0 then
		P(Vector3.new(8.2 * w, top, 8.4), CFrame.new(pos + Vector3.new(0, top / 2, 0.6)), stone)
		P(Vector3.new(8.4 * w, 0.1, 8.6), CFrame.new(pos + Vector3.new(0, top, 0.6)), col, true, 0.2)
	end
	local y0 = pos.Y + top -- top of the dais
	-- seat block (top of the seat = y0 + 1.9)
	P(Vector3.new(5.2, 1.9, 3.6), CFrame.new(pos + Vector3.new(0, y0 + 0.95 - pos.Y, -0.2)), stone)
	P(Vector3.new(5.3, 0.14, 3.7), CFrame.new(pos + Vector3.new(0, y0 + 1.9 - pos.Y, -0.2)), col, true, 0.25)
	-- tall back + crest
	P(Vector3.new(5.4, 8.2, 0.9), CFrame.new(pos + Vector3.new(0, y0 + 1.9 + 4.1 - pos.Y, -2.2)), stone)
	P(Vector3.new(6.0, 0.5, 1.2), CFrame.new(pos + Vector3.new(0, y0 + 1.9 + 8.4 - pos.Y, -2.2)), col, true, 0.05)
	P(Vector3.new(0.5, 6.2, 0.2), CFrame.new(pos + Vector3.new(0, y0 + 1.9 + 4.4 - pos.Y, -1.7)), col, true, 0.1)
	P(Vector3.new(3.4, 0.25, 0.2), CFrame.new(pos + Vector3.new(0, y0 + 1.9 + 7.2 - pos.Y, -1.7)), col, true, 0.1)
	-- wings: two slanted panels flanking the back
	for _, sx in { -1, 1 } do
		P(Vector3.new(0.45, 7.2, 3.2), CFrame.new(pos + Vector3.new(3.5 * sx, y0 + 1.9 + 3.4 - pos.Y, -1.2)) * CFrame.Angles(0, math.rad(-24 * sx), 0), stone)
		P(Vector3.new(0.15, 7.0, 0.3), CFrame.new(pos + Vector3.new(3.75 * sx, y0 + 1.9 + 3.4 - pos.Y, 0.05)) * CFrame.Angles(0, math.rad(-24 * sx), 0), col, true, 0.1)
		-- arm rests
		P(Vector3.new(0.9, 1.1, 3.2), CFrame.new(pos + Vector3.new(2.85 * sx, y0 + 1.9 + 0.55 - pos.Y, -0.2)), stone)
		P(Vector3.new(0.92, 0.1, 3.22), CFrame.new(pos + Vector3.new(2.85 * sx, y0 + 1.9 + 1.12 - pos.Y, -0.2)), col, true, 0.2)
	end
	return y0 + 1.9 -- seat height
end

local function runResultCut(token)
	killScreens()
	setModal(false)
	stopSlowFx()
	local winner = State:GetAttribute("Winner") or ""
	local winners = {}
	if winner ~= "" then
		for _, p in Players:GetPlayers() do
			if p.Team and p.Team.Name == winner then table.insert(winners, p) end
		end
		table.sort(winners, function(a, b) return a.UserId < b.UserId end)
		while #winners > 3 do table.remove(winners) end
	end
	local winTeam = winners[1] and winners[1].Team
	local col = winTeam and teamColor(winTeam) or K.dim
	local iWon = player.Team ~= nil and player.Team.Name == winner and winner ~= ""

	fade.BackgroundTransparency = 1
	tween(fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 })
	task.wait(0.28)
	if not alive(token) then return end
	local root = track(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(4, 5, 8), BorderSizePixel = 0, ZIndex = 1 }, gui))
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(col:Lerp(BLACK, 0.8), rgb(3, 4, 6)) }, root)
	local scene = newScene(root, 3, true)
	local cam = scene.cam
	cam.FieldOfView = 38
	addStars(scene.world, 140, 70, Vector3.new(0, 8, -40), 30)

	-- thrones: the player list is ordered so the middle throne is the first winner (the tallest dais)
	local n = math.max(1, #winners)
	local TX = { [1] = { 0 }, [2] = { -6.6, 6.6 }, [3] = { 0, -11.6, 11.6 } }
	local xs = TX[n]
	local figs = {}
	for i = 1, n do
		local big = (n == 1) or (n == 3 and i == 1) -- single winner or the middle of three: raised
		local pos = Vector3.new(xs[i], 0, 0)
		local seatY = buildThrone(scene.world, pos, col, big)
		-- light column behind each throne
		part(scene.world, Vector3.new(4.4, 70, 4.4), CFrame.new(pos + Vector3.new(0, 35, -5)), col, true, 0.86)
		local p = winners[i]
		if p then
			local fig = Skins.NewFigure(scene.world, skinOf(p), { weapon = weaponOf(p), still = true })
			fig.sit = 1
			-- hips (2.7 * body height up the leg) sit on the cushion; the thighs are about half a stud thick
			local rootY = seatY + 0.45 - 2.7 * Skins.Proportions.Height
			table.insert(figs, { fig = fig, base = CFrame.new(xs[i], rootY, -0.15), phase = (i - 1) * 0.7 })
		end
	end

	local cv = makeCanvas(root, 6)
	local title = label(cv, winTeam and (winner:upper() .. " TEAM WINS") or "ROUND OVER", 120, F.H, col, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 70),
		Size = UDim2.fromOffset(1600, 130), ZIndex = 8 })
	new("UIStroke", { Color = BLACK, Thickness = 4, Transparency = 0.4 }, title)
	local ts = new("UIScale", { Scale = 1.6 }, title)
	title.TextTransparency = 1
	tween(ts, POP, { Scale = 1 })
	tween(title, TweenInfo.new(0.2), { TextTransparency = 0 })
	if winTeam then
		local sub = label(cv, iWon and "VICTORY" or "DEFEAT", 44, F.HM, iWon and K.gold or K.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 200),
			Size = UDim2.fromOffset(600, 50), ZIndex = 8, TextTransparency = 1 })
		task.delay(0.35, function() tween(sub, TweenInfo.new(0.3), { TextTransparency = 0 }) end)
	end
	sfx(iWon and "RoundWin" or "RoundLose")
	tween(fade, TweenInfo.new(0.35), { BackgroundTransparency = 1 })

	local t0 = os.clock()
	local total = math.max(1, C.RESULT_TIME)
	renderFns.result = function(dt)
		local t = os.clock() - t0
		local k = math.clamp(t / total, 0, 1)
		-- slow push-in on the thrones
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 5.2 - 0.6 * k, 33 - 4 * k), Vector3.new(0, 6.6, 0))
		for _, f in figs do
			f.fig:SetRoot(f.base)
			f.fig:Update(t + f.phase, dt)
		end
	end
end

-- ======================================================================================
-- SUMMARY
-- ======================================================================================
local lastResult
ResultR.OnClientEvent:Connect(function(data) lastResult = data end)

local function fmtMult(m) return ("x%.2f"):format(m) end
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function runSummary(token)
	killScreens()
	renderFns.result = nil
	local res = lastResult
	do
		local w = 0
		while not res and w < 3 and alive(token) do task.wait(0.1); w += 0.1; res = lastResult end
	end
	if not alive(token) then return end
	res = res or { outcome = "none", base = 0, rows = {}, mult = 1, souls = 0 }
	lastResult = nil

	local myCol = teamColor(player.Team)
	local won = res.outcome == "win"
	local root = track(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(6, 7, 11), BorderSizePixel = 0, ZIndex = 1 }, gui))
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(14, 16, 26), rgb(4, 5, 8)) }, root)
	setModal(true)
	fade.BackgroundTransparency = 0
	tween(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 })

	-- LEFT: you
	local left = new("Frame", { Size = UDim2.fromScale(0.36, 1), BackgroundTransparency = 1, ZIndex = 2 }, root)
	local scene = newScene(left, 2, true)
	scene.cam.FieldOfView = 30
	addStars(scene.world, 70, 30, Vector3.new(0, 4, -18), 20)
	discUnder(scene.world, Vector3.new(0, 0, 0), myCol, 3)
	part(scene.world, Vector3.new(4.4, 60, 4.4), CFrame.new(0, 30, -4), myCol, true, 0.84)
	local fig = Skins.NewFigure(scene.world, skinOf(player), { weapon = weaponOf(player) })
	local figBase = CFrame.Angles(0, math.rad(32), 0)
	local t0 = os.clock()
	renderFns.summary = function(dt)
		local t = os.clock() - t0
		scene.cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.4, 17), Vector3.new(0, 4.1, 0))
		local hop = won and math.abs(math.sin(t * 3)) * 0.9 or 0
		fig:SetRoot(CFrame.new(0, hop, 0) * figBase)
		fig:Update(t, dt)
	end

	-- CENTER
	local cv = makeCanvas(root, 6)
	local PX, PW = 760, 800
	local titleText = (res.outcome == "win" and "VICTORY") or (res.outcome == "loss" and "DEFEAT") or (res.outcome == "draw" and "DRAW") or "MATCH OVER"
	local title = label(cv, titleText, 104, F.H, won and K.gold or (res.outcome == "loss" and K.redHi or K.text),
		{ Position = UDim2.fromOffset(PX, 70), Size = UDim2.fromOffset(PW, 112), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
	label(cv, "MATCH SUMMARY", 18, F.M, K.dim, { Position = UDim2.fromOffset(PX + 4, 52), Size = UDim2.fromOffset(300, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
	new("Frame", { Position = UDim2.fromOffset(PX, 196), Size = UDim2.fromOffset(PW, 1), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = 8 }, cv)

	local ROW_H, ROW0 = 52, 220
	local rowsOut = {}
	local function makeRow(index, left, detail, right, rightColor, dim)
		local row = new("Frame", { Position = UDim2.fromOffset(PX, ROW0 + (index - 1) * ROW_H), Size = UDim2.fromOffset(PW, ROW_H - 6), BackgroundTransparency = 1, ZIndex = 8 }, cv)
		local us = new("UIScale", { Scale = 0.001 }, row)
		local a = label(row, left, 28, F.H, dim and K.mute or K.text, { Size = UDim2.fromOffset(380, ROW_H - 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 })
		local b = label(row, detail or "", 22, F.M, K.dim, { Position = UDim2.fromOffset(330, 0), Size = UDim2.fromOffset(250, ROW_H - 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 })
		local c = label(row, right, 32, F.H, rightColor, { Position = UDim2.new(1, -240, 0, 0), Size = UDim2.fromOffset(240, ROW_H - 6), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9 })
		new("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = 9 }, row)
		for _, l in { a, b, c } do l.TextTransparency = 1 end
		local function pop()
			sfx("Notify")
			tween(us, POP, { Scale = 1 })
			for _, l in { a, b, c } do tween(l, TweenInfo.new(0.15), { TextTransparency = 0 }) end
		end
		table.insert(rowsOut, pop)
		return row
	end

	local idx = 1
	makeRow(idx, "MATCH BASE", nil, commas(res.base or 0) .. " SOULS", K.soul, false)
	for _, r in res.rows or {} do
		idx += 1
		local dim = math.abs((r.mult or 1) - 1) < 0.001
		local col = (r.mult or 1) > 1.0001 and K.green or ((r.mult or 1) < 0.9999 and K.redHi or K.mute)
		makeRow(idx, r.label, r.detail, fmtMult(r.mult or 1), col, dim)
	end
	local totalY = ROW0 + idx * ROW_H + 10
	local totalRow = new("Frame", { Position = UDim2.fromOffset(PX, totalY), Size = UDim2.fromOffset(PW, 56), BackgroundTransparency = 1, ZIndex = 8 }, cv)
	local totalUS = new("UIScale", { Scale = 0.001 }, totalRow)
	local tl = label(totalRow, "TOTAL MULTIPLIER", 30, F.HM, K.dim, { Size = UDim2.fromOffset(400, 56), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 })
	local tr = label(totalRow, fmtMult(res.mult or 1), 52, F.H, K.gold, { Position = UDim2.new(1, -300, 0, 0), Size = UDim2.fromOffset(300, 56), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9 })

	-- souls counter + continue
	local counterY = totalY + 90
	local iconHolder = new("Frame", { Position = UDim2.fromOffset(PX, counterY + 14), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, ZIndex = 9 }, cv)
	UI.SoulIcon(iconHolder, 84)
	local numLabel = label(cv, "0", 124, F.H, K.text, { Position = UDim2.fromOffset(PX + 100, counterY - 6), Size = UDim2.fromOffset(420, 124),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 })
	local numScale = new("UIScale", { Scale = 1 }, numLabel)
	iconHolder.Visible, numLabel.Visible = false, false

	local sent = false
	local btn = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(PX + 560, counterY + 22), Size = UDim2.fromOffset(240, 76),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 9, Visible = false }, cv)
	local btnLabel = label(btn, "CONTINUE", 36, F.H, rgb(14, 15, 19), { Size = UDim2.fromScale(1, 1), ZIndex = 10 })
	new("Frame", { Position = UDim2.new(1, -18, 1, -5), Size = UDim2.fromOffset(18, 5), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 10 }, btn)
	local btnScale = new("UIScale", { Scale = 0.001 }, btn)
	local timerLabel = label(cv, "", 18, F.M, K.dim, { Position = UDim2.fromOffset(PX + 560, counterY + 106), Size = UDim2.fromOffset(240, 22), ZIndex = 9, Visible = false })
	local timerBg = new("Frame", { Position = UDim2.fromOffset(PX + 560, counterY + 132), Size = UDim2.fromOffset(240, 3), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = 9, Visible = false }, cv)
	local timerFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 10 }, timerBg)

	local function doContinue()
		if sent then return end
		sent = true
		ContinueR:FireServer()
		btnLabel.Text = "LOADING"
		btn.BackgroundColor3 = K.line2
		tween(fade, TweenInfo.new(0.6), { BackgroundTransparency = 0 })
	end
	btn.MouseEnter:Connect(function() if not sent then tween(btn, QUICK, { BackgroundColor3 = K.redHi }) btnLabel.TextColor3 = WHITE end end)
	btn.MouseLeave:Connect(function() if not sent then tween(btn, QUICK, { BackgroundColor3 = WHITE }) btnLabel.TextColor3 = rgb(14, 15, 19) end end)
	btn.MouseButton1Click:Connect(doContinue)

	-- reveal sequence
	task.spawn(function()
		task.wait(0.8)
		for _, pop in rowsOut do
			if not alive(token) then return end
			pop()
			task.wait(0.46)
		end
		if not alive(token) then return end
		task.wait(0.15)
		sfx("Notify")
		tween(totalUS, POP, { Scale = 1 })
		task.wait(0.6)
		if not alive(token) then return end
		iconHolder.Visible, numLabel.Visible = true, true
		local goal = res.souls or 0
		local dur = goal > 0 and 1.7 or 0
		local c0 = os.clock()
		while dur > 0 do
			if not alive(token) then return end
			local a = math.clamp((os.clock() - c0) / dur, 0, 1)
			local e = 1 - (1 - a) ^ 2.4
			numLabel.Text = commas(math.max(1, math.floor(e * goal + 0.5)))
			if a >= 1 then break end
			task.wait()
		end
		numLabel.Text = commas(goal)
		numScale.Scale = 1.25
		tween(numScale, POP, { Scale = 1 })
		numLabel.TextColor3 = K.soulPale
		sfx(won and "RoundWin" or "Notify")
		-- continue button + 15 s timer
		btn.Visible, timerLabel.Visible, timerBg.Visible = true, true, true
		tween(btnScale, POP, { Scale = 1 })
		local auto = C.SUMMARY_AUTO or 15
		local started = os.clock()
		while alive(token) and not sent do
			local remain = auto - (os.clock() - started)
			if remain <= 0 then doContinue() break end
			timerLabel.Text = ("RETURNING TO LOBBY IN %d"):format(math.ceil(remain))
			timerFill.Size = UDim2.fromScale(math.clamp(remain / auto, 0, 1), 1)
			task.wait(0.05)
		end
	end)
end

-- ======================================================================================
-- phase driver
-- ======================================================================================
local function onPhase()
	local ph = State:GetAttribute("Phase")
	if ph == lastPhase then return end
	lastPhase = ph
	phaseToken += 1
	local token = phaseToken
	if ph ~= "Pregame" and ph ~= "Warp" then renderFns.pregame = nil end
	if ph ~= "Warp" then renderFns.warp = nil end
	if ph ~= "Result" then renderFns.result = nil end
	if ph ~= "SlowMo" and ph ~= "Result" then stopSlowFx() end
	if ph ~= "Summary" then renderFns.summary = nil end
	if ph ~= "Warp" then restoreWorld() end
	if ph ~= "Pregame" and ph ~= "Summary" then setModal(false) end

	if ph == "Pregame" then task.spawn(runPregame, token)
	elseif ph == "Warp" then task.spawn(runWarp, token)
	elseif ph == "Countdown" then
		killScreens()
		fade.BackgroundTransparency = 1
		flash.BackgroundTransparency = 1
		task.spawn(runCountdown, token)
	elseif ph == "Playing" then
		killScreens()
		fade.BackgroundTransparency = 1
		flash.BackgroundTransparency = 1
		task.spawn(runGo, token)
	elseif ph == "SlowMo" then task.spawn(runSlowMo, token)
	elseif ph == "Result" then task.spawn(runResultCut, token)
	elseif ph == "Summary" then task.spawn(runSummary, token)
	else
		killScreens()
		fade.BackgroundTransparency = 1
		flash.BackgroundTransparency = 1
	end
end
State:GetAttributeChangedSignal("Phase"):Connect(onPhase)
onPhase()
