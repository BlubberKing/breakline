-- CosmeticsClient v4 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in v5.10.
-- v5.16 (owner Nov 8):
--   * PLAYER SKINS are called COSTUMES everywhere (tabs, labels, the showcase picker). The shop preview of a costume says COLORWAY FOR <base costume>.
--   * gun skins say "<GUN> SKIN" (was "FOR THE <GUN>" on the cards and "GOES ON <GUN>" in the preview + locker).
--   * locker GUN SKINS: one small TAB per gun side by side (like the shop's gun row, with how many skins you own for it) - click a gun to see its
--     skins (STOCK + yours). Was: every gun stacked under each other.
--   * NEW POSES tab (shop + locker): the locker shows your poses on the left, the selected pose PLAYING on your costume and the 6-slot POSE WHEEL on
--     the right (click a slot to put the selected pose there, T opens the wheel in a match / the lobby). Shop: poses for souls / essence.
--   * NEW TITLES tab (shop + locker): titles sit above your name in the lobby (and on your player card). Locker: EQUIP / REMOVE + SHOW ON MY PLAYER CARD.
--   * PLAYER CARD tab: ADD POSE under REPOSITION for a costume in a showcase slot (pick the pose it holds on your card); TITLE ON CARD switch.
-- v5.13 (owner Nov 7):
--   * BUG FIX - the card editor's corner squares (resize) and round handle (turn) only ever MOVED the item. The handles were found by doing maths
--     on the mouse position against the card's AbsolutePosition, and those two do not use the same screen origin (Roblox top bar inset), so a press
--     on a handle landed a few dozen pixels off and counted as a press on the item. Now every handle and every item on the card is a real (invisible)
--     button, so Roblox itself decides what was pressed, and a drag only uses how far the pointer MOVED (no absolute positions at all).
--   * REPOSITION button under every showcase slot: opens a big view of that item. Skins + gun skins: drag to turn them ANY way (like the shop
--     preview, just the model, no disc / pad under a skin). Power-up cards: drag to lean the card a little left / right / up / down
--     (PlayerCards.CARD_TILT). DONE (bottom middle) saves the angle; the item shows at that angle on your player card. RESET = straight, CANCEL.
-- v5.12 (owner Nov 7):
--   * PLAYER CARD tab = a card EDITOR: click a showcase item on your card, drag it to move it, drag a corner to resize, drag the round handle to turn it
--     (mouse wheel resizes too); RESET SPOT / RESET ALL. Saved with Equip("place", slot, { x, y, s, r }). The info on the card always sits on top.
--   * clicking a showcase slot shows three TABS under it (PLAYER SKINS / GUN SKINS / CARDS) instead of one long cramped list.
--   * SHOP: the open shop fills the screen; the other shop is a slim tab on the side (souls on the right while the essence shop is open, essence on the
--     left while the souls shop is open), click it to swap. The shop always opens on the ESSENCE SHOP.
--   * BUG FIX: turning a model in the preview and letting go no longer closes the preview.
--   * no more blinking: pictures are built once and cloned after that, and the locker viewer is kept between refreshes.
-- v5.11 (owner Nov 7):
--   * drag-to-turn really works now: the viewer used holder.InputBegan, but the info panel sat ON TOP of the viewer (so the click never reached it) and the
--     lobby's first-person camera could keep the mouse locked. Now a global click is hit-tested against the viewer and a Modal button frees the cursor.
--   * the COSMETICS button just says COSMETICS (the "SKINS // SHOP" line is gone); the made-up skin descriptions / taglines and the gun "paint job" text are gone.
--   * colourways: the LOCKER only lists the three base skins; the colourways you own are picked from a swatch row under the preview (ORIGINAL + editions).
--     The SHOP still sells every colourway as its own item.
--   * new PLAYER CARD tab in the locker (background + 3 showcase slots of your lobby player card) and a PLAYER CARDS tab in the shop (backgrounds to buy).
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
local PlayerCards = require(RS:WaitForChild("PlayerCards")) -- v5.11
local Poses = require(RS:WaitForChild("Poses"))   -- v5.16: POSES tab (shop + locker), ADD POSE on the player card
local Titles = require(RS:WaitForChild("Titles")) -- v5.16: TITLES tab (shop + locker)
local GuiService = game:GetService("GuiService")
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
	if item.kind == "banner" then return Cat.OwnsBanner(player, item.id) end
	if item.kind == "pose" then return Cat.OwnsPose(player, item.id) end   -- v5.16
	if item.kind == "title" then return Cat.OwnsTitle(player, item.id) end -- v5.16
	return Cat.OwnsGunSkin(player, item.id)
end
local function wornSkin() local s = player:GetAttribute("Skin"); return Skins.Is(s) and s or Skins.Default end
local function equippedOn(gun) return GunSkins.Equipped(player, gun) end
local function wheelSlotOf(id) -- v5.16: the pose-wheel slot a pose sits in (or nil)
	for i, v in Poses.Wheel(player) do if v == id then return i end end
	return nil
end
local function isEquipped(item)
	if item.kind == "skin" then return wornSkin() == item.id end
	if item.kind == "banner" then return PlayerCards.Read(player).bg == item.id end
	if item.kind == "pose" then return wheelSlotOf(item.id) ~= nil end              -- v5.16: "equipped" = on the wheel
	if item.kind == "title" then return player:GetAttribute("Title") == item.id end -- v5.16
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
local figOf = setmetatable({}, { __mode = "k" }) -- v5.16: model -> posed figure (the viewer keeps an animated pose playing)
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
local function addFigure(model, skinId, poseId)
	local ok, fig = pcall(Skins.NewFigure, model, skinId, { static = true, pose = poseId }) -- v5.16: + a pose (it plays in the viewer)
	if ok and fig then pcall(fig.Update, fig, 0, 0) end
	if ok and fig and poseId then figOf[model] = fig end
	-- a dark disc under the feet
	local d = new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 6, 6), Color = rgb(20, 22, 28),
		Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.rad(90)) }, model)
	new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 6.5, 6.5), Color = K.red,
		Material = Enum.Material.Neon, Transparency = 0.25, CFrame = CFrame.new(0, -0.2, 0) * CFrame.Angles(0, 0, math.rad(90)) }, model)
	return d
end

-- a small still picture (cards): figure or gun fitted into the frame, never cropped
-- v5.12: every figure / gun picture is built ONCE (a template) and CLONED after that. The pages are re-drawn after every click (equip, buy, a new
-- background ...), and before this every model was rebuilt one per frame, so all the models on screen blinked out and back in. Now a picture that
-- was built before is cloned straight into the new card in the same frame: nothing blinks.
local thumbTpl, thumbOrder = {}, {}
local THUMB_MAX = 140
local function thumbKey(item)
	if item.kind == "banner" then return "banner|" .. item.id end
	if item.kind == "title" then return "title|" .. item.id end
	if item.kind == "pose" then return "pose|" .. item.id .. "|" .. wornSkin() end -- v5.16: a pose is shown on the costume you wear
	if item.kind == "flex" then return ("flex|%s|%dx%d"):format(item.value, item.w or 0, item.h or 0) end
	return item.kind .. "|" .. tostring(item.id) .. "|" .. tostring(item.gun)
end
local function thumbTemplate(item)
	local key = thumbKey(item)
	local t = thumbTpl[key]
	if t then return t end
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 160), LightColor = rgb(255, 250, 244),
		LightDirection = Vector3.new(-0.5, -0.9, -0.4) })
	new("Camera", { FieldOfView = 20 }, vp)
	local model = new("Model", {}, vp)
	if item.kind == "skin" or item.kind == "pose" then
		local pd = item.kind == "pose" and Poses.ById[item.id] or nil
		local ok, fig = pcall(Skins.NewFigure, model, item.kind == "pose" and wornSkin() or item.id,
			{ static = true, pose = pd and item.id or nil, poseT = pd and (pd.still or 0) or nil })
		if ok and fig then pcall(fig.Update, fig, 0, 0) end
		t = { vp = vp, dir = Vector3.new(0.28, 0.1, 1), opts = { pad = 0.04, fov = 22 } }
	else
		addGunParts(model, item.gun, item.id ~= "STOCK" and item.id or nil)
		t = { vp = vp, dir = Vector3.new(1, 0.1, 0), opts = { pad = 0.1, fov = 16 } }
	end
	thumbTpl[key] = t
	table.insert(thumbOrder, key)
	while #thumbOrder > THUMB_MAX do
		local k = table.remove(thumbOrder, 1)
		local old = thumbTpl[k]
		thumbTpl[k] = nil
		if old then old.vp:Destroy() end
	end
	return t
end
local function thumb(parent, item)
	if item.kind == "banner" then -- v5.11: player card background (animated ones move here too)
		return PlayerCards.DrawBanner(parent, item.id, true)
	elseif item.kind == "title" then -- v5.16: a title = its text plate
		return Titles.Plate(parent, item.id, 64)
	elseif item.kind == "flex" then -- v5.11: a showcase item (skin / gun skin / card); PlayerCards keeps its own template cache
		return PlayerCards.ShowcaseItem(parent, item.value, item.w, item.h)
	end
	local t = thumbTemplate(item)
	local vp = t.vp:Clone()
	local cam = vp:FindFirstChildOfClass("Camera")
	local model = vp:FindFirstChildOfClass("Model")
	vp.Parent = parent
	UI.FitViewport(vp, cam, model, t.dir, t.opts)
	return vp
end

-- the FIRST time a picture is needed it is built in the background (one per frame, so opening a page never hitches);
-- every time after that it is cloned at once (v5.12)
local thumbJobs, thumbReady = {}, {}
task.spawn(function()
	while true do
		local job = table.remove(thumbJobs, 1)
		if job then
			if job.well.Parent then
				local ok = pcall(thumb, job.well, job.item)
				if ok then thumbReady[thumbKey(job.item)] = true end
			end
			task.wait()
		else
			task.wait(0.1)
		end
	end
end)
local function queueThumb(well, item)
	if item.kind == "banner" or item.kind == "title" or thumbReady[thumbKey(item)] then
		pcall(thumb, well, item)
		return
	end
	table.insert(thumbJobs, { well = well, item = item })
