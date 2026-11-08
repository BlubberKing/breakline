-- ShopClient v1.2 (v5.14: new CARDS tab - daily card shop + card packs with their own layout, built by the CardShopUI module; ESC closes the pack
--   view first and does nothing while a pack is opening) (v1.1 v5.9: cart icon, Essence next to the souls, clear CLOSE button, no filler line) (v1) (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in v4.7.
-- 1) SHOP. Opens from the SHOP button (left side of the screen, halfway down) or from the shop NPC (ShopServer adds the prompt; the server then fires
--    ShopRemotes.Open). Three tabs at the top: GUNS / GADGETS / MOVEMENT. Click an item = a panel on the right: guns show their real stats (WeaponConfig),
--    gadgets show what they do + their numbers (GadgetConfig), movement abilities what they do + their numbers. Prices are SOULS (LobbyCatalog.Price).
--    BUY asks twice (BUY -> CONFIRM) so nothing is bought by accident. Only items you own show up in the loadout pickers.
-- 2) STARTER PICK. A player who has never picked (attribute StarterDone is false) gets a full-screen choice: WEAPON (M4A1 / V9 / AK-47) and
--    MOVEMENT (Double Jump / Wall Climb / Dash). The Frag Grenade, Flashbang and Sentry are shown as "you also start with" (no choice).
-- Needs in ReplicatedStorage: LobbyCatalog, UIKit, GunModels, GadgetModels, WeaponConfig + GadgetConfig (copies of Breakline's), ShopRemotes (made by ShopServer).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local UI = require(RS:WaitForChild("UIKit"))
local K, F = UI.C, UI.F
local new = UI.new
local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local GunModels = require(RS:WaitForChild("GunModels"))
local GM = require(RS:WaitForChild("GadgetModels"))
local WeaponCfg = require(RS:WaitForChild("WeaponConfig"))
local GadgetCfg = require(RS:WaitForChild("GadgetConfig"))
local CardShopUI = require(RS:WaitForChild("CardShopUI")) -- v5.14: the CARDS tab
local Remotes = RS:WaitForChild("ShopRemotes")
local BuyR, StarterR, OpenR = Remotes:WaitForChild("Buy"), Remotes:WaitForChild("Starter"), Remotes:WaitForChild("Open")

local rgb = Color3.fromRGB
local BLACK = Color3.new(0, 0, 0)
local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tween(o, info, goal) TweenService:Create(o, info, goal):Play() end

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
		if st and st.Color ~= K.red then tween(st, FAST, { Color = stHot }) end
	end)
	b.MouseLeave:Connect(function()
		tween(b, FAST, { BackgroundColor3 = bg })
		if st and st.Color ~= K.red then tween(st, FAST, { Color = stCol }) end
	end)
end

-- ================= pictures =================
local function gunPicture(parent, weaponId)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 158),
		LightColor = rgb(255, 252, 246), LightDirection = Vector3.new(-0.5, -1, -0.3) }, parent)
	local ok, desc = pcall(GunModels.Describe, weaponId, "Iron")
	if not ok or not desc then return vp end
	local model = new("Model", {}, vp)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = (d.Glow and K.red) or d.Color,
				Material = d.Material or Enum.Material.SmoothPlastic, Transparency = d.Transparency or 0, Reflectance = d.Reflectance or 0 }, model)
			if d.Shape then p.Shape = d.Shape end
			local half = d.Size / 2
			minV, maxV = minV:Min(d.CF.Position - half), maxV:Max(d.CF.Position + half)
		end
	end
	local cam = new("Camera", { FieldOfView = 16 }, vp)
	UI.FitViewport(vp, cam, model, Vector3.new(1, 0.08, 0), { pad = 0.1, fov = 16 }) -- v5.9: fitted, never cropped
	return vp
end

local function itemPicture(parent, item, abilitySize)
	if item.kind == "weapon" then
		gunPicture(parent, item.id)
	elseif item.kind == "gadget" then
		GM.Picture(parent, item.id)
	else
		local ic = UI.AbilityIcon(parent, item.icon or item.id, abilitySize or 84, item.color)
		ic.AnchorPoint, ic.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	end
end

