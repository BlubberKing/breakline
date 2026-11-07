-- CosmeticsClient v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in v5.10.
-- Two screens + one button:
--  1) COSMETICS SHOP: the COSMETICS button on the left of the screen, right UNDER the SHOP button (same look). Tabs PLAYER SKINS / GUN SKINS. Every tab is split in two halves:
--     the ESSENCE SHOP (premium currency, big, on the LEFT = the first thing you see) and the SOULS SHOP (free currency, on the right, clearly labelled EARN BY PLAYING).
--     Click any item = a big PREVIEW opens: drag with the mouse (or a finger) to turn it round every way, scroll to zoom, then BUY (asks twice) or EQUIP.
--  2) COSMETICS LOCKER: opened by the hanger button next to PLAY (or TAB). Its own menu with two tabs: PLAYER SKINS (every skin you own, click = preview, EQUIP) and GUN SKINS
--     (every gun skin you own, grouped by gun with a STOCK card each; it says which gun a skin goes on, and EQUIPPED ON <gun> once it is on).
-- All purchases / equips are checked on the server (CosmeticsServer). Needs in ReplicatedStorage: UIKit, Skins, GunSkins, GunModels, CosmeticsCatalog, LobbyCatalog, CosmeticsRemotes.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local UI = require(RS:WaitForChild("UIKit"))
local K, F, new = UI.C, UI.F, UI.new
local Skins = require(RS:WaitForChild("Skins"))
local GunSkins = require(RS:WaitForChild("GunSkins"))
local GunModels = require(RS:WaitForChild("GunModels"))
local Cat = require(RS:WaitForChild("CosmeticsCatalog"))
local Remotes = RS:WaitForChild("CosmeticsRemotes")
local BuyR, EquipR = Remotes:WaitForChild("Buy"), Remotes:WaitForChild("Equip")

local rgb = Color3.fromRGB
local BLACK = Color3.new(0, 0, 0)
local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tween(o, info, goal) TweenService:Create(o, info, goal):Play() end

local ESS, ESS_PALE = K.essence, K.essencePale
local SOULC = K.soul

-- ================= small builders =================
local function box(parent, x, y, w, h, color, transp)
	return new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = color, BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
end
local function stroke(o, color, th, transp)
	return new("UIStroke", { Color = color, Thickness = th or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function lbl(parent, text, size, x, y, w, h, color, font, align, wrap)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font or F.B, TextColor3 = color or K.text,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = wrap and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center, TextWrapped = wrap or false }, parent)
end
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function hot(b, bg, bgHot, st, stCol, stHot)
	b.MouseEnter:Connect(function()
		tween(b, FAST, { BackgroundColor3 = bgHot })
		if st then tween(st, FAST, { Color = stHot }) end
	end)
	b.MouseLeave:Connect(function()
		tween(b, FAST, { BackgroundColor3 = bg })
		if st then tween(st, FAST, { Color = stCol }) end
	end)
end
local function chip(parent, x, y, w, h, text, bg, fg, line, size)
	local c = box(parent, x, y, w, h, bg)
	if line then stroke(c, line, 1) end
	lbl(c, text, size or 12, 0, 0, w, h, fg, F.MB, Enum.TextXAlignment.Center)
	return c
end
local function priceRow(parent, x, y, item, big)
	local ic = (item.currency == "essence") and UI.EssenceIcon(parent, big and 34 or 24) or UI.SoulIcon(parent, big and 34 or 24)
	ic.Position = UDim2.fromOffset(x, y)
	lbl(parent, commas(item.amount), big and 30 or 20, x + (big and 42 or 30), y - 3, 160, big and 38 or 28, item.currency == "essence" and ESS_PALE or K.text, F.H)
end

-- ================= state helpers =================
local function souls() return player:GetAttribute("Souls") or 0 end
local function essence() return player:GetAttribute("Essence") or 0 end
local function balance(cur) return cur == "essence" and essence() or souls() end
local function owned(item)
	if item.kind == "skin" then return Cat.OwnsSkin(player, item.id) end
	return Cat.OwnsGunSkin(player, item.id)
end
local function wornSkin() local s = player:GetAttribute("Skin"); return Skins.Is(s) and s or Skins.Default end
local function equippedOn(gun) return GunSkins.Equipped(player, gun) end
local function isEquipped(item)
	if item.kind == "skin" then return wornSkin() == item.id end
	return item.gun ~= nil and equippedOn(item.gun) == item.id
end
local function myWeapon()
	local raw = player:GetAttribute("LoadoutJson")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" and GunSkins.GunNames[t.Weapon] then return t.Weapon end
	end
	return "VX9"
end

-- ================= pictures =================
local function addGunParts(model, gunId, skinId)
	local ok, desc = pcall(GunModels.Describe, gunId, "Iron", skinId)
	if not ok or not desc then return end
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Size = d.Size, CFrame = d.CF, Color = d.Color,
				Material = d.Material or Enum.Material.SmoothPlastic, Transparency = d.Transparency or 0, Reflectance = d.Reflectance or 0,
				TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, model)
			if d.Shape then p.Shape = d.Shape end
		end
	end