end

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
		-- v5.12: the new model is built first and swapped in, so the viewer never shows an empty frame
		local fresh = new("Model", {})
		V.kind = item.kind
		if item.kind == "skin" or item.kind == "pose" then
			addFigure(fresh, item.kind == "pose" and wornSkin() or item.id, item.kind == "pose" and item.id or nil) -- v5.16: a pose plays on your costume
			V.fig, V.figT0 = figOf[fresh], os.clock()
			V.yaw, V.pitch = 0.45, 0.1
		else
			V.fig = nil
			addGunParts(fresh, item.gun, item.id ~= "STOCK" and item.id or nil)
			V.yaw, V.pitch = math.pi / 2 + 0.25, 0.14
		end
		fresh.Parent = vp
		model:Destroy()
		model = fresh
		local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
		if ok and cf then
			V.center = cf.Position
			if item.kind ~= "gun" then V.center = Vector3.new(cf.Position.X, cf.Position.Y + 0.15, cf.Position.Z) end
			local r = size.Magnitude / 2
			V.baseDist = r / math.sin(math.rad(cam.FieldOfView / 2)) * (item.kind ~= "gun" and 1.05 or 1.02)
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
		if V.fig then pcall(V.fig.Update, V.fig, os.clock() - (V.figT0 or 0), dt) end -- v5.16: an animated pose keeps playing
		place()
	end))
	-- v5.11: hit-test every click ourselves (the info panel is layered over the viewer, so holder.InputBegan never fired) and turn by how far the
	-- pointer moved (Delta as a fallback while the mouse is locked)
	local function shown()
		local o = holder
		while o and o:IsA("GuiObject") do
			if not o.Visible then return false end
			o = o.Parent
		end
		return o ~= nil and (not o:IsA("ScreenGui") or o.Enabled)
	end
	local function pointer(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local inset = GuiService:GetGuiInset()
			return Vector2.new(input.Position.X, input.Position.Y) + inset
		end
		return UIS:GetMouseLocation()
	end
	local function over(pos)
		local ap, as = holder.AbsolutePosition, holder.AbsoluteSize
		return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
	end
	local lastPos
	table.insert(conns, UIS.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not holder.Parent or not shown() then return end
			local pos = pointer(input)
			if over(pos) then
				V.dragging = true
				V.touched = os.clock()
				lastPos = pos
			end
		end
	end))
	table.insert(conns, UIS.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if holder.Parent and shown() and over(UIS:GetMouseLocation()) then
				V.dist = math.clamp(V.dist * (1 - input.Position.Z * 0.09), V.baseDist * 0.4, V.baseDist * 1.6)
				V.touched = os.clock()
			end
			return
		end
		if not V.dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local pos = pointer(input)
			local d = lastPos and (pos - lastPos) or Vector2.zero
			lastPos = pos
			if d.Magnitude < 0.01 then d = Vector2.new(input.Delta.X, input.Delta.Y) end -- mouse locked: the position does not move, the delta does
			V.yaw -= d.X * 0.011
			V.pitch = math.clamp(V.pitch + d.Y * 0.008, -1.25, 1.25)
			V.touched = os.clock()
		end
	end))
	table.insert(conns, UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then V.dragging = false V.touched = os.clock() end
	end))
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
	lbl(btn, "COSMETICS", 21, 54, 0, 100, 64, K.text, F.H) -- v5.11: just the name (the "SKINS // SHOP" line was filler)
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
-- v5.11: a visible Modal button frees the mouse while a cosmetics screen is open (the lobby camera is first person, which can lock it)
local modalBtn = new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Visible = false }, gui)
local menuWas, flagHolders = nil, 0
local function holdMenu()
	if flagHolders == 0 then menuWas = player:GetAttribute("LobbyMenuOpen") end
	flagHolders += 1
	player:SetAttribute("LobbyMenuOpen", true)
	player:SetAttribute("CosmeticsShown", true) -- LobbyClient ignores ESC / TAB while this is set
	modalBtn.Visible = true
end
local function releaseMenu()
	flagHolders = math.max(0, flagHolders - 1)
	if flagHolders == 0 then
		player:SetAttribute("LobbyMenuOpen", menuWas)
		player:SetAttribute("CosmeticsShown", nil)
		modalBtn.Visible = false
	end
end

local shopOpen, lockerOpen = false, false
local shopRoot = new("Frame", { Name = "Shop", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, stage)
local lockerRoot = new("Frame", { Name = "Locker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, stage)

-- ======================================================================================
-- shared: info panel with a viewer, used by the PREVIEW (shop) and the locker's right side
-- ======================================================================================
-- v5.11: no descriptions any more (the owner: they read as AI). Only plain facts: what it is, what it goes on.
local function describe(_item) return "" end
local function baseName(id) local s = Skins.Get(id); return s.base and Skins.Get(s.base).name or s.name end
local function subLine(item)
	if item.kind == "skin" then
		local s = Skins.Get(item.id)
		return s.base and (baseName(item.id) .. " COLOURWAY") or "BASE COSTUME"
	elseif item.kind == "banner" then
		return item.anim and "PLAYER CARD  //  ANIMATED" or "PLAYER CARD"
	elseif item.kind == "pose" then -- v5.16
		return item.anim and "POSE  //  ANIMATED" or "POSE  //  STILL"
	elseif item.kind == "title" then
		return "TITLE"
	end
	return string.upper(item.gunName or "") .. " SKIN" -- v5.16: "<GUN> SKIN" (was "FOR THE <GUN>")
end
local function kindLine(item)
	if item.kind == "skin" then return "COSTUME  //  " .. subLine(item) end -- v5.16: player skins are called COSTUMES
	if item.kind == "banner" then return "PLAYER CARD BACKGROUND" .. (item.anim and "  //  ANIMATED" or "") end
	if item.kind == "pose" then return subLine(item) end
	if item.kind == "title" then return "TITLE  //  SHOWN ABOVE YOUR NAME" end
	return "GUN SKIN"
end

-- ======================================================================================
-- SHOP
-- ======================================================================================
local shopTab = "skin"            -- skin | gun | banner (v5.11)
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

-- v5.16: PLAYER SKINS -> COSTUMES, + POSES + TITLES (shop and locker)
local TABS = { { id = "skin", name = "COSTUMES" }, { id = "gun", name = "GUN SKINS" }, { id = "pose", name = "POSES" }, { id = "title", name = "TITLES" },
	{ id = "banner", name = "PLAYER CARDS" } }
local LOCK_TABS = { { id = "skin", name = "COSTUMES" }, { id = "gun", name = "GUN SKINS" }, { id = "pose", name = "POSES" }, { id = "title", name = "TITLES" },
	{ id = "card", name = "PLAYER CARD" } }
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

-- v5.12: the two shops. The OPEN one fills the screen; the other one is a slim tab on the side (the souls tab on the RIGHT while the essence shop is open,
-- the essence tab on the LEFT while the souls shop is open). Click the tab to swap. The shop always opens on the ESSENCE SHOP.
local SHOP_X, SHOP_W, SLIVER_W, SLIVER_GAP = 56, 1808, 92, 12
local PW_OPEN = SHOP_W - SLIVER_W - SLIVER_GAP -- 1704
local shopSide = "essence"
local panels, slivers = {}, {}
local function makeSliver(cur)
	local isEss = cur == "essence"
	local col = isEss and ESS or SOULC
	local b = new("TextButton", { Name = "Sliver_" .. cur, Text = "", AutoButtonColor = false, BackgroundColor3 = isEss and rgb(30, 16, 50) or rgb(12, 26, 40),
		BorderSizePixel = 0, Position = UDim2.fromOffset(0, 216), Size = UDim2.fromOffset(SLIVER_W, 820), Visible = false }, shopRoot)
	local st = stroke(b, col, 1.5, 0.25)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(isEss and rgb(66, 34, 104) or rgb(24, 52, 78), isEss and rgb(18, 10, 30) or rgb(8, 16, 24)) }, b)
	local ic = isEss and UI.EssenceIcon(b, 46) or UI.SoulIcon(b, 46)
	ic.AnchorPoint = Vector2.new(0.5, 0)
	ic.Position = UDim2.new(0.5, 0, 0, 22)
	-- the name runs down the tab
	local name = new("TextLabel", { Name = "Name", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(520, 60), Rotation = 90, Text = isEss and "ESSENCE SHOP" or "SOULS SHOP", TextSize = 40, FontFace = F.H,
		TextColor3 = isEss and ESS_PALE or K.soulPale }, b)
	local chev = lbl(b, isEss and "<" or ">", 30, 0, 0, SLIVER_W, 40, col, F.H, Enum.TextXAlignment.Center)
	chev.AnchorPoint = Vector2.new(0, 1)
	chev.Position = UDim2.new(0, 0, 1, -18)
	b.MouseEnter:Connect(function()
		tween(st, FAST, { Transparency = 0, Thickness = 2.5 })
		tween(name, FAST, { TextColor3 = K.text })
	end)
	b.MouseLeave:Connect(function()
		tween(st, FAST, { Transparency = 0.25, Thickness = 1.5 })
		tween(name, FAST, { TextColor3 = isEss and ESS_PALE or K.soulPale })
	end)
	slivers[cur] = b
	return b
end
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
	new("UIGridLayout", { CellSize = UDim2.fromOffset(316, 348), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, scroll) -- 5 per row
	new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 18), PaddingBottom = UDim.new(0, 20) }, scroll)
	panels[cur] = { panel = panel, scroll = scroll }
	return scroll
end
makePanel("essence", SHOP_X, PW_OPEN)
makePanel("souls", SHOP_X + SLIVER_W + SLIVER_GAP, PW_OPEN)
makeSliver("essence")
makeSliver("souls")

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
	lbl(b, subLine(item), 11, 15, 252, 300, 14, item.kind == "gun" and K.soulPale or K.dim, F.MB)
	if isOwned then
		local eq = isEquipped(item)
		local tag = chip(b, 14, 280, eq and 120 or 90, 24, eq and "EQUIPPED" or "OWNED", eq and rgb(14, 56, 36) or rgb(24, 70, 44), K.green, K.green, 12)
		tag.Position = UDim2.fromOffset(14, 284)
	else
		priceRow(b, 14, 286, item, false)
	end
	b.MouseButton1Click:Connect(function() openPreview(item) end)
	return b
end

local function clearScroll(scroll)
	for _, c in scroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
end

local function shopItems(cur)
	local out = {}
	for _, it in Cat.Items(shopTab) do
		if it.currency == cur and (shopTab ~= "gun" or gunFilter == "ALL" or it.gun == gunFilter) then table.insert(out, it) end
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
	-- v5.12: the open shop fills the screen, the other one is a tab on its side
	local other = shopSide == "essence" and "souls" or "essence"
	for cur, p in panels do
		local open = cur == shopSide
		local x = (shopSide == "essence") and SHOP_X or (SHOP_X + SLIVER_W + SLIVER_GAP)
		p.panel.Visible = open
		p.panel.Position = UDim2.fromOffset(x, top)
		p.panel.Size = UDim2.fromOffset(PW_OPEN, 1036 - top)
		p.scroll.Size = UDim2.fromOffset(PW_OPEN, 1036 - top - 74)
	end
	for cur, s in slivers do
		s.Visible = cur == other
		s.Position = UDim2.fromOffset((other == "souls") and (SHOP_X + PW_OPEN + SLIVER_GAP) or SHOP_X, top)
		s.Size = UDim2.fromOffset(SLIVER_W, 1036 - top)
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
		if cur ~= shopSide then continue end -- only the open shop is filled
		local list = shopItems(cur)
		for i, it in list do shopCard(p.scroll, it, i) end
		if #list == 0 then
			local e = lbl(p.scroll, shopTab == "gun" and "NOTHING HERE FOR THIS GUN YET" or "NOTHING HERE YET", 18, 0, 0, 400, 40, K.mute, F.H, Enum.TextXAlignment.Left)
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
-- v5.12: click the side tab = that shop opens over the screen (a short slide in from the tab's side)
for cur, s in slivers do
	s.MouseButton1Click:Connect(function()
		if shopSide == cur then return end
		shopSide = cur
		panels[cur].scroll.CanvasPosition = Vector2.zero
		refreshShop()
		local p = panels[cur].panel
		local goal = p.Position
		p.Position = goal + UDim2.fromOffset(cur == "souls" and 60 or -60, 0)
		tween(p, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = goal })
	end)
end

-- ----- PREVIEW (big, drag to turn) -----
local pv = new("Frame", { Name = "Preview", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Active = true }, stage)
local pvDim = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 20 }, pv)
local pvPanel = box(pv, 150, 100, 1620, 880, K.panel, 0)
pvPanel.ZIndex = 21
pvPanel.Active = true -- v5.12: clicks on the panel (the viewer, the info) never reach the dim backdrop behind it
stroke(pvPanel, K.line2, 1.5)
local pvViewer, pvBody, pvFlat
local function pvClear()
	if pvViewer then pvViewer.destroy() pvViewer = nil end
	if pvBody then pvBody:Destroy() pvBody = nil end
	if pvFlat then pvFlat:Destroy() pvFlat = nil end
end
-- your own card data (used to preview a background on YOUR card)
local function myCardData(bg)
	local cd = PlayerCards.Read(player)
	if bg then cd = { bg = bg, show = cd.show, pos = cd.pos, poses = cd.poses, showTitle = cd.showTitle } end
	return { userId = player.UserId, name = player.DisplayName, username = player.Name, level = player:GetAttribute("Level"), card = cd,
		title = player:GetAttribute("Title") } -- v5.16: + the title