-- ================= gui shell =================
local gui = new("ScreenGui", { Name = "ShopGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

-- the SHOP button, left side of the screen
local shopBtn = new("TextButton", { Name = "ShopButton", Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel, BackgroundTransparency = 0.06, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.fromOffset(156, 64), Visible = false }, gui)
do
	local st = stroke(shopBtn, K.line, 1)
	box(shopBtn, 0, 0, 3, 64, K.red)
	-- v5.9: a shopping CART drawn from thin bars (the old bag - solid box + round handle - read as a padlock)
	local cart = new("Frame", { Position = UDim2.fromOffset(14, 17), Size = UDim2.fromOffset(34, 30), BackgroundTransparency = 1 }, shopBtn)
	local function seg(x1, y1, x2, y2, th)
		local dx, dy = x2 - x1, y2 - y1
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
			Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th * 0.6, th), Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = K.text, BorderSizePixel = 0 }, cart)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	end
	seg(1, 2, 6, 2, 2.5)     -- handle
	seg(6, 2, 10, 19, 2.5)   -- back of the basket, down to the base
	seg(8, 7, 32, 7, 2.5)    -- basket top rim
	seg(32, 7, 29, 17, 2.5)  -- front of the basket
	seg(10, 17, 29, 17, 2.5) -- basket bottom
	seg(10, 19, 30, 22, 2)   -- frame under the basket
	for _, wx in { 13, 27 } do -- wheels
		local w = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(wx, 27), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = K.text, BorderSizePixel = 0 }, cart)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, w)
	end
	lbl(shopBtn, "SHOP", 26, 58, 0, 90, 64, K.text, F.H)
	hot(shopBtn, K.panel, K.panel2, st, K.line, K.red)
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

-- ================= menu flag (blocks walking / abilities behind the UI, same flag the Card Index uses) =================
local menuWas = nil
local flagHolders = 0
local function holdMenu()
	if flagHolders == 0 then menuWas = player:GetAttribute("LobbyMenuOpen") end
	flagHolders += 1
	player:SetAttribute("LobbyMenuOpen", true)
end
local function releaseMenu()
	flagHolders = math.max(0, flagHolders - 1)
	if flagHolders == 0 then player:SetAttribute("LobbyMenuOpen", menuWas) end
end

-- ================= SHOP =================
local shopOpen, starterOpen = false, false
local tab = "gun" -- gun | gadget | move
local selected = nil
local armedId, armedAt = nil, 0
local toastText, toastGood = "", false
local refreshAll

local shop = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, stage)
local starter = new("Frame", { Name = "Starter", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, stage)
lbl(shop, "SHOP", 56, 64, 28, 400, 70, K.text, F.H)
-- v5.9: the explainer line under SHOP is gone
box(shop, 64, 130, 1792, 1, K.line)

-- souls (top right) + close
-- v5.9: souls + ESSENCE (to the right of the souls) in one box, and the shared clear CLOSE button
local soulsBox = box(shop, 1280, 40, 400, 52, K.panel, 0.1)
stroke(soulsBox, K.line, 1)
do
	local ic = UI.SoulIcon(soulsBox, 34)
	ic.Position = UDim2.fromOffset(12, 9)
	local ec = UI.EssenceIcon(soulsBox, 32)
	ec.Position = UDim2.fromOffset(214, 10)
end
local soulsLbl = lbl(soulsBox, "0", 28, 56, 0, 150, 52, K.text, F.H)
local essenceLbl = lbl(soulsBox, "0", 28, 256, 0, 140, 52, K.text, F.H)
local closeBtn = UI.CloseButton(shop, "CLOSE", { Position = UDim2.fromOffset(1704, 45) })

-- tabs
local TABS = { { id = "gun", name = "GUNS" }, { id = "gadget", name = "GADGETS" }, { id = "move", name = "MOVEMENT" }, { id = "cards", name = "CARDS" } } -- v5.14: + CARDS
local tabBtns = {}
for i, t in TABS do
	local b = new("TextButton", { Text = t.name, TextSize = 24, FontFace = F.H, TextColor3 = K.dim, BackgroundTransparency = 1, AutoButtonColor = false,
		Position = UDim2.fromOffset(64 + (i - 1) * 250, 146), Size = UDim2.fromOffset(230, 52) }, shop)
	local u = box(b, 0, 50, 230, 3, K.red)
	u.Visible = false
	tabBtns[t.id] = { b = b, u = u }
end

local gridScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(56, 216), Size = UDim2.fromOffset(1200, 820), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = K.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, shop)
new("UIGridLayout", { CellSize = UDim2.fromOffset(280, 252), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }, gridScroll)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingBottom = UDim.new(0, 20) }, gridScroll)