end
local function addFigure(model, skinId)
	local ok, fig = pcall(Skins.NewFigure, model, skinId, { static = true })
	if ok and fig then pcall(fig.Update, fig, 0, 0) end
	-- a dark disc under the feet
	local d = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 6, 6), Color = rgb(20, 22, 28),
		Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)) }, model)
	new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 6.5, 6.5), Color = K.red,
		Material = Enum.Material.Neon, Transparency = 0.25, CFrame = CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90)) }, model)
	return d
end

-- a small still picture (cards): figure or gun fitted into the frame, never cropped
local function thumb(parent, item)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 160), LightColor = rgb(255, 250, 244),
		LightDirection = Vector3.new(-0.5, -0.9, -0.4) }, parent)
	local cam = new("Camera", { FieldOfView = 20 }, vp)
	local model = new("Model", {}, vp)
	if item.kind == "skin" then
		local ok, fig = pcall(Skins.NewFigure, model, item.id, { static = true })
		if ok and fig then pcall(fig.Update, fig, 0, 0) end
		UI.FitViewport(vp, cam, model, Vector3.new(0.28, 0.1, 1), { pad = 0.04, fov = 22 })
	else
		addGunParts(model, item.gun, item.id ~= "STOCK" and item.id or nil)
		UI.FitViewport(vp, cam, model, Vector3.new(1, 0.1, 0), { pad = 0.1, fov = 16 })
	end
	return vp
end

-- cards fill their pictures one per frame so opening a page never hitches
local thumbJobs = {}
task.spawn(function()
	while true do
		local job = table.remove(thumbJobs, 1)
		if job then
			if job.well.Parent then pcall(thumb, job.well, job.item) end
			task.wait()
		else
			task.wait(0.1)
		end
	end
end)
local function queueThumb(well, item) table.insert(thumbJobs, { well = well, item = item }) end

-- ================= the 3D viewer: drag to turn, scroll to zoom =================
local viewers = {}
local function newViewer(parent, x, y, w, h)
	local holder = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = rgb(8, 9, 12), BorderSizePixel = 0, ClipsDescendants = true, Active = true }, parent)
	stroke(holder, K.line, 1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(20, 22, 30), rgb(6, 7, 10)) }, holder)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 162), LightColor = rgb(255, 250, 244),
		LightDirection = Vector3.new(-0.45, -0.8, -0.5) }, holder)
	local cam = new("Camera", { FieldOfView = 34 }, vp)
	vp.CurrentCamera = cam
	local model = new("Model", {}, vp)
	local hint = lbl(holder, "DRAG TO TURN   //   SCROLL TO ZOOM", 13, 0, h - 34, w, 24, K.dim, F.MB, Enum.TextXAlignment.Center)
	hint.ZIndex = 5
	local V = { yaw = 0.4, pitch = 0.12, dist = 14, baseDist = 14, center = Vector3.zero, dragging = false, touched = 0, kind = "skin" }
	local conns = {}
	function V.set(item)
		model:ClearAllChildren()
		V.kind = item.kind
		if item.kind == "skin" then
			addFigure(model, item.id)
			V.yaw, V.pitch = 0.45, 0.1
		else
			addGunParts(model, item.gun, item.id ~= "STOCK" and item.id or nil)
			V.yaw, V.pitch = math.pi / 2 + 0.25, 0.14
		end
		local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
		if ok and cf then
			V.center = cf.Position
			if item.kind == "skin" then V.center = Vector3.new(cf.Position.X, cf.Position.Y + 0.15, cf.Position.Z) end
			local r = size.Magnitude / 2
			V.baseDist = r / math.sin(math.rad(cam.FieldOfView / 2)) * (item.kind == "skin" and 0.98 or 1.02)
		end
		V.dist = V.baseDist
		V.touched = os.clock() - 10 -- spins by itself until the player grabs it
	end
	local function place()
		local cp, sp = math.cos(V.pitch), math.sin(V.pitch)
		local dir = Vector3.new(math.sin(V.yaw) * cp, sp, math.cos(V.yaw) * cp)
		cam.CFrame = CFrame.lookAt(V.center + dir * V.dist, V.center)
	end
	table.insert(conns, RunService.RenderStepped:Connect(function(dt)
		if not holder.Parent then return end
		if not V.dragging and os.clock() - V.touched > 3 then V.yaw += dt * 0.5 end
		place()
	end))
	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			V.dragging = true
			V.touched = os.clock()
		end
	end)
	table.insert(conns, UIS.InputChanged:Connect(function(input)
		if not V.dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			V.yaw -= input.Delta.X * 0.011
			V.pitch = math.clamp(V.pitch + input.Delta.Y * 0.008, -1.25, 1.25)
			V.touched = os.clock()
		end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then V.dragging = false V.touched = os.clock() end
	end))
	holder.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			V.dist = math.clamp(V.dist * (1 - input.Position.Z * 0.09), V.baseDist * 0.4, V.baseDist * 1.6)
			V.touched = os.clock()
		end
	end)
	function V.destroy()
		for _, c in conns do c:Disconnect() end
		table.clear(conns)
		holder:Destroy()
	end
	V.holder = holder
	table.insert(viewers, V)
	return V
end