end
-- v5.16: a nameplate mock-up (title above LV + your name) for the TITLE preview / locker
local function titlePreview(parent, w, h, titleId)
	local f = box(parent, 0, 0, w, h, rgb(8, 9, 12), 0)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(24, 28, 38), rgb(6, 7, 10)) }, f)
	stroke(f, K.line, 1)
	local t = Titles.ById[titleId]
	local col = t and t.color or K.mute
	local tl = lbl(f, t and t.text or "NO TITLE", 40, 0, h / 2 - 66, w, 48, col, F.H, Enum.TextXAlignment.Center)
	new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.3 }, tl)
	local row = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, h / 2 - 12), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 56),
		BackgroundTransparency = 1 }, f)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local chipF = new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), BackgroundColor3 = K.void, BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = 1 }, row)
	stroke(chipF, K.red, 2)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, chipF)
	new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), Text = "LV " .. tostring(player:GetAttribute("Level") or 1),
		TextSize = 24, FontFace = F.MB, TextColor3 = K.text }, chipF)
	local nm = new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 56), Text = string.upper(player.DisplayName),
		TextSize = 44, FontFace = F.H, TextColor3 = K.text, LayoutOrder = 2 }, row)
	new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.4 }, nm)
	lbl(f, "HOW IT LOOKS ABOVE YOUR HEAD IN THE LOBBY", 12, 0, h - 40, w, 18, K.mute, F.MB, Enum.TextXAlignment.Center)
	return f
end
-- v5.16: put a pose on the wheel (the first empty slot, else the last slot)
local function poseToWheel(id)
	local w = Poses.Wheel(player)
	local slot = nil
	for i = 1, Poses.WHEEL do if w[i] == "" then slot = i break end end
	slot = slot or Poses.WHEEL
	return EquipR:InvokeServer("wheel", slot, id)
end

function openPreview(item, keepView)
	previewItem = item
	if not keepView then armedId, toastText = nil, "" end
	local reuse = keepView and (pvViewer ~= nil or pvFlat ~= nil)
	if not reuse then pvClear() end
	pv.Visible = true
	if pvBody then pvBody:Destroy() end
	pvBody = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 22 }, pvPanel)
	if not reuse then
		if item.kind == "title" then
			-- v5.16: a title is shown the way it sits above your name
			pvFlat = titlePreview(pvPanel, 960, 832, item.id)
			pvFlat.Position = UDim2.fromOffset(24, 24)
			pvFlat.ZIndex = 22
			for _, d in pvFlat:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 23 end end
		elseif item.kind == "banner" then
			-- v5.11: a background is shown on YOUR player card, big
			pvFlat = box(pvPanel, 24, 24, 960, 832, rgb(8, 9, 12), 0)
			pvFlat.ZIndex = 22
			stroke(pvFlat, K.line, 1)
			local c = PlayerCards.Render(pvFlat, myCardData(item.id), 912)
			c.Position = UDim2.fromOffset(24, (832 - 912 * PlayerCards.H / PlayerCards.W) / 2)
		else
			pvViewer = newViewer(pvPanel, 24, 24, 960, 832)
			pvViewer.holder.ZIndex = 22
			pvViewer.set(item)
		end
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
	if describe(item) ~= "" then
		local d = lbl(pvBody, describe(item), 17, X, 204, 576, 140, K.text, F.B, nil, true)
		d.LineHeight = 1.18
		d.ZIndex = 23
	end
	if item.kind == "gun" then -- v5.16: "<GUN> SKIN" (was "GOES ON: <GUN>")
		local g = lbl(pvBody, string.upper(item.gunName or "") .. " SKIN", 16, X, 206, 576, 24, K.soulPale, F.MB)
		g.ZIndex = 23
	elseif item.kind == "skin" then -- v5.16: the empty space under the name says which costume this is a colourway of
		local sk = Skins.Get(item.id)
		local g = lbl(pvBody, sk.base and ("COLORWAY FOR  " .. string.upper(baseName(item.id))) or "BASE COSTUME", 16, X, 206, 576, 24, K.soulPale, F.MB)
		g.ZIndex = 23
	elseif item.kind == "pose" then
		local g = lbl(pvBody, "PRESS T IN A MATCH OR THE LOBBY TO OPEN YOUR POSE WHEEL", 13, X, 206, 576, 24, K.soulPale, F.MB)
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
		local eqText = item.kind == "pose" and ("ON YOUR WHEEL  //  SLOT " .. tostring(wheelSlotOf(item.id) or "")) or ("EQUIPPED" .. (item.kind == "gun" and (" ON " .. string.upper(item.gunName or "")) or ""))
		local tl = lbl(t, eq and eqText or "YOU OWN THIS", 20, 0, 0, 576, 60, K.green, F.H, Enum.TextXAlignment.Center)
		tl.ZIndex = 24
		if not eq then
			local e = new("TextButton", { Text = item.kind == "gun" and ("EQUIP ON " .. string.upper(item.gunName or "")) or (item.kind == "pose" and "PUT ON YOUR WHEEL" or "EQUIP"), TextSize = 24, FontFace = F.H, TextColor3 = K.text, BackgroundColor3 = K.red,
				AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(X, 716), Size = UDim2.fromOffset(576, 70), ZIndex = 23 }, pvBody)
			hot(e, K.red, K.redHi, nil)
			e.MouseButton1Click:Connect(function()
				e.Text = "..."
				local ok, res, msg = pcall(function()
					if item.kind == "pose" then return poseToWheel(item.id) end -- v5.16
					if item.kind == "title" then return EquipR:InvokeServer("title", item.id) end
					return EquipR:InvokeServer(item.kind == "banner" and "card" or item.kind, item.id, item.gun)
				end)
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
-- v5.12 BUG FIX: turning a model in the preview and letting go closed the preview. The press started on the viewer, the release landed on the
-- dim backdrop (a button) and counted as "click outside". Now the preview only closes when the press AND the release are both outside the panel
-- and nothing was being dragged.
local function overPanel()
	local m = UIS:GetMouseLocation()
	local ap, as = pvPanel.AbsolutePosition, pvPanel.AbsoluteSize
	return m.X >= ap.X and m.X <= ap.X + as.X and m.Y >= ap.Y and m.Y <= ap.Y + as.Y
end
local pvPressOutside = false
pvDim.MouseButton1Down:Connect(function()
	pvPressOutside = not overPanel() and not (pvViewer and pvViewer.dragging)
end)
pvDim.MouseButton1Click:Connect(function()
	local ok = pvPressOutside and not overPanel()
	pvPressOutside = false
	if ok then closePreview() end
end)

-- ======================================================================================
-- LOCKER
-- ======================================================================================
local lockTab = "skin"            -- skin | gun | card
local selectedLock = nil -- skin: { kind = "skin", base, variant }   gun: { kind = "gun", id, gun, item }  (id "STOCK" = the plain gun)
local cardSlot = nil     -- PLAYER CARD tab: the showcase slot being filled (1..3) or nil (= choosing a background)
local poseSlot = nil     -- v5.16 PLAYER CARD tab: the showcase slot whose COSTUME is getting a pose (ADD POSE), or nil
local lockGun = nil      -- v5.16 GUN SKINS tab: the gun whose skins are shown (one tab per gun, like the shop)
local selPose = nil      -- v5.16 POSES tab: the pose selected on the left (click a wheel slot on the right to put it there)
local selTitle = nil     -- v5.16 TITLES tab: the title selected on the left
local lockViewer, lockInfo
local refreshLocker
local closeLocker -- forward (a locked colourway / background jumps to the shop)
local lockMsg = ""
local pendingPreview = nil -- shop item to open right after the shop opens (from a locked colourway / background)

lbl(lockerRoot, "COSMETICS", 56, 64, 28, 700, 70, K.text, F.H)
box(lockerRoot, 64, 130, 1792, 1, K.line)
local lockClose = UI.CloseButton(lockerRoot, "CLOSE", { Position = UDim2.fromOffset(1704, 45) })
local lockTabBtns = {}
for i, t in LOCK_TABS do
	local b = new("TextButton", { Text = t.name, TextSize = 24, FontFace = F.H, TextColor3 = K.dim, BackgroundTransparency = 1, AutoButtonColor = false,
		Position = UDim2.fromOffset(64 + (i - 1) * 250, 146), Size = UDim2.fromOffset(230, 52) }, lockerRoot)
	local u = box(b, 0, 50, 230, 3, K.red)
	u.Visible = false
	lockTabBtns[t.id] = { b = b, u = u }
end
local shopLink = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(1556, 148), Size = UDim2.fromOffset(300, 46) }, lockerRoot) -- v5.16: further right (5 tabs now)
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

-- jump to the shop preview of something you do not own yet
local function showInShop(kind, id)
	local it = Cat.Find(kind, id)
	if not it then return end
	pendingPreview = it
	if closeLocker then closeLocker() end
	player:SetAttribute("CosmeticsOpen", "shop")
end

local function bigButton(parent, text, y, on, danger)
	local b = new("TextButton", { Text = text, TextSize = 24, FontFace = F.H, TextColor3 = on and K.green or K.text, BackgroundColor3 = on and rgb(18, 52, 34) or (danger and K.panel3 or K.red),
		AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(2, y), Size = UDim2.fromOffset(690, 70) }, parent)
	if on then stroke(b, K.green, 1) elseif danger then stroke(b, K.line2, 1) hot(b, K.panel3, K.panel2, nil) else hot(b, K.red, K.redHi, nil) end
	return b
end

local function lockCard(parent, item, order, w)
	local on, eq
	if item.kind == "skin" then
		on = selectedLock and selectedLock.kind == "skin" and selectedLock.base == item.base
		eq = Cat.BaseOf(wornSkin()) == item.base
	else
		on = selectedLock and selectedLock.kind == item.kind and selectedLock.id == item.id
		eq = (item.id == "STOCK") and (equippedOn(item.gun) == nil) or ((item.id ~= "STOCK") and isEquipped(item))
	end
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(w, 300) }, parent)
	local st = stroke(b, on and K.red or K.line, on and 2.5 or 1)
	hot(b, K.panel2, rgb(30, 33, 40), (not on) and st or nil, K.line, K.line2)
	local well = box(b, 1, 1, w - 2, 200, K.void, 0.1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(20, 24, 32), rgb(8, 9, 12)) }, well)
	queueThumb(well, item)
	lbl(b, string.upper(item.name), 22, 14, 206, w - 28, 28, K.text, F.H)
	local sub = item.kind == "gun" and (string.upper(item.gunName or "") .. " SKIN") or (item.sub or "") -- v5.16: "<GUN> SKIN"
	lbl(b, sub, 11, 15, 234, w - 28, 14, item.kind == "gun" and K.soulPale or K.dim, F.MB)
	if eq then
		local txt = item.kind == "gun" and ("EQUIPPED ON " .. string.upper(item.gunName or "")) or "EQUIPPED"
		local cw = math.max(100, #txt * 9 + 22)
		chip(b, 14, 262, cw, 24, txt, rgb(14, 56, 36), K.green, K.green, 11)
	end
	b.MouseButton1Click:Connect(function()
		if item.kind == "skin" then
			selectedLock = { kind = "skin", base = item.base, variant = item.id }
		else
			selectedLock = { kind = item.kind, id = item.id, gun = item.gun, item = item }
		end
		lockMsg = ""
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
local function lockRow(order, items, w, cardFn, hgt)
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, hgt or 300), LayoutOrder = order, AutomaticSize = Enum.AutomaticSize.Y }, lockGrid)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(w, hgt or 300), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	for i, it in items do (cardFn or lockCard)(row, it, i, w) end
	return row
end

