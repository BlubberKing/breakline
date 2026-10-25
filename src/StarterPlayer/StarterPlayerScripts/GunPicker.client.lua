-- GunPicker (TEMPORARY test menu — will be replaced by the lobby loadout screen).
-- "GUNS" tab at the top of the screen (or press G). Pick any gun + its sight; swaps instantly.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Weapons = require(RS:WaitForChild("WeaponConfig"))
local GunModels = require(RS:WaitForChild("GunModels"))
local SetLoadout = RS:WaitForChild("GunRemotes"):WaitForChild("SetLoadout")

local ACCENT = GunModels.Colors.Accent
local BG = Color3.fromRGB(12, 12, 16)
local CARD = Color3.fromRGB(24, 25, 31)
local TEXT = Color3.fromRGB(235, 235, 240)
local SUB = Color3.fromRGB(150, 150, 162)

local gui = Instance.new("ScreenGui")
gui.Name = "GunPicker"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p end
local function stroke(p, color, t) local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = t or 1; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s end
local function text(parent, str, size, color, font, xa)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = str
	l.TextSize = size
	l.TextColor3 = color or TEXT
	l.Font = font or Enum.Font.GothamBold
	l.TextXAlignment = xa or Enum.TextXAlignment.Left
	l.Size = UDim2.new(1, 0, 0, size + 4)
	l.Parent = parent
	return l
end

-- ===== top tab =====
local tab = Instance.new("TextButton")
tab.Name = "Tab"
tab.AnchorPoint = Vector2.new(0.5, 0)
tab.Position = UDim2.new(0.5, 0, 0, 6)
tab.Size = UDim2.fromOffset(150, 30)
tab.BackgroundColor3 = BG
tab.BackgroundTransparency = 0.25
tab.AutoButtonColor = false
tab.Font = Enum.Font.GothamBlack
tab.TextSize = 14
tab.TextColor3 = TEXT
tab.Text = "GUNS  [G]"
tab.Parent = gui
corner(tab, 6)
local tabStroke = stroke(tab, ACCENT, 1.5)

-- ===== panel =====
local panel = Instance.new("TextButton") -- Modal button frees the mouse in first person while open
panel.Name = "Panel"
panel.Text = ""
panel.AutoButtonColor = false
panel.Modal = true
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 44)
panel.Size = UDim2.new(0.86, 0, 0.8, 0)
panel.BackgroundColor3 = BG
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
corner(panel, 10)
stroke(panel, Color3.fromRGB(45, 46, 56), 1)
local sizeLimit = Instance.new("UISizeConstraint"); sizeLimit.MaxSize = Vector2.new(1180, 760); sizeLimit.Parent = panel

local header = text(panel, "ARMORY  ·  TEST LOADOUT", 18, TEXT, Enum.Font.GothamBlack)
header.Position = UDim2.fromOffset(20, 14)
header.Size = UDim2.new(1, -40, 0, 22)
local hint = text(panel, "Temporary picker — click a gun to equip it, pick a sight under it. TTK = time to kill (100 HP, body / head).", 12, SUB, Enum.Font.Gotham)
hint.Position = UDim2.fromOffset(20, 38)
hint.Size = UDim2.new(1, -40, 0, 16)

local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(14, 62)
scroll.Size = UDim2.new(1, -28, 1, -76)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = ACCENT
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 10), UDim.new(0, 6), UDim.new(0, 6)
pad.Parent = scroll
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(268, 236)
grid.CellPadding = UDim2.fromOffset(12, 12)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll

-- stat bar maxes (for 0..1 bars)
local function dps(cfg) return cfg.Damage * cfg.Pellets / Weapons.AvgInterval(cfg) end
local MAX = { dps = 1, range = 1, mob = 1.1, handling = 1 }
for _, id in Weapons.Order do
	local c = Weapons.Get(id)
	MAX.dps = math.max(MAX.dps, dps(c))
	MAX.range = math.max(MAX.range, math.min(c.FalloffEnd, 220))
end

local cards = {}

local function statBar(parent, name, v, order)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 12)
	row.LayoutOrder = order
	row.Parent = parent
	local l = text(row, name, 10, SUB, Enum.Font.GothamBold)
	l.Size = UDim2.new(0, 64, 1, 0)
	local bg = Instance.new("Frame")
	bg.Position = UDim2.new(0, 66, 0.5, -2)
	bg.Size = UDim2.new(1, -66, 0, 4)
	bg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	bg.BorderSizePixel = 0
	bg.Parent = row
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(math.clamp(v, 0.04, 1), 1)
	f.BackgroundColor3 = TEXT
	f.BorderSizePixel = 0
	f.Parent = bg
end

local function equip(id, sight)
	SetLoadout:FireServer(id, sight)
end

local function refresh()
	local cur, curSight = player:GetAttribute("Weapon"), player:GetAttribute("Sight")
	for id, c in cards do
		local on = id == cur
		c.stroke.Color = on and ACCENT or Color3.fromRGB(45, 46, 56)
		c.stroke.Thickness = on and 2 or 1
		c.equipped.Visible = on
		local cfg = Weapons.Get(id)
		local shown = on and curSight or c.chosen or cfg.DefaultSight
		for sid, b in c.sightButtons do
			local sel = sid == shown
			b.BackgroundColor3 = sel and ACCENT or Color3.fromRGB(38, 39, 48)
			b.TextColor3 = sel and Color3.new(0, 0, 0) or TEXT
		end
	end
