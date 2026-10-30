-- MatchHUD v3.2 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only.
-- v3.2 polish: rounded health segments with a white 'damage trail' that drains behind the real value, low-health pulse, team-colored
-- name tick, soft corner shading so white text reads on any map, rounded selected gun slot, ammo that pops on change, reload bar that
-- glows. Same Finals layout + same attributes as v3.1.
-- (v3.1)
-- In-match HUD styled after THE FINALS: no boxes or panels, white condensed text with a soft shadow, segmented health bars.
--   * bottom-left: your squad. YOU are always at the bottom and big (name, segmented health, "HP / MAX");
--     teammates are stacked above you, smaller (name + small health pips). Dead teammates go grey with a skull mark.
--   * bottom-right: item selection. Weapon name + ammo above a row of slots: [1] your lobby gun (picture of the real model,
--     selected = white square with a dark gun), [2][3][4] your lobby gadgets (dim until gadgets exist in Breakline).
--     Reload shows as a thin bar under the ammo.
-- Reads: GunClient's local attributes (HUDWeapon, HUDAmmo, HUDMag, HUDReload, HUDReloadU, HUDMode), the Player attributes
-- Weapon + LoadoutJson (GunServer), and teammates' Humanoids. Needs ReplicatedStorage: GunModels, LobbyCatalog (copy of the lobby's).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local GunModels = require(RS:WaitForChild("GunModels"))
local Catalog = RS:FindFirstChild("LobbyCatalog") and require(RS.LobbyCatalog) or nil

pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)

local WHITE = Color3.fromRGB(245, 245, 242)
local DIM = Color3.fromRGB(170, 170, 166)
local DARK = Color3.fromRGB(18, 18, 18)
local RED = Color3.fromRGB(230, 50, 50)
local FAM = Font.fromEnum(Enum.Font.RobotoCondensed).Family
local F_BOLD = Font.new(FAM, Enum.FontWeight.Bold)
local F_MED = Font.new(FAM, Enum.FontWeight.Medium)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
-- white text with the soft dark shadow The Finals uses (no outline boxes)
local function text(parent, str, size, x, y, w, h, font, align, color)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = str, TextSize = size, FontFace = font or F_BOLD, TextColor3 = color or WHITE,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), TextXAlignment = align or Enum.TextXAlignment.Left }, parent)
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.55 }, l)
	return l
end
local function rect(parent, x, y, w, h, color, transp)
	return new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = color or WHITE,
		BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
end

local gui = new("ScreenGui", { Name = "MatchHUD2", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4 }, player:WaitForChild("PlayerGui"))
-- design at 1920x1080, scaled to the screen
local root = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1 }, gui)
local scale = new("UIScale", {}, root)
local function rescale()
	local vs = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	scale.Scale = math.max(0.45, math.min(vs.X / 1920, vs.Y / 1080))
end
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