-- ----- PLAYER SKINS: base skin + its colourways -----
local function skinSide(sel)
	lockInfo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, lockSide)
	local base, variant = sel.base, sel.variant
	local worn = wornSkin()
	local vs = Skins.Get(variant)
	lbl(lockInfo, string.upper(Skins.Get(base).name), 46, 2, 446, 690, 54, K.text, F.H)
	lbl(lockInfo, "COLOURWAY:  " .. (vs.base and vs.name or "ORIGINAL"), 13, 4, 500, 690, 18, K.redHi, F.MB)
	-- swatch row: ORIGINAL + every colourway of this skin (owned = pick it, not owned = see it in the shop)
	local list = { base }
	for _, id in Cat.Colourways(base) do table.insert(list, id) end
	local SWW = math.min(166, math.floor((690 - (#list - 1) * 8) / #list))
	for i, id in list do
		local s = Skins.Get(id)
		local own = Cat.OwnsSkin(player, id)
		local on = id == variant
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0,
			Position = UDim2.fromOffset(2 + (i - 1) * (SWW + 8), 530), Size = UDim2.fromOffset(SWW, 86) }, lockInfo)
		local st = stroke(b, on and K.red or K.line, on and 2.5 or 1)
		if not on then hot(b, K.panel2, rgb(30, 33, 40), st, K.line, K.line2) end
		local sw = box(b, 8, 8, SWW - 16, 34, s.card or K.panel3, own and 0 or 0.6)
		stroke(sw, Color3.new(1, 1, 1), 1, 0.75)
		if id == worn then chip(sw, SWW - 16 - 34, 7, 28, 20, "ON", rgb(14, 56, 36), K.green, nil, 10) end
		lbl(b, s.base and s.name or "ORIGINAL", 15, 8, 46, SWW - 16, 20, own and K.text or K.mute, F.H).TextTruncate = Enum.TextTruncate.AtEnd
		local info = own and "" or ((s.price and s.price.essence) and (commas(s.price.essence) .. " ESSENCE") or (s.price and s.price.souls and (commas(s.price.souls) .. " SOULS")) or "")
		lbl(b, own and "OWNED" or ("LOCKED  " .. info), 9, 8, 66, SWW - 16, 14, own and K.dim or K.mute, F.MB).TextTruncate = Enum.TextTruncate.AtEnd
		b.MouseButton1Click:Connect(function()
			if own then
				selectedLock.variant = id
				lockMsg = ""
				refreshLocker()
			else
				showInShop("skin", id)
			end
		end)
	end
	local eq = worn == variant
	local btn = bigButton(lockInfo, eq and "EQUIPPED" or "EQUIP", 740, eq)
	btn.MouseButton1Click:Connect(function()
		if eq then return end
		btn.Text = "..."
		local ok, res = pcall(function() return EquipR:InvokeServer("skin", variant) end)
		if not ok or res ~= true then btn.Text = "COULD NOT EQUIP" end
	end)
end

-- ----- GUN SKINS -----
local function gunSide(item)
	lockInfo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, lockSide)
	local isStock = item.id == "STOCK"
	local eq = isStock and (equippedOn(item.gun) == nil) or ((not isStock) and isEquipped(item))
	lbl(lockInfo, "GUN SKIN", 12, 4, 568, 680, 16, K.redHi, F.MB) -- v5.16 wording
	lbl(lockInfo, string.upper(item.name), 46, 2, 586, 690, 54, K.text, F.H)
	lbl(lockInfo, string.upper(item.gunName or "") .. " SKIN", 14, 4, 646, 690, 20, K.soulPale, F.MB)
	local label, action
	if isStock then
		label = eq and "ON STOCK" or ("BACK TO STOCK " .. string.upper(item.gunName or ""))
		action = function() return EquipR:InvokeServer("gun", "", item.gun) end
	else
		label = eq and ("EQUIPPED ON " .. string.upper(item.gunName or "")) or ("EQUIP ON " .. string.upper(item.gunName or ""))
		action = function() return EquipR:InvokeServer("gun", item.id, item.gun) end
	end
	local b = bigButton(lockInfo, label, 740, eq)
	b.MouseButton1Click:Connect(function()
		if eq then return end
		b.Text = "..."
		local ok, res = pcall(action)
		if not ok or res ~= true then b.Text = "COULD NOT EQUIP" end
	end)
end

-- ----- v5.16 POSES: your poses on the left, the selected pose playing on your costume + the 6-slot WHEEL on the right -----
local function poseCard(parent, id, order, w)
	local pd = Poses.ById[id]
	local slot = wheelSlotOf(id)
	local on = selPose == id
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(w, 270) }, parent)
	local st = stroke(b, on and K.red or K.line, on and 2.5 or 1)
	if not on then hot(b, K.panel2, rgb(30, 33, 40), st, K.line, K.line2) end
	local well = box(b, 1, 1, w - 2, 196, K.void, 0.1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(20, 24, 32), rgb(8, 9, 12)) }, well)
	queueThumb(well, { kind = "pose", id = id })
	lbl(b, pd.name, 22, 14, 202, w - 28, 28, K.text, F.H)
	lbl(b, pd.anim and "ANIMATED" or "STILL", 11, 15, 230, w - 28, 14, K.dim, F.MB)
	if slot then chip(b, w - 104, 228, 90, 22, "SLOT " .. slot, rgb(14, 56, 36), K.green, K.green, 11) end
	b.MouseButton1Click:Connect(function()
		selPose = id
		lockMsg = ""
		refreshLocker()
	end)
	return b
end
local function poseSide()
	lockInfo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, lockSide)
	local pd = selPose and Poses.ById[selPose]
	lbl(lockInfo, pd and pd.name or "POSES", 30, 2, 372, 450, 38, K.text, F.H)
	lbl(lockInfo, "POSE WHEEL  //  PRESS T IN A MATCH OR THE LOBBY", 11, 4, 408, 690, 16, K.redHi, F.MB)
	lbl(lockInfo, pd and ("CLICK A SLOT TO PUT " .. pd.name .. " THERE") or "PICK A POSE ON THE LEFT, THEN CLICK A SLOT", 11, 4, 424, 690, 16, K.dim, F.MB)
	-- the wheel (same layout as the in-game one: slot 1 at the top, clockwise)
	local wheel = Poses.Wheel(player)
	local WCX, WCY, WR, WD = 190, 622, 112, 92
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(WCX, WCY), Size = UDim2.fromOffset(WR * 2 + WD + 20, WR * 2 + WD + 20),
		BackgroundColor3 = rgb(10, 11, 15), BackgroundTransparency = 0.1, BorderSizePixel = 0 }, lockInfo)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	stroke(ring, K.line, 1)
	local mid = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(WCX, WCY), Size = UDim2.fromOffset(92, 92), BackgroundColor3 = K.panel,
		BorderSizePixel = 0 }, lockInfo)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, mid)
	stroke(mid, K.line2, 1)
	lbl(mid, "T", 36, 0, 12, 92, 42, K.text, F.H, Enum.TextXAlignment.Center)
	lbl(mid, "IN GAME", 9, 0, 56, 92, 12, K.dim, F.MB, Enum.TextXAlignment.Center)
	for i = 1, Poses.WHEEL do
		local a = math.rad(-90 + (i - 1) * 60)
		local id = wheel[i]
		local filled = id ~= ""
		local isSel = filled and id == selPose
		local b = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(WCX + math.cos(a) * WR, WCY + math.sin(a) * WR),
			Size = UDim2.fromOffset(WD, WD), BackgroundColor3 = isSel and rgb(40, 22, 26) or K.panel2, BorderSizePixel = 0 }, lockInfo)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
		local st = stroke(b, isSel and K.red or (filled and K.line2 or K.line), isSel and 2.5 or 1.2)
		hot(b, isSel and rgb(40, 22, 26) or K.panel2, rgb(36, 30, 36), st, isSel and K.red or (filled and K.line2 or K.line), K.red)
		local well = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(60, 54), BackgroundTransparency = 1,
			ClipsDescendants = true }, b)
		if filled then queueThumb(well, { kind = "pose", id = id }) end
		lbl(b, filled and Poses.ById[id].name or "EMPTY", 12, 6, 60, WD - 12, 16, filled and K.text or K.mute, F.H, Enum.TextXAlignment.Center).TextTruncate = Enum.TextTruncate.AtEnd
		local n = new("TextLabel", { BackgroundColor3 = isSel and K.red or K.panel3, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(a) * 44, 0.5, math.sin(a) * 44), Size = UDim2.fromOffset(20, 20), Text = tostring(i), TextSize = 12, FontFace = F.H, TextColor3 = K.text }, b)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, n)
		b.MouseButton1Click:Connect(function()
			if not selPose then lockMsg = "Pick a pose on the left first." refreshLocker() return end
			local ok, res, msg = pcall(function() return EquipR:InvokeServer("wheel", i, selPose) end)
			lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
			if lockMsg ~= "" then refreshLocker() end
		end)
	end
	-- take the selected pose off the wheel
	local slotNow = selPose and wheelSlotOf(selPose)
	local clr = new("TextButton", { Text = slotNow and ("TAKE OFF THE WHEEL  (SLOT " .. slotNow .. ")") or "NOT ON THE WHEEL", TextSize = 18, FontFace = F.H,
		TextColor3 = slotNow and K.text or K.mute, BackgroundColor3 = K.panel3, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(392, 700),
		Size = UDim2.fromOffset(300, 46), TextWrapped = true }, lockInfo)
	local cst = stroke(clr, K.line2, 1)
	if slotNow then
		hot(clr, K.panel3, K.panel2, cst, K.line2, K.redHi)
		clr.MouseButton1Click:Connect(function()
			local ok, res, msg = pcall(function() return EquipR:InvokeServer("wheel", slotNow, "") end)
			lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
			if lockMsg ~= "" then refreshLocker() end
		end)
	end
	-- right column: what the selected pose is + where it sits
	if pd then
		lbl(lockInfo, pd.anim and "ANIMATED POSE" or "STILL POSE", 12, 394, 476, 298, 16, K.dim, F.MB)
		lbl(lockInfo, slotNow and ("ON SLOT " .. slotNow) or "NOT ON THE WHEEL", 26, 392, 494, 300, 34, slotNow and K.green or K.mute, F.H)
		lbl(lockInfo, "MOVING OR PULLING OUT AN ITEM ENDS A POSE", 11, 394, 540, 298, 30, K.mute, F.MB, nil, true)
	end
	if lockMsg ~= "" then lbl(lockInfo, lockMsg, 13, 392, 756, 300, 36, K.redHi, F.MB, nil, true) end
end

-- ----- v5.16 TITLES: your titles on the left, how it looks over your name + EQUIP / REMOVE + the player-card switch on the right -----
local function titleCard(parent, id, order, w)
	local t = Titles.ById[id]
	local eq = player:GetAttribute("Title") == id
	local on = selTitle == id
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(w, 170) }, parent)
	local st = stroke(b, on and K.red or K.line, on and 2.5 or 1)
	if not on then hot(b, K.panel2, rgb(30, 33, 40), st, K.line, K.line2) end
	local well = box(b, 1, 1, w - 2, 110, K.void, 0.1)
	Titles.Plate(well, id, 52)
	lbl(b, string.upper(t.tier == "free" and "FREE" or t.tier == "souls" and "SOULS TITLE" or "PREMIUM TITLE"), 11, 15, 120, w - 28, 14, K.dim, F.MB)
	if eq then chip(b, 14, 138, 100, 22, "EQUIPPED", rgb(14, 56, 36), K.green, K.green, 11) end
	b.MouseButton1Click:Connect(function()
		selTitle = id
		lockMsg = ""
		refreshLocker()
	end)
	return b