-- ================= gui shell =================
local gui = new("ScreenGui", { Name = "CosmeticsGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 41, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- the COSMETICS button: left side, right under the SHOP button (ShopClient puts SHOP at the vertical middle, 156 x 64)
local btn = new("TextButton", { Name = "CosmeticsButton", Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 76), Size = UDim2.fromOffset(156, 64), Visible = false }, gui)
do
	local st = stroke(btn, K.line, 1)
	box(btn, 0, 0, 3, 64, ESS)
	local ic = UI.EssenceIcon(btn, 36)
	ic.Position = UDim2.fromOffset(12, 14)
	lbl(btn, "COSMETICS", 19, 54, 8, 100, 28, K.text, F.H)
	lbl(btn, "SKINS  //  SHOP", 10, 55, 36, 100, 16, K.dim, F.MB)
	hot(btn, K.panel, K.panel2, st, K.line, ESS)
end

local dim = new("Frame", { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(6, 7, 9), BackgroundTransparency = 0.02, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 1 }, gui)
local stage = new("Frame", { Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, gui)
local uiScale = new("UIScale", {}, stage)
local function rescale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	uiScale.Scale = math.min(vp.X / 1920, vp.Y / 1080)
end
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

-- menu flag (blocks walking / abilities behind the UI, same flag the shop + card index use)
local menuWas, flagHolders = nil, 0
local function holdMenu()
	if flagHolders == 0 then menuWas = player:GetAttribute("LobbyMenuOpen") end
	flagHolders += 1
	player:SetAttribute("LobbyMenuOpen", true)
end
local function releaseMenu()
	flagHolders = math.max(0, flagHolders - 1)
	if flagHolders == 0 then player:SetAttribute("LobbyMenuOpen", menuWas) end
end

local shopOpen, lockerOpen = false, false
local shopRoot = new("Frame", { Name = "Shop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, stage)
local lockerRoot = new("Frame", { Name = "Locker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, stage)

-- ======================================================================================
-- shared: info panel with a viewer, used by the PREVIEW (shop) and the locker's right side
-- ======================================================================================
local function describe(item)
	if item.kind == "skin" then return item.desc or "" end
	local d = ("A %s paint job for the %s. Same stats, new look: every part of the gun is repainted."):format(string.lower(item.name), item.gunName or "gun")
	if item.glow then d ..= " The bright parts glow." end
	return d
end
local function kindLine(item)
	if item.kind == "skin" then return "PLAYER SKIN  //  " .. string.upper(item.sub or "") end
	return "GUN SKIN  //  FOR THE " .. string.upper(item.gunName or "")
end

-- ======================================================================================
-- SHOP
-- ======================================================================================
local shopTab = "skin"            -- skin | gun
local gunFilter = myWeapon()      -- a gun id, or "ALL"
local previewItem, armedId, armedAt, toastText, toastGood = nil, nil, 0, "", false
local refreshShop, openPreview, closePreview

lbl(shopRoot, "COSMETICS SHOP", 56, 64, 28, 700, 70, K.text, F.H)
box(shopRoot, 64, 130, 1792, 1, K.line)
local balBox = box(shopRoot, 1280, 40, 400, 52, K.panel, 0.1)
stroke(balBox, K.line, 1)
do
	local ic = UI.SoulIcon(balBox, 34)
	ic.Position = UDim2.fromOffset(12, 9)
	local ec = UI.EssenceIcon(balBox, 34)
	ec.Position = UDim2.fromOffset(212, 9)
end
local balSouls = lbl(balBox, "0", 28, 56, 0, 150, 52, K.text, F.H)
local balEss = lbl(balBox, "0", 28, 256, 0, 140, 52, ESS_PALE, F.H)
local shopClose = UI.CloseButton(shopRoot, "CLOSE", { Position = UDim2.fromOffset(1704, 45) })

local TABS = { { id = "skin", name = "PLAYER SKINS" }, { id = "gun", name = "GUN SKINS" } }
local tabBtns = {}
for i, t in TABS do
	local b = new("TextButton", { Text = t.name, TextSize = 24, FontFace = F.H, TextColor3 = K.dim, BackgroundTransparency = 1, AutoButtonColor = false,
		Position = UDim2.fromOffset(64 + (i - 1) * 250, 146), Size = UDim2.fromOffset(230, 52) }, shopRoot)
	local u = box(b, 0, 50, 230, 3, K.red)
	u.Visible = false
	tabBtns[t.id] = { b = b, u = u }
end

-- gun filter chips (GUN SKINS tab only)
local chipRow = new("Frame", { Position = UDim2.fromOffset(56, 206), Size = UDim2.fromOffset(1808, 46), BackgroundTransparency = 1, Visible = false }, shopRoot)
local chipBtns = {}
do
	local x = 8
	local list = { "ALL" }
	for _, g in GunSkins.GunOrder do table.insert(list, g) end
	for _, g in list do
		local name = g == "ALL" and "ALL GUNS" or GunSkins.GunNames[g]
		local w = math.max(70, #name * 11 + 28)
		local b = new("TextButton", { Text = name, TextSize = 16, FontFace = F.H, TextColor3 = K.dim, BackgroundColor3 = K.panel, AutoButtonColor = false, BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, 4), Size = UDim2.fromOffset(w, 38) }, chipRow)
		local st = stroke(b, K.line, 1)
		chipBtns[g] = { b = b, st = st }
		b.MouseButton1Click:Connect(function() gunFilter = g if refreshShop then refreshShop() end end)
		x += w + 8
	end
end

-- the two halves
local PX_ESS, PW_ESS, PX_SOUL, PW_SOUL = 56, 1130, 1210, 654
local panels = {}
local function makePanel(cur, x, w)
	local isEss = cur == "essence"
	local panel = box(shopRoot, x, 216, w, 820, K.panel, 0.04)
	stroke(panel, isEss and ESS or SOULC, isEss and 2 or 1.5, isEss and 0 or 0.35)
	local head = box(panel, 0, 0, w, 66, isEss and rgb(36, 20, 58) or rgb(16, 30, 44), 0)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(isEss and rgb(66, 34, 104) or rgb(24, 52, 78), isEss and rgb(26, 14, 42) or rgb(12, 24, 36)) }, head)
	local ic = isEss and UI.EssenceIcon(head, 44) or UI.SoulIcon(head, 44)
	ic.Position = UDim2.fromOffset(16, 11)
	lbl(head, isEss and "ESSENCE SHOP" or "SOULS SHOP", 34, 72, 0, 400, 66, isEss and ESS_PALE or K.soulPale, F.H)
	local tagW = isEss and 150 or 200
	chip(head, w - tagW - 18, 20, tagW, 26, isEss and "PREMIUM" or "EARN BY PLAYING", isEss and ESS or K.soul, isEss and rgb(20, 8, 40) or rgb(6, 24, 40), nil, 13)
	local scroll = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 74), Size = UDim2.fromOffset(w, 820 - 74), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = K.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, panel)
	new("UIGridLayout", { CellSize = isEss and UDim2.fromOffset(348, 348) or UDim2.fromOffset(300, 348), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingBottom = UDim.new(0, 20) }, scroll)
	panels[cur] = { panel = panel, scroll = scroll }
	return scroll
end
makePanel("essence", PX_ESS, PW_ESS)
makePanel("souls", PX_SOUL, PW_SOUL)

local function shopCard(scroll, item, order)
	local isOwned = owned(item)
	local isEss = item.currency == "essence"
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order }, scroll)
	local st = stroke(b, K.line, 1)
	hot(b, K.panel2, rgb(30, 33, 40), st, K.line, isEss and ESS or SOULC)
	local well = box(b, 1, 1, 10, 214, K.void, 0.1)
	well.Size = UDim2.new(1, -2, 0, 214)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(isEss and rgb(30, 18, 46) or rgb(16, 26, 38), rgb(8, 9, 12)) }, well)
	queueThumb(well, item)
	lbl(b, string.upper(item.name), 24, 14, 222, 300, 30, K.text, F.H)
	lbl(b, item.kind == "gun" and ("FOR THE  " .. string.upper(item.gunName or "")) or string.upper(item.sub or ""), 11, 15, 252, 300, 14, item.kind == "gun" and K.soulPale or K.dim, F.MB)
	if isOwned then
		local eq = isEquipped(item)
		local tag = chip(b, 14, 280, eq and 120 or 90, 24, eq and "EQUIPPED" or "OWNED", eq and rgb(14, 56, 36) or rgb(24, 70, 44), K.green, K.green, 12)
		tag.Position = UDim2.fromOffset(14, 284)
	else
		priceRow(b, 14, 286, item, false)
	end
	local view = lbl(b, "PREVIEW", 11, 0, 290, 334, 16, K.mute, F.MB, Enum.TextXAlignment.Right)
	view.Position = UDim2.new(1, -16, 0, 290)
	view.Size = UDim2.fromOffset(100, 16)
	view.AnchorPoint = Vector2.new(1, 0)
	view.TextXAlignment = Enum.TextXAlignment.Right
	b.MouseButton1Click:Connect(function() openPreview(item) end)
	return b