local detail = box(shop, 1292, 216, 564, 816, K.panel, 0.04)
stroke(detail, K.line, 1)
local detailBody = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, detail)

-- v5.14: the CARDS tab has its own page (daily shop + card packs), it replaces the grid + detail panel while that tab is open
local cardsPage = CardShopUI.Mount(shop, { gui = gui })
local cardsShown = false

local function itemsOf(t)
	local list = (t == "gun" and Catalog.Weapons) or (t == "gadget" and Catalog.Gadgets) or Catalog.Moves
	local out = table.clone(list)
	table.sort(out, function(a, b) return (Catalog.Price[a.id] or 0) < (Catalog.Price[b.id] or 0) end)
	return out
end
local function owned(id) return Catalog.OwnedSet(player)[id] == true end
local function souls() return player:GetAttribute("Souls") or 0 end

local function priceRow(parent, x, y, price, big)
	local ic = UI.SoulIcon(parent, big and 30 or 22)
	ic.Position = UDim2.fromOffset(x, y)
	lbl(parent, commas(price), big and 26 or 18, x + (big and 36 or 28), y - 2, 140, big and 30 or 22, K.text, F.H)
end

local function buildGrid()
	for _, c in gridScroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	for i, item in itemsOf(tab) do
		local isOwned = owned(item.id)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel, BorderSizePixel = 0, LayoutOrder = i }, gridScroll)
		local st = stroke(b, selected == item.id and K.red or K.line, selected == item.id and 2 or 1)
		hot(b, K.panel, K.panel2, st, K.line, K.line2)
		local well = box(b, 1, 1, 278, 150, K.void, 0.2)
		local pic = new("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 1, -18), BackgroundTransparency = 1 }, well)
		itemPicture(pic, item, 76)
		lbl(b, string.upper(item.name), 22, 14, 158, 252, 28, K.text, F.H)
		lbl(b, string.upper(item.sub), 11, 15, 186, 252, 14, K.dim, F.M)
		if isOwned then
			local tag = box(b, 14, 214, 88, 22, rgb(24, 70, 44))
			stroke(tag, K.green, 1)
			lbl(tag, "OWNED", 12, 0, 0, 88, 22, K.green, F.MB, Enum.TextXAlignment.Center)
		else
			priceRow(b, 14, 212, Catalog.Price[item.id] or 0, false)
		end
		b.MouseButton1Click:Connect(function()
			selected = item.id
			armedId = nil
			toastText = ""
			refreshAll()
		end)
	end
end

-- ----- detail panel -----
local function statBar(parent, y, label, valueText, frac)
	lbl(parent, label, 11, 28, y, 200, 14, K.dim, F.M)
	lbl(parent, valueText, 13, 306, y - 2, 230, 18, K.text, F.MB, Enum.TextXAlignment.Right)
	local back = box(parent, 28, y + 18, 508, 6, BLACK, 0.45)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, back)
	local fill = box(back, 0, 0, math.max(4, math.floor(508 * math.clamp(frac, 0.02, 1))), 6, K.text)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, fill)
	return y + 40
end
local function statLine(parent, y, label, valueText)
	lbl(parent, string.upper(label), 11, 28, y, 220, 18, K.dim, F.M)
	lbl(parent, valueText, 14, 240, y - 1, 296, 20, K.text, F.MB, Enum.TextXAlignment.Right)
	box(parent, 28, y + 24, 508, 1, K.line, 0.5)
	return y + 30
end

