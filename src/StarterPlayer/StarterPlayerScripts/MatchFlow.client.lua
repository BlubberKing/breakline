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
--   Warp      (5.6 s) v5.9: the map's watercolor painting -> your soul lights up and flies INTO it, through a 3D watercolor version of
--                     the real map, down onto your spawn -> slow white flash -> you stand on your spawn (first person) -> card roll
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
local function restoreWorld()
	pcall(function() RunService:UnbindFromRenderStep("BreaklineWarpCam") end) -- first-person run-in camera (v3.7)
	if player:GetAttribute("CutsceneRun") ~= nil then player:SetAttribute("CutsceneRun", nil) end
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
-- v5.16 PREGAME BACKGROUND = a MISSION BRIEFING of the map you are about to play (replaces the black starfield).
-- Owner: "change the background from a black spacey area into something more on brand, that represents the map they are loading into, but not the
-- same loading picture ... like a stealth mission: a stealth image of the map and stuff that looks like a briefing".
--   * RECON MAP (whole screen, behind the squad): the REAL map (the <name>_map folder MatchServer cloned, MatchState.MapFolder) redrawn live as a
--     night-vision / thermal recon picture seen from high above: floors dark, every block coloured by its HEIGHT (low = deep teal, tall = pale
--     green), bright outlines on the tallest blocks, a faint grid, both teams' insertion points (from the RedSpawn / BlueSpawn markers) as glowing
--     pillars + rings with a tag, and THE LINE across the middle (Breakline). The camera drifts slowly over it from your team's side.
--   * FEED LOOK on top: scan lines, a slow scan band, vignette, corner brackets, a blinking REC + RECON FEED // <map> + a running clock.
--   * MISSION BRIEFING panel (right): operation (map), mode, squad, area (real size in studs), insertion time + INTEL lines that are true game facts,
--     typed in line by line, with a red CLASSIFIED stamp. OBJECTIVES panel (left).
-- Nothing is uploaded: everything is built from the map that is already loaded + GUI frames.
-- ======================================================================================
local INTEL = {
	base = rgb(9, 32, 78), base2 = rgb(4, 18, 50), floor = rgb(14, 48, 110), fill = rgb(34, 92, 178), line = rgb(228, 243, 255), lineDim = rgb(120, 170, 228),
	grid = rgb(74, 126, 206), ui = rgb(228, 243, 255), uiDim = rgb(132, 178, 232), accent = rgb(122, 216, 255), panel = rgb(7, 26, 66), hostile = rgb(255, 126, 104),
	MAX_PARTS = 600, MAX_EDGED = 260,
}
local function intelMapFolder()
	local n = State:GetAttribute("MapFolder")
	if type(n) == "string" and n ~= "" then
		local f = workspace:FindFirstChild(n)
		if f then return f end
	end
	for _, ch in workspace:GetChildren() do
		if (ch:IsA("Folder") or ch:IsA("Model")) and string.lower(ch.Name):match(string.lower(C.MAPS.Suffix) .. "$") then return ch end
	end
	return nil