end

local function clearScroll(scroll)
	for _, c in scroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
end

local function shopItems(cur)
	local out = {}
	for _, it in Cat.Items(shopTab) do
		if it.currency == cur and (shopTab == "skin" or gunFilter == "ALL" or it.gun == gunFilter) then table.insert(out, it) end
	end
	return out
end

function refreshShop()
	balSouls.Text = commas(souls())
	balEss.Text = commas(essence())
	for id, t in tabBtns do
		t.b.TextColor3 = (id == shopTab) and K.text or K.dim
		t.u.Visible = id == shopTab
	end
	local gunTab = shopTab == "gun"
	chipRow.Visible = gunTab
	local top = gunTab and 262 or 216
	for _, p in panels do
		p.panel.Position = UDim2.new(p.panel.Position.X.Scale, p.panel.Position.X.Offset, 0, top)
		p.panel.Size = UDim2.fromOffset(p.panel.Size.X.Offset, 1036 - top)
		p.scroll.Size = UDim2.fromOffset(p.panel.Size.X.Offset, 1036 - top - 74)
	end
	for g, c in chipBtns do
		local on = g == gunFilter
		c.b.TextColor3 = on and K.text or K.dim
		c.b.BackgroundColor3 = on and K.panel3 or K.panel
		c.st.Color = on and K.red or K.line
		c.st.Thickness = on and 2 or 1
	end
	for cur, p in panels do
		local keep = p.scroll.CanvasPosition
		clearScroll(p.scroll)
		local list = shopItems(cur)
		for i, it in list do shopCard(p.scroll, it, i) end
		if #list == 0 then
			local e = lbl(p.scroll, "NOTHING HERE FOR THIS GUN YET", 18, 0, 0, 400, 40, K.mute, F.H, Enum.TextXAlignment.Left)
			e.LayoutOrder = 1
		end
		p.scroll.CanvasPosition = keep
	end
	if previewItem and openPreview then openPreview(previewItem, true) end
