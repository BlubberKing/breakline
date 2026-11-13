-- MatchFlow v1.8 (v5.19: the 20 s loadout screen is BLACK SPACE with stars again (the blueprint is gone) + a bigger loadout dock; the WARP is a METEOR SOUL DROP:
--   your soul starts in space right above your spawn, burns down through the atmosphere like a re-entering rocket (cel fire with ink outlines + an
--   anime layer drawn 12x a second: speed lines, flame tongues, impact frames, DON!), slams into your spawn, then the normal respawn reveal builds your
--   body and the camera wooshes into your head as the card roll starts. The watercolour painting + fly-through + white flash are gone.)
-- MatchFlow v1.7 (v5.18: a gun is EITHER the primary OR in the reserve - picking it as the primary clears it from the reserve, the reserve picker no longer offers your primary)
-- MatchFlow v1.6 (v5.17: the loadout background is a BLUEPRINT sheet (white lines on navy): SITE PLAN of the real map straight from above on the RIGHT, MISSION BRIEFING + OBJECTIVES on the LEFT, the middle left free for the squad)
-- MatchFlow v1.5 (v5.16: the loadout screen background is a MISSION BRIEFING of the map you are about to play - a live night-vision / thermal recon picture
--   of the real map (height-coloured blocks, outlines, grid, both insertion points, THE LINE), a feed look (scan lines, REC, clock, corner brackets), a typed
--   MISSION BRIEFING panel + OBJECTIVES - instead of the black starfield; a gadget and a reserve slot can no longer hold the same item; the camera hand-over
--   keeps the match mouse sensitivity (MatchConfig.MOUSE_SENS))
-- MatchFlow v1.4 (v5.14: the big loadout picker stays open through the 5-4-3-2-1 countdown slams and only closes when the clock hits 0)
-- MatchFlow v1.3 (v5.10: the Warp camera trails the soul (further behind + above, the soul stays in view instead of filling the screen), the painting reuses the picture link the loading
--   screen verified (MapImageSrc), and the RESULT cutscene is a LINE-UP: the winning team stands side by side holding their guns in a pose, a crown floating over each head (with their
--   win streak xN), instead of sitting on thrones) (v1.2 v5.9: watercolor fly-through warp, no run-in; loadout picker texts trimmed) (v1.1 v3.8: cursor fix on menu screens, XP bar on the summary) (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only.
-- Everything that happens around the match, driven by ReplicatedStorage.MatchState.Phase (set by MatchServer):
--   Pregame   (20 s)  you + teammates stand side by side, loadout dock at the bottom (changeable), clock on top, big numbers flash for 5..1
--   Warp      (6.0 s) v5.19: METEOR SOUL DROP - space above your spawn -> the soul burns down through the atmosphere -> impact on your spawn ->
--                     the respawn reveal builds your body -> the camera wooshes into your head -> card roll
--   Countdown (3 s)   3 - 2 - 1 on the real map, everybody frozen on their spawn
--   Playing           "GO", then the normal match
--   Result    (3.5 s) cutscene: the winning team celebrates in the middle of the screen
--   Summary           stats + soul multipliers pop in one by one, souls count up, CONTINUE (auto after 15 s) -> lobby
-- All 3D scenes are drawn inside ViewportFrames.
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
local Levels = require(RS:WaitForChild("Levels")) -- v3.8: XP bar on the summary screen
local Sfx = require(RS:WaitForChild("Sfx"))
local Crown = require(RS:WaitForChild("Crown")) -- v5.10: the crown over the winners
local GunSkins = RS:FindFirstChild("GunSkins") and require(RS.GunSkins) or nil -- v5.10: winners hold their equipped gun skin
local GunModels = RS:FindFirstChild("GunModels") and require(RS.GunModels) or nil
local LoadoutPicker = require(RS:WaitForChild("LoadoutPicker")) -- v5.7: shared dock + big picker
local GM = RS:FindFirstChild("GadgetModels") and require(RS.GadgetModels) or nil -- v4.1: real gadget pictures
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

-- v3.8: besides freeing the mouse, tell GunClient a menu is open (GunMenuOpen): it shows the cursor and ignores clicks.
-- (Before, the cursor stayed hidden on the loadout + summary screens and every click fired your gun.)
local function setModal(on)
	modal.Visible = on
	player:SetAttribute("GunMenuOpen", on or nil)
end

-- ---- world helpers (the old run-in shot is gone in v5.9; restoreWorld still resets the camera + anything hidden) ----
local hiddenGuis, warpFolder = {}, nil
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
local warpCleanup -- v5.19: set by the WARP section (meteor soul drop) - removes its effects and the local reveal flags
local function restoreWorld()
	pcall(function() RunService:UnbindFromRenderStep("BreaklineWarpCam") end) -- first-person run-in camera (v3.7)
	if player:GetAttribute("CutsceneRun") ~= nil then player:SetAttribute("CutsceneRun", nil) end
	if warpActive then
		warpActive = false
		setOthersHidden(false)
	end
	for g in hiddenGuis do if g.Parent then g.Enabled = true end end
	table.clear(hiddenGuis)
	if warpCleanup then pcall(warpCleanup) end
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
local function label(parent, text, size, font, color, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font or F.H, TextColor3 = color or K.text }, parent)
	for k, v in props or {} do l[k] = v end
	return l
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

	-- v3.7: the last 5 seconds are LOUD. A layer over the squad (under the clock / dock / picker) darkens the scene and shows a huge
	-- number that slams in every second (white 5-4, team color 3-2-1) with a shock ring and red edge pulses.
	local cdLayer = makeCanvas(root, 5)
	local cdDim = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4000, 3000),
		BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 }, cdLayer)
	-- v7: the big "MATCH STARTS IN" line used to sit right on the squad's faces + names. It is now the small caption above the clock at the top
	-- of the screen (see clockCap below), so nothing covers the players during the last 5 seconds.
	local bigNum = label(cdLayer, "", 440, F.H, WHITE, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 500), Size = UDim2.fromOffset(900, 460),
		TextTransparency = 1, ZIndex = 5 })
	local bigStroke = new("UIStroke", { Color = BLACK, Thickness = 7, Transparency = 1 }, bigNum)
	local bigScale = new("UIScale", { Scale = 1 }, bigNum)
	local cdRing = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 500), Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1, ZIndex = 3 }, cdLayer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, cdRing)
	local cdRingStroke = new("UIStroke", { Color = myCol, Thickness = 6, Transparency = 1 }, cdRing)
	local edges = {}
	for i, spec in { { 0, 0, 1, 0, 90 }, { 0, 1, 1, 0, 270 }, { 0, 0, 0, 1, 0 }, { 1, 0, 0, 1, 180 } } do
		-- top, bottom, left, right glow strips (gradient fades toward the middle of the screen)
		local horiz = spec[3] == 1
		local e = new("Frame", { AnchorPoint = Vector2.new(spec[1], spec[2]), Position = UDim2.fromScale(spec[1], spec[2]),
			Size = horiz and UDim2.new(1, 0, 0.22, 0) or UDim2.new(0.16, 0, 1, 0), BackgroundColor3 = K.red, BackgroundTransparency = 1,
			BorderSizePixel = 0, ZIndex = 4 }, root)
		new("UIGradient", { Rotation = spec[5], Transparency = NumberSequence.new(0, 1) }, e)
		edges[i] = e
	end

	local PREGAME_LOOK_Y = 3.8 -- v5.19: 4.2 -> 3.8 (the squad sits ~30 px higher, clear of the bigger loadout dock). Lower = squad higher on screen
	local scene = newScene(root, 3, true)
	scene.cam.FieldOfView = 34
	local cam = scene.cam
	local baseCam = Vector3.new(0, 4.2, 28) -- v5.8: squad raised again (v5.7 4.9 / look 5.3 put the feet into the loadout dock); LOOK_Y below
	-- v5.19 (owner): back to BLACK SPACE with stars behind the squad (the v5.16 briefing / v5.17 blueprint background is gone)
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

	-- ---- clock (v7: slick, no box - big number, a thin progress line, the map name underneath) ----
	local clock = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 26), Size = UDim2.fromOffset(300, 134),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 8 }, cv)
	local clockCap = label(clock, "DEPLOYING IN", 14, F.M, K.dim, { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 18), ZIndex = 9 })
	local clockNum = label(clock, tostring(C.PREGAME_TIME), 84, F.H, K.text, { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 90), ZIndex = 9 })
	new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.45 }, clockNum)
	local clockScale = new("UIScale", { Scale = 1 }, clockNum)
	local barBg = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(170, 3),
		BackgroundColor3 = K.line, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 9 }, clock)
	local barFill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = myCol, BorderSizePixel = 0, ZIndex = 10 }, barBg)
	-- map name: from the map folder name (test_map -> TEST), set by MatchServer
	local mapName = tostring(State:GetAttribute("MapName") or "")
	local mapLbl = label(cv, string.upper(mapName), 26, F.H, K.text, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 166),
		Size = UDim2.fromOffset(500, 30), ZIndex = 8, Visible = mapName ~= "" })
	new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.5 }, mapLbl)
	local mapCap = label(cv, "MAP", 12, F.MB, K.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 150),
		Size = UDim2.fromOffset(200, 16), ZIndex = 8, Visible = mapName ~= "" })
	-- v5.7: the faint CHOOSE YOUR LOADOUT line behind the player names is gone
	do -- the map attribute can arrive a moment after this screen opens
		local conn
		conn = State:GetAttributeChangedSignal("MapName"):Connect(function()
			local n = tostring(State:GetAttribute("MapName") or "")
			mapLbl.Text, mapLbl.Visible, mapCap.Visible = string.upper(n), n ~= "", n ~= ""
		end)
		mapLbl.Destroying:Connect(function() conn:Disconnect() end)
	end
	-- team strip top left
	do
		local t = player.Team
		new("Frame", { Position = UDim2.fromOffset(56, 44), Size = UDim2.fromOffset(4, 54), BackgroundColor3 = myCol, BorderSizePixel = 0, ZIndex = 8 }, cv)
		label(cv, "MATCH STARTING", 15, F.M, K.dim, { Position = UDim2.fromOffset(74, 42), Size = UDim2.fromOffset(300, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
		label(cv, t and (t.Name:upper() .. " TEAM") or "SPECTATING", 40, F.H, myCol, { Position = UDim2.fromOffset(74, 58), Size = UDim2.fromOffset(500, 44),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 8 })
	end

	-- ---- loadout dock (v5.7: lower on the screen; a click opens the BIG lobby-style menu with everything you own) ----
	local dockY = 936 -- v5.19: the tiles are bigger (92 -> 118 px), so the row starts higher and still ends at the same bottom edge
	local selected, bigPicker, dock
	local PICK_SUBS = { -- v5.9: only the reserve keeps its line (it tells you the J key); the others were filler
		reserve = "SWAP IN WHILE YOU ARE DEAD (PRESS J)  //  ONE GUN OR GADGET PER SLOT",
	}
	local function itemAt(kind, idx)
		if kind == "weapon" then return loadout.Weapon
		elseif kind == "move" then return loadout.Move
		elseif kind == "gadget" then return loadout.Gadgets[idx]
		else return loadout.Reserve[idx] end
	end
	local function applyItem(kind, idx, id)
		if kind == "weapon" then
			loadout.Weapon = id
			-- v5.18: a gun is EITHER the primary OR in the reserve, never both: picking it as the primary takes it out of the reserve
			for j = 1, 3 do if loadout.Reserve[j] == id then loadout.Reserve[j] = "" end end
		elseif kind == "reserve" and id ~= "" and id == loadout.Weapon then
			return -- v5.18: the primary gun can not also sit in the reserve (it is not offered there)
		elseif kind == "move" then loadout.Move = id
		else
			-- v5.11: same rule as the lobby - picking an item that already sits in another slot of the same row SWAPS the two slots,
			-- so a row can never hold the same gadget / reserve item twice
			local arr = (kind == "gadget") and loadout.Gadgets or loadout.Reserve
			if id ~= "" then
				for j = 1, 3 do
					if j ~= idx and arr[j] == id then arr[j] = arr[idx] break end
				end
			end
			arr[idx] = id
			-- v5.16: an item is EITHER a gadget OR in the reserve, never both: picking it for one row takes it out of the other
			if id ~= "" then
				local other = (kind == "gadget") and loadout.Reserve or loadout.Gadgets
				for j = 1, 3 do if other[j] == id then other[j] = "" end end
			end
		end
		LoadoutR:FireServer({ Weapon = loadout.Weapon, Move = loadout.Move, Gadgets = table.clone(loadout.Gadgets), Reserve = table.clone(loadout.Reserve) })
		if dock then dock:Paint() end
	end
	local function closePicker()
		if bigPicker then
			local pk = bigPicker
			bigPicker = nil
			pk:Destroy()
		end
		selected = nil
		if dock then dock:Select(nil) end
	end
	local function openPicker(t)
		local same = selected == t
		closePicker()
		if same then return end
		selected = t
		dock:Select(t)
		sfx("MenuOpen")
		local items = {}
		-- v4.7: only what you own (bought in the lobby shop)
		local function addOwned(list) for _, it in list do if Catalog.Owns(player, it.id) then table.insert(items, it) end end end
		if t.kind == "weapon" then addOwned(Catalog.Weapons)
		elseif t.kind == "move" then addOwned(Catalog.Moves)
		elseif t.kind == "gadget" then addOwned(Catalog.Gadgets)
		else
			addOwned(Catalog.Gadgets)
			addOwned(Catalog.Weapons)
			-- v5.18: the gun you carry as your primary is not offered for a reserve slot
			for i = #items, 1, -1 do if items[i].id == loadout.Weapon then table.remove(items, i) end end
		end
		-- v5.7: the big menu (same look as the lobby loadout), not the tiny horizontal scroll any more
		bigPicker = LoadoutPicker.Big(cv, {
			title = PICK_TITLES[t.kind] .. ((t.kind == "gadget" or t.kind == "reserve") and ("  /  SLOT " .. t.idx) or ""),
			sub = PICK_SUBS[t.kind] or "",
			items = items, current = itemAt(t.kind, t.idx), allowNone = t.kind ~= "weapon", z = 30,
			onPick = function(id) sfx("LoadoutPick") applyItem(t.kind, t.idx, id) end,
			onClose = function() bigPicker = nil; selected = nil; if dock then dock:Select(nil) end end,
		})
	end
	dock = LoadoutPicker.Dock(cv, { y = dockY, z = 8, itemAt = itemAt, onClick = openPicker, sq = 118 }) -- v5.19: bigger tiles
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
		cam.CFrame = CFrame.lookAt(baseCam + Vector3.new(math.sin(t * 0.35) * 0.9, math.sin(t * 0.5) * 0.15, 0), Vector3.new(0, PREGAME_LOOK_Y, 0)) -- v5.8: 4.2 (v5.7: 5.3, first: 3.6). Lower = squad higher on screen
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
				barFill.BackgroundColor3 = K.red
				clockScale.Scale = 1.35
				tween(clockScale, POP, { Scale = 1 })
				-- the big countdown number slams in
				local hot = left <= 3
				local col = hot and myCol:Lerp(K.redHi, 0.25) or WHITE
				local SLAM = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				local SETTLE = TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				bigNum.Text = tostring(left)
				bigNum.TextColor3 = col
				bigNum.TextTransparency, bigStroke.Transparency = 0, 0.2
				bigScale.Scale = 1.9
				tween(bigScale, SLAM, { Scale = 1 })
				task.delay(0.3, function()
					if bigNum.Parent and bigNum.Text == tostring(left) then
						tween(bigNum, SETTLE, { TextTransparency = 0.35 })
						tween(bigStroke, SETTLE, { Transparency = 0.7 })
						tween(bigScale, SETTLE, { Scale = 0.9 })
					end
				end)
				tween(cdDim, TweenInfo.new(0.3), { BackgroundTransparency = hot and 0.45 or 0.6 })
				clockCap.Text = "MATCH STARTS IN"
				clockCap.TextColor3 = K.redHi
				-- shock ring
				cdRing.Size = UDim2.fromOffset(300, 300)
				cdRingStroke.Color, cdRingStroke.Transparency, cdRingStroke.Thickness = col, 0.1, hot and 10 or 6
				tween(cdRing, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(820, 820) })
				tween(cdRingStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Thickness = 1 })
				-- red edge pulse (stronger on 3-2-1)
				for _, e in edges do
					e.BackgroundTransparency = hot and 0.35 or 0.6
					tween(e, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
				end
				-- v5.14: the picker is NOT closed on 3-2-1 any more (it kicked you out of the loadout menu every second); it closes at 0 below
			end
			if left <= 0 then closePicker() end -- v5.14: only when the clock runs out
		end
	end
end

-- ======================================================================================
-- WARP v6 (v5.19) - METEOR SOUL DROP. Replaces the v5.9 watercolour painting + fly-through + white flash.
-- Owner: "remove that whole sequence ... have the soul spawn really high in the sky, like in space, directly above where the player will spawn,
-- fly down really fast with fire on it like a rocket re-entering the atmosphere, land on the spawn with a cool animation, then the respawn
-- animation ... when the camera wooshes into the player the card roll starts ... anime style, like an anime artist drew the stuff onto it".
--   0.00  the loadout screen fades to black
--   SPACE0  SPACE: the real camera sits next to your soul ~720 studs straight above your spawn (world darkened + a star field = space),
--           the map is a small patch far below. The soul ignites.
--   DROP0   RE-ENTRY: the soul falls, faster and faster (it ends at several hundred studs/s), the camera chases it. Cel-shaded fire
--           (flat neon layers with a black INK OUTLINE = a Highlight with no fill), a smoke ribbon, embers, a heat glow at the screen edges.
--           On top an ANIME LAYER drawn in 2D and animated "on twos" (12 drawings a second, like hand-drawn animation): manga speed lines
--           that rush out from the soul, inked flame tongues trailing it, sharp ink scratches.
--   LAND    IMPACT: two anime IMPACT FRAMES (black frame with white burst lines, then white frame with black lines), a shockwave ring + dust
--           with ink outlines, a scorch mark, a fire pillar, embers, the camera shakes, a big brush-style DON! pops up.
--   REVEAL  the normal RESPAWN REVEAL (RespawnReveal + RevealFX): souls build your body from the feet up while the camera hovers behind you,
--           then the camera wooshes into your head - exactly when the phase switches to Cards, so the card roll starts the moment you land in it.
-- Everybody's soul drops (teammates and enemies at their own spawns); only yours is followed by the camera.
-- The reveal is started LOCALLY on each client (the character attributes Revealing / RevealStart / RevealBuild are set on this client only,
-- the server never sees them): RespawnReveal, GunClient and ThirdPersonClient already know what to do with them.
-- Timing: C.WARP_TIME (6.0) = DROP + the reveal (C.REVEAL_TIME). All in SD below.
-- ======================================================================================
local SD = {
	HEIGHT = 720,                                      -- studs above the spawn where the soul starts ("space")
	SLANT = 0.3,                                       -- how much the fall comes in at an angle (0 = straight down); it comes from behind your side
	SPACE0 = 0.55,                                     -- black -> space shot
	DROP0 = 1.3,                                       -- the soul starts to fall
	REVEAL_PAD = 0.12,                                 -- impact camera shake before the reveal camera takes over
	FIRE = { Color3.fromRGB(255, 255, 240), Color3.fromRGB(255, 226, 92), Color3.fromRGB(255, 142, 38), Color3.fromRGB(226, 58, 30) },
	SMOKE = Color3.fromRGB(70, 66, 74),
	INK = Color3.fromRGB(24, 12, 18),                  -- the "pen" colour of every outline
	ANIME_FPS = 12,                                    -- the 2D art layer updates at 12 drawings a second (anime "on twos")
	IMPACT_TEXT = "ドンッ!",                            -- the big impact sound-word (Japanese "DON!"); set to "BOOM!" if your font shows boxes
}
SD.LAND = C.WARP_TIME - C.REVEAL_TIME - SD.REVEAL_PAD - 0.05 -- touchdown
SD.REVEAL_AT = SD.LAND + SD.REVEAL_PAD                       -- the respawn reveal starts (ends ~0.05 s before the card roll phase)

local warpState -- everything the drop created (cleaned by warpCleanup)
warpCleanup = function()
	local ws = warpState
	warpState = nil
	pcall(function() RunService:UnbindFromRenderStep("BreaklineWarpCam") end)
	if not ws then return end
	if ws.cc then ws.cc:Destroy() end
	if ws.blur then ws.blur:Destroy() end
	for ch in ws.revealed do
		if ch.Parent and ch:GetAttribute("Revealing") == true then ch:SetAttribute("Revealing", false) end
	end
end

-- one falling soul (3D): core + soul glow + heat cap + 4 cel flame layers + flickering tongues + smoke ribbon + embers + light
local function newMeteor(folder)
	local m = {}
	local fire = new("Model", { Name = "SoulFire" }, folder)
	local smoke = new("Model", { Name = "SoulSmoke" }, folder)
	m.fire, m.smoke = fire, smoke
	m.core = part(fire, Vector3.one * 1.5, CFrame.new(), SD.FIRE[1], true, 0, Enum.PartType.Ball)
	m.glow = part(folder, Vector3.one * 2.8, CFrame.new(), K.soul, true, 0.45, Enum.PartType.Ball)
	m.cap = part(fire, Vector3.new(3.4, 1.3, 3.4), CFrame.new(), SD.FIRE[2], true, 0.1, Enum.PartType.Ball)
	m.layers = {}
	local L = { { 1.2, 5 }, { 2.0, 9 }, { 2.8, 15 }, { 3.6, 23 } } -- diameter, length (at full speed)
	for i, d in L do
		m.layers[i] = { p = part(fire, Vector3.new(1, 1, 1), CFrame.new(), SD.FIRE[i], true, (i - 1) * 0.08, Enum.PartType.Cylinder), d = d[1], len = d[2] }
		m.layers[i].tip = part(fire, Vector3.one, CFrame.new(), SD.FIRE[i], true, (i - 1) * 0.08, Enum.PartType.Ball)
	end
	m.tongues = {}
	for i = 1, 8 do
		m.tongues[i] = { p = part(fire, Vector3.new(0.6, 0.6, 4), CFrame.new(), SD.FIRE[(i % 3) + 2], true, 0.05), a = (i / 8) * math.pi * 2, len = 4 }
	end
	m.ribbon, m.hist = {}, {}
	for i = 1, 36 do
		m.ribbon[i] = part(smoke, Vector3.one * 0.1, CFrame.new(), SD.SMOKE, false, 1, Enum.PartType.Cylinder)
	end
	m.embers = {}
	for i = 1, 28 do
		m.embers[i] = { p = part(folder, Vector3.one * 0.35, CFrame.new(), SD.FIRE[(i % 3) + 2], true, 1), born = -9, pos = Vector3.zero, vel = Vector3.zero }
	end
	-- the ink outline (what makes the flat neon read as a drawing)
	for _, mdl in { fire, smoke } do
		new("Highlight", { FillTransparency = 1, OutlineColor = SD.INK, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Adornee = mdl }, mdl)
	end
	m.light = new("PointLight", { Color = SD.FIRE[3], Range = 40, Brightness = 0, Shadows = false }, m.core)
	m.nextEmber = 0
	return m
end

local function setMeteorVisible(m, on)
	for _, d in m.fire:GetDescendants() do if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 0 or 1 end end
	m.glow.LocalTransparencyModifier = on and 0 or 1
	m.light.Enabled = on
end

-- heat: 0 in space, 1 at full re-entry; spd: 0..1 of the top speed
local function stepMeteor(m, pos, dir, heat, spd, t, dt, frame)
	local look = CFrame.lookAt(pos, pos + dir) -- -Z = the way it falls
	m.core.CFrame = CFrame.new(pos)
	m.core.Size = Vector3.one * (1.3 + 0.25 * math.sin(t * 30))
	m.glow.CFrame = CFrame.new(pos)
	m.glow.Transparency = 0.35 + 0.4 * heat
	m.cap.CFrame = look * CFrame.new(0, 0, -0.9) * CFrame.Angles(math.rad(90), 0, 0)
	m.cap.Transparency = 1 - heat * 0.9
	m.cap.Size = Vector3.new(3.4 + heat, 1.2, 3.4 + heat)
	-- flame layers stream BEHIND the soul (+Z of `look`), longer the faster it goes; they flicker like drawn flames
	for i, L in m.layers do
		local flick = 0.85 + 0.3 * math.noise(t * 9, i * 3.1)
		local len = math.max(0.2, L.len * (0.25 + 0.75 * spd) * heat * flick)
		local w = L.d * (0.6 + 0.4 * heat)
		L.p.Size = Vector3.new(len, w, w)
		L.p.CFrame = look * CFrame.new(0, 0, len / 2) * CFrame.Angles(0, math.rad(90), 0)
		L.tip.Size = Vector3.one * w * 0.98
		L.tip.CFrame = look * CFrame.new(0, 0, len)
		local tr = heat < 0.05 and 1 or ((i - 1) * 0.08)
		L.p.Transparency, L.tip.Transparency = tr, tr
	end
	for i, g in m.tongues do
		if m.artFrame ~= frame then g.len = rng:NextNumber(3, 9) end -- a new drawing 12x a second (held in between, like hand-drawn animation)
		local a = g.a + t * 2.2
		local off = Vector3.new(math.cos(a), math.sin(a), 0) * (1.1 + 0.5 * heat)
		local len = g.len * heat * (0.4 + 0.6 * spd)
		g.p.Size = Vector3.new(0.55, 0.55, math.max(0.1, len))
		g.p.CFrame = look * CFrame.new(off + Vector3.new(0, 0, len / 2 + 0.6)) * CFrame.Angles(0, 0, a)
		g.p.Transparency = heat < 0.05 and 1 or 0.05
	end
	m.artFrame = frame
	m.light.Brightness = 1 + 5 * heat
	-- smoke ribbon (history of positions, fades out behind)
	if not m.hist[1] or (m.hist[1].pos - pos).Magnitude > 1.2 then
		table.insert(m.hist, 1, { pos = pos, t = t })
		if #m.hist > #m.ribbon + 1 then table.remove(m.hist) end
	end
	for i, seg in m.ribbon do
		local a, b = m.hist[i], m.hist[i + 1]
		if a and b and heat > 0.05 then
			local pa = (i == 1) and pos or a.pos
			local len = (b.pos - pa).Magnitude
			local k = 1 - (i - 1) / #m.ribbon
			if len > 0.01 then
				local w = (0.8 + 3.2 * (1 - k)) * heat
				seg.Size = Vector3.new(len + 0.4, w, w)
				seg.CFrame = CFrame.lookAt((pa + b.pos) / 2, b.pos) * CFrame.Angles(0, math.rad(90), 0)
				seg.Transparency = 1 - 0.75 * k * heat
				seg.Color = SD.FIRE[3]:Lerp(SD.SMOKE, math.clamp((1 - k) * 2.2, 0, 1))
			else
				seg.Transparency = 1
			end
		else
			seg.Transparency = 1
		end
	end
	-- embers peel off
	if heat > 0.3 and t >= m.nextEmber then
		m.nextEmber = t + 0.03
		for _, e in m.embers do
			if t - e.born > 0.7 then
				e.born, e.pos = t, pos
				e.vel = -dir * rng:NextNumber(10, 40) + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)) * 18
				break
			end
		end
	end
	for _, e in m.embers do
		local a = (t - e.born) / 0.7
		if a >= 0 and a < 1 then
			e.pos += e.vel * dt
			e.p.CFrame = CFrame.new(e.pos) * CFrame.Angles(t * 7, t * 5, 0)
			e.p.Size = Vector3.one * (0.45 * (1 - a) + 0.05)
			e.p.Transparency = 0.1 + 0.9 * a
		else
			e.p.Transparency = 1
		end
	end