local function gunStats(parent, y, id)
	local cfg = WeaponCfg.Get(id)
	local perShot = cfg.Damage * cfg.Pellets
	local rpm = cfg.FireMode == "Burst" and math.floor(60 / WeaponCfg.AvgInterval(cfg) + 0.5) or cfg.RPM
	y = statBar(parent, y, "DAMAGE", cfg.Pellets > 1 and (cfg.Damage .. " x " .. cfg.Pellets) or tostring(cfg.Damage), perShot / 90)
	y = statBar(parent, y, "FIRE RATE", rpm .. " RPM", rpm / 900)
	y = statBar(parent, y, "MAGAZINE", tostring(cfg.MagSize), cfg.MagSize / 80)
	y = statBar(parent, y, "RELOAD", ("%.1f s"):format(cfg.ReloadTime), math.clamp(1 - (cfg.ReloadTime - 1) / 5, 0.05, 1))
	y = statBar(parent, y, "RANGE", cfg.Range .. " studs", cfg.Range / 1500)
	y = statBar(parent, y, "MOBILITY", ("%d%%"):format(math.floor(cfg.MoveSpeed * 100 + 0.5)), (cfg.MoveSpeed - 0.8) / 0.3)
	y += 6
	y = statLine(parent, y, "Fire mode", cfg.FireMode)
	y = statLine(parent, y, "Headshot", ("x%.2f"):format(cfg.HeadMultiplier))
	y = statLine(parent, y, "Shots to kill (250 hp)", tostring(math.ceil(250 / perShot - 1e-6)))
	return y
end

local function gadgetLines(id)
	local c = GadgetCfg.Items[id]
	if not c then return {} end
	local out = { { "Charges", tostring(c.charges) }, { "Recharge", c.recharge .. " s per charge" } }
	local function add(l, v) table.insert(out, { l, v }) end
	if id == "FRAG" then add("Damage", tostring(c.damage)) add("Blast radius", c.radius .. " studs") add("Fuse", c.fuse .. " s")
	elseif id == "SMOKE" then add("Cloud radius", c.radius .. " studs") add("Lasts", c.duration .. " s")
	elseif id == "FLASH" then add("Fuse", c.fuse .. " s") add("Blind (max)", c.maxTime .. " s") add("Range", c.range .. " studs")
	elseif id == "SENTRY" then add("Health", tostring(c.health)) add("Lifetime", c.life .. " s") add("Range", c.range .. " studs") add("Fire rate", c.rpm .. " RPM")
	elseif id == "SHIELD" then add("Dome radius", c.radius .. " studs") add("Dome health", tostring(c.hp)) add("Lifetime", c.life .. " s")
	elseif id == "MINE" then add("Arm time", c.arm .. " s") add("Trigger range", c.trigger .. " studs") add("Damage", tostring(c.damage)) add("Max active", tostring(c.maxActive))
	end
	return out
end