end

for _, t in TABS do
	tabBtns[t.id].b.MouseButton1Click:Connect(function()
		if shopTab == t.id then return end
		shopTab = t.id
		for _, p in panels do p.scroll.CanvasPosition = Vector2.zero end
		refreshShop()
	end)
end

-- ----- PREVIEW (big, drag to turn) -----
local pv = new("Frame", { Name = "Preview", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Active = true }, stage)
local pvDim = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 20 }, pv)
local pvPanel = box(pv, 150, 100, 1620, 880, K.panel, 0)
pvPanel.ZIndex = 21
stroke(pvPanel, K.line2, 1.5)
local pvViewer, pvBody
local function pvClear()
	if pvViewer then pvViewer.destroy() pvViewer = nil end
	if pvBody then pvBody:Destroy() pvBody = nil end
end

function openPreview(item, keepView)
	previewItem = item
	if not keepView then armedId, toastText = nil, "" end
	local reuse = keepView and pvViewer ~= nil
	if not reuse then pvClear() end
	pv.Visible = true
	if pvBody then pvBody:Destroy() end
	pvBody = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22 }, pvPanel)
	if not reuse then
		pvViewer = newViewer(pvPanel, 24, 24, 960, 832)
		pvViewer.holder.ZIndex = 22
		pvViewer.set(item)
	end
	local isEss = item.currency == "essence"
	local X = 1020
	lbl(pvBody, kindLine(item), 13, X, 34, 560, 18, isEss and ESS_PALE or K.redHi, F.MB).ZIndex = 23
	local nameL = lbl(pvBody, string.upper(item.name), 64, X, 56, 570, 76, K.text, F.H)
	nameL.ZIndex = 23
	local tier = chip(pvBody, X, 140, isEss and 110 or 150, 26, isEss and "PREMIUM" or "SOULS ITEM", isEss and ESS or K.soul, isEss and rgb(20, 8, 40) or rgb(6, 24, 40), nil, 12)
	tier.ZIndex = 23
	for _, c in tier:GetChildren() do if c:IsA("GuiObject") then c.ZIndex = 24 end end
	box(pvBody, X, 188, 576, 1, K.line).ZIndex = 23
	local d = lbl(pvBody, describe(item), 17, X, 204, 576, 140, K.text, F.B, nil, true)
	d.LineHeight = 1.18
	d.ZIndex = 23
	if item.kind == "gun" then
		local g = lbl(pvBody, "THIS SKIN GOES ON:  " .. string.upper(item.gunName or ""), 14, X, 330, 576, 22, K.soulPale, F.MB)
		g.ZIndex = 23
	end
	-- price + action
	local isOwned = owned(item)
	box(pvBody, X, 612, 576, 1, K.line).ZIndex = 23
	if isOwned then
		local eq = isEquipped(item)
		local t = box(pvBody, X, 640, 576, 60, rgb(18, 52, 34))
		stroke(t, K.green, 1)
		t.ZIndex = 23
		local tl = lbl(t, eq and ("EQUIPPED" .. (item.kind == "gun" and (" ON " .. string.upper(item.gunName or "")) or "")) or "YOU OWN THIS", 20, 0, 0, 576, 60, K.green, F.H, Enum.TextXAlignment.Center)
		tl.ZIndex = 24
		if not eq then
			local e = new("TextButton", { Text = item.kind == "gun" and ("EQUIP ON " .. string.upper(item.gunName or "")) or "EQUIP", TextSize = 24, FontFace = F.H, TextColor3 = K.text, BackgroundColor3 = K.red,
				AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(X, 716), Size = UDim2.fromOffset(576, 70), ZIndex = 23 }, pvBody)
			hot(e, K.red, K.redHi, nil)
			e.MouseButton1Click:Connect(function()
				e.Text = "..."
				local ok, res, msg = pcall(function() return EquipR:InvokeServer(item.kind, item.id, item.gun) end)
				toastText, toastGood = (ok and msg) or "Could not reach the server.", ok and res == true
				refreshShop()
			end)
		end
	else
		priceRow(pvBody, X, 628, item, true)
		local have = balance(item.currency)
		local can = have >= item.amount
		local curName = item.currency == "essence" and "ESSENCE" or "SOULS"
		local line = can and ("YOU HAVE " .. commas(have) .. " " .. curName) or ("YOU NEED " .. commas(item.amount - have) .. " MORE " .. curName)
		lbl(pvBody, line, 12, X, 676, 400, 16, can and K.dim or K.redHi, F.MB).ZIndex = 23
		local armed = armedId == item.id and os.clock() - armedAt < 3
		local b = new("TextButton", { Text = armed and "CONFIRM PURCHASE" or "BUY", TextSize = 26, FontFace = F.H, TextColor3 = can and K.text or K.mute,
			BackgroundColor3 = can and (armed and K.redHi or K.red) or K.panel3, AutoButtonColor = false, BorderSizePixel = 0,
			Position = UDim2.fromOffset(X, 704), Size = UDim2.fromOffset(576, 76), ZIndex = 23 }, pvBody)
		if can then hot(b, armed and K.redHi or K.red, K.redHi, nil) end
		b.MouseButton1Click:Connect(function()
			if not can then
				toastText, toastGood = item.currency == "essence" and "Not enough essence." or "Not enough souls. Win matches to earn more.", false
				openPreview(item, true)
				return
			end
			if armedId ~= item.id or os.clock() - armedAt >= 3 then
				armedId, armedAt = item.id, os.clock()
				openPreview(item, true)
				task.delay(3.05, function() if armedId == item.id and os.clock() - armedAt >= 3 then armedId = nil if previewItem == item and pv.Visible then openPreview(item, true) end end end)
				return
			end
			armedId = nil
			b.Text = "..."
			local ok, res, msg = pcall(function() return BuyR:InvokeServer(item.kind, item.id) end)
			toastText, toastGood = (ok and msg) or (ok and tostring(res)) or "Could not reach the server.", ok and res == true
			refreshShop()
		end)
	end
	if toastText ~= "" then
		local t = lbl(pvBody, toastText, 13, X, 800, 576, 20, toastGood and K.green or K.redHi, F.MB, Enum.TextXAlignment.Center)
		t.ZIndex = 23
	end
	local close = UI.CloseButton(pvBody, "BACK", { Position = UDim2.fromOffset(1620 - 152 - 24, 24), ZIndex = 24 })
	close.MouseButton1Click:Connect(function() closePreview() end)