end
local function boxCorners(cf, size)
	local h, out = size / 2, {}
	for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
		table.insert(out, cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
	end end end
	return out
end

-- v5.17 BLUEPRINT: the loadout background is a blueprint sheet (white lines on navy). Layout rule (owner): everything important sits on the SIDES,
-- the middle (x 520 - 1400 of the 1920 canvas) is only faint paper + construction circles because the squad stands there.
--   LEFT  column (x 56 - 466): MISSION BRIEFING (operation, mode, squad, area, insertion + numbered NOTES) and OBJECTIVES.
--   RIGHT column (x 1400 - 1872): SITE PLAN = the real map seen straight from above as clean white outlines (drawn live from the loaded map folder),
--     both insertion points, THE LINE, dimension lines, a legend.
local function buildBriefing(root, myCol)
	local api = {}
	local mode = tostring(State:GetAttribute("Mode") or "Breakline")
	local oneV1 = string.lower(mode) == "1v1"
	local myTeam = player.Team and player.Team.Name or ""
	local feed = makeCanvas(root, 2)
	local function fr(props, parent)
		local f = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = INTEL.ui, ZIndex = 2 }, parent or feed)
		for k, v in props do f[k] = v end
		return f
	end

	-- ---------- 1) paper: navy sheet, fine + major grid, a soft light behind the squad, construction circles, border + ticks ----------
	local sheet = new("Frame", { Name = "BlueprintSheet", Size = UDim2.fromScale(1, 1), BackgroundColor3 = INTEL.base, BorderSizePixel = 0, ZIndex = 1 }, root)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(13, 42, 96), rgb(5, 21, 56)) }, sheet)
	for x = 0, 1920, 48 do
		local major = x % 240 == 0
		fr({ Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(major and 2 or 1, 1080), BackgroundColor3 = INTEL.grid, BackgroundTransparency = major and 0.78 or 0.9 })
	end
	for y = 0, 1080, 48 do
		local major = y % 240 == 0
		fr({ Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(1920, major and 2 or 1), BackgroundColor3 = INTEL.grid, BackgroundTransparency = major and 0.78 or 0.9 })
	end
	-- soft light behind the squad so the dark outfits read on the navy paper
	local glow = fr({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 560), Size = UDim2.fromOffset(1000, 900), BackgroundColor3 = rgb(70, 140, 230), BackgroundTransparency = 0.55 })
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.86), NumberSequenceKeypoint.new(1, 1) }) }, glow)
	-- construction circles + centre lines (only behind the squad)
	for _, r in { 330, 470 } do
		local c = fr({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 600), Size = UDim2.fromOffset(r * 2, r * 2), BackgroundTransparency = 1 })
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
		new("UIStroke", { Color = INTEL.lineDim, Thickness = 1.5, Transparency = 0.72 }, c)
	end
	fr({ Position = UDim2.fromOffset(960, 215), Size = UDim2.fromOffset(1, 700), BackgroundColor3 = INTEL.lineDim, BackgroundTransparency = 0.8 })
	-- sheet border (double line) with tick marks round the edge
	for _, inset in { 22, 32 } do
		local b = fr({ Position = UDim2.fromOffset(inset, inset), Size = UDim2.fromOffset(1920 - inset * 2, 1080 - inset * 2), BackgroundTransparency = 1 })
		new("UIStroke", { Color = INTEL.line, Thickness = inset == 22 and 2 or 1, Transparency = inset == 22 and 0.35 or 0.6 }, b)
	end
	for x = 80, 1840, 80 do
		fr({ Position = UDim2.fromOffset(x, 22), Size = UDim2.fromOffset(1, 10), BackgroundTransparency = 0.45 })
		fr({ Position = UDim2.fromOffset(x, 1048), Size = UDim2.fromOffset(1, 10), BackgroundTransparency = 0.45 })
	end
	for y = 80, 1000, 80 do
		fr({ Position = UDim2.fromOffset(22, y), Size = UDim2.fromOffset(10, 1), BackgroundTransparency = 0.45 })
		fr({ Position = UDim2.fromOffset(1888, y), Size = UDim2.fromOffset(10, 1), BackgroundTransparency = 0.45 })
	end

	-- ---------- 2) the SITE PLAN (right column): the real map from straight above, white outlines ----------
	local BX, BY, BW, BH = 1400, 232, 472, 556 -- the whole plan box (canvas px)
	local VX, VY, VW, VH = BX + 30, BY + 74, BW - 44, BH - 120 -- the viewport inside it (margins left for dimension lines)
	local boxF = fr({ Position = UDim2.fromOffset(BX, BY), Size = UDim2.fromOffset(BW, BH), BackgroundColor3 = INTEL.panel, BackgroundTransparency = 0.12 })
	new("UIStroke", { Color = INTEL.line, Thickness = 1.5, Transparency = 0.25 }, boxF)
	fr({ Position = UDim2.fromOffset(BX, BY), Size = UDim2.fromOffset(BW, 4), BackgroundColor3 = INTEL.accent })
	local mapName = string.upper(tostring(State:GetAttribute("MapName") or "UNKNOWN"))
	label(feed, "SITE PLAN", 30, F.H, WHITE, { Position = UDim2.fromOffset(BX + 18, BY + 12), Size = UDim2.fromOffset(300, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	label(feed, "SHEET 01  //  " .. mapName, 14, F.MB, INTEL.accent, { Position = UDim2.fromOffset(BX + 18, BY + 46), Size = UDim2.fromOffset(BW - 36, 20), TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd })

	local vp = new("ViewportFrame", { Name = "SitePlan", Position = UDim2.fromOffset(VX, VY), Size = UDim2.fromOffset(VW, VH), BackgroundColor3 = INTEL.base2, BorderSizePixel = 0, ZIndex = 2,
		Ambient = WHITE, LightColor = WHITE, LightDirection = Vector3.new(0, -1, 0) }, feed)
	new("UIStroke", { Color = INTEL.lineDim, Thickness = 1, Transparency = 0.35 }, vp)
	local cam = new("Camera", { FieldOfView = 20 }, vp)
	vp.CurrentCamera = cam
	local world = new("Model", { Name = "Plan" }, vp)
	local folder = intelMapFolder()
	local lo, hi
	local mb = folder and folder:FindFirstChild("MapBounds", true) or workspace:FindFirstChild("MapBounds")
	if mb and mb:IsA("BasePart") then
		for _, c in boxCorners(mb.CFrame, mb.Size) do lo = lo and lo:Min(c) or c; hi = hi and hi:Max(c) or c end
	end
	local spawns = { Red = {}, Blue = {} }
	local srcList = {}
	if folder then
		for _, d in folder:GetDescendants() do
			if d:IsA("BasePart") then
				local team = (d.Name == "RedSpawn" or (d.Parent and d.Parent.Name == "RedSpawn")) and "Red"
					or ((d.Name == "BlueSpawn" or (d.Parent and d.Parent.Name == "BlueSpawn")) and "Blue") or nil
				if team then
					table.insert(spawns[team], d.Position)
				elseif d.Transparency < 0.95 and d.Name ~= "MapBounds" then
					table.insert(srcList, d)
				end
			end
		end
		table.sort(srcList, function(a, b) return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z end)
	end
	if not lo then
		for _, d in srcList do
			if math.max(d.Size.X, d.Size.Z) < 600 then
				for _, c in boxCorners(d.CFrame, d.Size) do lo = lo and lo:Min(c) or c; hi = hi and hi:Max(c) or c end
			end
		end
	end
	if not lo then lo, hi = Vector3.new(-70, 0, -130), Vector3.new(70, 30, 130) end
	local center = (lo + hi) / 2
	local floorY = lo.Y
	local spanX, spanZ = hi.X - lo.X, hi.Z - lo.Z

	-- which way is "up" on the plan: from YOUR insertion towards the enemy's, so you read the map from your own side
	local mineAvg, theirAvg
	local function avg(list) local s = Vector3.zero for _, q in list do s += q end return s / #list end
	if #spawns.Red > 0 then spawns.RedAvg = avg(spawns.Red) end
	if #spawns.Blue > 0 then spawns.BlueAvg = avg(spawns.Blue) end
	mineAvg, theirAvg = spawns[myTeam .. "Avg"], spawns[(myTeam == "Red") and "BlueAvg" or "RedAvg"]
	local upDir = Vector3.new(0, 0, -1)
	if mineAvg and theirAvg then
		local d = theirAvg - mineAvg
		if Vector2.new(d.X, d.Z).Magnitude > 1 then upDir = Vector3.new(d.X, 0, d.Z).Unit end
	elseif mineAvg then
		local d = center - mineAvg
		if Vector2.new(d.X, d.Z).Magnitude > 1 then upDir = Vector3.new(d.X, 0, d.Z).Unit end
	end
	local rightDir = upDir:Cross(Vector3.new(0, 1, 0)) -- screen right when looking straight down with `upDir` as screen up
	-- extents along the plan's own axes (so a map turned by the camera still fits)
	local function ext(vv) return math.abs(vv.X * rightDir.X + vv.Z * rightDir.Z), math.abs(vv.X * upDir.X + vv.Z * upDir.Z) end
	local halfW, halfH = 0, 0
	for _, c in { Vector3.new(lo.X, 0, lo.Z), Vector3.new(hi.X, 0, lo.Z), Vector3.new(lo.X, 0, hi.Z), Vector3.new(hi.X, 0, hi.Z) } do
		local w, h = ext(c - Vector3.new(center.X, 0, center.Z))
		halfW, halfH = math.max(halfW, w), math.max(halfH, h)
	end
	halfW, halfH = math.max(halfW, 20), math.max(halfH, 20)
	local tanH = math.tan(math.rad(cam.FieldOfView / 2))
	local aspect = VW / VH
	local dist = math.max(halfH / tanH, halfW / (tanH * aspect)) * 1.1
	cam.CFrame = CFrame.lookAt(Vector3.new(center.X, floorY + dist, center.Z), Vector3.new(center.X, floorY, center.Z), upDir)
	local studPx = (2 * dist * tanH) / VH -- studs per screen pixel (line thickness)
	local lineTh = math.max(0.25, studPx * 1.7)

	-- the play area (a thin dashed-looking border) + a fine grid every ~10 % of the long side
	do
		local y = floorY + 0.2
		local function seg(a, b, th, col, tr)
			local len = (b - a).Magnitude
			if len > 0.05 then part(world, Vector3.new(th, 0.1, len), CFrame.lookAt((a + b) / 2, b), col, true, tr) end
		end
		local corners = { Vector3.new(lo.X, y, lo.Z), Vector3.new(hi.X, y, lo.Z), Vector3.new(hi.X, y, hi.Z), Vector3.new(lo.X, y, hi.Z) }
		for k = 1, 4 do seg(corners[k], corners[k % 4 + 1], lineTh * 1.3, INTEL.line, 0.05) end
		local step = math.max(8, math.floor(math.max(spanX, spanZ) / 18))
		local n = 0
		for x = math.ceil(lo.X / step) * step, hi.X, step do
			n += 1 if n > 40 then break end
			seg(Vector3.new(x, y - 0.05, lo.Z), Vector3.new(x, y - 0.05, hi.Z), lineTh * 0.5, INTEL.grid, 0.55)
		end
		n = 0
		for z = math.ceil(lo.Z / step) * step, hi.Z, step do
			n += 1 if n > 40 then break end
			seg(Vector3.new(lo.X, y - 0.05, z), Vector3.new(hi.X, y - 0.05, z), lineTh * 0.5, INTEL.grid, 0.55)
		end
	end
	-- every solid block: a pale fill + a white outline of its footprint (flat floors are skipped, they would just fill the sheet)
	do
		local edged = 0
		for i, src in srcList do
			if i > INTEL.MAX_PARTS then break end
			local sz, cf = src.Size, src.CFrame
			local flat = sz.Y < 0.3 * math.min(sz.X, sz.Z) and math.abs(cf.UpVector.Y) > 0.9
			if not flat and math.max(sz.X, sz.Z) < 900 then
				local top = floorY
				local corners = boxCorners(cf, sz)
				for _, c in corners do top = math.max(top, c.Y) end
				local topY = floorY + 0.4 + math.min(top - floorY, 40) * 0.01
				if src:IsA("Part") and src.Shape == Enum.PartType.Block then
					local h = sz / 2
					local tc = { cf:PointToWorldSpace(Vector3.new(-h.X, 0, -h.Z)), cf:PointToWorldSpace(Vector3.new(h.X, 0, -h.Z)),
						cf:PointToWorldSpace(Vector3.new(h.X, 0, h.Z)), cf:PointToWorldSpace(Vector3.new(-h.X, 0, h.Z)) }
					-- fill: a flat slab the footprint's size at the block's height
					local fill = part(world, Vector3.new(sz.X, 0.1, sz.Z), CFrame.new(cf.Position.X, topY - 0.05, cf.Position.Z) * CFrame.Angles(0, math.atan2(-cf.LookVector.X, -cf.LookVector.Z), 0), INTEL.fill, true, 0.55)
					fill.Name = "Fill"
					if edged < INTEL.MAX_EDGED and sz.Y > 1.5 then
						edged += 1
						for k = 1, 4 do
							local a, b = tc[k], tc[k % 4 + 1]
							a, b = Vector3.new(a.X, topY, a.Z), Vector3.new(b.X, topY, b.Z)
							local len = (b - a).Magnitude
							if len > 0.05 then part(world, Vector3.new(lineTh, 0.1, len + lineTh), CFrame.lookAt((a + b) / 2, b), INTEL.line, true, 0.05) end
						end
					end
				else
					local ok, c = pcall(function() return src:Clone() end)
					if ok and c then
						for _, ch in c:GetChildren() do ch:Destroy() end
						c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
						if c:IsA("UnionOperation") then c.UsePartColor = true end
						if c:IsA("MeshPart") then pcall(function() c.TextureID = "" end) end
						c.Material, c.Color, c.Transparency = Enum.Material.Neon, INTEL.fill, 0.45
						c.Parent = world
					end
				end
			end
		end
	end
	-- THE LINE across the middle (Breakline): a dashed white line, perpendicular to the way you face
	if not oneV1 then
		local y = floorY + 0.9
		local dash = math.max(3, halfW * 2 / 28)
		local x = -halfW
		while x < halfW do
			local len = math.min(dash, halfW - x)
			local mid = Vector3.new(center.X, y, center.Z) + rightDir * (x + len / 2)
			part(world, Vector3.new(lineTh * 2.2, 0.1, len), CFrame.lookAt(mid, mid + rightDir), INTEL.accent, true, 0)
			x += dash * 1.8
		end
	end
	-- insertion points: a ring + a cross per team
	local insert = {}
	for _, team in { "Red", "Blue" } do
		local s = spawns[team .. "Avg"]
		if s then
			local own = team == myTeam
			local col = own and INTEL.accent or INTEL.hostile
			local rr = math.max(4, halfW * 0.11)
			local up = CFrame.Angles(0, 0, math.rad(90))
			part(world, Vector3.new(0.1, rr * 2, rr * 2), CFrame.new(s.X, floorY + 1.2, s.Z) * up, col, true, 0.1, Enum.PartType.Cylinder)
			part(world, Vector3.new(0.12, rr * 2 - lineTh * 3.2, rr * 2 - lineTh * 3.2), CFrame.new(s.X, floorY + 1.3, s.Z) * up, INTEL.base2, true, 0, Enum.PartType.Cylinder)
			part(world, Vector3.new(lineTh * 1.6, 0.1, rr * 1.6), CFrame.new(s.X, floorY + 1.5, s.Z), col, true, 0)
			part(world, Vector3.new(rr * 1.6, 0.1, lineTh * 1.6), CFrame.new(s.X, floorY + 1.5, s.Z), col, true, 0)
			insert[team] = { pos = Vector3.new(s.X, floorY + 1.5, s.Z), col = col, own = own }
		end
	end

	-- dimension lines in the plan box margins (GUI): width under the plan, length on its left
	do
		local dy = VY + VH + 12
		fr({ Position = UDim2.fromOffset(VX, dy), Size = UDim2.fromOffset(VW, 1), BackgroundColor3 = INTEL.accent, BackgroundTransparency = 0.2 })
		for _, x in { VX, VX + VW - 1 } do fr({ Position = UDim2.fromOffset(x, dy - 6), Size = UDim2.fromOffset(1, 13), BackgroundColor3 = INTEL.accent }) end
		local wLabel = label(feed, ("%d  STUDS"):format(math.floor(halfW * 2 + 0.5)), 14, F.MB, INTEL.accent, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(VX + VW / 2, dy + 5),
			Size = UDim2.fromOffset(200, 18), BackgroundTransparency = 1, ZIndex = 3 })
		local dx = VX - 12
		fr({ Position = UDim2.fromOffset(dx, VY), Size = UDim2.fromOffset(1, VH), BackgroundColor3 = INTEL.accent, BackgroundTransparency = 0.2 })
		for _, y in { VY, VY + VH - 1 } do fr({ Position = UDim2.fromOffset(dx - 6, y), Size = UDim2.fromOffset(13, 1), BackgroundColor3 = INTEL.accent }) end
		label(feed, ("%d  STUDS"):format(math.floor(halfH * 2 + 0.5)), 14, F.MB, INTEL.accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(dx - 14, VY + VH / 2),
			Size = UDim2.fromOffset(200, 18), Rotation = -90, ZIndex = 3 })
		local _ = wLabel
	end
	-- legend under the plan
	do
		local ly = BY + BH + 14
		local function legend(y, text, col, kind)
			if kind == "ring" then
				local r = fr({ Position = UDim2.fromOffset(BX + 14, y + 3), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1 })
				new("UICorner", { CornerRadius = UDim.new(1, 0) }, r)
				new("UIStroke", { Color = col, Thickness = 2 }, r)
			else
				for k = 0, 2 do fr({ Position = UDim2.fromOffset(BX + 12 + k * 8, y + 10), Size = UDim2.fromOffset(5, 3), BackgroundColor3 = col }) end
			end
			label(feed, text, 15, F.MB, INTEL.ui, { Position = UDim2.fromOffset(BX + 44, y), Size = UDim2.fromOffset(BW - 60, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
		end
		legend(ly, "YOUR INSERTION", INTEL.accent, "ring")
		legend(ly + 26, "HOSTILE INSERTION", INTEL.hostile, "ring")
		if not oneV1 then legend(ly + 52, "THE LINE", INTEL.accent, "dash") end
	end
	-- tags for the insertion points (follow the plan)
	local tags = {}
	for team, ins in insert do
		local t = label(feed, ins.own and "YOU" or "HOSTILE", 15, F.H, ins.col, { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(120, 20), ZIndex = 4 })
		new("UIStroke", { Color = INTEL.base2, Thickness = 2.5, Transparency = 0.1 }, t)
		table.insert(tags, { label = t, pos = ins.pos })
		local _ = team
	end
	-- a slow scan line across the plan
	local scan = fr({ Position = UDim2.fromOffset(VX, VY), Size = UDim2.fromOffset(VW, 3), BackgroundColor3 = INTEL.accent, BackgroundTransparency = 0.55, ZIndex = 3 })
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, scan)

	-- ---------- 3) MISSION BRIEFING + OBJECTIVES (left column) ----------
	local LX, LW = 56, 410
	local plate = new("Frame", { Position = UDim2.fromOffset(LX, 232), Size = UDim2.fromOffset(LW, 420), BackgroundColor3 = INTEL.panel, BackgroundTransparency = 0.12,
		BorderSizePixel = 0, ZIndex = 2 }, feed)
	new("UIStroke", { Color = INTEL.line, Thickness = 1.5, Transparency = 0.25 }, plate)
	fr({ Size = UDim2.fromOffset(LW, 4), BackgroundColor3 = INTEL.accent }, plate)
	label(plate, "MISSION BRIEFING", 30, F.H, WHITE, { Position = UDim2.fromOffset(18, 14), Size = UDim2.fromOffset(300, 36), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	local stampL = label(plate, "REV A", 16, F.H, INTEL.accent, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(LW - 54, 32), Size = UDim2.fromOffset(70, 26), ZIndex = 4 })
	new("UIStroke", { Color = INTEL.accent, Thickness = 2, Transparency = 0.15, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stampL)
	fr({ Position = UDim2.fromOffset(18, 60), Size = UDim2.fromOffset(LW - 36, 1), BackgroundTransparency = 0.55 }, plate)
	local squadN = 0
	for _, p in Players:GetPlayers() do if p.Team == player.Team then squadN += 1 end end
	local timeStr = os.date("%H:%M")
	local rows = {
		{ "OPERATION", mapName },
		{ "MODE", oneV1 and "1V1  //  DUEL" or "BREAKLINE  //  3V3" },
		{ "SQUAD", (myTeam ~= "" and string.upper(myTeam) or "-") .. (oneV1 and "" or ("  //  " .. squadN .. (squadN == 1 and " OPERATOR" or " OPERATORS"))) },
		{ "AREA", ("%d x %d STUDS"):format(math.floor(spanX), math.floor(spanZ)) },
		{ "INSERTION", timeStr .. "  LOCAL" },
	}
	local notes = oneV1 and {
		"ONE HOSTILE. FIRST TO " .. tostring(C.V1 and C.V1.KillsToWin or 5) .. " KILLS TAKES THE ROUND.",
		"AFTER A DEATH YOU SIT OUT A FEW SECONDS AND WATCH THEM.",
	} or {
		"BOX DROPS EVERY " .. tostring(C.BOX and C.BOX.SpawnInterval or 60) .. " S ON BOTH SIDES OF THE LINE.",
		"3 HOLES PER SIDE. MORE PLUGGED BOXES MOVES THE LINE.",
		"THEIR PLUGGED BOXES CAN BE SHOT OR STOLEN.",
	}
	local typed = {}
	local ry = 74
	for _, r in rows do
		label(plate, r[1], 13, F.MB, INTEL.uiDim, { Position = UDim2.fromOffset(18, ry + 2), Size = UDim2.fromOffset(110, 22), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
		local v = label(plate, "", 18, F.MB, WHITE, { Position = UDim2.fromOffset(132, ry), Size = UDim2.fromOffset(LW - 150, 24), TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd })
		table.insert(typed, { l = v, text = r[2] })
		ry += 30
	end
	ry += 6
	fr({ Position = UDim2.fromOffset(18, ry), Size = UDim2.fromOffset(LW - 36, 1), BackgroundTransparency = 0.55 }, plate)
	ry += 10
	label(plate, "NOTES", 14, F.MB, INTEL.accent, { Position = UDim2.fromOffset(18, ry), Size = UDim2.fromOffset(200, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	ry += 26
	for i, line in notes do
		local v = label(plate, "", 14, F.M, rgb(222, 238, 255), { Position = UDim2.fromOffset(18, ry), Size = UDim2.fromOffset(LW - 36, 38), TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, ZIndex = 3 })
		table.insert(typed, { l = v, text = i .. ".  " .. line })
		ry += 42
	end
	plate.Size = UDim2.fromOffset(LW, ry + 10)
	-- OBJECTIVES (left, under the briefing)
	local obj = oneV1 and { "WIN " .. tostring(C.V1 and C.V1.KillsToWin or 5) .. " GUNFIGHTS" } or { "PLUG BOXES INTO YOUR HOLES", "PUSH THE LINE TO THEIR FINISH", "BREAK THEIR PLUGGED BOXES" }
	local oy = 232 + ry + 10 + 18
	local op = new("Frame", { Position = UDim2.fromOffset(LX, oy), Size = UDim2.fromOffset(LW, 64 + #obj * 36), BackgroundColor3 = INTEL.panel, BackgroundTransparency = 0.12,
		BorderSizePixel = 0, ZIndex = 2 }, feed)
	new("UIStroke", { Color = INTEL.line, Thickness = 1.5, Transparency = 0.25 }, op)
	fr({ Size = UDim2.fromOffset(LW, 4), BackgroundColor3 = INTEL.accent }, op)
	label(op, "OBJECTIVES", 26, F.H, WHITE, { Position = UDim2.fromOffset(18, 12), Size = UDim2.fromOffset(300, 32), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
	for k, o in obj do
		local y = 54 + (k - 1) * 36
		local bx = fr({ Position = UDim2.fromOffset(18, y + 4), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1 }, op)
		new("UIStroke", { Color = INTEL.accent, Thickness = 2 }, bx)
		local v = label(op, "", 17, F.MB, rgb(228, 243, 255), { Position = UDim2.fromOffset(46, y), Size = UDim2.fromOffset(LW - 60, 24), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
		table.insert(typed, { l = v, text = o })
	end
	-- type every line in, one after another
	task.spawn(function()
		task.wait(0.5)
		for _, tl in typed do
			for i = 1, #tl.text, 2 do
				if not tl.l.Parent then return end
				tl.l.Text = string.sub(tl.text, 1, i + 1)
				task.wait(0.012)
			end
			tl.l.Text = tl.text
			task.wait(0.05)
		end
	end)

	-- ---------- per frame ----------
	local t0 = os.clock()
	function api.update(_dt)
		local t = os.clock() - t0
		scan.Position = UDim2.fromOffset(VX, VY + (t * 90) % (VH - 3))
		local vs = vp.AbsoluteSize
		local sc = feed:FindFirstChildOfClass("UIScale")
		local k = sc and sc.Scale or 1
		for _, tg in tags do
			local sp = project(cam, vs, tg.pos)
			if sp then
				local c = Vector2.new(VX, VY) + sp / k
				tg.label.Position = UDim2.fromOffset(c.X, c.Y - 14)
				tg.label.Visible = true
			else
				tg.label.Visible = false
			end
		end
	end
	return api
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

	local PREGAME_LOOK_Y = 4.2 -- v5.8: camera look height on the squad (about 70 px higher on a 1080p screen than v5.7)
	local scene = newScene(root, 3, true)
	scene.cam.FieldOfView = 34
	local cam = scene.cam
	local baseCam = Vector3.new(0, 4.2, 28) -- v5.8: squad raised again (v5.7 4.9 / look 5.3 put the feet into the loadout dock); LOOK_Y below
	-- v5.16: the black starfield is gone; the background is the MISSION BRIEFING of the map (buildBriefing above)
	local okB, brief = pcall(buildBriefing, root, myCol)
	if not okB then warn("[MatchFlow] briefing background:", brief) brief = nil end
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
	local dockY = 962
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
	dock = LoadoutPicker.Dock(cv, { y = dockY, z = 8, itemAt = itemAt, onClick = openPicker })
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
		if brief then pcall(brief.update, dt) end -- v5.16: recon map drift, scan band, tags
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
-- WARP (v5.9): black -> the map's watercolor painting fills the screen -> your soul lights up and flies INTO it. The painting opens up
-- into a 3D watercolor version of the real map (built live from the loaded <name>_map folder: washed translucent blocks, ink edges with
-- sketchy overshoot, soft floor shadows, a pencil grid on the floor) and the soul flies through it down onto your spawn -> slow white
-- flash -> you are standing on your spawn in first person and the card roll starts. (The v3.7 first-person run-in is gone.)
-- ======================================================================================
local WC = {
	paper = rgb(241, 236, 227),    -- background / paper
	floor = rgb(233, 226, 213),    -- floors + wide flat slabs
	wash = rgb(126, 133, 180),     -- walls / blocks (translucent)
	washDeep = rgb(101, 107, 158), -- every third block a little deeper, like a second wash layer
	ink = rgb(48, 52, 86),         -- edge lines
	shadow = rgb(112, 114, 162),   -- soft floor shadows
	grid = rgb(150, 154, 190),     -- pencil grid
}
local WARP_MAX_PARTS, WARP_MAX_EDGED, WARP_MAX_SHADOWS = 380, 150, 70
local SUN = Vector3.new(0.55, -1, 0.35).Unit

-- the map folder MatchServer cloned into Workspace (MatchState.MapFolder); nil when the match runs on a bare MapBounds part
local function loadedMapFolder()
	local n = State:GetAttribute("MapFolder")
	if type(n) == "string" and n ~= "" then
		local f = workspace:FindFirstChild(n)
		if f then return f end
	end
	for _, ch in workspace:GetChildren() do
		if (ch:IsA("Folder") or ch:IsA("Model")) and string.lower(ch.Name):match(string.lower(C.MAPS.Suffix) .. "$") then return ch end
	end
	return nil
end

-- builds the watercolor copy of the map inside `world` (a Model in a ViewportFrame). Returns the bounding box (lo, hi) of what it drew.
local function buildWatercolorMap(world, folder)
	local lo, hi
	if not folder then return nil, nil end
	local list = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "MapBounds" and not d.Name:match("Spawn$") then
			table.insert(list, d)
		end
	end
	table.sort(list, function(a, b) return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z end)
	local texId = C.MAPS.WashTexture
	if type(texId) == "string" and (texId == "" or texId == "rbxassetid://0") then texId = nil end
	local edged, shadows, textured = 0, 0, 0
	local function inkBar(a, b, th)
		local len = (b - a).Magnitude
		if len < 0.05 then return end
		part(world, Vector3.new(th, th, len), CFrame.lookAt((a + b) / 2, b), WC.ink, false, 0.32)
	end
	for i, src in list do
		if i > WARP_MAX_PARTS then break end
		local sz, cf = src.Size, src.CFrame
		local flat = sz.Y < 0.3 * math.min(sz.X, sz.Z) and math.abs(cf.UpVector.Y) > 0.9
		local p
		if src:IsA("Part") then
			p = part(world, sz, cf, WC.wash, false, 0, src.Shape)
		elseif src:IsA("WedgePart") or src:IsA("CornerWedgePart") then
			p = new(src.ClassName, { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Size = sz, CFrame = cf }, world)
		else -- MeshPart / Union / Truss: a stripped clone, recoloured
			local ok, c = pcall(function() return src:Clone() end)
			if ok and c then
				for _, ch in c:GetChildren() do ch:Destroy() end
				c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.CastShadow = true, false, false, false, false
				if c:IsA("UnionOperation") then c.UsePartColor = true end
				if c:IsA("MeshPart") then pcall(function() c.TextureID = "" end) end
				c.Parent = world
				p = c
			end
		end
		if p then
			p.Material = Enum.Material.SmoothPlastic
			p.Color = flat and WC.floor or ((i % 3 == 0) and WC.washDeep or WC.wash)
			p.Transparency = flat and 0 or 0.5
			local h = sz / 2
			local corners = {}
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz2 in { -1, 1 } do
				table.insert(corners, cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz2 * h.Z)))
			end end end
			if math.max(sz.X, sz.Z) < 600 then -- a giant baseplate must not stretch the flight path
				for _, c in corners do
					lo = lo and lo:Min(c) or c
					hi = hi and hi:Max(c) or c
				end
			end
			-- ink edges with a small overshoot past every corner (the sketched construction-line look of the painting)
			if edged < WARP_MAX_EDGED and src:IsA("Part") and src.Shape == Enum.PartType.Block then
				edged += 1
				local th = math.clamp(math.max(sz.X, sz.Y, sz.Z) * 0.006, 0.07, 0.16)
				local over = math.clamp(math.min(sz.X, sz.Y, sz.Z) * 0.08 + 0.35, 0.35, 1.4)
				local axes = { { cf.RightVector, h.X }, { cf.UpVector, h.Y }, { cf.LookVector, h.Z } }
				for ai = 1, 3 do
					local ax, ext = axes[ai][1], axes[ai][2]
					local b1, b2 = axes[ai % 3 + 1], axes[(ai + 1) % 3 + 1]
					for _, s1 in { -1, 1 } do
						for _, s2 in { -1, 1 } do
							local mid = cf.Position + b1[1] * b1[2] * s1 + b2[1] * b2[2] * s2
							inkBar(mid - ax * (ext + over), mid + ax * (ext + over), th)
						end
					end
				end
			end
			-- soft wash shadow on the floor next to standing blocks
			if not flat and shadows < WARP_MAX_SHADOWS and sz.Y > 2 then
				shadows += 1
				local bottom = cf.Position.Y - (math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.RightVector.Y) * h.X + math.abs(cf.LookVector.Y) * h.Z)
				local reach = math.min(sz.Y, 30) * 0.45
				local off = Vector3.new(SUN.X, 0, SUN.Z).Unit * reach
				local yaw = select(2, cf:ToOrientation())
				local s = part(world, Vector3.new(sz.X + reach * 0.9, 0.06, sz.Z + reach * 0.9), CFrame.new(Vector3.new(cf.Position.X, bottom + 0.06, cf.Position.Z) + off * 0.55) * CFrame.Angles(0, yaw, 0),
					WC.shadow, false, 0.8)
				s.Transparency = 0.8
			end
			-- optional uploaded watercolor wash texture (MatchConfig.MAPS.WashTexture) on the biggest pieces
			if texId and textured < 120 then
				textured += 1
				for _, face in Enum.NormalId:GetEnumItems() do
					new("Texture", { Texture = texId, Face = face, StudsPerTileU = 26, StudsPerTileV = 26, Transparency = flat and 0.25 or 0.45,
						Color3 = flat and Color3.new(1, 1, 1) or rgb(225, 228, 255) }, p)
				end
			end
		end
	end
	-- pencil grid on the floor, every 8 studs, inside the drawn area
	if lo and hi then
		local y = lo.Y + 0.08
		local step = math.max(8, math.floor(math.max(hi.X - lo.X, hi.Z - lo.Z) / 28))
		local n = 0
		for x = math.ceil(lo.X / step) * step, hi.X, step do
			n += 1
			if n > 40 then break end
			part(world, Vector3.new(0.05, 0.03, hi.Z - lo.Z), CFrame.new(x, y, (lo.Z + hi.Z) / 2), WC.grid, false, 0.7)
		end
		n = 0
		for z = math.ceil(lo.Z / step) * step, hi.Z, step do
			n += 1
			if n > 40 then break end
			part(world, Vector3.new(hi.X - lo.X, 0.03, 0.05), CFrame.new((lo.X + hi.X) / 2, y, z), WC.grid, false, 0.7)
		end
	end
	return lo, hi
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
	-- timeline (seconds after the phase started; C.WARP_TIME = 5.6)
	local SHOW, FLY0, FLY1 = 0.6, 1.1, 4.7    -- painting appears / soul flight starts / soul reaches your spawn
	local FLASH0, FLASH1, OUT1 = 4.25, 5.05, 5.55 -- white flash builds up slowly, holds, then clears onto the real map

	-- 1) fade the pre-game screen out
	renderFns.pregame = nil
	setModal(false)
	tween(fade, TweenInfo.new(0.55), { BackgroundTransparency = 0 })
	if not waitUntil(SHOW) then return end
	killScreens()

	-- 2) the scene: painting (2D) behind, the 3D watercolor map, the soul on top
	local root = track(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WC.paper, BorderSizePixel = 0, ZIndex = 1 }, gui))
	local mapScene = newScene(root, 2, false)
	local mapVP, mapCam = mapScene.vp, mapScene.cam
	mapVP.BackgroundColor3 = WC.paper
	mapVP.Ambient = rgb(205, 205, 214)
	mapVP.LightColor = rgb(255, 250, 240)
	mapVP.LightDirection = SUN
	mapCam.FieldOfView = 70
	local lo, hi = buildWatercolorMap(mapScene.world, loadedMapFolder())
	local verified = player:GetAttribute("MapImageSrc") -- v5.10: the link the loading screen saw really load (direct asset or thumbnail)
	local img = verified or State:GetAttribute("MapImage")
	local painting, paintScale
	if type(img) == "string" and img ~= "" then
		painting = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Image = img, ScaleType = Enum.ScaleType.Crop, ZIndex = 3 }, root)
		paintScale = new("UIScale", { Scale = 1 }, painting)
		if not verified then task.spawn(UI.LoadImage, painting, img, 3) end -- never saw it load: try the thumbnail link too
	end
	mapVP.ImageTransparency = painting and 1 or 0
	-- warm paper vignette over everything (painted edges)
	do
		local v = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(120, 112, 140), BorderSizePixel = 0, ZIndex = 5 }, root)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(0.82, 1),
			NumberSequenceKeypoint.new(1, 0.55) }) }, v)
		local v2 = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(120, 112, 140), BorderSizePixel = 0, ZIndex = 5 }, root)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.8, 1),
			NumberSequenceKeypoint.new(1, 0.6) }) }, v2)
	end
	local soulScene = newScene(root, 6, true)
	local soulVP, soulCam = soulScene.vp, soulScene.cam
	soulVP.Ambient, soulVP.LightColor = rgb(255, 255, 255), rgb(255, 255, 255)
	soulCam.FieldOfView = 70
	local sw = soulScene.world

	-- 3) the flight path: from high above + behind your side of the map down onto your spawn spot
	local endPos, fwd
	do
		local w0 = os.clock()
		local r
		repeat
			r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not r then task.wait() end
		until r or os.clock() - w0 > 0.4 or not alive(token)
		if not alive(token) then return end
		if r then
			endPos = r.Position + Vector3.new(0, 1.5, 0)
			fwd = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
		end
		local center = (lo and hi) and (lo + hi) / 2 or Vector3.zero
		if not endPos then endPos = center + Vector3.new(0, 5, 0) end
		if not fwd or fwd.Magnitude < 0.05 then
			fwd = Vector3.new(center.X - endPos.X, 0, center.Z - endPos.Z)
			if fwd.Magnitude < 0.05 then fwd = Vector3.new(0, 0, -1) end
		end
		fwd = fwd.Unit
	end
	local size = (lo and hi) and (hi - lo) or Vector3.new(120, 40, 200)
	local back = math.clamp(math.max(size.X, size.Z) * 0.45, 40, 150)
	local up = math.clamp(size.Y + 30, 34, 110)
	local P0 = endPos - fwd * back + Vector3.new(0, up, 0)
	local P1 = endPos - fwd * back * 0.35 + Vector3.new(0, up * 0.95, 0)
	local P2 = endPos - fwd * 16 + Vector3.new(0, 9, 0)
	local P3 = endPos
	local function bez(s)
		local a = 1 - s
		return P0 * (a * a * a) + P1 * (3 * a * a * s) + P2 * (3 * a * s * s) + P3 * (s * s * s)
	end
	local function ease(u) return u * u * (3 - 2 * u) end

	-- 4) the soul: bright core, two soft halos, and a smooth tapered ribbon trail (pooled cylinders, no chunky blocks)
	local core = part(sw, Vector3.one * 0.5, CFrame.new(), K.soulPale, true, 1, Enum.PartType.Ball)
	local halo1 = part(sw, Vector3.one, CFrame.new(), K.soul, true, 1, Enum.PartType.Ball)
	local halo2 = part(sw, Vector3.one, CFrame.new(), K.soul, true, 1, Enum.PartType.Ball)
	local TRAIL_N, TRAIL_LIFE = 60, 0.6
	local ribbon, glow = {}, {}
	for i = 1, TRAIL_N do
		ribbon[i] = part(sw, Vector3.new(0.1, 0.1, 0.1), CFrame.new(), K.soulPale, true, 1, Enum.PartType.Cylinder)
		glow[i] = part(sw, Vector3.new(0.1, 0.1, 0.1), CFrame.new(), K.soul, true, 1, Enum.PartType.Cylinder)
	end
	local motes = {}
	for i = 1, 24 do motes[i] = { p = part(sw, Vector3.one * 0.08, CFrame.new(), K.soulPale, true, 1, Enum.PartType.Ball), born = -10, pos = Vector3.zero, vel = Vector3.zero } end
	local hist = {} -- { pos, t }, newest first
	local nextMote = 0

	local function soulPos(u, t)
		local s = ease(u)
		local pos = bez(math.min(1, s + 0.07 * (1 - s)))
		local side = fwd:Cross(Vector3.yAxis)
		local amp = (1 - u) ^ 1.4
		return pos + side * math.sin(t * 2.6) * 2.2 * amp + Vector3.new(0, math.sin(t * 3.4 + 1) * 1.2 * amp, 0)
	end

	-- painting first (or the 3D map straight away when this map has no painting yet)
	fade.BackgroundTransparency = 0
	tween(fade, TweenInfo.new(0.45), { BackgroundTransparency = 1 })
	if painting then
		tween(paintScale, TweenInfo.new(FLY0 + 1.0 - SHOW, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1.35 })
		task.delay(1.4 - SHOW, function()
			if not root.Parent then return end
			tween(mapVP, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { ImageTransparency = 0 })
			tween(painting, TweenInfo.new(0.85, Enum.EasingStyle.Sine), { ImageTransparency = 1 })
		end)
	end

	renderFns.warp = function(dt)
		local t = T()
		local u = math.clamp((t - FLY0) / (FLY1 - FLY0), 0, 1)
		local s = ease(u)
		-- v5.10: the camera TRAILS the soul. It rides the same path but a good way behind (up to ~16% of the flight + a few studs back along the path and up),
		-- looks at the soul, and only turns toward the spawn at the very end. Before, it sat right on top of the soul and the soul filled the screen.
		local pos = soulPos(u, t)
		local lagS = math.max(0, s - 0.16 * math.min(1, s * 5))
		local here = bez(lagS)
		local tan = bez(math.min(1, lagS + 0.03)) - bez(math.max(0, lagS - 0.03))
		tan = tan.Magnitude > 0.01 and tan.Unit or fwd
		local camPos = here - tan * 6 + Vector3.new(0, 3.4, 0)
		local look = (pos + Vector3.new(0, 0.9, 0)):Lerp(endPos + fwd * 30, (s ^ 3) * 0.85)
		if (look - camPos).Magnitude < 0.5 then look = camPos + fwd end
		local camCF = CFrame.lookAt(camPos, look)
		mapCam.CFrame, soulCam.CFrame = camCF, camCF
		mapCam.FieldOfView = 60 + 8 * math.sin(math.pi * s)
		soulCam.FieldOfView = mapCam.FieldOfView
		-- soul
		local light = math.clamp((t - 0.75) / 0.7, 0, 1)
		local pulse = 1 + 0.1 * math.sin(t * 13)
		local sz = (0.18 + 0.32 * light) * pulse
		core.Size, halo1.Size, halo2.Size = Vector3.one * sz, Vector3.one * sz * 2.1, Vector3.one * sz * 3.6
		core.CFrame, halo1.CFrame, halo2.CFrame = CFrame.new(pos), CFrame.new(pos), CFrame.new(pos)
		core.Transparency = 1 - light
		halo1.Transparency = 1 - 0.32 * light
		halo2.Transparency = 1 - 0.12 * light
		-- trail history: a new point every 0.12 studs of movement
		if light > 0 and (not hist[1] or (hist[1].pos - pos).Magnitude > 0.12) then
			table.insert(hist, 1, { pos = pos, t = t })
			if #hist > TRAIL_N + 1 then table.remove(hist) end
		end
		for i = 1, TRAIL_N do
			local a, b = hist[i], hist[i + 1]
			local seg, gl = ribbon[i], glow[i]
			if a and b and i > 0 then
				local age = (t - b.t) / TRAIL_LIFE
				local k = 1 - math.max(age, (i - 1) / TRAIL_N)
				if k > 0 then
					local pa = (i == 1) and pos or a.pos
					local len = (b.pos - pa).Magnitude
					if len > 0.001 then
						local w = sz * 0.55 * k ^ 0.8
						local cf = CFrame.lookAt((pa + b.pos) / 2, b.pos) * CFrame.Angles(0, math.rad(90), 0)
						seg.Size = Vector3.new(len + w * 0.6, w, w)
						seg.CFrame = cf
						seg.Transparency = 1 - 0.85 * k * light
						gl.Size = Vector3.new(len + w * 1.6, w * 2.8, w * 2.8)
						gl.CFrame = cf
						gl.Transparency = 1 - 0.22 * k * light
					else
						seg.Transparency, gl.Transparency = 1, 1
					end
				else
					seg.Transparency, gl.Transparency = 1, 1
				end
			else
				seg.Transparency, gl.Transparency = 1, 1
			end
		end
		-- a few soft motes peel off the trail and drift away
		if light > 0.5 and u > 0 and t >= nextMote then
			nextMote = t + 0.05
			for _, m in motes do
				if t - m.born > 0.9 then
					m.born, m.pos = t, pos
					m.vel = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 1)) * 1.6
					break
				end
			end
		end
		for _, m in motes do
			local a = (t - m.born) / 0.9
			if a >= 0 and a < 1 then
				m.pos += m.vel * dt
				m.p.CFrame = CFrame.new(m.pos)
				m.p.Size = Vector3.one * (0.09 * (1 - a) + 0.02)
				m.p.Transparency = 0.25 + 0.75 * a
			else
				m.p.Transparency = 1
			end
		end
	end

	-- 5) gradual white flash, then you are on your spawn (first person) and the card roll starts
	if not waitUntil(FLASH0) then return end
	tween(flash, TweenInfo.new(FLASH1 - FLASH0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { BackgroundTransparency = 0 })
	if not waitUntil(FLASH1 + 0.05) then return end
	renderFns.warp = nil
	killScreens()
	fade.BackgroundTransparency = 1
	restoreWorld()
	do -- hand the camera over looking the way your spawn faces
		local ch = player.Character
		local head = ch and ch:FindFirstChild("Head")
		local r = ch and ch:FindFirstChild("HumanoidRootPart")
		if head and r then
			local lv = Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z)
			if lv.Magnitude > 0.05 then camera.CFrame = CFrame.lookAt(head.Position, head.Position + lv.Unit) end
		end
	end
	game:GetService("UserInputService").MouseDeltaSensitivity = C.MOUSE_SENS or 1 -- v5.16: the match sensitivity (GunClient keeps it there)
	tween(flash, TweenInfo.new(OUT1 - FLASH1 - 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
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