end

-- the impact in the world: shockwave ring, dust chunks with ink outlines, scorch mark, fire pillar, ember burst
local function impactFx(folder, pos, scale)
	scale = scale or 1
	local up = CFrame.Angles(0, 0, math.rad(90))
	local ring = part(folder, Vector3.new(0.3, 4, 4), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * up, SD.FIRE[2], true, 0.05, Enum.PartType.Cylinder)
	tween(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, 46 * scale, 46 * scale), Transparency = 1 })
	local ring2 = part(folder, Vector3.new(0.25, 3, 3), CFrame.new(pos + Vector3.new(0, 0.5, 0)) * up, WHITE, true, 0, Enum.PartType.Cylinder)
	tween(ring2, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, 26 * scale, 26 * scale), Transparency = 1 })
	local scorch = part(folder, Vector3.new(0.08, 9 * scale, 9 * scale), CFrame.new(pos + Vector3.new(0, 0.06, 0)) * up, rgb(26, 20, 22), false, 0.25, Enum.PartType.Cylinder)
	tween(scorch, TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
	local pillar = part(folder, Vector3.new(2, 3, 3), CFrame.new(pos) * up, SD.FIRE[3], true, 0.05, Enum.PartType.Cylinder)
	tween(pillar, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(34 * scale, 7 * scale, 7 * scale), CFrame = CFrame.new(pos + Vector3.new(0, 17 * scale, 0)) * up, Transparency = 1 })
	local core = part(folder, Vector3.one * 3, CFrame.new(pos + Vector3.new(0, 1, 0)), SD.FIRE[1], true, 0, Enum.PartType.Ball)
	tween(core, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.one * 14 * scale, Transparency = 1 })
	-- dust chunks (cel grey with an ink outline, they arc out and fall)
	local dust = new("Model", { Name = "ImpactDust" }, folder)
	new("Highlight", { FillTransparency = 1, OutlineColor = SD.INK, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.Occluded, Adornee = dust }, dust)
	for i = 1, 18 do
		local a = (i / 18) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local s = rng:NextNumber(0.8, 1.9) * scale
		local p = part(dust, Vector3.new(s, s * 0.8, s), CFrame.new(pos + Vector3.new(0, 0.6, 0)), (i % 2 == 0) and rgb(196, 188, 176) or rgb(150, 142, 134), false, 0)
		local dirH = Vector3.new(math.cos(a), 0, math.sin(a))
		local dist = rng:NextNumber(9, 17) * scale
		local peak = pos + dirH * dist * 0.5 + Vector3.new(0, rng:NextNumber(3, 7) * scale, 0)
		local land = pos + dirH * dist + Vector3.new(0, 0.3, 0)
		tween(p, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(peak) * CFrame.Angles(a, a * 2, 0) })
		task.delay(0.28, function()
			if not p.Parent then return end
			tween(p, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(land) * CFrame.Angles(a * 2, a * 3, 0) })
			task.delay(0.5, function() if p.Parent then tween(p, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.one * 0.1 }) end end)
		end)
	end
	-- ember burst
	for i = 1, 22 do
		local e = part(folder, Vector3.one * 0.4, CFrame.new(pos + Vector3.new(0, 1, 0)), SD.FIRE[(i % 3) + 2], true, 0)
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.6), rng:NextNumber(-1, 1)).Unit * rng:NextNumber(8, 20) * scale
		tween(e, TweenInfo.new(rng:NextNumber(0.4, 0.8), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(pos + v), Size = Vector3.one * 0.05, Transparency = 1 })
	end