end
local function titleSide()
	lockInfo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, lockSide)
	local prev = titlePreview(lockInfo, 694, 400, selTitle or player:GetAttribute("Title"))
	prev.Position = UDim2.fromOffset(0, 0)
	local cur = player:GetAttribute("Title") or ""
	local t = selTitle and Titles.ById[selTitle]
	lbl(lockInfo, t and t.text or "NO TITLE", 40, 2, 420, 690, 50, t and t.color or K.mute, F.H)
	-- show on the player card (on / off)
	local showT = PlayerCards.Read(player).showTitle ~= false
	local tg = new("TextButton", { Text = "SHOW ON MY PLAYER CARD:  " .. (showT and "ON" or "OFF"), TextSize = 18, FontFace = F.H, TextColor3 = showT and K.green or K.text,
		BackgroundColor3 = K.panel3, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(2, 560), Size = UDim2.fromOffset(690, 50) }, lockInfo)
	local tst = stroke(tg, showT and K.green or K.line2, 1)
	hot(tg, K.panel3, K.panel2, tst, showT and K.green or K.line2, K.redHi)
	tg.MouseButton1Click:Connect(function()
		local ok, res, msg = pcall(function() return EquipR:InvokeServer("cardtitle", not showT) end)
		lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
		if lockMsg ~= "" then refreshLocker() end
	end)
	if cur ~= "" then
		local rm = bigButton(lockInfo, "REMOVE TITLE", 660, false, true)
		rm.MouseButton1Click:Connect(function()
			rm.Text = "..."
			local ok, res = pcall(function() return EquipR:InvokeServer("title", "") end)
			if not ok or res ~= true then rm.Text = "COULD NOT REMOVE" end
		end)
	end
	if t then
		local eq = cur == selTitle
		local btn = bigButton(lockInfo, eq and "EQUIPPED" or "EQUIP", 740, eq)
		btn.MouseButton1Click:Connect(function()
			if eq then return end
			btn.Text = "..."
			local ok, res = pcall(function() return EquipR:InvokeServer("title", selTitle) end)
			if not ok or res ~= true then btn.Text = "COULD NOT EQUIP" end
		end)
	end
	if lockMsg ~= "" then lbl(lockInfo, lockMsg, 13, 2, 620, 690, 18, K.redHi, F.MB, Enum.TextXAlignment.Center) end
end

-- ----- PLAYER CARD: background + showcase + v5.12 free placement -----
local function ownedCardIds()
	local raw = player:GetAttribute("CardsJson")
	local out = {}
	local ok, t = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw or "{}")
	local Cards = require(RS:WaitForChild("Cards"))
	if ok and type(t) == "table" then
		for _, c in Cards.List do if (t[c.id] or 0) > 0 then table.insert(out, c.id) end end
	end
	if #out == 0 then for _, c in Cards.List do table.insert(out, c.id) end end -- everybody has the starter collection
	table.sort(out, function(a, b) return Cards.Sort(Cards.ById[a], Cards.ById[b]) end)
	return out
end

local function bannerCard(parent, id, order, w)
	local bd = PlayerCards.ById[id]
	local own = Cat.OwnsBanner(player, id)
	local eq = PlayerCards.Read(player).bg == id
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(w, 230) }, parent)
	local st = stroke(b, eq and K.green or K.line, eq and 2 or 1)
	if not eq then hot(b, K.panel2, rgb(30, 33, 40), st, K.line, K.line2) end
	local well = box(b, 1, 1, w - 2, 150, K.void, 0)
	well.ClipsDescendants = true
	queueThumb(well, { kind = "banner", id = id })
	if not own then box(well, 0, 0, w - 2, 150, Color3.new(0, 0, 0), 0.45).ZIndex = 5 end
	lbl(b, bd.name, 22, 14, 156, w - 28, 28, own and K.text or K.mute, F.H)
	local status = eq and "EQUIPPED" or (own and (bd.anim and "OWNED  //  ANIMATED" or "OWNED") or (bd.price.essence and (commas(bd.price.essence) .. " ESSENCE") or (commas(bd.price.souls) .. " SOULS")))
	lbl(b, status, 11, 15, 188, w - 28, 16, eq and K.green or (own and K.dim or (bd.price and bd.price.essence and ESS_PALE or K.soulPale)), F.MB)
	b.MouseButton1Click:Connect(function()
		if not own then showInShop("banner", id) return end
		if eq then return end
		local ok, res, msg = pcall(function() return EquipR:InvokeServer("card", id) end)
		lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
	end)
	return b
end

local editSel = nil -- v5.12: the showcase item selected ON the card (1..3) for moving / resizing / turning
local function flexCard(parent, value, order, w)
	local cur = PlayerCards.Read(player).show[cardSlot or 1]
	local on = cur == value
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(w, 250) }, parent)
	local st = stroke(b, on and K.green or K.line, on and 2 or 1)
	if not on then hot(b, K.panel2, rgb(30, 33, 40), st, K.line, K.line2) end
	local well = box(b, 1, 1, w - 2, 196, K.void, 0.1)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(20, 24, 32), rgb(8, 9, 12)) }, well)
	queueThumb(well, { kind = "flex", value = value, w = w - 2, h = 196 })
	local nm = lbl(b, PlayerCards.ItemName(value), 16, 12, 202, w - 24, 22, K.text, F.H)
	nm.TextTruncate = Enum.TextTruncate.AtEnd
	if on then lbl(b, "IN THIS SLOT", 10, 13, 226, w - 24, 14, K.green, F.MB) end
	b.MouseButton1Click:Connect(function()
		if on or not cardSlot then return end
		local slot = cardSlot
		local ok, res, msg = pcall(function() return EquipR:InvokeServer("show", slot, value) end)
		lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
		if ok and res == true then editSel = slot end -- select it on the card so it can be placed right away
	end)
	return b
end

-- ===== v5.12 CARD EDITOR: drag the showcase items around your card, resize them, turn them =====
-- Click an item ON the card to select it (red box): drag it = move, drag a corner = resize, drag the round handle above it = turn, mouse wheel = resize.
-- The info (avatar, name, level, @username) is always drawn on top of the items. Every change is sent to the server (Equip "place") when you let go;
-- until the server's copy comes back the card shows your local copy, so nothing jumps back.
local ED_W = 690
local editor = nil       -- { root, holder, card, items, overlay, selBox, key }
local localPos = {}      -- [slot] = placement the player just made (shown until the server echoes it)
local pendingPlace = {}  -- [slot] = placement waiting to be sent
local drag = nil         -- { mode = "move" | "size" | "turn", slot, start, place }
local refreshAfterDrag = false
local SNAP = 5           -- turning snaps to 0 / 45 / 90 ... within this many degrees

local function myCard()
	local d = myCardData()
	for i = 1, 3 do if localPos[i] then d.card.pos[i] = localPos[i] end end
	return d
end
-- v5.13: every item has an invisible hit button that follows it, and the selected item gets a red box + 4 corner buttons + a round turn button.
-- The handle buttons are NOT inside the turned box (their spots are turned here by hand), so what you see is exactly what you can press.
local function itemPoint(p, lx, ly) -- a point in the item's own (unturned) frame -> card coordinates
	local a = math.rad(p.r)
	local cs, sn = math.cos(a), math.sin(a)
	return Vector2.new(p.x + lx * cs - ly * sn, p.y + lx * sn + ly * cs)
end
local CORNERS = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }
local TURN_GAP = 34 -- the round handle sits this far above the top edge of the item (card pixels)
local function updateHandles()
	if not editor then return end
	for i, b in editor.hits do
		local o = editor.items[i]
		if o and o.place then
			b.Position = UDim2.fromOffset(o.place.x, o.place.y)
			b.Size = UDim2.fromOffset(PlayerCards.SW * o.place.s, PlayerCards.SH * o.place.s)
			b.Rotation = o.place.r
		end
	end
	local it = editSel and editor.items[editSel]
	local on = it ~= nil and it.place ~= nil
	editor.selBox.Visible = on
	editor.stem.Visible = on
	editor.turn.Visible = on
	for _, c in editor.corners do c.b.Visible = on end
	if not on then return end
	local p = it.place
	local hw, hh = PlayerCards.SW * p.s / 2, PlayerCards.SH * p.s / 2
	editor.selBox.Position = UDim2.fromOffset(p.x, p.y)
	editor.selBox.Size = UDim2.fromOffset(hw * 2, hh * 2)
	editor.selBox.Rotation = p.r
	for _, c in editor.corners do
		local q = itemPoint(p, c.c[1] * hw, c.c[2] * hh)
		c.b.Position = UDim2.fromOffset(q.X, q.Y)
		c.at = q
	end
	local sq = itemPoint(p, 0, -hh - TURN_GAP / 2)
	editor.stem.Position = UDim2.fromOffset(sq.X, sq.Y)
	editor.stem.Rotation = p.r
	local tq = itemPoint(p, 0, -hh - TURN_GAP)
	editor.turn.Position = UDim2.fromOffset(tq.X, tq.Y)
	editor.turnAt = tq
end
local function destroyEditor()
	if editor then editor.root:Destroy() editor = nil end
	drag = nil
end
local wireEditor -- v5.13: connects the editor's buttons (defined below, next to the drag code)
local repo = nil -- v5.13: the open REPOSITION view (or nil)
local function buildEditor()
	local d = myCard()
	local key = d.card.bg .. "|" .. table.concat(d.card.show, ",") .. "|" .. tostring(d.level) .. "|" .. tostring(d.name) .. "|" .. table.concat(d.card.poses or {}, ",")
		.. "|" .. tostring(d.title) .. "|" .. tostring(d.card.showTitle) -- v5.16
	if editor and editor.key == key and editor.root.Parent then
		-- same background + same items: only move them (no rebuild, so nothing blinks)
		for i, it in editor.items do it.apply(d.card.pos[i]) end
		updateHandles()
		return
	end
	local old = editor
	local root = new("Frame", { Name = "CardEditor", Size = UDim2.fromOffset(694, 220), BackgroundTransparency = 1, ZIndex = 3 }, lockSide)
	lbl(root, "YOUR CARD", 13, 4, 0, 690, 18, K.redHi, F.MB)
	local holder, card, items = PlayerCards.Render(root, d, ED_W)
	holder.Position = UDim2.fromOffset(2, 24)
	-- handles live outside the card's clipping, in the same native 840 x 236 coordinates
	local overlay = new("Frame", { Name = "EditOverlay", Size = UDim2.fromOffset(PlayerCards.W, PlayerCards.H), BackgroundTransparency = 1, ZIndex = 20 }, holder)
	new("UIScale", { Scale = ED_W / PlayerCards.W }, overlay)
	local function hitButton(name, z, size)
		return new("TextButton", { Name = name, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = size and UDim2.fromOffset(size, size) or UDim2.fromScale(1, 1), ZIndex = z, Selectable = false }, overlay)
	end
	-- v5.13: the whole card is a button (a press on an empty spot = deselect), every item has its own button on top of it (slot 3 on top),
	-- and the handles are buttons on top of everything. Roblox decides which one was pressed.
	local bg = hitButton("CardHit", 20)
	bg.AnchorPoint = Vector2.zero
	local hits = {}
	for i = 1, 3 do
		if items[i] then hits[i] = hitButton("ItemHit" .. i, 21 + i, 10) end
	end
	local selBox = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 26 }, overlay)
	stroke(selBox, K.red, 2.5)
	local stem = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, TURN_GAP - 10), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 26, Visible = false }, overlay)
	local corners = {}
	for ci, c in CORNERS do
		local b = hitButton("Corner" .. ci, 28, 28) -- 28 card pixels to press, a 16 px square to see
		local sq = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = K.text,
			BorderSizePixel = 0, ZIndex = 29 }, b)
		stroke(sq, K.red, 2)
		b.Visible = false
		corners[ci] = { b = b, c = c }
	end
	local turn = hitButton("Turn", 28, 32)
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = K.text,
		BorderSizePixel = 0, ZIndex = 29 }, turn)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	stroke(ring, K.red, 2)
	turn.Visible = false
	editor = { root = root, holder = holder, card = card, items = items, overlay = overlay, selBox = selBox, stem = stem, corners = corners, turn = turn,
		hits = hits, bg = bg, key = key, hover = {} }
	if old then old.root:Destroy() end
	wireEditor(editor)
	updateHandles()
end