local function renderDetail()
	for _, c in detailBody:GetChildren() do c:Destroy() end
	local item = selected and Catalog.ById[selected]
	if not item then
		lbl(detailBody, "SELECT AN ITEM", 26, 0, 360, 564, 40, K.mute, F.H, Enum.TextXAlignment.Center)
		lbl(detailBody, "Click anything on the left to see what it does.", 13, 0, 404, 564, 20, K.mute, F.B, Enum.TextXAlignment.Center)
		return
	end
	local well = box(detailBody, 1, 1, 562, 214, K.void, 0.15)
	local pic = new("Frame", { Position = UDim2.fromOffset(30, 10), Size = UDim2.new(1, -60, 1, -20), BackgroundTransparency = 1 }, well)
	itemPicture(pic, item, 120)
	lbl(detailBody, string.upper(item.name), 40, 28, 224, 508, 48, K.text, F.H)
	local kindName = item.kind == "weapon" and "GUN" or (item.kind == "gadget" and "GADGET" or "MOVEMENT")
	lbl(detailBody, kindName .. "  //  " .. string.upper(item.sub), 12, 29, 272, 508, 16, K.redHi, F.MB)
	box(detailBody, 28, 298, 508, 1, K.line)
	local y = 312
	if item.kind == "weapon" then
		y = gunStats(detailBody, y, item.id)
	else
		lbl(detailBody, "WHAT IT DOES", 11, 28, y, 300, 14, K.dim, F.M)
		local d = lbl(detailBody, Catalog.Desc[item.id] or "", 15, 28, y + 20, 508, 120, K.text, F.B, nil, true)
		d.LineHeight = 1.15
		y += 150
		lbl(detailBody, "STATS", 11, 28, y, 300, 14, K.dim, F.M)
		y += 22
		local lines = item.kind == "gadget" and gadgetLines(item.id) or Catalog.MoveStats[item.id] or {}
		for _, row in lines do y = statLine(detailBody, y, row[1], row[2]) end
	end

	-- buy area
	local isOwned = owned(item.id)
	local price = Catalog.Price[item.id] or 0
	box(detailBody, 28, 706, 508, 1, K.line)
	if isOwned then
		local tag = box(detailBody, 28, 724, 508, 64, rgb(18, 52, 34))
		stroke(tag, K.green, 1)
		lbl(tag, "OWNED  -  PICK IT IN YOUR LOADOUT", 18, 0, 0, 508, 64, K.green, F.H, Enum.TextXAlignment.Center)
	else
		priceRow(detailBody, 28, 722, price, true)
		local have = souls()
		local can = have >= price
		lbl(detailBody, can and ("YOU HAVE " .. commas(have)) or ("YOU NEED " .. commas(price - have) .. " MORE"), 11, 28, 760, 260, 14, can and K.dim or K.redHi, F.M)
		local armed = armedId == item.id and os.clock() - armedAt < 3
		local b = new("TextButton", { Text = armed and "CONFIRM PURCHASE" or "BUY", TextSize = 22, FontFace = F.H, TextColor3 = can and K.text or K.mute,
			BackgroundColor3 = can and (armed and K.redHi or K.red) or K.panel3, AutoButtonColor = false, BorderSizePixel = 0,
			Position = UDim2.fromOffset(300, 722), Size = UDim2.fromOffset(236, 62) }, detailBody)
		if can then hot(b, armed and K.redHi or K.red, K.redHi, nil) end
		b.MouseButton1Click:Connect(function()
			if not can then
				toastText, toastGood = "Not enough souls. Win matches to earn more.", false
				renderDetail()
				return
			end
			if armedId ~= item.id or os.clock() - armedAt >= 3 then
				armedId, armedAt = item.id, os.clock()
				renderDetail()
				task.delay(3.05, function() if armedId == item.id and os.clock() - armedAt >= 3 then armedId = nil if selected == item.id and shopOpen then renderDetail() end end end)
				return
			end
			armedId = nil
			b.Text = "..."
			local ok, res, msg = pcall(function() return BuyR:InvokeServer(item.id) end)
			toastText, toastGood = (ok and msg) or (ok and tostring(res)) or "Could not reach the server.", ok and res == true
			refreshAll()
		end)
	end
	if toastText ~= "" then
		lbl(detailBody, toastText, 12, 28, 790, 508, 18, toastGood and K.green or K.redHi, F.MB, Enum.TextXAlignment.Center)
	end
end

function refreshAll()
	soulsLbl.Text = commas(souls())
	essenceLbl.Text = commas(player:GetAttribute("Essence") or 0)
	for id, t in tabBtns do
		t.b.TextColor3 = (id == tab) and K.text or K.dim
		t.u.Visible = id == tab
	end
	if tab == "cards" then -- v5.14
		gridScroll.Visible, detail.Visible = false, false
		if cardsShown then cardsPage.Refresh() else cardsShown = true cardsPage.Show() end
		return
	end
	if cardsShown then cardsShown = false cardsPage.Hide() end
	gridScroll.Visible, detail.Visible = true, true
	buildGrid()
	renderDetail()
end

for _, t in TABS do
	tabBtns[t.id].b.MouseButton1Click:Connect(function()
		if tab == t.id or cardsPage.Busy() then return end
		tab = t.id
		selected = (tab ~= "cards" and itemsOf(tab)[1]) and itemsOf(tab)[1].id or nil
		armedId, toastText = nil, ""
		gridScroll.CanvasPosition = Vector2.zero
		refreshAll()
	end)
end

local function updateButton()
	local show = not shopOpen and not starterOpen and player:GetAttribute("StarterDone") == true and player:GetAttribute("LobbyMenuOpen") ~= true
	shopBtn.Visible = show