end

function closePreview()
	if not pv.Visible then return end
	pv.Visible = false
	previewItem = nil
	pvClear()
end
pvDim.MouseButton1Click:Connect(closePreview)

-- ======================================================================================
-- LOCKER
-- ======================================================================================
local lockTab = "skin"
local selectedLock = nil -- { kind, id, gun? }  (id "STOCK" = the plain gun)
local lockViewer, lockInfo
local refreshLocker

lbl(lockerRoot, "COSMETICS", 56, 64, 28, 700, 70, K.text, F.H)
box(lockerRoot, 64, 130, 1792, 1, K.line)
local lockClose = UI.CloseButton(lockerRoot, "CLOSE", { Position = UDim2.fromOffset(1704, 45) })
local lockTabBtns = {}
for i, t in TABS do
	local b = new("TextButton", { Text = t.name, TextSize = 24, FontFace = F.H, TextColor3 = K.dim, BackgroundTransparency = 1, AutoButtonColor = false,
		Position = UDim2.fromOffset(64 + (i - 1) * 250, 146), Size = UDim2.fromOffset(230, 52) }, lockerRoot)
	local u = box(b, 0, 50, 230, 3, K.red)
	u.Visible = false
	lockTabBtns[t.id] = { b = b, u = u }
end
local shopLink = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(1260, 148), Size = UDim2.fromOffset(300, 46) }, lockerRoot)
do
	local st = stroke(shopLink, ESS, 1.5)
	local ic = UI.EssenceIcon(shopLink, 30)
	ic.Position = UDim2.fromOffset(10, 8)
	lbl(shopLink, "GET MORE IN THE SHOP", 15, 50, 0, 245, 46, K.text, F.H)
	hot(shopLink, K.panel, K.panel2, st, ESS, ESS_PALE)
end

local lockGrid = new("ScrollingFrame", { Position = UDim2.fromOffset(56, 214), Size = UDim2.fromOffset(1090, 826), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
	ScrollBarImageColor3 = K.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, lockerRoot)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingBottom = UDim.new(0, 24) }, lockGrid)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }, lockGrid)
local lockSide = new("Frame", { Position = UDim2.fromOffset(1170, 214), Size = UDim2.fromOffset(694, 826), BackgroundTransparency = 1 }, lockerRoot)

local function lockCard(parent, item, order, w)
	local on = selectedLock and selectedLock.kind == item.kind and selectedLock.id == item.id
	local eq = (item.id == "STOCK") and (equippedOn(item.gun) == nil) or ((item.id ~= "STOCK") and isEquipped(item))
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(w, 300) }, parent)
	local st = stroke(b, on and K.red or K.line, on and 2.5 or 1)
	hot(b, K.panel2, rgb(30, 33, 40), (not on) and st or nil, K.line, K.line2)
	local well = box(b, 1, 1, w - 2, 200, K.void, 0.1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(20, 24, 32), rgb(8, 9, 12)) }, well)
	queueThumb(well, item)
	lbl(b, string.upper(item.name), 22, 14, 206, w - 28, 28, K.text, F.H)
	local sub = item.kind == "gun" and ("FOR  " .. string.upper(item.gunName or "")) or string.upper(item.sub or "")
	lbl(b, sub, 11, 15, 234, w - 28, 14, item.kind == "gun" and K.soulPale or K.dim, F.MB)
	if eq then
		local txt = item.kind == "gun" and ("EQUIPPED ON " .. string.upper(item.gunName or "")) or "EQUIPPED"
		local cw = math.max(100, #txt * 9 + 22)
		chip(b, 14, 262, cw, 24, txt, rgb(14, 56, 36), K.green, K.green, 11)
	end
	b.MouseButton1Click:Connect(function()
		selectedLock = { kind = item.kind, id = item.id, gun = item.gun, item = item }
		refreshLocker()
	end)
	return b
end

local function lockSection(title, sub, order)
	local h = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, 44), LayoutOrder = order }, lockGrid)
	lbl(h, title, 28, 0, 0, 500, 44, K.text, F.H)
	if sub then lbl(h, sub, 12, 0, 0, 1020, 44, K.dim, F.MB, Enum.TextXAlignment.Right) end
	box(h, 0, 42, 1040, 1, K.line)
	return h