local function slotKind(slot) return (PlayerCards.Parse(PlayerCards.Read(player).show[slot])) end
local function setPlace(slot, p)
	p = PlayerCards.CleanPlace(p, slot, slotKind(slot)) -- v5.13: the kind limits the REPOSITION angle (cards only lean a little)
	localPos[slot] = p
	local it = editor and editor.items[slot]
	if it then it.apply(p) end
	updateHandles()
	return p
end
local function commit(slot)
	if localPos[slot] then pendingPlace[slot] = localPos[slot] end
end
local function editorLive()
	return editor ~= nil and repo == nil and lockerOpen and lockTab == "card" and stage.Visible and lockerRoot.Visible and not pv.Visible
end
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
-- v5.13: only DIFFERENCES of the pointer position are used, so it does not matter which screen origin a number is measured from
local function screenPos(input)
	if input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y) end
	return UIS:GetMouseLocation()
end
local function startDrag(mode, slot, anchor, input)
	local it = editor and editor.items[slot]
	if not it or not it.place then return end
	-- anchor = the card point that was pressed (the handle / the item centre); from now on: card point = anchor + pointer movement / zoom
	drag = { mode = mode, slot = slot, anchor = anchor, s0 = screenPos(input), place = table.clone(it.place),
		touch = input.UserInputType == Enum.UserInputType.Touch }
end

wireEditor = function(ed)
	local function hover(o)
		o.MouseEnter:Connect(function() ed.hover[o] = true end)
		o.MouseLeave:Connect(function() ed.hover[o] = nil end)
	end
	hover(ed.bg)
	ed.bg.InputBegan:Connect(function(input) -- an empty spot of the card: deselect
		if not isPress(input) or not editorLive() or editor ~= ed then return end
		editSel = nil
		updateHandles()
	end)
	for i, b in ed.hits do
		hover(b)
		b.InputBegan:Connect(function(input) -- an item: select it + move it
			if not isPress(input) or not editorLive() or editor ~= ed then return end
			local it = ed.items[i]
			if not it or not it.place then return end
			editSel = i
			updateHandles()
			startDrag("move", i, Vector2.new(it.place.x, it.place.y), input)
		end)
	end
	for _, c in ed.corners do
		hover(c.b)
		c.b.InputBegan:Connect(function(input) -- a corner: resize
			if not isPress(input) or not editorLive() or editor ~= ed or not editSel or not c.at then return end
			startDrag("size", editSel, c.at, input)
		end)
	end
	hover(ed.turn)
	ed.turn.InputBegan:Connect(function(input) -- the round handle: turn
		if not isPress(input) or not editorLive() or editor ~= ed or not editSel or not ed.turnAt then return end
		startDrag("turn", editSel, ed.turnAt, input)
	end)
end

UIS.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if not editorLive() or not editSel or not editor.items[editSel] or next(editor.hover) == nil then return end
		local cur = table.clone(editor.items[editSel].place)
		cur.s = cur.s * (1 + input.Position.Z * 0.07)
		setPlace(editSel, cur)
		commit(editSel)
		return
	end
	if not drag or not editor then return end
	if drag.touch then
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
	elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local k = editor.card.AbsoluteSize.X / PlayerCards.W -- screen pixels per card pixel (all the UIScales included)
	if k <= 0 then return end
	local p = drag.anchor + (screenPos(input) - drag.s0) / k
	local s0 = drag.place
	local c = Vector2.new(s0.x, s0.y)
	local nxt = table.clone(s0)
	if drag.mode == "move" then
		local d = p - drag.anchor
		nxt.x, nxt.y = s0.x + d.X, s0.y + d.Y
	elseif drag.mode == "size" then
		local d0 = math.max(8, (drag.anchor - c).Magnitude)
		nxt.s = s0.s * (p - c).Magnitude / d0
	else -- turn
		local a0 = math.atan2(drag.anchor.Y - c.Y, drag.anchor.X - c.X)
		local a1 = math.atan2(p.Y - c.Y, p.X - c.X)
		local r = s0.r + math.deg(a1 - a0)
		local snap = math.floor(r / 45 + 0.5) * 45
		if math.abs(r - snap) <= SNAP then r = snap end
		nxt.r = r
	end
	setPlace(drag.slot, nxt)
end)

UIS.InputEnded:Connect(function(input)
	if not isPress(input) then return end
	if not drag then return end
	commit(drag.slot)
	drag = nil
	if refreshAfterDrag then refreshAfterDrag = false if refreshLocker and lockerOpen then refreshLocker() end end
end)

-- send placements one at a time (the newest one per slot wins)
task.spawn(function()
	while true do
		task.wait(0.2)
		local slot = next(pendingPlace)
		if slot then
			local p = pendingPlace[slot]
			pendingPlace[slot] = nil
			local ok, res, msg = pcall(function() return EquipR:InvokeServer("place", slot, p) end)
			if not ok or res ~= true then
				if ok and msg == "Slow down." then
					if not pendingPlace[slot] then pendingPlace[slot] = p end
				else
					localPos[slot] = nil
					lockMsg = (ok and msg) or "Could not reach the server."
					if lockerOpen and lockTab == "card" and refreshLocker then refreshLocker() end
				end
			end
		end
	end
end)
-- forget a local placement once the server's copy matches it
local function syncLocal()
	local srv = PlayerCards.Read(player).pos
	for i = 1, 3 do
		local l = localPos[i]
		if l and not pendingPlace[i] and not (drag and drag.slot == i) then
			local s = srv[i]
			if math.abs(s.x - l.x) < 0.11 and math.abs(s.y - l.y) < 0.11 and math.abs(s.s - l.s) < 0.011 and math.abs(s.r - l.r) < 0.11 then localPos[i] = nil end
		end
	end
end

-- ===== v5.13 REPOSITION: a big view of one showcase item to set the angle it shows at on your card =====
-- Skins + gun skins: drag to turn them any way (the same feel as the shop preview; just the model, no disc / pad under a skin). The model is fitted
-- into a box with the same shape as a showcase slot, so what you see is how it sits on your card. Power-up cards: drag to lean the card a little
-- (PlayerCards.CARD_TILT each way). DONE (bottom middle) saves it with the spot / size / turn you gave the item on the card.
local closeRepo
local function repoButton(parent, text, x, y, w, h, main)
	local b = new("TextButton", { Text = text, TextSize = main and 26 or 18, FontFace = F.H, TextColor3 = K.text, BackgroundColor3 = main and K.red or K.panel3,
		AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	if main then hot(b, K.red, K.redHi, nil) else stroke(b, K.line2, 1) hot(b, K.panel3, K.panel2, nil) end
	return b
end
local function openRepo(slot)
	local data = PlayerCards.Read(player)
	local value = data.show[slot]
	local kind, id = PlayerCards.Parse(value)
	if not kind then return end
	if closeRepo then closeRepo() end
	editSel, drag = slot, nil
	local cur = localPos[slot] or data.pos[slot]
	local R = { slot = slot, value = value, kind = kind, yaw = cur.yaw or 0, pitch = cur.pitch or 0, conns = {} }
	local T = PlayerCards.CARD_TILT
	local root = new("Frame", { Name = "Reposition", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(6, 7, 9), BackgroundTransparency = 0.02, BorderSizePixel = 0,
		Active = true, ZIndex = 40 }, stage)
	R.root = root
	lbl(root, "REPOSITION", 56, 64, 28, 700, 70, K.text, F.H)
	lbl(root, ("SLOT %d  //  %s"):format(slot, PlayerCards.ItemName(value)), 18, 68, 96, 1300, 26, K.dim, F.MB)
	box(root, 64, 130, 1792, 1, K.line)
	-- the whole middle of the screen is the drag surface
	local area = new("TextButton", { Name = "DragArea", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(64, 146),
		Size = UDim2.fromOffset(1792, 770), Selectable = false }, root)
	local CX, CY = 896, 380
	if kind == "card" then
		local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(520, 728), BackgroundTransparency = 1 }, area)
		R.tilt = PlayerCards.TiltCard(holder, id, 470)
		if not R.tilt then -- a card without a baked picture cannot lean: show it flat and say so
			PlayerCards.ShowcaseItem(holder, value, 520, 728)
			lbl(root, "THIS CARD HAS NO BAKED PICTURE YET, SO IT STAYS STRAIGHT", 16, 64, 884, 1792, 22, K.redHi, F.MB, Enum.TextXAlignment.Center)
		end
	else
		local BH = 720
		local BW = math.floor(BH * PlayerCards.SW / PlayerCards.SH)
		R.BW, R.BH = BW, BH
		local frame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(BW, BH), BackgroundTransparency = 1 }, area)
		stroke(frame, K.line, 1, 0.4) -- the shape of the showcase slot
		R.pose = data.poses and data.poses[slot] or nil -- v5.16: a costume keeps its pose in the REPOSITION view
		local vp, cam = PlayerCards.MakeView(value, BW, BH, BW, BH, R.yaw, R.pitch, R.pose)
		if vp then
			vp.AnchorPoint = Vector2.new(0.5, 0.5)
			vp.Position = UDim2.fromOffset(CX, CY)
			vp.Parent = area
			R.cam = cam
		end
	end
	local readout = lbl(root, "", 14, 64, 912, 1792, 20, K.mute, F.MB, Enum.TextXAlignment.Center)
	lbl(root, kind == "card" and ("DRAG TO LEAN THE CARD LEFT / RIGHT / UP / DOWN  (UP TO %d DEGREES)"):format(T) or "DRAG TO TURN IT ANY WAY", 15, 64, 140, 1792, 22,
		K.dim, F.MB, Enum.TextXAlignment.Center)
	local function show()
		if R.tilt then
			R.tilt.set(R.yaw, R.pitch)
		elseif R.cam then
			local cf = PlayerCards.ViewCam(value, R.BW, R.BH, R.BW, R.BH, R.yaw, R.pitch, R.pose)
			if cf then R.cam.CFrame = cf end
		end
		readout.Text = kind == "card" and ("LEFT / RIGHT %d    UP / DOWN %d"):format(math.floor(R.yaw + 0.5), math.floor(R.pitch + 0.5))
			or ("TURN %d    TIP %d"):format(math.floor(R.yaw + 0.5), math.floor(R.pitch + 0.5))
	end
	show()
	-- drag (only how far the pointer moved counts)
	area.InputBegan:Connect(function(input)
		if not isPress(input) or repo ~= R then return end
		R.drag, R.last, R.touch = true, screenPos(input), input.UserInputType == Enum.UserInputType.Touch
	end)
	table.insert(R.conns, UIS.InputChanged:Connect(function(input)
		if not R.drag then return end
		if R.touch then
			if input.UserInputType ~= Enum.UserInputType.Touch then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local pos = screenPos(input)
		local d = pos - R.last
		R.last = pos
		if d.Magnitude < 0.01 then d = Vector2.new(input.Delta.X, input.Delta.Y) end -- a locked mouse moves the delta, not the position
		if kind == "card" then
			R.yaw = math.clamp(R.yaw + d.X * 0.12, -T, T)
			R.pitch = math.clamp(R.pitch - d.Y * 0.12, -T, T)
		else
			R.yaw = (R.yaw - d.X * 0.63 + 180) % 360 - 180
			R.pitch = math.clamp(R.pitch + d.Y * 0.46, -PlayerCards.PITCH_MAX, PlayerCards.PITCH_MAX)
		end
		show()
	end))
	table.insert(R.conns, UIS.InputEnded:Connect(function(input)
		if isPress(input) then R.drag = false end
	end))
	-- buttons: DONE bottom middle, RESET left of it, CANCEL right of it
	local done = repoButton(root, "DONE", 960 - 160, 960, 320, 74, true)
	local reset = repoButton(root, "RESET ANGLE", 960 - 160 - 24 - 220, 969, 220, 56)
	local cancel = repoButton(root, "CANCEL", 960 + 160 + 24, 969, 220, 56)
	done.MouseButton1Click:Connect(function()
		if repo ~= R then return end
		local p = table.clone(localPos[slot] or PlayerCards.Read(player).pos[slot])
		p.yaw, p.pitch = R.yaw, R.pitch
		setPlace(slot, p)
		commit(slot)
		closeRepo()
	end)
	reset.MouseButton1Click:Connect(function()
		R.yaw, R.pitch = 0, 0
		show()
	end)
	cancel.MouseButton1Click:Connect(function() closeRepo() end)
	repo = R