end

local function openShop()
	if shopOpen or starterOpen or player:GetAttribute("StarterDone") ~= true then return end
	shopOpen = true
	holdMenu()
	dim.Visible, stage.Visible = true, true
	shop.Visible, starter.Visible = true, false
	if tab ~= "cards" and (not selected or not Catalog.ById[selected]) then selected = itemsOf(tab)[1].id end
	armedId, toastText = nil, ""
	refreshAll()
	updateButton()
end
local function closeShop()
	if not shopOpen then return end
	if cardsPage.Busy() then return end -- v5.14: never close the shop under a pack that is opening
	if cardsShown then cardsShown = false cardsPage.Hide() end
	shopOpen = false
	dim.Visible, stage.Visible = false, false
	releaseMenu()
	updateButton()
end
shopBtn.MouseButton1Click:Connect(openShop)
closeBtn.MouseButton1Click:Connect(closeShop)
OpenR.OnClientEvent:Connect(function()
	if shopOpen then closeShop() else openShop() end
end)
UIS.InputBegan:Connect(function(input, gpe)
	if gpe or UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.Escape and shopOpen then
		if tab == "cards" and cardsPage.CloseOverlay() then return end -- v5.14: the pack view closes first; nothing while a pack opens
		closeShop()
	end
end)

player:GetAttributeChangedSignal("Souls"):Connect(function() if shopOpen then refreshAll() end end)
player:GetAttributeChangedSignal("Essence"):Connect(function() if shopOpen then refreshAll() end end)
player:GetAttributeChangedSignal("OwnedJson"):Connect(function() if shopOpen then refreshAll() end end)
player:GetAttributeChangedSignal("LobbyMenuOpen"):Connect(updateButton)
player:GetAttributeChangedSignal("StarterDone"):Connect(updateButton)

-- ================= STARTER PICK =================