-- soft dark corners so the white text is readable on bright maps (very light, never a box)
do
	local function shade(x, y, w, h, rot)
		local f = rect(root, x, y, w, h, Color3.new(0, 0, 0), 0)
		f.ZIndex = 0
		new("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }) }, f)
	end
	shade(0, 1080 - 420, 760, 420, -45)       -- bottom-left
	shade(1920 - 760, 1080 - 330, 760, 330, 225) -- bottom-right
end
local TWEEN = game:GetService("TweenService")
local function teamColor3()
	return (player.Team and not player.Neutral) and player.TeamColor.Color or WHITE
end

-- ================= bottom-left: squad =================
local squad = new("Frame", { Position = UDim2.fromOffset(48, 0), Size = UDim2.fromOffset(460, 1080 - 44), BackgroundTransparency = 1 }, root)

-- segmented bar: n segments, fills left to right. Each segment has a faint white "ghost" that drains slowly behind the real fill
-- (shows how much you just lost). Returns set(frac, color) and tick(dt) which must be called every frame.
local function segBar(parent, x, y, n, segW, segH, gap)
	local segs = {}
	local ghostFrac, targetFrac = 1, 1
	for i = 1, n do
		local back = rect(parent, x + (i - 1) * (segW + gap), y, segW, segH, Color3.new(0, 0, 0), 0.5)
		new("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.floor(segH / 4))) }, back)
		local ghost = rect(back, 0, 0, segW, segH, WHITE, 0.55)
		new("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.floor(segH / 4))) }, ghost)
		local fill = rect(back, 0, 0, segW, segH, WHITE, 0)
		new("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.floor(segH / 4))) }, fill)
		segs[i] = { back = back, ghost = ghost, fill = fill, w = segW }
	end
	local function paint(frac, color)
		for i, sg in segs do
			local f = math.clamp(frac * n - (i - 1), 0, 1)
			sg.fill.Size = UDim2.fromOffset(math.floor(sg.w * f + 0.5), sg.fill.Size.Y.Offset)
			sg.fill.BackgroundColor3 = color or WHITE
			local g = math.clamp(ghostFrac * n - (i - 1), 0, 1)
			sg.ghost.Size = UDim2.fromOffset(math.floor(sg.w * g + 0.5), sg.ghost.Size.Y.Offset)
		end
	end
	local lastColor = WHITE
	local function set(frac, color)
		frac = math.clamp(frac, 0, 1)
		if frac > ghostFrac then ghostFrac = frac end -- healing: ghost snaps up
		targetFrac = frac
		lastColor = color or WHITE
		paint(frac, lastColor)
	end
	local function tick(dt)
		if ghostFrac > targetFrac then
			ghostFrac = math.max(targetFrac, ghostFrac - dt * 0.35)
			paint(targetFrac, lastColor)
		end
	end
	return set, tick
end

-- you (bottom, large)
local meName = text(squad, player.DisplayName, 30, 0, 1080 - 44 - 124, 420, 34, F_BOLD)
local meHP = text(squad, "100", 34, 0, 1080 - 44 - 82, 80, 36, F_BOLD)
local meMax = text(squad, "/ 100", 22, 66, 1080 - 44 - 74, 80, 28, F_MED, nil, DIM)
local meBar, meTick = segBar(squad, 0, 1080 - 44 - 38, 10, 38, 22, 4)
local meTick_ = meTick
-- team-colored tick left of your name + a thin underline that pulses when you are low
local meAccent = rect(squad, -16, 1080 - 44 - 120, 6, 28, WHITE, 0)
new("UICorner", { CornerRadius = UDim.new(0, 3) }, meAccent)
local meGlow = rect(squad, 0, 1080 - 44 - 12, 10 * 42 - 4, 3, RED, 1)
new("UICorner", { CornerRadius = UDim.new(0, 2) }, meGlow)

-- teammates (above you)
local mateRows = {}
local function mateRow(i)
	if mateRows[i] then return mateRows[i] end
	local y = 1080 - 44 - 124 - i * 62
	local row = new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(420, 58), BackgroundTransparency = 1 }, squad)
	local name = text(row, "", 22, 0, 0, 360, 26, F_BOLD)
	local dead = text(row, "DOWN", 14, 0, 0, 360, 26, F_BOLD, Enum.TextXAlignment.Right, RED)
	local bar, tick = segBar(row, 0, 30, 10, 14, 10, 3)
	local tick_ = rect(row, -12, 4, 4, 20, WHITE, 0)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, tick_)
	mateRows[i] = { row = row, name = name, bar = bar, tick = tick, accent = tick_, dead = dead }
	return mateRows[i]
end

local function teammates()
	local list = {}
	if not player.Team or player.Neutral then return list end
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Team == player.Team then table.insert(list, p) end
	end
	table.sort(list, function(a, b) return a.UserId < b.UserId end)
	return list
end

local function hpOf(p)
	local ch = p.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if not hum then return 0, 100 end
	return math.max(0, hum.Health), math.max(1, hum.MaxHealth)
end

-- ================= bottom-right: item selection =================
local items = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(1920 - 48, 1080 - 40), Size = UDim2.fromOffset(560, 190), BackgroundTransparency = 1 }, root)
local wName = text(items, "", 30, 0, 0, 380, 34, F_BOLD, Enum.TextXAlignment.Right)
local ammoBig = text(items, "30", 34, 392, -2, 100, 38, F_BOLD, Enum.TextXAlignment.Right)
local ammoMag = text(items, "/30", 22, 494, 6, 66, 28, F_MED, Enum.TextXAlignment.Left, DIM)
local modeTxt = text(items, "", 14, 0, 34, 560, 18, F_MED, Enum.TextXAlignment.Right, DIM)
local reloadBack = rect(items, 392, 40, 168, 5, Color3.new(0, 0, 0), 0.45)
new("UICorner", { CornerRadius = UDim.new(0, 3) }, reloadBack)
local reloadFill = rect(reloadBack, 0, 0, 0, 5, WHITE, 0)
new("UICorner", { CornerRadius = UDim.new(0, 3) }, reloadFill)
reloadBack.Visible = false