end
closeRepo = function()
	local R = repo
	if not R then return end
	repo = nil
	for _, c in R.conns do c:Disconnect() end
	R.root:Destroy()
	updateHandles()
end

local FLEX_TABS = { { id = "skin", name = "COSTUMES" }, { id = "gun", name = "GUN SKINS" }, { id = "card", name = "CARDS" } }
local flexTab = "skin" -- v5.12: the picker under a showcase slot has three tabs instead of one long list

local function cardSide()
	lockInfo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, lockSide)
	buildEditor()
	local pcData = PlayerCards.Read(player)
	-- how to edit + the selected item's buttons
	lbl(lockInfo, "CLICK AN ITEM ON YOUR CARD:  DRAG = MOVE  //  WHITE CORNER = SIZE  //  ROUND HANDLE = TURN  //  WHEEL = SIZE", 11, 4, 226, 690, 16, K.dim, F.MB)
	local resetB = new("TextButton", { Text = "RESET SPOT", TextSize = 16, FontFace = F.H, TextColor3 = K.text, BackgroundColor3 = K.panel3, AutoButtonColor = false,
		BorderSizePixel = 0, Position = UDim2.fromOffset(2, 250), Size = UDim2.fromOffset(160, 36) }, lockInfo)
	stroke(resetB, K.line2, 1)
	hot(resetB, K.panel3, K.panel2, nil)
	resetB.MouseButton1Click:Connect(function()
		local slot = editSel or cardSlot
		if not slot then lockMsg = "Select an item on your card first." refreshLocker() return end
		setPlace(slot, PlayerCards.DefaultPlace(slot))
		commit(slot)
	end)
	local resetAll = new("TextButton", { Text = "RESET ALL", TextSize = 16, FontFace = F.H, TextColor3 = K.text, BackgroundColor3 = K.panel3, AutoButtonColor = false,
		BorderSizePixel = 0, Position = UDim2.fromOffset(172, 250), Size = UDim2.fromOffset(140, 36) }, lockInfo)
	stroke(resetAll, K.line2, 1)
	hot(resetAll, K.panel3, K.panel2, nil)
	resetAll.MouseButton1Click:Connect(function()
		for i = 1, 3 do setPlace(i, PlayerCards.DefaultPlace(i)) commit(i) end
	end)
	-- v5.16: the title on your card (on / off) - only when you wear a title
	if Titles.Is(player:GetAttribute("Title")) then
		local showT = pcData.showTitle ~= false
		local tb = new("TextButton", { Text = "TITLE ON CARD:  " .. (showT and "ON" or "OFF"), TextSize = 16, FontFace = F.H, TextColor3 = showT and K.green or K.text,
			BackgroundColor3 = K.panel3, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(322, 250), Size = UDim2.fromOffset(220, 36) }, lockInfo)
		local tst = stroke(tb, showT and K.green or K.line2, 1)
		hot(tb, K.panel3, K.panel2, tst, showT and K.green or K.line2, K.redHi)
		tb.MouseButton1Click:Connect(function()
			local ok, res, msg = pcall(function() return EquipR:InvokeServer("cardtitle", not showT) end)
			lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
			if lockMsg ~= "" then refreshLocker() end
		end)
	end

	lbl(lockInfo, "SHOWCASE", 28, 2, 300, 400, 40, K.text, F.H)
	box(lockInfo, 2, 342, 690, 1, K.line)
	for i = 1, 3 do
		local v = pcData.show[i]
		local on = cardSlot == i
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0,
			Position = UDim2.fromOffset(2 + (i - 1) * 236, 356), Size = UDim2.fromOffset(218, 300) }, lockInfo)
		local st = stroke(b, on and K.red or K.line, on and 2.5 or 1)
		if not on then hot(b, K.panel2, rgb(30, 33, 40), st, K.line, K.line2) end
		lbl(b, "SLOT " .. i, 11, 12, 8, 120, 14, on and K.redHi or K.mute, F.MB)
		local well = box(b, 8, 28, 202, 222, K.void, 0.1)
		if PlayerCards.Parse(v) then
			queueThumb(well, { kind = "flex", value = v, w = 202, h = 222 })
		else
			for _, sz in { Vector2.new(26, 3), Vector2.new(3, 26) } do
				new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(sz.X, sz.Y), BackgroundColor3 = K.mute, BorderSizePixel = 0 }, well)
			end
		end
		local nm = lbl(b, PlayerCards.Parse(v) and PlayerCards.ItemName(v) or "EMPTY", 15, 12, 258, 196, 22, PlayerCards.Parse(v) and K.text or K.mute, F.H)
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		-- v5.13: REPOSITION under every slot (opens the big view where the item's angle is set)
		local has = PlayerCards.Parse(v) ~= nil
		local rb = new("TextButton", { Text = "REPOSITION", TextSize = 17, FontFace = F.H, TextColor3 = has and K.text or K.mute, BackgroundColor3 = K.panel3,
			AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(2 + (i - 1) * 236, 664), Size = UDim2.fromOffset(218, 40) }, lockInfo)
		local rst = stroke(rb, has and K.line2 or K.line, 1)
		if has then hot(rb, K.panel3, K.panel2, rst, K.line2, K.red) end
		rb.MouseButton1Click:Connect(function()
			if has then openRepo(i) end
		end)
		-- v5.16 ADD POSE under REPOSITION when the slot holds a COSTUME: pick the pose it holds on your card
		if PlayerCards.Parse(v) == "skin" then
			local pz = pcData.poses[i] or ""
			local onP = poseSlot == i
			local pb = new("TextButton", { Text = pz ~= "" and ("POSE: " .. (Poses.ById[pz] and Poses.ById[pz].name or pz)) or "ADD POSE", TextSize = 16, FontFace = F.H,
				TextColor3 = K.text, BackgroundColor3 = onP and rgb(40, 22, 26) or K.panel3, AutoButtonColor = false, BorderSizePixel = 0,
				Position = UDim2.fromOffset(2 + (i - 1) * 236, 710), Size = UDim2.fromOffset(218, 36) }, lockInfo)
			pb.TextTruncate = Enum.TextTruncate.AtEnd
			local pst = stroke(pb, onP and K.red or K.line2, onP and 2 or 1)
			if not onP then hot(pb, K.panel3, K.panel2, pst, K.line2, K.red) end
			pb.MouseButton1Click:Connect(function()
				poseSlot = (poseSlot == i) and nil or i
				cardSlot = nil
				lockMsg = ""
				lockGrid.CanvasPosition = Vector2.zero
				refreshLocker()
			end)
		end
		b.MouseButton1Click:Connect(function()
			if cardSlot == i then cardSlot = nil else cardSlot = i end
			poseSlot = nil -- v5.16
			editSel = PlayerCards.Parse(v) and i or editSel
			lockMsg = ""
			lockGrid.CanvasPosition = Vector2.zero
			refreshLocker()
		end)
	end
	if cardSlot or poseSlot then
		local back = bigButton(lockInfo, "CHANGE BACKGROUND INSTEAD", 754, false, true) -- v5.16: a bit lower (ADD POSE sits under REPOSITION)
		back.MouseButton1Click:Connect(function() cardSlot = nil poseSlot = nil lockMsg = "" refreshLocker() end)
	end
	if lockMsg ~= "" then lbl(lockInfo, lockMsg, 13, 2, 202, 690, 18, K.redHi, F.MB, Enum.TextXAlignment.Center) end
end

-- v5.12: the viewer on the right is KEPT between refreshes (it used to be destroyed and rebuilt after every click, so the model blinked);
-- it only swaps its model when a different item is selected.
local function ensureViewer(rectKey, x, y, w, h, item, itemKey)
	if lockViewer and lockViewer.rectKey ~= rectKey then lockViewer.destroy() lockViewer = nil end
	if not lockViewer then
		lockViewer = newViewer(lockerRoot, x, y, w, h)
		lockViewer.rectKey = rectKey
	end
	if lockViewer.itemKey ~= itemKey then
		lockViewer.set(item)
		lockViewer.itemKey = itemKey
	end
end

function refreshLocker()
	if drag then refreshAfterDrag = true return end -- never rebuild under a dragging finger
	syncLocal()
	for id, t in lockTabBtns do
		t.b.TextColor3 = (id == lockTab) and K.text or K.dim
		t.u.Visible = id == lockTab
	end
	local keep = lockGrid.CanvasPosition
	for _, c in lockGrid:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	if lockInfo then lockInfo:Destroy() lockInfo = nil end
	if lockTab ~= "card" then destroyEditor() end
	if lockTab == "skin" then
		-- v5.11: only the BASE skins; colourways are picked under the preview
		local worn = wornSkin()
		local items = {}
		for _, baseId in Cat.BaseSkins() do
			local cws = Cat.Colourways(baseId)
			local n = 1
			for _, id in cws do if Cat.OwnsSkin(player, id) then n += 1 end end
			local showId = (Cat.BaseOf(worn) == baseId) and worn or baseId
			table.insert(items, { kind = "skin", id = showId, base = baseId, name = Skins.Get(baseId).name,
				sub = (#cws > 0) and ("%d / %d COLOURWAYS"):format(n, #cws + 1) or "" })
		end
		lockSection("YOUR COSTUMES", nil, 1) -- v5.16: player skins are called COSTUMES
		lockRow(2, items, 328)
		if not (selectedLock and selectedLock.kind == "skin") then selectedLock = { kind = "skin", base = Cat.BaseOf(worn), variant = worn } end
		if Cat.BaseOf(selectedLock.variant) ~= selectedLock.base or not Cat.OwnsSkin(player, selectedLock.variant) then selectedLock.variant = selectedLock.base end
		lockGrid.CanvasPosition = keep
		ensureViewer("skin", 1170, 214, 694, 430, { kind = "skin", id = selectedLock.variant }, "skin|" .. selectedLock.variant)
		skinSide(selectedLock)
	elseif lockTab == "gun" then
		-- v5.16: one small TAB per gun side by side (like the shop's gun row) instead of every gun stacked under each other; click a gun = its skins
		local ownedSet = {}
		for _, id in Cat.OwnedGunSkins(player) do ownedSet[id] = true end
		local counts = {}
		for _, g in GunSkins.GunOrder do
			counts[g] = 0
			for _, sk in GunSkins.ForGun(g) do if ownedSet[sk.id] then counts[g] += 1 end end
		end
		if not (lockGun and GunSkins.GunNames[lockGun]) then
			lockGun = myWeapon()
			if counts[lockGun] == 0 then for _, g in GunSkins.GunOrder do if counts[g] > 0 then lockGun = g break end end end
		end
		local bar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, 46), LayoutOrder = 1, AutomaticSize = Enum.AutomaticSize.Y }, lockGrid)
		new("UIGridLayout", { CellSize = UDim2.fromOffset(122, 40), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, bar)
		for i, g in GunSkins.GunOrder do
			local on = g == lockGun
			local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = on and K.panel3 or K.panel, BorderSizePixel = 0, LayoutOrder = i }, bar)
			local st = stroke(b, on and K.red or K.line, on and 2 or 1)
			if not on then hot(b, K.panel, K.panel2, st, K.line, K.line2) end
			lbl(b, GunSkins.GunNames[g], 15, 10, 0, 84, 40, on and K.text or K.dim, F.H).TextTruncate = Enum.TextTruncate.AtEnd
			lbl(b, tostring(counts[g]), 13, 92, 0, 22, 40, counts[g] > 0 and K.soulPale or K.mute, F.MB, Enum.TextXAlignment.Right)
			b.MouseButton1Click:Connect(function()
				if lockGun == g then return end
				lockGun = g
				selectedLock = nil
				lockGrid.CanvasPosition = Vector2.zero
				refreshLocker()
			end)
		end
		local g = lockGun
		local mine = { { kind = "gun", id = "STOCK", name = "STOCK", sub = GunSkins.GunNames[g], gun = g, gunName = GunSkins.GunNames[g] } }
		for _, sk in GunSkins.ForGun(g) do
			if ownedSet[sk.id] then table.insert(mine, { kind = "gun", id = sk.id, name = sk.name, sub = sk.sub, gun = g, gunName = sk.gunName, glow = sk.glow }) end
		end
		local eqId = equippedOn(g)
		local eqName = eqId and GunSkins.ById[eqId] and GunSkins.ById[eqId].name or "STOCK"
		lockSection(GunSkins.GunNames[g] .. " SKINS", "ON THIS GUN NOW:  " .. eqName, 2)
		lockRow(3, mine, 328)
		if #mine == 1 then
			local e = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, 60), LayoutOrder = 4 }, lockGrid)
			lbl(e, "NO SKINS FOR THE " .. GunSkins.GunNames[g] .. " YET", 22, 0, 10, 1040, 36, K.mute, F.H)
		end
		if not (selectedLock and selectedLock.kind == "gun" and selectedLock.gun == g) then
			local id = eqId or "STOCK"
			local it = (id == "STOCK") and mine[1] or nil
			if not it then for _, m in mine do if m.id == id then it = m end end end
			it = it or mine[1]
			selectedLock = { kind = "gun", id = it.id, gun = g, item = it }
		end
		lockGrid.CanvasPosition = keep
		local sel = selectedLock and selectedLock.kind == "gun" and selectedLock.item
		if sel then
			ensureViewer("gun", 1170, 214, 694, 540, sel, "gun|" .. sel.gun .. "|" .. sel.id)
			gunSide(sel)
		elseif lockViewer then
			lockViewer.destroy()
			lockViewer = nil
		end
	elseif lockTab == "pose" then
		-- v5.16 POSES
		local list = Cat.OwnedPoses(player)
		if not (selPose and Poses.Is(selPose)) then selPose = Poses.Wheel(player)[1] ~= "" and Poses.Wheel(player)[1] or list[1] end
		lockSection("YOUR POSES", ("%d OWNED"):format(#list), 1)
		lockRow(2, list, 250, poseCard, 270)
		lockGrid.CanvasPosition = keep
		if selPose then ensureViewer("pose", 1170, 214, 694, 350, { kind = "pose", id = selPose }, "pose|" .. selPose .. "|" .. wornSkin())
		elseif lockViewer then lockViewer.destroy() lockViewer = nil end
		poseSide()
	elseif lockTab == "title" then
		-- v5.16 TITLES
		if lockViewer then lockViewer.destroy() lockViewer = nil end
		local list = Cat.OwnedTitles(player)
		if not (selTitle and Titles.Is(selTitle)) then
			local cur = player:GetAttribute("Title")
			selTitle = (Titles.Is(cur) and cur) or list[1]
		end
		lockSection("YOUR TITLES", ("%d OWNED"):format(#list), 1)
		lockRow(2, list, 334, titleCard, 170)
		lockGrid.CanvasPosition = keep
		titleSide()
	else -- card
		if lockViewer then lockViewer.destroy() lockViewer = nil end
		local pcNow = PlayerCards.Read(player)
		if poseSlot and PlayerCards.Parse(pcNow.show[poseSlot]) ~= "skin" then poseSlot = nil end
		if poseSlot then
			-- v5.16 ADD POSE: the poses you own (+ NO POSE) for the costume in that slot
			lockSection("POSE  //  SLOT " .. poseSlot .. "  //  " .. PlayerCards.ItemName(pcNow.show[poseSlot]), nil, 1)
			local cur = pcNow.poses[poseSlot] or ""
			local list = { "" }
			for _, id in Cat.OwnedPoses(player) do table.insert(list, id) end
			local slotNow = poseSlot
			lockRow(2, list, 250, function(parent, id, order, w)
				local on = cur == id
				local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.fromOffset(w, 250) }, parent)
				local st = stroke(b, on and K.green or K.line, on and 2 or 1)
				if not on then hot(b, K.panel2, rgb(30, 33, 40), st, K.line, K.line2) end
				local well = box(b, 1, 1, w - 2, 196, K.void, 0.1)
				new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(20, 24, 32), rgb(8, 9, 12)) }, well)
				local _, skinId = PlayerCards.Parse(pcNow.show[slotNow])
				if id ~= "" then
					task.defer(function()
						if not well.Parent then return end
						local vp = PlayerCards.MakeView(pcNow.show[slotNow], w - 2, 196, w - 2, 196, nil, nil, id)
						if vp then vp.Parent = well end
					end)
				else
					queueThumb(well, { kind = "skin", id = skinId })
				end
				lbl(b, id == "" and "NO POSE" or Poses.ById[id].name, 18, 12, 202, w - 24, 24, K.text, F.H)
				if on then lbl(b, "ON THIS COSTUME", 10, 13, 226, w - 24, 14, K.green, F.MB) end
				b.MouseButton1Click:Connect(function()
					if on then return end
					local ok, res, msg = pcall(function() return EquipR:InvokeServer("cardpose", slotNow, id) end)
					lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
					if lockMsg ~= "" then refreshLocker() end
				end)
				return b
			end, 250)
		elseif cardSlot then
			-- the slot, then three tabs (PLAYER SKINS / GUN SKINS / CARDS) and only the open tab's items (was one long list)
			lockSection("SHOWCASE  //  SLOT " .. cardSlot, nil, 1)
			local bar = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, 56), LayoutOrder = 2 }, lockGrid)
			for i, t in FLEX_TABS do
				local on = flexTab == t.id
				local b = new("TextButton", { Text = t.name, TextSize = 22, FontFace = F.H, TextColor3 = on and K.text or K.dim, BackgroundColor3 = on and K.panel3 or K.panel,
					AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset((i - 1) * 222, 6), Size = UDim2.fromOffset(210, 46) }, bar)
				local st = stroke(b, on and K.red or K.line, on and 2 or 1)
				if on then box(b, 0, 43, 210, 3, K.red) else hot(b, K.panel, K.panel2, st, K.line, K.line2) end
				b.MouseButton1Click:Connect(function()
					if flexTab == t.id then return end
					flexTab = t.id
					lockGrid.CanvasPosition = Vector2.zero
					refreshLocker()
				end)
			end
			local cur = PlayerCards.Read(player).show[cardSlot]
			local emptyOn = not PlayerCards.Parse(cur)
			local clr = new("TextButton", { Text = emptyOn and "SLOT IS EMPTY" or "EMPTY THIS SLOT", TextSize = 18, FontFace = F.H, TextColor3 = emptyOn and K.mute or K.text,
				BackgroundColor3 = K.panel, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(1040 - 200, 6), Size = UDim2.fromOffset(200, 46) }, bar)
			local cst = stroke(clr, K.line, 1)
			if not emptyOn then
				hot(clr, K.panel, K.panel2, cst, K.line, K.redHi)
				clr.MouseButton1Click:Connect(function()
					local slot = cardSlot
					local ok, res, msg = pcall(function() return EquipR:InvokeServer("show", slot, "") end)
					lockMsg = (ok and res == true) and "" or ((ok and msg) or "Could not reach the server.")
				end)
			end
			local list, w = {}, 250
			if flexTab == "skin" then
				for _, id in Cat.OwnedSkins(player) do table.insert(list, "skin:" .. id) end
			elseif flexTab == "gun" then
				for _, id in Cat.OwnedGunSkins(player) do table.insert(list, "gun:" .. id) end
			else
				for _, id in ownedCardIds() do table.insert(list, "card:" .. id) end
				w = 196
			end
			if #list > 0 then
				lockRow(3, list, w, flexCard, 250)
			else
				local e = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1040, 80), LayoutOrder = 3 }, lockGrid)
				lbl(e, flexTab == "gun" and "NO GUN SKINS YET" or "NOTHING HERE YET", 26, 0, 16, 1040, 40, K.mute, F.H)
			end
		else
			lockSection("BACKGROUNDS", nil, 1)
			lockRow(2, PlayerCards.Order, 334, bannerCard, 230)
		end
		lockGrid.CanvasPosition = keep
		cardSide()
	end