end
local function lockRow(order, items, w)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, 300), LayoutOrder = order, AutomaticSize = Enum.AutomaticSize.Y }, lockGrid)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(w, 300), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	for i, it in items do lockCard(row, it, i, w) end
	return row
end

local function lockSideBody(item)
	if lockInfo then lockInfo:Destroy() lockInfo = nil end
	if not item then return end
	lockInfo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, lockSide)
	local isStock = item.id == "STOCK"
	local eq = isStock and (equippedOn(item.gun) == nil) or ((not isStock) and isEquipped(item))
	lbl(lockInfo, (item.kind == "gun" and ("GUN SKIN  //  FOR THE " .. string.upper(item.gunName or "")) or ("PLAYER SKIN  //  " .. string.upper(item.sub or ""))), 12, 4, 568, 680, 16, K.redHi, F.MB)
	lbl(lockInfo, string.upper(item.name), 46, 2, 586, 690, 54, K.text, F.H)
	local desc = isStock and ("The plain " .. (item.gunName or "gun") .. ", no paint.") or describe(item)
	local d = lbl(lockInfo, desc, 15, 4, 642, 690, 56, K.dim, F.B, nil, true)
	d.LineHeight = 1.15
	if item.kind == "gun" then lbl(lockInfo, "GOES ON:  " .. string.upper(item.gunName or ""), 13, 4, 700, 690, 18, K.soulPale, F.MB) end
	local label, action
	if item.kind == "skin" then
		label = eq and "EQUIPPED" or "EQUIP"
		action = function() return EquipR:InvokeServer("skin", item.id) end
	elseif isStock then
		label = eq and "ON STOCK" or ("BACK TO STOCK " .. string.upper(item.gunName or ""))
		action = function() return EquipR:InvokeServer("gun", "", item.gun) end
	else
		label = eq and ("EQUIPPED ON " .. string.upper(item.gunName or "")) or ("EQUIP ON " .. string.upper(item.gunName or ""))
		action = function() return EquipR:InvokeServer("gun", item.id, item.gun) end
	end
	local b = new("TextButton", { Text = label, TextSize = 24, FontFace = F.H, TextColor3 = eq and K.green or K.text, BackgroundColor3 = eq and rgb(18, 52, 34) or K.red, AutoButtonColor = false,
		BorderSizePixel = 0, Position = UDim2.fromOffset(2, 740), Size = UDim2.fromOffset(690, 70) }, lockInfo)
	if eq then stroke(b, K.green, 1) else hot(b, K.red, K.redHi, nil) end
	b.MouseButton1Click:Connect(function()
		if eq then return end
		b.Text = "..."
		local ok, res = pcall(action)
		if not ok or res ~= true then b.Text = "COULD NOT EQUIP" end
		-- the server's attribute change refreshes the screen
	end)
end