local SLOT = 76
local slotRow = new("Frame", { Position = UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(560, 120), BackgroundTransparency = 1 }, items)
-- divider line under the row, like the Finals' thin underline
rect(slotRow, 0, SLOT + 10, 560, 2, WHITE, 0.6)

local gunSlot -- { frame, vp, id }
local gadgetSlots = {}

local function gunViewport(parent, weaponId, dark)
	for _, c in parent:GetChildren() do if c:IsA("ViewportFrame") then c:Destroy() end end
	local vp = new("ViewportFrame", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
		Ambient = dark and Color3.new(0, 0, 0) or Color3.fromRGB(200, 200, 200), LightColor = dark and Color3.new(0, 0, 0) or WHITE, LightDirection = Vector3.new(-0.4, -1, -0.2) }, parent)
	local ok, desc = pcall(GunModels.Describe, weaponId, "Iron")
	if not ok or not desc then return vp end
	local model = new("Model", {}, vp)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = dark and DARK or WHITE, Material = Enum.Material.SmoothPlastic }, model)
			if d.Shape then p.Shape = d.Shape end
			minV, maxV = minV:Min(d.CF.Position - d.Size / 2), maxV:Max(d.CF.Position + d.Size / 2)
		end
	end
	local center = (minV + maxV) / 2
	local len = math.max(maxV.Z - minV.Z, (maxV.Y - minV.Y) * 1.4)
	local cam = new("Camera", { FieldOfView = 16 }, vp)
	local dist = (len / 2) / math.tan(math.rad(8)) + 0.5
	-- side view, muzzle pointing left (the Finals draws its icons that way)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(-dist, 0, 0), center)
	vp.CurrentCamera = cam
	return vp
end