end

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

	-- 1) fade the pre-game screen out
	renderFns.pregame = nil
	setModal(false)
	tween(fade, TweenInfo.new(0.5), { BackgroundTransparency = 0 })
	if not waitUntil(SD.SPACE0) then return end
	killScreens()
	warpCleanup()

	local ws = { revealed = {}, meteors = {} }
	warpState = ws
	warpActive = true
	warpFolder = new("Folder", { Name = "BreaklineSoulDrop" }, workspace)
	local folder = warpFolder
	-- the HUD stays hidden until the card roll (restoreWorld switches it back on)
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, g in pg:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled and g ~= gui and g.Name ~= "RevealGui" and not g.Name:find("Loading") then
				g.Enabled = false
				hiddenGuis[g] = true
			end
		end
	end
	-- space look: a darker, cooler world (eases back to normal on the way down) + a little blur at top speed
	ws.cc = new("ColorCorrectionEffect", { Name = "SoulDropCC", Brightness = -0.3, Contrast = 0.25, Saturation = -0.2, TintColor = rgb(200, 212, 255) }, game:GetService("Lighting"))
	ws.blur = new("BlurEffect", { Name = "SoulDropBlur", Size = 0 }, game:GetService("Lighting"))

	-- 2) who drops where: every player on a team, at their own spawn (characters are being respawned right now, so positions are re-read)
	local function dropPlayers()
		local list = {}
		for _, p in Players:GetPlayers() do
			if p.Team and p.Team.Name ~= "Lobby" then table.insert(list, p) end
		end
		if not table.find(list, player) then table.insert(list, player) end
		return list
	end
	local function landOf(p)
		local ch = p.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart")
		if not r then return nil end
		local cf, size = ch:GetBoundingBox()
		local feet = cf.Position.Y - size.Y / 2
		local look = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
		look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
		return Vector3.new(r.Position.X, feet, r.Position.Z), look, ch, size.Y
	end
	local function meteorFor(p)
		local m = ws.meteors[p]
		if not m then
			m = newMeteor(folder)
			ws.meteors[p] = m
		end
		return m
	end

	-- 3) the 2D anime layer (drawn over the real world, redrawn 12x a second)
	local root = track(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 }, gui))
	local stars = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, root)
	for _ = 1, 90 do
		local s = rng:NextInteger(1, 3)
		new("Frame", { Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber()), Size = UDim2.fromOffset(s, s), BorderSizePixel = 0,
			BackgroundColor3 = rng:NextNumber() < 0.3 and rgb(170, 205, 255) or WHITE, BackgroundTransparency = rng:NextNumber(0, 0.5), ZIndex = 2 }, stars)
	end
	local spaceTop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 1 }, root)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.55, 0.55), NumberSequenceKeypoint.new(1, 0.9) }) }, spaceTop)
	local heatEdges = {}
	for i, rot in { 0, 90, 180, 270 } do
		local e = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = SD.FIRE[3], BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3 }, root)
		new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.22, 1), NumberSequenceKeypoint.new(1, 1) }) }, e)
		heatEdges[i] = e
	end
	local art = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, root)
	local lines = {}
	for i = 1, 44 do
		local f = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, BackgroundColor3 = (i % 4 == 0) and SD.INK or WHITE, BackgroundTransparency = 1, ZIndex = 6 }, art)
		new("UIStroke", { Color = SD.INK, Thickness = 1, Transparency = 1 }, f)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(1, 0.35) }) }, f)
		lines[i] = f
	end
	local tongues = {}
	for i = 1, 9 do
		local f = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, BackgroundColor3 = SD.FIRE[(i % 3) + 2], BackgroundTransparency = 1, ZIndex = 7 }, art)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
		new("UIStroke", { Color = SD.INK, Thickness = 3, Transparency = 1 }, f)
		new("UIGradient", { Color = ColorSequence.new(SD.FIRE[1], SD.FIRE[(i % 3) + 2]) }, f)
		tongues[i] = f
	end
	local scratches = {}
	for i = 1, 5 do
		local f = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0, BackgroundColor3 = SD.INK, BackgroundTransparency = 1, ZIndex = 8 }, art)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
		scratches[i] = f
	end
	local function hideArt()
		for _, f in lines do f.BackgroundTransparency = 1; f.UIStroke.Transparency = 1 end
		for _, f in tongues do f.BackgroundTransparency = 1; f.UIStroke.Transparency = 1 end
		for _, f in scratches do f.BackgroundTransparency = 1 end
	end
	-- redraw the art around screen point `sp`, trailing toward screen direction `d2`, intensity `k` (0..1)
	local function drawArt(sp, d2, k)
		local vp = camera.ViewportSize
		local reach = math.sqrt(vp.X * vp.X + vp.Y * vp.Y) * 0.6
		local trailAng = math.atan2(d2.Y, d2.X)
		for i, f in lines do
			local a = rng:NextNumber(0, math.pi * 2)
			local r0 = rng:NextNumber(0.18, 0.75) * reach
			local len = rng:NextNumber(0.25, 0.6) * reach * (0.5 + 0.5 * k)
			f.Position = UDim2.fromOffset(sp.X + math.cos(a) * r0, sp.Y + math.sin(a) * r0)
			f.Size = UDim2.fromOffset(len, (i % 5 == 0) and 4 or 2)
			f.Rotation = math.deg(a)
			local on = rng:NextNumber() < (0.35 + 0.65 * k)
			f.BackgroundTransparency = on and (0.15 + 0.5 * (1 - k)) or 1
			f.UIStroke.Transparency = on and 0.5 or 1
		end
		for i, f in tongues do
			local spread = (i - 5) / 4 * math.rad(32)
			local a = trailAng + spread + rng:NextNumber(-0.1, 0.1)
			local len = (70 + 150 * k) * rng:NextNumber(0.6, 1.15) * (1 - math.abs(i - 5) / 7)
			local off = rng:NextNumber(10, 30)
			f.Position = UDim2.fromOffset(sp.X + math.cos(a) * off, sp.Y + math.sin(a) * off)
			f.Size = UDim2.fromOffset(len, (16 + 18 * k) * rng:NextNumber(0.7, 1.1))
			f.Rotation = math.deg(a)
			f.BackgroundTransparency = k > 0.05 and 0.05 or 1
			f.UIStroke.Transparency = k > 0.05 and 0 or 1
		end
		for _, f in scratches do
			local a = trailAng + rng:NextNumber(-0.5, 0.5)
			local off = rng:NextNumber(40, 140)
			f.Position = UDim2.fromOffset(sp.X + math.cos(a) * off, sp.Y + math.sin(a) * off)
			f.Size = UDim2.fromOffset(rng:NextNumber(60, 180) * k, rng:NextInteger(2, 4))
			f.Rotation = math.deg(a)
			f.BackgroundTransparency = (k > 0.2 and rng:NextNumber() < 0.7) and 0.1 or 1
		end
	end

	-- 4) the drop path (re-computed every frame from the live spawn position)
	local function path(land, look, u)
		local slant = -look * SD.SLANT -- it comes in from behind the spawn's facing
		local dir = (Vector3.new(0, -1, 0) + Vector3.new(slant.X, 0, slant.Z)).Unit -- the fall direction
		local s = u ^ 2.6 -- accelerating
		local endP = land + Vector3.new(0, 1.2, 0)
		return endP - dir * SD.HEIGHT * (1 - s), dir, s
	end
	local function speedAt(u) return math.clamp(2.6 * u ^ 1.6, 0, 2.6) / 2.6 end

	camera.CameraType = Enum.CameraType.Scriptable
	fade.BackgroundTransparency = 0
	tween(fade, TweenInfo.new(0.45), { BackgroundTransparency = 1 })
	sfx("SoulIgnite")
	local reentrySound, impactDone, revealStarted, lastArt, shakeUntil = false, false, false, -1, 0
	local myLand, myLook = nil, Vector3.new(0, 0, -1)

	local function camStep(dt)
		if not alive(token) or warpState ~= ws then return end
		local t = T()
		local frame = math.floor(t * SD.ANIME_FPS) -- (GunClient puts the first-person gun away by itself while the camera is Scriptable)
		local u = math.clamp((t - SD.DROP0) / (SD.LAND - SD.DROP0), 0, 1)
		local spd = speedAt(u)
		local alt = SD.HEIGHT * (1 - u ^ 2.6)
		local heat = math.clamp((1 - alt / SD.HEIGHT) * 2.4, 0, 1) * math.clamp(alt / 25, 0, 1) -- burns up high, cools right before the ground
		if alt > 60 then heat = math.max(heat, 0.12 * math.clamp((t - SD.SPACE0) / 0.5, 0, 1)) end -- it ignites in space
		-- every soul (bodies stay hidden until the reveal)
		for _, p in dropPlayers() do
			local land, look, ch = landOf(p)
			if land then
				if p == player then myLand, myLook = land, look end
				if ch and not ws.revealed[ch] then
					for _, d in ch:GetDescendants() do
						if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end
					end
				end
				local m = meteorFor(p)
				if t < SD.LAND then
					local pos, dir = path(land, look, u)
					setMeteorVisible(m, true)
					stepMeteor(m, pos, dir, heat, spd, t, dt, frame)
				elseif m.fire.Parent then
					setMeteorVisible(m, false)
					for _, seg in m.ribbon do seg.Transparency = 1 end
					if not m.impacted then
						m.impacted = true
						impactFx(folder, land, p == player and 1 or 0.8)
					end
				end
			end
		end
		if not reentrySound and t >= SD.DROP0 then reentrySound = true sfx("SoulReentry") end

		-- space look eases off as the soul enters the atmosphere
		local spaceK = math.clamp(alt / SD.HEIGHT - 0.45, 0, 0.55) / 0.55
		ws.cc.Brightness = -0.3 * spaceK
		ws.cc.Contrast = 0.25 * spaceK + 0.12 * heat
		ws.cc.Saturation = -0.2 * spaceK + 0.25 * heat
		ws.cc.TintColor = rgb(200, 212, 255):Lerp(WHITE, 1 - spaceK):Lerp(rgb(255, 232, 210), heat * 0.6)
		stars.Visible = spaceK > 0.02
		for _, s in stars:GetChildren() do s.BackgroundTransparency = 1 - spaceK * 0.9 end
		spaceTop.BackgroundTransparency = 1 - spaceK
		for _, e in heatEdges do e.BackgroundTransparency = 1 - 0.55 * heat * (0.8 + 0.2 * math.sin(t * 25)) end
		ws.blur.Size = 5 * heat * spd

		-- camera (until the respawn reveal takes over)
		if not revealStarted and myLand then
			local pos, dir = path(myLand, myLook, u)
			local side = dir:Cross(Vector3.yAxis)
			side = side.Magnitude > 0.05 and side.Unit or Vector3.xAxis
			local camCF, fov
			if t < SD.DROP0 then
				-- space: beside the soul, looking down past it at the map far below; a slow drift in
				local k = math.clamp((t - SD.SPACE0) / (SD.DROP0 - SD.SPACE0), 0, 1)
				local cp = pos + side * (16 - 4 * k) - dir * (9 - 3 * k) + Vector3.new(0, 4, 0)
				camCF = CFrame.lookAt(cp, pos + dir * 6) -- the soul in view, the map far below behind it
				fov = 58
			else
				-- chase: behind + beside the soul, pulled further back at speed; looks ahead down the fall
				local back = 9 + 10 * spd
				local cp = pos - dir * back + side * (6 + 3 * spd) + Vector3.new(0, 2, 0)
				local chase = CFrame.lookAt(cp, pos + dir * (18 + 30 * spd))
				-- the last moment: the camera stops in the air where the respawn reveal will start (behind + above the spawn), the soul slams past it
				local ch = player.Character
				local cf, size
				if ch then cf, size = ch:GetBoundingBox() end
				local height = size and math.max(size.Y, 4) or 5
				local orbit = math.rad(-14)
				local bk = (CFrame.Angles(0, orbit, 0) * CFrame.lookAt(Vector3.zero, myLook)).LookVector
				local hover = myLand - bk * 8.4 + Vector3.new(0, 5.2, 0)
				local landCam = CFrame.lookAt(hover, myLand + Vector3.new(0, height * 0.35, 0))
				local lastK = math.clamp((t - (SD.LAND - 0.42)) / 0.34, 0, 1)
				lastK = lastK * lastK * (3 - 2 * lastK)
				camCF = chase:Lerp(landCam, lastK)
				fov = (60 + 22 * spd) * (1 - lastK) + 62 * lastK
			end
			if t < shakeUntil then
				local a = (shakeUntil - t) / 0.35
				camCF = camCF * CFrame.new(rng:NextNumber(-1, 1) * 0.6 * a, rng:NextNumber(-1, 1) * 0.6 * a, 0) * CFrame.Angles(0, 0, rng:NextNumber(-1, 1) * 0.03 * a)
			end
			camera.CFrame = camCF
			camera.FieldOfView = fov
		end

		-- the anime layer: a new drawing 12x a second (it holds between drawings, like hand-drawn animation)
		if frame ~= lastArt then
			lastArt = frame
			local m = ws.meteors[player]
			if t >= SD.DROP0 and t < SD.LAND - 0.05 and m and myLand then
				local pos, dir = path(myLand, myLook, u)
				local a = camera:WorldToViewportPoint(pos)
				local b = camera:WorldToViewportPoint(pos - dir * 6)
				if a.Z > 0 then
					local d2 = Vector2.new(b.X - a.X, b.Y - a.Y)
					if d2.Magnitude < 1 then d2 = Vector2.new(0, -1) end
					drawArt(Vector2.new(a.X, a.Y), d2.Unit, math.clamp(spd * 1.3 * heat + 0.15, 0, 1))
				else
					hideArt()
				end
			else
				hideArt()
			end
		end

		-- IMPACT
		if not impactDone and t >= SD.LAND then
			impactDone = true
			shakeUntil = t + 0.35
			sfx("SoulImpact")
			hideArt()
			local sp = myLand and camera:WorldToViewportPoint(myLand) or Vector3.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2, 1)
			-- two IMPACT FRAMES: black + white burst lines, then white + black lines (each ~2 frames of a 30 fps anime)
			local imp = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 30 }, root)
			local burst = {}
			for i = 1, 26 do
				local a = (i / 26) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
				local f = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(sp.X + math.cos(a) * 30, sp.Y + math.sin(a) * 30),
					Size = UDim2.fromOffset(rng:NextNumber(500, 1400), rng:NextInteger(3, 10)), Rotation = math.deg(a), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 31 }, imp)
				new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, f)
				burst[i] = f
			end
			task.delay(0.07, function()
				if not imp.Parent then return end
				imp.BackgroundColor3 = WHITE
				for _, f in burst do f.BackgroundColor3 = BLACK end
				task.delay(0.07, function() if imp.Parent then imp:Destroy() end end)
			end)
			-- the big sound-word
			local word = label(root, SD.IMPACT_TEXT, 150, F.H, SD.FIRE[2], { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(sp.X + 150, math.max(140, sp.Y - 170)),
				Size = UDim2.fromOffset(700, 190), Rotation = -9, ZIndex = 32 })
			new("UIStroke", { Color = SD.INK, Thickness = 9 }, word)
			local wsScale = new("UIScale", { Scale = 2.2 }, word)
			task.delay(0.14, function()
				if not word.Parent then return end
				tween(wsScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				task.delay(0.75, function()
					if not word.Parent then return end
					tween(word, TweenInfo.new(0.35), { TextTransparency = 1 })
					tween(word.UIStroke, TweenInfo.new(0.35), { Transparency = 1 })
					tween(wsScale, TweenInfo.new(0.35), { Scale = 1.15 })
				end)
			end)
			word.Visible = false
			task.delay(0.14, function() if word.Parent then word.Visible = true end end)
		end

		-- RESPAWN REVEAL: hand every body to RespawnReveal (locally); its camera hovers behind you, then wooshes into your head
		if not revealStarted and t >= SD.REVEAL_AT then
			revealStarted = true
			pcall(function() RunService:UnbindFromRenderStep("BreaklineWarpCam") end) -- the camera now belongs to RespawnReveal
			-- the world goes back to normal colours for the reveal
			ws.cc.Brightness, ws.cc.Contrast, ws.cc.Saturation, ws.cc.TintColor = 0, 0, 0, WHITE
			ws.blur.Size = 0
			for _, e in heatEdges do e.BackgroundTransparency = 1 end
			stars.Visible = false
			spaceTop.BackgroundTransparency = 1
			local now = serverNow()
			for _, p in dropPlayers() do
				local ch = p.Character
				if ch and not ws.revealed[ch] then
					ws.revealed[ch] = true
					ch:SetAttribute("RevealStart", now)
					ch:SetAttribute("RevealBuild", C.REVEAL_BUILD)
					ch:SetAttribute("RevealFrom", 0)
					ch:SetAttribute("Revealing", true)
				end
			end
			local revealEnd = now + C.REVEAL_TIME
			task.delay(C.REVEAL_TIME + 0.02, function()
				if warpState ~= ws then return end
				for ch in ws.revealed do
					if ch.Parent and ch:GetAttribute("Revealing") == true and serverNow() >= revealEnd - 0.05 then ch:SetAttribute("Revealing", false) end
				end
				game:GetService("UserInputService").MouseDeltaSensitivity = C.MOUSE_SENS or 1 -- v5.16: the match sensitivity (GunClient keeps it there)
			end)
		end
	end
	RunService:BindToRenderStep("BreaklineWarpCam", Enum.RenderPriority.Camera.Value + 1, camStep)
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
-- RESULT (v5.10): the winning team stands in a line, side by side, each in a pose with their gun, a crown floating over every head (5 s)
-- Up to 3 winners: the first (lowest user id) in the middle, a little forward. The crown shows the player's win streak (xN from 2 up); its gems follow the streak tier.
-- ======================================================================================
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
	cam.FieldOfView = 36
	addStars(scene.world, 140, 70, Vector3.new(0, 8, -40), 30)
	-- the stage: one wide dark floor with a glowing team rim, and a soft light column behind every winner
	local up = CFrame.Angles(0, 0, math.rad(90))
	part(scene.world, Vector3.new(0.3, 30, 30), CFrame.new(0, -0.45, 0) * up, col, true, 0.2, Enum.PartType.Cylinder)
	part(scene.world, Vector3.new(0.5, 29, 29), CFrame.new(0, -0.2, 0) * up, rgb(14, 15, 19), false, 0, Enum.PartType.Cylinder)

	local n = math.max(1, #winners)
	local XS = { [1] = { 0 }, [2] = { -2.9, 2.9 }, [3] = { 0, -5.4, 5.4 } }
	local ZS = { [1] = { 0 }, [2] = { 0, 0 }, [3] = { 1.1, -0.2, -0.2 } } -- the middle winner steps a little forward
	local YAW = { [1] = { 0 }, [2] = { 12, -12 }, [3] = { 0, 14, -14 } }
	local xs, zs, yaws = XS[n], ZS[n], YAW[n]
	local figs = {}
	for i = 1, n do
		local pos = Vector3.new(xs[i], 0, zs[i])
		discUnder(scene.world, pos, col, 2.5)
		part(scene.world, Vector3.new(4.2, 70, 4.2), CFrame.new(pos + Vector3.new(0, 35, -6)), col, true, 0.88)
		local p = winners[i]
		if p then
			local w = weaponOf(p)
			local fig = Skins.NewFigure(scene.world, skinOf(p), { weapon = w, gunSkin = GunSkins and GunSkins.Equipped(p, w) or nil, still = true, stance = "aim" })
			local streak = math.max(1, math.floor(tonumber(p:GetAttribute("Streak")) or 1))
			local crown = Crown.Build(scene.world, { tier = Crown.TierFor(streak), anchored = true, scale = 1.25 })
			table.insert(figs, { fig = fig, base = CFrame.new(pos) * CFrame.Angles(0, math.rad(yaws[i]), 0), pos = pos, phase = (i - 1) * 0.7, crown = crown, streak = streak })
		end
	end

	local cv = makeCanvas(root, 6)
	for _, f in figs do -- the streak number beside each crown (2D, placed every frame from the crown's 3D position)
		if f.streak >= 2 then
			f.tag = label(cv, "x" .. f.streak, 46, F.H, rgb(255, 214, 96), { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(120, 54), ZIndex = 8, Rotation = -12,
				TextXAlignment = Enum.TextXAlignment.Left })
			new("UIStroke", { Color = rgb(70, 40, 6), Thickness = 3, Transparency = 0.1 }, f.tag)
		end
	end
	local title = label(cv, winTeam and (winner:upper() .. " TEAM WINS") or "ROUND OVER", 120, F.H, col, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 70),
		Size = UDim2.fromOffset(1600, 130), ZIndex = 8 })
	new("UIStroke", { Color = BLACK, Thickness = 4, Transparency = 0.4 }, title)
	local ts = new("UIScale", { Scale = 1.6 }, title)
	title.TextTransparency = 1
	tween(ts, POP, { Scale = 1 })
	tween(title, TweenInfo.new(0.2), { TextTransparency = 0 })
	if winTeam then
		local streakMe = math.floor(tonumber(player:GetAttribute("Streak")) or 0)
		local subText = iWon and (streakMe >= 2 and ("VICTORY   //   " .. streakMe .. " WINS IN A ROW") or "VICTORY") or "DEFEAT"
		local sub = label(cv, subText, 44, F.HM, iWon and K.gold or K.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 200),
			Size = UDim2.fromOffset(1100, 50), ZIndex = 8, TextTransparency = 1 })
		task.delay(0.35, function() tween(sub, TweenInfo.new(0.3), { TextTransparency = 0 }) end)
	end
	sfx(iWon and "RoundWin" or "RoundLose")
	tween(fade, TweenInfo.new(0.35), { BackgroundTransparency = 1 })

	local t0 = os.clock()
	local total = math.max(1, C.RESULT_TIME)
	renderFns.result = function(dt)
		local t = os.clock() - t0
		local k = math.clamp(t / total, 0, 1)
		-- slow push-in on the line-up (the group is framed a little low so the title has the top of the screen to itself)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.6 - 0.3 * k, 31 - 3.5 * k), Vector3.new(0, 5.9, 0))
		local vs = scene.vp.AbsoluteSize
		for _, f in figs do
			f.fig:SetRoot(f.base)
			f.fig:Update(t + f.phase, dt)
			-- the crown floats over the head: bobs, turns slowly
			local bob = math.sin(t * 2.2 + f.phase * 3) * 0.14
			local cpos = f.pos + Vector3.new(0, f.fig.HeadTop + 1.25 + bob, 0)
			f.crown:PivotTo(CFrame.new(cpos) * CFrame.Angles(0, t * 0.9 + f.phase, 0))
			if f.tag then
				local sp = project(cam, vs, cpos + cam.CFrame.RightVector * 1.3 + Vector3.new(0, 0.7, 0))
				if sp then
					local c = (sp - cv.AbsolutePosition) / cv.UIScale.Scale
					f.tag.Position = UDim2.fromOffset(c.X, c.Y)
				end
			end
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
		fig:SetRoot(figBase) -- v3.7: stands still (no hopping), only breathes / glances around
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

	-- ===== v3.8: XP bar (very bottom of the reward info). It fills up while the stat rows pop in. =====
	local xpGain = math.max(0, math.floor(res.xp or 0))
	local xpStart = math.max(0, math.floor(res.xpBefore or 0))
	local xpY = counterY + 158
	local xpHolder = new("Frame", { Position = UDim2.fromOffset(PX, xpY), Size = UDim2.fromOffset(PW, 74), BackgroundTransparency = 1, ZIndex = 9, Visible = xpGain > 0 }, cv)
	local xpLevel = label(xpHolder, "LV 1", 30, F.H, K.text, { Size = UDim2.fromOffset(200, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 10 })
	local xpGainLbl = label(xpHolder, "+0 XP", 24, F.M, K.soul, { Position = UDim2.new(1, -300, 0, 4), Size = UDim2.fromOffset(300, 28), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10 })
	local xpBack = new("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(PW, 16), BackgroundColor3 = K.panel3, BorderSizePixel = 0, ZIndex = 10 }, xpHolder)
	new("UIStroke", { Color = K.line2, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, xpBack)
	local xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.soul, BorderSizePixel = 0, ZIndex = 11 }, xpBack)
	new("UIGradient", { Color = ColorSequence.new(K.soul, K.soulPale), Rotation = 0 }, xpFill)
	local xpNums = label(xpHolder, "", 14, F.M, K.dim, { Position = UDim2.fromOffset(0, 58), Size = UDim2.fromOffset(PW, 16), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 10 })
	local xpProgress, xpShown = 0, 0 -- progress 0..1 of this match's XP that is "earned" on screen so far
	local lastLevel = (Levels.FromXp(xpStart))
	local function paintXp()
		local total = xpStart + xpGain * xpShown
		local lvl, into, need = Levels.FromXp(math.floor(total + 0.0001))
		if lvl > lastLevel then
			lastLevel = lvl
			sfx("RoundWin")
			xpLevel.TextColor3 = K.gold
			TweenService:Create(xpLevel, TweenInfo.new(0.9), { TextColor3 = K.text }):Play()
		end
		xpLevel.Text = (lvl > (Levels.FromXp(xpStart)) and "LEVEL UP!  LV " or "LV ") .. lvl
		xpFill.Size = UDim2.fromScale(math.clamp(into / math.max(need, 1), 0, 1), 1)
		xpGainLbl.Text = ("+%d XP"):format(math.floor(xpGain * xpShown + 0.5))
		xpNums.Text = lvl >= Levels.MAX and "MAX LEVEL" or ("%d / %d"):format(into, need)
	end
	paintXp()
	task.spawn(function()
		while alive(token) do
			local dt = task.wait()
			if xpShown ~= xpProgress then
				xpShown += (xpProgress - xpShown) * math.min(1, dt * 4.5)
				if math.abs(xpProgress - xpShown) < 0.002 then xpShown = xpProgress end
				paintXp()
			end
		end
	end)

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
		for i, pop in rowsOut do
			if not alive(token) then return end
			pop()
			xpProgress = i / (#rowsOut + 1) -- the XP bar climbs with every stat row
			task.wait(0.46)
		end
		if not alive(token) then return end
		task.wait(0.15)
		sfx("Notify")
		tween(totalUS, POP, { Scale = 1 })
		xpProgress = 1
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