end

for _, t in LOCK_TABS do
	lockTabBtns[t.id].b.MouseButton1Click:Connect(function()
		if lockTab == t.id then return end
		lockTab = t.id
		selectedLock, cardSlot, lockMsg, editSel, poseSlot = nil, nil, "", nil, nil
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
	shopSide = "essence" -- v5.12: the shop always opens on the ESSENCE SHOP
	for _, p in panels do p.scroll.CanvasPosition = Vector2.zero end
	if pendingPreview then shopTab = (pendingPreview.kind == "gun" and "gun") or (pendingPreview.kind == "banner" and "banner") or (pendingPreview.kind == "pose" and "pose")
		or (pendingPreview.kind == "title" and "title") or "skin" end
	refreshShop()
	updateButton()
	if pendingPreview then
		local it = pendingPreview
		pendingPreview = nil
		openPreview(it)
	end
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
closeLocker = function()
	if not lockerOpen then return end
	lockerOpen = false
	closeRepo() -- v5.13
	destroyEditor()
	editSel = nil
	if lockViewer then lockViewer.destroy() lockViewer = nil end
	if lockInfo then lockInfo:Destroy() lockInfo = nil end
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
-- v5.11: "card" = open the locker on the PLAYER CARD tab (EDIT CARD on the play screen), "shop" = open the shop
player:GetAttributeChangedSignal("CosmeticsOpen"):Connect(function()
	local v = player:GetAttribute("CosmeticsOpen")
	if not v then return end
	player:SetAttribute("CosmeticsOpen", nil)
	if v == "shop" then
		if lockerOpen then closeLocker() end
		openShop()
	elseif v == "card" then
		if shopOpen then closeShop() end
		lockTab, selectedLock, cardSlot, lockMsg, editSel, poseSlot = "card", nil, nil, "", nil, nil
		if lockerOpen then refreshLocker() else openLocker() end
	elseif lockerOpen then closeLocker() elseif not shopOpen then openLocker() end
end)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe or UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if repo then closeRepo() elseif pv.Visible then closePreview() elseif shopOpen then closeShop() elseif lockerOpen then closeLocker() end
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
for _, a in { "Souls", "Essence", "Skin", "SkinsOwnedJson", "GunSkinsOwnedJson", "GunSkinsJson", "BannersOwnedJson", "CardsJson", "Level",
	"PosesOwnedJson", "PoseWheelJson", "TitlesOwnedJson", "Title" } do -- v5.16: + poses / wheel / titles
	player:GetAttributeChangedSignal(a):Connect(softRefresh)
end
-- v5.12: when only the PLACEMENT of the showcase items changed (the server echoing a move), just move them on the editor card - no page rebuild
local function cardSig()
	local d = PlayerCards.Read(player)
	return d.bg .. "|" .. table.concat(d.show, ",") .. "|" .. table.concat(d.poses, ",") .. "|" .. tostring(d.showTitle) -- v5.16: + poses + title switch
end
local lastCardSig = cardSig()
player:GetAttributeChangedSignal("PlayerCardJson"):Connect(function()
	local sig = cardSig()
	local onlyMoved = sig == lastCardSig
	lastCardSig = sig
	if onlyMoved and lockerOpen and lockTab == "card" and editor then
		syncLocal()
		if not drag then buildEditor() end
		return
	end
	softRefresh()
end)
player:GetAttributeChangedSignal("LobbyMenuOpen"):Connect(updateButton)
player:GetAttributeChangedSignal("StarterDone"):Connect(updateButton)
updateButton()