local function makeSlot(x, w, key)
	local f = rect(slotRow, x, 0, w, SLOT, WHITE, 1)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, f)
	local border = new("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.55 }, f)
	local k = text(slotRow, key, 16, x, SLOT + 14, w, 20, F_BOLD, Enum.TextXAlignment.Center, DIM)
	return { frame = f, border = border, key = k }
end

local function buildSlots()
	for _, c in slotRow:GetChildren() do if c:IsA("Frame") and c ~= nil and c.Size.Y.Offset == SLOT then c:Destroy() end end
	for _, c in slotRow:GetChildren() do if c:IsA("TextLabel") then c:Destroy() end end
	gadgetSlots = {}
	-- gun slot (wide) on the right, gadgets to its left (Finals order: weapon at the far right of the row is the selected one)
	local gx = 560 - 170
	gunSlot = makeSlot(gx, 170, "1")
	gunSlot.frame.BackgroundTransparency = 0 -- selected: solid white square
	gunSlot.border.Transparency = 1
	gunSlot.key.TextColor3 = WHITE
	local raw = player:GetAttribute("LoadoutJson")
	local lo = {}
	if type(raw) == "string" then
		local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(t) == "table" then lo = t end
	end
	for i = 1, 3 do
		local x = gx - i * (SLOT + 12)
		local s = makeSlot(x, SLOT, tostring(i + 1))
		local id = type(lo.Gadgets) == "table" and lo.Gadgets[4 - i] or ""
		local item = Catalog and Catalog.ById[id]
		if item then
			text(s.frame, item.glyph, 24, 0, 0, SLOT, SLOT, F_BOLD, Enum.TextXAlignment.Center, DIM)
			local soon = text(s.frame, "SOON", 10, 0, SLOT - 16, SLOT, 14, F_MED, Enum.TextXAlignment.Center, DIM)
			soon.TextTransparency = 0.3
		else
			s.border.Transparency = 0.85
		end
		table.insert(gadgetSlots, s)
	end
	gunSlot.id = nil
end

local function refreshGun()
	local id = player:GetAttribute("Weapon")
	if gunSlot and id and gunSlot.id ~= id then
		gunSlot.id = id
		gunViewport(gunSlot.frame, id, true)
	end
end

local function refreshAmmo()
	local name = player:GetAttribute("HUDWeapon")
	wName.Text = name and string.upper(name) or ""
	local a, m = player:GetAttribute("HUDAmmo") or 0, player:GetAttribute("HUDMag") or 0
	if ammoBig.Text ~= tostring(a) then
		ammoBig.TextSize = 40
		TWEEN:Create(ammoBig, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 34 }):Play()
	end
	ammoBig.Text = tostring(a)
	ammoMag.Text = "/" .. tostring(m)
	ammoBig.TextColor3 = (m > 0 and a <= m * 0.25) and RED or WHITE
	modeTxt.Text = player:GetAttribute("HUDMode") or ""
	reloadBack.Visible = player:GetAttribute("HUDReload") == true
end

for _, k in { "HUDWeapon", "HUDAmmo", "HUDMag", "HUDReload", "HUDMode" } do player:GetAttributeChangedSignal(k):Connect(refreshAmmo) end
player:GetAttributeChangedSignal("Weapon"):Connect(refreshGun)
player:GetAttributeChangedSignal("LoadoutJson"):Connect(function() buildSlots() refreshGun() end)
player:GetAttributeChangedSignal("HUDReloadU"):Connect(function()
	reloadFill.Size = UDim2.fromOffset(math.floor(168 * (player:GetAttribute("HUDReloadU") or 0)), 5)
end)
buildSlots()
refreshGun()
refreshAmmo()

-- ================= per-frame: health + squad + hide while carrying =================
local acc = 0
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	meTick_(dt)
	for _, r in mateRows do if r.tick then r.tick(dt) end end
	acc += dt
	if acc < 0.05 then return end
	acc = 0
	-- you
	local hp, max = hpOf(player)
	meName.Text = player.DisplayName
	meHP.Text = tostring(math.ceil(hp))
	meMax.Text = "/ " .. tostring(math.floor(max))
	meMax.Position = UDim2.fromOffset(meHP.TextBounds.X + 8, meMax.Position.Y.Offset)
	meBar(hp / max, (hp / max <= 0.3) and RED or WHITE)
	meAccent.BackgroundColor3 = teamColor3()
	local low = hp > 0 and hp / max <= 0.3
	meGlow.BackgroundTransparency = low and (0.35 + 0.4 * (0.5 + 0.5 * math.sin(clock * 9))) or 1
	meHP.TextColor3 = low and RED or WHITE
	-- teammates
	local mates = teammates()
	for i = 1, math.max(#mates, #mateRows) do
		local p = mates[i]
		if p then
			local r = mateRow(i)
			r.row.Visible = true
			local h, m = hpOf(p)
			local alive = h > 0
			r.name.Text = p.DisplayName
			r.name.TextColor3 = alive and WHITE or DIM
			r.dead.Visible = not alive
			r.bar(h / m, alive and ((h / m <= 0.3) and RED or WHITE) or DIM)
			r.accent.BackgroundColor3 = alive and teamColor3() or DIM
		elseif mateRows[i] then
			mateRows[i].row.Visible = false
		end
	end
	-- the item row is pointless while carrying a box (guns are locked)
	items.Visible = player:GetAttribute("Carrying") ~= true
end)