end

for i, id in Weapons.Order do
	local cfg = Weapons.Get(id)
	local card = Instance.new("TextButton")
	card.Name = id
	card.Text = ""
	card.AutoButtonColor = false
	card.LayoutOrder = i
	card.BackgroundColor3 = CARD
	card.Parent = scroll
	corner(card, 8)
	local st = stroke(card, Color3.fromRGB(45, 46, 56), 1)
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(12, 10)
	inner.Size = UDim2.new(1, -24, 1, -20)
	inner.Parent = card
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 3)
	list.Parent = inner

	local cls = text(inner, string.upper(cfg.Class) .. "  ·  " .. string.upper(cfg.FireMode == "Burst" and (cfg.BurstCount .. "-burst") or cfg.FireMode), 10, ACCENT, Enum.Font.GothamBlack)
	cls.LayoutOrder = 1
	local nm = text(inner, cfg.Name, 17, TEXT, Enum.Font.GothamBlack)
	nm.LayoutOrder = 2
	local insp = text(inner, cfg.Inspiration, 10, SUB, Enum.Font.Gotham)
	insp.LayoutOrder = 3
	insp.TextWrapped = true
	insp.Size = UDim2.new(1, 0, 0, 26)
	insp.TextYAlignment = Enum.TextYAlignment.Top

	local ttkB, stkB = Weapons.TTK(cfg, false)
	local ttkH, stkH = Weapons.TTK(cfg, true)
	local dmgStr = cfg.Pellets > 1 and (cfg.Damage .. "x" .. cfg.Pellets) or tostring(cfg.Damage)
	local rate = cfg.FireMode == "Burst" and math.floor(60 / Weapons.AvgInterval(cfg)) or cfg.RPM
	local info = text(inner, string.format("DMG %s  ·  %d RPM  ·  MAG %d  ·  RELOAD %.1fs", dmgStr, rate, cfg.MagSize, cfg.ReloadTime), 10, TEXT, Enum.Font.GothamBold)
	info.LayoutOrder = 4
	local ttk = text(inner, string.format("TTK  %.2fs (%d)  /  %.2fs (%d) head", ttkB, stkB, ttkH, stkH), 11, TEXT, Enum.Font.GothamBlack)
	ttk.LayoutOrder = 5

	statBar(inner, "DPS", dps(cfg) / MAX.dps, 6)
	statBar(inner, "RANGE", math.min(cfg.FalloffEnd, 220) / MAX.range, 7)
	statBar(inner, "MOBILITY", (cfg.MoveSpeed - 0.8) / (MAX.mob - 0.8), 8)
	statBar(inner, "HANDLING", 1 - (cfg.ADSTime - 0.1) / 0.25, 9)

	-- sight toggles (only if the gun has more than one choice)
	local sightRow = Instance.new("Frame")
	sightRow.BackgroundTransparency = 1
	sightRow.Size = UDim2.new(1, 0, 0, 24)
	sightRow.LayoutOrder = 10
	sightRow.Parent = inner
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.Padding = UDim.new(0, 5)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = sightRow
	local c = { stroke = st, sightButtons = {}, chosen = nil }
	if #cfg.Sights > 1 then
		for j, sid in cfg.Sights do
			local def = GunModels.Sights[sid] or { Display = sid }
			local b = Instance.new("TextButton")
			b.LayoutOrder = j
			b.AutoButtonColor = false
			b.Size = UDim2.fromOffset(56, 22)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 11
			b.Text = def.Display
			b.Parent = sightRow
			corner(b, 4)
			b.Activated:Connect(function()
				c.chosen = sid
				equip(id, sid)
				refresh()
			end)
			c.sightButtons[sid] = b
		end
	else
		local only = text(sightRow, "Sight: " .. ((GunModels.Sights[cfg.Sights[1]] or {}).Display or cfg.Sights[1]), 10, SUB, Enum.Font.GothamBold)
		only.Size = UDim2.new(1, 0, 1, 0)
	end

	local eq = text(card, "EQUIPPED", 10, ACCENT, Enum.Font.GothamBlack, Enum.TextXAlignment.Right)
	eq.Position = UDim2.new(0, 0, 0, 10)
	eq.Size = UDim2.new(1, -12, 0, 14)
	c.equipped = eq

	card.Activated:Connect(function()
		equip(id, c.chosen or (player:GetAttribute("Weapon") == id and player:GetAttribute("Sight")) or cfg.DefaultSight)
	end)
	card.MouseEnter:Connect(function() TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(32, 33, 41) }):Play() end)
	card.MouseLeave:Connect(function() TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = CARD }):Play() end)
	cards[id] = c
end

-- ===== open / close =====
local open = false
local function setOpen(v)
	open = v
	panel.Visible = v
	player:SetAttribute("GunMenuOpen", v)
	UIS.MouseIconEnabled = v
	tabStroke.Thickness = v and 2.5 or 1.5
	tab.Text = v and "CLOSE  [G]" or "GUNS  [G]"
	if v then refresh() end
end
tab.Activated:Connect(function() setOpen(not open) end)
UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.G then setOpen(not open)
	elseif input.KeyCode == Enum.KeyCode.Escape and open then setOpen(false) end
end)
player:GetAttributeChangedSignal("Weapon"):Connect(refresh)
player:GetAttributeChangedSignal("Sight"):Connect(refresh)
player.CharacterAdded:Connect(function() if open then setOpen(false) end end)
refresh()