local function buildStarter()
	local S = Catalog.Starter
	local pickW, pickM = nil, nil
	lbl(starter, "CHOOSE YOUR STARTING GEAR", 52, 0, 40, 1920, 64, K.text, F.H, Enum.TextXAlignment.Center)
	lbl(starter, "THESE TWO ARE YOURS FOR FREE  //  EVERYTHING ELSE CAN BE BOUGHT IN THE SHOP WITH SOULS", 13, 0, 108, 1920, 18, K.dim, F.M, Enum.TextXAlignment.Center)

	local confirm
	local statusLbl
	local function updateConfirm()
		local ready = pickW ~= nil and pickM ~= nil
		confirm.BackgroundColor3 = ready and K.red or K.panel3
		confirm.TextColor3 = ready and K.text or K.mute
		confirm.Text = ready and "START WITH THIS GEAR" or "PICK A WEAPON AND A MOVEMENT ABILITY"
	end

	local cards = { weapon = {}, move = {} }
	local function select_(kind, id)
		if kind == "weapon" then pickW = id else pickM = id end
		for cid, c in cards[kind] do
			local on = cid == id
			c.stroke.Color = on and K.red or K.line
			c.stroke.Thickness = on and 3 or 1
			c.tag.Visible = on
		end
		updateConfirm()
	end

	local function section(label, y)
		lbl(starter, label, 26, 180, y, 400, 34, K.text, F.H)
		box(starter, 180 + (#label * 17) + 24, y + 17, 1560 - (#label * 17) - 24, 1, K.line)
	end

	local CARD_W, CARD_H, GAP = 500, 250, 30
	local function card(kind, item, i, y)
		local x = 180 + (i - 1) * (CARD_W + GAP)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel, BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CARD_W, CARD_H) }, starter)
		local st = stroke(b, K.line, 1)
		hot(b, K.panel, K.panel2, st, K.line, K.line2)
		local well = box(b, 1, 1, CARD_W - 2, 150, K.void, 0.2)
		local pic = new("Frame", { Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -40, 1, -16), BackgroundTransparency = 1 }, well)
		itemPicture(pic, item, 96)
		lbl(b, string.upper(item.name), 30, 20, 156, 330, 36, K.text, F.H)
		if kind == "weapon" then
			local cfg = WeaponCfg.Get(item.id)
			lbl(b, string.upper(item.sub), 12, 21, 194, 300, 16, K.redHi, F.MB)
			local per = cfg.Damage * cfg.Pellets
			local rpm = cfg.FireMode == "Burst" and math.floor(60 / WeaponCfg.AvgInterval(cfg) + 0.5) or cfg.RPM
			lbl(b, ("DMG %d   //   %d RPM   //   %d RND"):format(per, rpm, cfg.MagSize), 12, 21, 216, 460, 18, K.dim, F.M)
		else
			lbl(b, string.upper(item.sub), 12, 21, 194, 300, 16, K.redHi, F.MB)
			local d = lbl(b, Catalog.Desc[item.id] or "", 12, 21, 212, CARD_W - 40, 36, K.dim, F.B, nil, true)
			d.TextTruncate = Enum.TextTruncate.AtEnd
		end
		local tag = box(b, CARD_W - 118, 14, 104, 26, K.red)
		lbl(tag, "SELECTED", 12, 0, 0, 104, 26, K.text, F.MB, Enum.TextXAlignment.Center)
		tag.Visible = false
		tag.ZIndex = 5
		for _, d in tag:GetChildren() do if d:IsA("GuiObject") then d.ZIndex = 6 end end
		cards[kind][item.id] = { stroke = st, tag = tag }
		b.MouseButton1Click:Connect(function() select_(kind, item.id) end)
	end

	section("WEAPON", 150)
	for i, id in S.Weapons do card("weapon", Catalog.ById[id], i, 192) end
	section("MOVEMENT", 468)
	for i, id in S.Moves do card("move", Catalog.ById[id], i, 510) end

	-- the starting gadgets (no choice)
	lbl(starter, "YOU ALSO START WITH", 13, 180, 784, 300, 18, K.dim, F.MB)
	for i, id in S.Gadgets do
		local item = Catalog.ById[id]
		local x = 180 + (i - 1) * 330
		local tile = box(starter, x, 810, 300, 84, K.panel, 0.1)
		stroke(tile, K.line, 1)
		local pw = box(tile, 0, 0, 96, 84, K.void, 0.3)
		local pf = new("Frame", { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 1, -8), BackgroundTransparency = 1 }, pw)
		itemPicture(pf, item, 40)
		lbl(tile, string.upper(item.name), 20, 108, 14, 184, 28, K.text, F.H)
		lbl(tile, "GADGET", 11, 109, 46, 180, 14, K.dim, F.M)
	end

	confirm = new("TextButton", { Text = "", TextSize = 22, FontFace = F.H, AutoButtonColor = false, BackgroundColor3 = K.panel3, BorderSizePixel = 0,
		Position = UDim2.fromOffset(660, 940), Size = UDim2.fromOffset(600, 72) }, starter)
	statusLbl = lbl(starter, "", 13, 0, 1020, 1920, 20, K.redHi, F.MB, Enum.TextXAlignment.Center)
	updateConfirm()
	local busy = false
	confirm.MouseButton1Click:Connect(function()
		if busy or not pickW or not pickM then return end
		busy = true
		confirm.Text = "..."
		local ok, res, msg = pcall(function() return StarterR:InvokeServer(pickW, pickM) end)
		if ok and res == true then
			starterOpen = false
			dim.Visible, stage.Visible = false, false
			starter.Visible = false
			releaseMenu()
			updateButton()
		else
			busy = false
			statusLbl.Text = string.upper((ok and msg) or "Could not reach the server.")
			updateConfirm()
		end
	end)
end

local starterBuilt = false
local function openStarter()
	if starterOpen then return end
	starterOpen = true
	if not starterBuilt then starterBuilt = true buildStarter() end
	holdMenu()
	closeShop()
	dim.Visible, stage.Visible = true, true
	shop.Visible = false
	starter.Visible = true
	updateButton()
end

-- once the profile is loaded: a player who never picked gets the choice
task.spawn(function()
	while player.Parent and player:GetAttribute("ProfileLoaded") ~= true do task.wait(0.2) end
	if player:GetAttribute("StarterDone") ~= true then
		task.wait(1.5) -- let the lobby loading screen finish
		openStarter()
	end
	updateButton()
end)
updateButton()