function refreshLocker()
	for id, t in lockTabBtns do
		t.b.TextColor3 = (id == lockTab) and K.text or K.dim
		t.u.Visible = id == lockTab
	end
	local keep = lockGrid.CanvasPosition
	for _, c in lockGrid:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	if lockViewer then lockViewer.destroy() lockViewer = nil end
	-- ----- build the lists -----
	local items = {}
	if lockTab == "skin" then
		for _, id in Cat.OwnedSkins(player) do
			local s = Skins.Get(id)
			table.insert(items, { kind = "skin", id = id, name = s.name, sub = s.sub, desc = s.desc })
		end
		lockSection("YOUR PLAYER SKINS", ("%d OWNED"):format(#items), 1)
		lockRow(2, items, 328)
		if not (selectedLock and selectedLock.kind == "skin") then
			local worn = wornSkin()
			for _, it in items do if it.id == worn then selectedLock = { kind = "skin", id = it.id, item = it } end end
		else
			local found = false
			for _, it in items do if it.id == selectedLock.id then selectedLock.item = it found = true end end
			if not found then selectedLock = nil end
		end
	else
		local ownedSet = {}
		for _, id in Cat.OwnedGunSkins(player) do ownedSet[id] = true end
		local order, any = 1, false
		for _, g in GunSkins.GunOrder do
			local mine = {}
			for _, s in GunSkins.ForGun(g) do
				if ownedSet[s.id] then table.insert(mine, { kind = "gun", id = s.id, name = s.name, sub = s.sub, gun = g, gunName = s.gunName, glow = s.glow }) end
			end
			if #mine > 0 then
				any = true
				local eqId = equippedOn(g)
				local eqName = eqId and GunSkins.ById[eqId] and GunSkins.ById[eqId].name or "STOCK"
				lockSection(GunSkins.GunNames[g], "ON THIS GUN NOW:  " .. eqName, order)
				order += 1
				table.insert(mine, 1, { kind = "gun", id = "STOCK", name = "STOCK", sub = GunSkins.GunNames[g], gun = g, gunName = GunSkins.GunNames[g] })
				lockRow(order, mine, 328)
				order += 1
			end
		end
		if not any then
			local e = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, 200), LayoutOrder = 1 }, lockGrid)
			lbl(e, "YOU DON'T OWN ANY GUN SKINS YET", 34, 0, 20, 1040, 50, K.text, F.H)
			lbl(e, "Gun skins are bought in the COSMETICS SHOP with essence or souls. Each skin belongs to one gun and shows up here once you own it.", 16, 0, 78, 900, 60, K.dim, F.B, nil, true)
			selectedLock = nil
		else
			if not (selectedLock and selectedLock.kind == "gun") then
				-- default: the gun you play with, or the first one you own skins for
				local w = myWeapon()
				local pick
				for _, g in { w, table.unpack(GunSkins.GunOrder) } do
					for _, s in GunSkins.ForGun(g) do
						if ownedSet[s.id] and not pick then pick = { kind = "gun", id = equippedOn(g) or s.id, gun = g, item = { kind = "gun", id = equippedOn(g) or s.id, name = GunSkins.ById[equippedOn(g) or s.id].name, sub = s.sub, gun = g, gunName = s.gunName, glow = s.glow } } end
					end
				end
				selectedLock = pick
			end
		end
	end
	lockGrid.CanvasPosition = keep
	-- ----- the viewer + info on the right -----
	local sel = selectedLock and selectedLock.item
	if sel and sel.kind ~= lockTab then sel = nil end
	if sel then
		lockViewer = newViewer(lockerRoot, 1170, 214, 694, 540)
		lockViewer.set(sel)
	end
	lockSideBody(sel)
end

for _, t in TABS do
	lockTabBtns[t.id].b.MouseButton1Click:Connect(function()
		if lockTab == t.id then return end
		lockTab = t.id
		selectedLock = nil
		lockGrid.CanvasPosition = Vector2.zero
		refreshLocker()
	end)
end

-- ======================================================================================
-- open / close
-- ======================================================================================
local function updateButton()
	local show = not shopOpen and not lockerOpen and player:GetAttribute("StarterDone") == true and player:GetAttribute("LobbyMenuOpen") ~= true
	btn.Visible = show
end

local function openShop()
	if shopOpen or lockerOpen or player:GetAttribute("StarterDone") ~= true then return end
	shopOpen = true
	holdMenu()
	dim.Visible, stage.Visible = true, true
	shopRoot.Visible, lockerRoot.Visible = true, false
	armedId, toastText, previewItem = nil, "", nil
	pv.Visible = false
	refreshShop()
	updateButton()
end
local function closeShop()
	if not shopOpen then return end
	closePreview()
	shopOpen = false
	dim.Visible, stage.Visible, shopRoot.Visible = false, false, false
	releaseMenu()
	updateButton()
end

local function openLocker()
	if shopOpen or lockerOpen then return end
	lockerOpen = true
	holdMenu()
	dim.Visible, stage.Visible = true, true
	lockerRoot.Visible, shopRoot.Visible = true, false
	refreshLocker()
	updateButton()
end
local function closeLocker()
	if not lockerOpen then return end
	lockerOpen = false
	if lockViewer then lockViewer.destroy() lockViewer = nil end
	dim.Visible, stage.Visible, lockerRoot.Visible = false, false, false
	releaseMenu()
	updateButton()
end

btn.MouseButton1Click:Connect(openShop)
shopClose.MouseButton1Click:Connect(closeShop)
lockClose.MouseButton1Click:Connect(closeLocker)
shopLink.MouseButton1Click:Connect(function()
	closeLocker()
	task.defer(openShop)
end)

-- the hanger button next to PLAY (and TAB) in LobbyClient sets this attribute
player:GetAttributeChangedSignal("CosmeticsOpen"):Connect(function()
	if not player:GetAttribute("CosmeticsOpen") then return end
	player:SetAttribute("CosmeticsOpen", nil)
	if lockerOpen then closeLocker() elseif not shopOpen then openLocker() end
end)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe or UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if pv.Visible then closePreview() elseif shopOpen then closeShop() elseif lockerOpen then closeLocker() end
	end
end)

-- keep everything fresh when money / ownership / equipment changes
local pending = false
local function softRefresh()
	if pending then return end
	pending = true
	task.delay(0.15, function()
		pending = false
		if shopOpen then refreshShop() elseif lockerOpen then refreshLocker() end
	end)
end
for _, a in { "Souls", "Essence", "Skin", "SkinsOwnedJson", "GunSkinsOwnedJson", "GunSkinsJson" } do
	player:GetAttributeChangedSignal(a):Connect(softRefresh)
end
player:GetAttributeChangedSignal("LobbyMenuOpen"):Connect(updateButton)
player:GetAttributeChangedSignal("StarterDone"):Connect(updateButton)
updateButton()
