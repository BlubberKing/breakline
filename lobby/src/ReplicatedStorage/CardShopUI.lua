-- CardShopUI v1.1 (ModuleScript in ReplicatedStorage) - LOBBY place only. NEW in v5.14 (GDD 5.9). Used by ShopClient (the CARDS tab).
-- v5.16 (owner Nov 8): FIRST STEPS cover = a SEEDLING (the walking feet looked AI); "1 CARD // 12 POSSIBLE" -> "12 CARDS" on a dark plate; BREAKLINE on the
--   pack bigger + white with an outline; NEW CARDS IN sits right next to the DAILY SHOP title; opening: the light pool above SKIP ROLL is gone, the slash is
--   a thin tapered anime crescent with afterimages + an impact frame (no blocks), tapered speed lines; CLAIM is a polished rarity-coloured button.
-- The CARDS tab has its own layout (not the item grid + detail panel of the other tabs):
--   DAILY SHOP  - three big cards side by side, picked every day (00:00 UTC) from the cards inside the packs that are on sale, by rarity weight
--                 (CardShop.DailyOffer). Each: the card, its name + rarity, the price in souls, BUY (asks twice: BUY -> CONFIRM). One copy per card per day.
--   CARD PACKS  - 3 packs per row. Every pack has its own cover art (drawn in code, PackArt below), name, tag, a short line, the price, BUY and a
--                 square EYE button that opens the big view: every card in the pack (12) with its chance, + the chance per rarity.
--   Buying a pack plays the OPENING: the screen goes dark, a spotlight falls on the pack, an anime-style slash flashes across the top and rips it
--   open, then the cards spin round in a circle (coming in from the left, passing in front, going out to the right) and slow down until one lands in
--   front; it grows big and CLAIM is the only button. SKIP ROLL (bottom) jumps straight to the result while it spins.
-- The server (CardShopServer) rolls the card BEFORE the animation starts; the animation only shows that result.
--   CardShopUI.Mount(parent, ctx) -> api      parent = the shop frame (1920 x 1080 canvas), ctx = { gui = the shop ScreenGui }
--   api.Show() / api.Hide() / api.Refresh() (repaint balances + buttons) / api.Busy() (true while a pack is opening)
--   CardShopUI.PackArt(parent, pack, width) -> holder   (design size 250 x 360, scaled)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local UI = require(RS:WaitForChild("UIKit"))
local K, F = UI.C, UI.F
local new = UI.new
local Cards = require(RS:WaitForChild("Cards"))
local CardArt = require(RS:WaitForChild("CardArt"))
local CardShop = require(RS:WaitForChild("CardShop"))
local Sfx do local m = RS:FindFirstChild("Sfx") if m then local ok, r = pcall(require, m) if ok then Sfx = r end end end
local function sfx(name) if Sfx then pcall(Sfx.Play, name) end end

local rgb = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tween(o, info, goal) local t = TweenService:Create(o, info, goal) t:Play() return t end
local function ti(t, style, dir) return TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out) end

local M = {}

-- ================= small builders =================
local function box(parent, x, y, w, h, color, transp, z)
	return new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = color or K.panel,
		BackgroundTransparency = transp or 0, BorderSizePixel = 0, ZIndex = z or 1 }, parent)
end
local function stroke(o, color, th, transp)
	return new("UIStroke", { Color = color, Thickness = th or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function corner(o, r) return new("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0) }, o) end
local function lbl(parent, text, size, x, y, w, h, color, font, align, z)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font or F.B, TextColor3 = color or K.text,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), TextXAlignment = align or Enum.TextXAlignment.Left, ZIndex = z or 1 }, parent)
end
local function commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
local function rarityTint(R) -- readable rarity colour on the dark UI (same rule as the Card Index)
	if R.id == "signature" then return WHITE end
	if R.id == "common" then return R.light end
	return R.glow
end
local function souls() return player:GetAttribute("Souls") or 0 end
local function priceRow(parent, x, y, price, size, z)
	local ic = UI.SoulIcon(parent, size)
	ic.Position = UDim2.fromOffset(x, y)
	ic.ZIndex = z or 1
	return lbl(parent, commas(price), math.floor(size * 0.9), x + size + 6, y - 2, 160, size + 4, K.text, F.H, nil, z)
end
local function hot(b, bg, bgHot)
	b.MouseEnter:Connect(function() if b:GetAttribute("Hot") ~= false then tween(b, FAST, { BackgroundColor3 = bgHot }) end end)
	b.MouseLeave:Connect(function() if b:GetAttribute("Hot") ~= false then tween(b, FAST, { BackgroundColor3 = bg }) end end)
end
local function bar(parent, x1, y1, x2, y2, th, col, transp, z)
	local dx, dy = x2 - x1, y2 - y1
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th * 0.5, th), Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = col,
		BackgroundTransparency = transp or 0, BorderSizePixel = 0, ZIndex = z or 1 }, parent)
	corner(f)
	return f
end

-- ======================================================================================
-- PACK ART (drawn from plain frames, design size 250 x 360). A foil pack: gradient body with a diagonal sheen, crimped top + bottom
-- (little teeth on the edges), a dashed TEAR line under the top crimp (where the opening rips it), BREAKLINE, a ringed emblem
-- (FIRST STEPS = a seedling (v5.16, was two footprints), SOUL PACK = the soul ghost, LEVEL UP = three stacked chevrons + a star), the pack name + tag.
-- ======================================================================================
M.PACK_W, M.PACK_H = 250, 360
M.TEAR_Y = 62 -- the tear line (design px from the top)

-- v5.16 FIRST STEPS emblem = a SEEDLING (owner: the walking feet looked AI-drawn; make it something completely different). Flat, inked shapes like the
-- other two emblems: a ground line with two seeds, a curved stem in three strokes, two capsule leaves with a vein + a highlight, a small bud on top.
local function pill(parent, cx, cy, w, h, rot, col, transp, z)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(w, h), Rotation = rot or 0,
		BackgroundColor3 = col, BackgroundTransparency = transp or 0, BorderSizePixel = 0, ZIndex = z or 5 }, parent)
	corner(f)
	return f
end
local function seedling(art, cx, col, ink)
	-- ground + two seeds
	pill(art, cx, 210, 96, 12, 0, col, 0.1, 5)
	pill(art, cx - 30, 222, 9, 6, -10, col, 0.35, 5)
	pill(art, cx + 26, 223, 7, 5, 12, col, 0.45, 5)
	-- stem (three strokes = a gentle S curve)
	bar(art, cx, 206, cx - 3, 186, 6, col, 0, 6)
	bar(art, cx - 3, 186, cx + 1, 166, 6, col, 0, 6)
	bar(art, cx + 1, 166, cx, 148, 5, col, 0, 6)
	-- leaves: a long axis capsule each, a darker vein down the middle, a light highlight on the upper edge
	local function leaf(lx, ly, w, h, rot)
		pill(art, lx, ly, w, h, rot, col, 0, 6)
		local r = math.rad(rot)
		pill(art, lx - math.sin(r) * h * 0.18, ly - math.cos(r) * h * 0.18, w * 0.62, h * 0.28, rot, WHITE, 0.6, 7)
		pill(art, lx, ly, w * 0.78, 2, rot, ink, 0.35, 7)
	end
	leaf(cx - 23, 160, 52, 22, 30)
	leaf(cx + 24, 140, 58, 24, -35)
	-- the new bud at the tip
	pill(art, cx + 2, 143, 14, 9, -70, col, 0, 6)
end

function M.PackArt(parent, pack, width)
	local L = pack.look
	local W, H = M.PACK_W, M.PACK_H
	width = width or W
	local holder = new("Frame", { Name = "Pack_" .. pack.id, BackgroundTransparency = 1, Size = UDim2.fromOffset(width, width * H / W) }, parent)
	local art = new("Frame", { Name = "Art", Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1 }, holder)
	new("UIScale", { Scale = width / W }, art)
	-- body
	local body = box(art, 0, 0, W, H, WHITE, 0, 2)
	body.Name = "Body"
	corner(body, 10)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, L.top:Lerp(WHITE, 0.12)), ColorSequenceKeypoint.new(0.5, L.top:Lerp(L.bottom, 0.45)), ColorSequenceKeypoint.new(1, L.bottom) }) }, body)
	stroke(body, L.ink, 2)
	-- diagonal foil sheen (a gradient band, so it never needs clipping)
	local sheen = box(art, 0, 0, W, H, WHITE, 0, 3)
	corner(sheen, 10)
	new("UIGradient", { Rotation = 38, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.38, 0.72), NumberSequenceKeypoint.new(0.43, 0.9),
		NumberSequenceKeypoint.new(0.47, 0.8), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }) }, sheen)
	-- crimped ends: a darker strip with ridge lines and square teeth along the outer edge
	local crimpCol = L.bottom:Lerp(BLACK, 0.35)
	for _, top in { true, false } do
		local y = top and 0 or H - 24
		local strip = box(art, 0, y, W, 24, crimpCol, 0.05, 4)
		corner(strip, 8)
		box(strip, 0, top and 12 or 0, W, 12, crimpCol, 0.05, 4) -- squares off the inner side of the rounded strip
		for x = 8, W - 8, 7 do box(strip, x, 4, 1, 16, L.accent, 0.7, 5) end
		for x = 4, W - 10, 12 do box(art, x, top and -4 or H, 6, 4, crimpCol, 0.05, 4) end
	end
	-- tear line + a tiny "TEAR" mark
	for x = 10, W - 18, 12 do box(art, x, M.TEAR_Y, 7, 2, L.accent, 0.25, 5) end
	lbl(art, "TEAR", 9, W - 40, M.TEAR_Y - 13, 34, 10, L.accent, F.MB, Enum.TextXAlignment.Right, 5).TextTransparency = 0.25
	-- BREAKLINE
	-- v5.16: bigger + white with an ink outline (it was a small, pale mono line that disappeared on the foil)
	local bl = lbl(art, "B R E A K L I N E", 19, 0, 29, W, 24, WHITE, F.H, Enum.TextXAlignment.Center, 5)
	stroke(bl, L.ink, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	-- emblem ring
	local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2, 168), Size = UDim2.fromOffset(140, 140),
		BackgroundColor3 = L.accent, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 4 }, art)
	corner(ring)
	stroke(ring, L.accent, 3, 0.1)
	local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(116, 116),
		BackgroundTransparency = 1, ZIndex = 4 }, ring)
	corner(inner)
	stroke(inner, L.accent, 1, 0.5)
	local em = L.emblem
	if em == "steps" then
		seedling(art, W / 2, L.accent, L.ink) -- v5.16 (was two footprints)
	elseif em == "soul" then
		local s = UI.SoulIcon(art, 104)
		s.AnchorPoint, s.Position, s.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromOffset(W / 2, 170), 4
		for _, d in s:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 5 end end
	else -- levelup: three stacked chevrons + a star spark
		for i = 0, 2 do
			local cy = 196 - i * 26
			local tr = i == 2 and 0 or 0.15 + (2 - i) * 0.12
			bar(art, W / 2 - 34, cy + 14, W / 2, cy - 10, 9, L.accent, tr, 5)
			bar(art, W / 2 + 34, cy + 14, W / 2, cy - 10, 9, L.accent, tr, 5)
		end
		for _, r in { 0, 90 } do
			local st = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W / 2 + 46, 114), Size = UDim2.fromOffset(18, 3), Rotation = r,
				BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 5 }, art)
			corner(st)
		end
	end
	-- name + tag
	local nm = lbl(art, pack.name, 40, 0, 248, W, 48, WHITE, F.H, Enum.TextXAlignment.Center, 5)
	stroke(nm, L.ink, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	lbl(art, pack.tag, 12, 0, 293, W, 16, L.accent, F.MB, Enum.TextXAlignment.Center, 5)
	-- v5.16: "1 CARD // 12 POSSIBLE" -> "12 CARDS", big and on a dark plate so it reads on every pack colour
	local plate = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(W / 2, 312), Size = UDim2.fromOffset(108, 23),
		BackgroundColor3 = L.ink, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 5 }, art)
	corner(plate, 5)
	stroke(plate, L.accent, 1, 0.5)
	lbl(plate, tostring(#(pack.entries or {}) > 0 and #pack.entries or 12) .. " CARDS", 17, 0, 0, 108, 23, WHITE, F.H, Enum.TextXAlignment.Center, 6)
	return holder
end

-- ======================================================================================
-- MOUNT: the CARDS tab page
-- ======================================================================================
function M.Mount(parent, ctx)
	ctx = ctx or {}
	local api = {}
	local opening = false
	local stateData = nil
	local armed, armedAt = nil, 0 -- "daily:2" / "pack:soul_pack"
	local CONFIRM_TIME = 3

	local root = new("Frame", { Name = "CardsPage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 2 }, parent)
	local page = new("ScrollingFrame", { Position = UDim2.fromOffset(56, 212), Size = UDim2.fromOffset(1808, 826), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = K.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 2 }, root)
	new("UIPadding", { PaddingBottom = UDim.new(0, 40) }, page)
	local toast = lbl(root, "", 14, 0, 1046, 1920, 22, K.green, F.MB, Enum.TextXAlignment.Center, 3)
	local function say(text, good)
		toast.Text = text or ""
		toast.TextColor3 = good and K.green or K.redHi
		local t = text
		task.delay(4, function() if toast.Text == t then toast.Text = "" end end)
	end

	local PW, GAP = 580, 26 -- panel width / gap (3 per row across 1792)
	local repaintFns = {}

	-- ---------- a BUY button that asks twice ----------
	local function buyButton(parent2, x, y, w, h, key, price, onBuy, z)
		local b = new("TextButton", { Text = "BUY", TextSize = 22, FontFace = F.H, TextColor3 = K.text, BackgroundColor3 = K.red, AutoButtonColor = false,
			BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 3 }, parent2)
		hot(b, K.red, K.redHi)
		local function paint()
			local can = souls() >= price
			local isArmed = armed == key and os.clock() - armedAt < CONFIRM_TIME
			b:SetAttribute("Hot", can)
			b.Text = isArmed and "CONFIRM" or "BUY"
			b.BackgroundColor3 = can and (isArmed and K.redHi or K.red) or K.panel3
			b.TextColor3 = can and K.text or K.mute
		end
		b.MouseButton1Click:Connect(function()
			if opening then return end
			if souls() < price then say("Not enough souls. Win matches to earn more.", false) return end
			if armed ~= key or os.clock() - armedAt >= CONFIRM_TIME then
				armed, armedAt = key, os.clock()
				for _, fn in repaintFns do fn() end
				task.delay(CONFIRM_TIME + 0.05, function()
					if armed == key and os.clock() - armedAt >= CONFIRM_TIME then armed = nil for _, fn in repaintFns do fn() end end
				end)
				return
			end
			armed = nil
			b.Text = "..."
			onBuy()
		end)
		table.insert(repaintFns, paint)
		paint()
		return b
	end

	-- ---------- header rows ----------
	local function header(y, text)
		lbl(page, text, 40, 8, y, 700, 52, K.text, F.H, nil, 3)
		box(page, 8, y + 58, 1792, 1, K.line, 0, 3)
	end
	-- v5.16: NEW CARDS IN sits right next to the DAILY SHOP title (it was pushed all the way to the right edge)
	local dRow = new("Frame", { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(1792, 52), BackgroundTransparency = 1, ZIndex = 3 }, page)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 20) }, dRow)
	new("TextLabel", { BackgroundTransparency = 1, Text = "DAILY SHOP", TextSize = 40, FontFace = F.H, TextColor3 = K.text, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 52), LayoutOrder = 1, ZIndex = 3 }, dRow)
	local timerLbl = new("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 17, FontFace = F.MB, TextColor3 = K.dim, RichText = true,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, ZIndex = 3 }, dRow)
	box(page, 8, 58, 1792, 1, K.line, 0, 3)

	-- ---------- DAILY SHOP (3 big cards) ----------
	local DY, DH = 76, 540
	local dailyHolder = new("Frame", { Position = UDim2.fromOffset(0, DY), Size = UDim2.fromOffset(1808, DH), BackgroundTransparency = 1, ZIndex = 2 }, page)
	local dailyRepaint = {}
	local dailyBuilt = nil -- day number the panels were built for

	local refreshState -- forward
	local function buildDaily()
		for _, c in dailyHolder:GetChildren() do c:Destroy() end
		for i = #repaintFns, 1, -1 do if table.find(dailyRepaint, repaintFns[i]) then table.remove(repaintFns, i) end end
		table.clear(dailyRepaint)
		if not stateData then
			lbl(dailyHolder, "LOADING TODAY'S CARDS...", 22, 0, 220, 1808, 40, K.mute, F.H, Enum.TextXAlignment.Center, 3)
			return
		end
		dailyBuilt = stateData.day
		for i, o in stateData.daily do
			local R = Cards.RarityById[o.rarity] or Cards.Rarities[1]
			local card = Cards.ById[o.id]
			local x = 8 + (i - 1) * (PW + GAP)
			local panel = box(dailyHolder, x, 0, PW, DH, K.panel, 0.04, 2)
			stroke(panel, K.line, 1)
			local topLine = box(panel, 0, 0, PW, 3, rarityTint(R), 0, 3)
			local _ = topLine
			-- soft rarity glow behind the card
			local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(PW / 2, 196), Size = UDim2.fromOffset(330, 330),
				BackgroundColor3 = R.glow, BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 2 }, panel)
			corner(glow)
			local ch = CardArt.Build(panel, o.id, { width = 250, anim = false, rarity = o.rarity, position = UDim2.fromOffset(PW / 2, 196), anchor = Vector2.new(0.5, 0.5) })
			if ch then ch.ZIndex = 3 end
			lbl(panel, string.upper(card and card.name or o.id), 26, 24, 382, PW - 48, 32, K.text, F.H, nil, 3)
			lbl(panel, R.name, 13, 25, 414, 300, 18, rarityTint(R), F.MB, nil, 3)
			box(panel, 24, 444, PW - 48, 1, K.line, 0, 3)
			if o.bought then
				local tag = box(panel, 24, 462, PW - 48, 56, rgb(18, 52, 34), 0, 3)
				stroke(tag, K.green, 1)
				lbl(tag, "BOUGHT  -  BACK TOMORROW", 18, 0, 0, PW - 48, 56, K.green, F.H, Enum.TextXAlignment.Center, 4)
			else
				priceRow(panel, 24, 474, o.price, 30, 3)
				local before = #repaintFns
				buyButton(panel, PW - 24 - 220, 462, 220, 56, "daily:" .. o.slot, o.price, function()
					local remotes = RS:FindFirstChild("CardShopRemotes")
					local ok, res, msg = pcall(function() return remotes.BuyDaily:InvokeServer(o.slot) end)
					if ok and res == true then
						say(msg or "Bought.", true)
						sfx("CardPick")
					else
						say((ok and msg) or "Could not reach the server.", false)
					end
					refreshState()
				end, 3)
				for k2 = before + 1, #repaintFns do table.insert(dailyRepaint, repaintFns[k2]) end
			end
		end
	end

	-- ---------- CARD PACKS ----------
	local PY = DY + DH + 44
	header(PY, "CARD PACKS")
	local PACK_PH = 620
	local viewer -- forward (the eye view)
	local openPack -- forward (the opening animation)
	local packsY = PY + 76
	local onSale = {}
	for _, p in CardShop.Packs do if p.onSale then table.insert(onSale, p) end end
	for i, pack in onSale do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local x, y = 8 + col * (PW + GAP), packsY + row * (PACK_PH + GAP)
		local panel = box(page, x, y, PW, PACK_PH, K.panel, 0.04, 2)
		stroke(panel, K.line, 1)
		box(panel, 0, 0, PW, 3, pack.look.top, 0, 3)
		local well = box(panel, 1, 1, PW - 2, 404, K.void, 0.25, 2)
		-- a soft pool of the pack colour behind the pack
		local pool = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(PW / 2, 210), Size = UDim2.fromOffset(360, 360),
			BackgroundColor3 = pack.look.top, BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 2 }, well)
		corner(pool)
		local art = M.PackArt(panel, pack, 250)
		art.AnchorPoint, art.Position, art.ZIndex = Vector2.new(0.5, 0), UDim2.fromOffset(PW / 2, 24), 3
		lbl(panel, pack.name, 32, 24, 418, PW - 48, 38, K.text, F.H, nil, 3)
		lbl(panel, pack.tag, 12, 25, 456, PW - 48, 16, pack.look.top, F.MB, nil, 3)
		local d = lbl(panel, pack.desc, 13, 24, 478, PW - 48, 52, K.dim, F.B, nil, 3)
		d.TextWrapped, d.TextYAlignment = true, Enum.TextYAlignment.Top
		box(panel, 24, 540, PW - 48, 1, K.line, 0, 3)
		priceRow(panel, 24, 564, pack.price, 30, 3)
		buyButton(panel, PW - 24 - 64 - 12 - 200, 554, 200, 52, "pack:" .. pack.id, pack.price, function()
			local remotes = RS:FindFirstChild("CardShopRemotes")
			local ok, res, msg, result = pcall(function() return remotes.BuyPack:InvokeServer(pack.id) end)
			for _, fn in repaintFns do fn() end
			if ok and res == true and type(result) == "table" then
				openPack(pack, result)
			else
				say((ok and msg) or "Could not reach the server.", false)
			end
		end, 3)
		-- the EYE button (square): what is inside + the chances
		local eye = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel2, BorderSizePixel = 0,
			Position = UDim2.fromOffset(PW - 24 - 64, 554), Size = UDim2.fromOffset(64, 52), ZIndex = 3 }, panel)
		local est = stroke(eye, K.line2, 1)
		hot(eye, K.panel2, K.panel3)
		eye.MouseEnter:Connect(function() est.Color = K.text end)
		eye.MouseLeave:Connect(function() est.Color = K.line2 end)
		do -- eye drawn from an almond (two arcs faked with a rounded, squashed frame) + iris + pupil + glint
			local almond = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(36, 20),
				BackgroundTransparency = 1, ZIndex = 4 }, eye)
			corner(almond)
			stroke(almond, K.text, 2.5)
			local iris = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(13, 13),
				BackgroundColor3 = K.text, BorderSizePixel = 0, ZIndex = 5 }, eye)
			corner(iris)
			local pupil = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 5),
				BackgroundColor3 = K.panel, BorderSizePixel = 0, ZIndex = 6 }, iris)
			corner(pupil)
		end
		eye.MouseButton1Click:Connect(function() if not opening then viewer(pack) end end)
	end

	-- ---------- timer + state ----------
	local function fmt(sec)
		sec = math.max(0, math.floor(sec))
		return ("%02d:%02d:%02d"):format(sec // 3600, (sec % 3600) // 60, sec % 60)
	end
	local fetching = false
	function refreshState()
		if fetching then return end
		fetching = true
		task.spawn(function()
			local remotes = RS:WaitForChild("CardShopRemotes", 10)
			local ok, st = false, nil
			if remotes then ok, st = pcall(function() return remotes.GetState:InvokeServer() end) end
			fetching = false
			if ok and type(st) == "table" and type(st.daily) == "table" then
				stateData = st
				buildDaily()
			elseif not stateData then
				buildDaily()
			end
		end)
	end
	local timerConn = nil
	local function startTimer()
		if timerConn then return end
		local acc = 1
		timerConn = RunService.Heartbeat:Connect(function(dt)
			acc += dt
			if acc < 0.25 then return end
			acc = 0
			if not stateData then timerLbl.Text = "" return end
			local remain = stateData.endsAt - workspace:GetServerTimeNow()
			timerLbl.Text = 'NEW CARDS IN  <font color="#FFFFFF">' .. fmt(remain) .. "</font>"
			if remain <= 0 and not fetching then refreshState() end
		end)
	end

	-- ======================================================================================
	-- EYE VIEW: every card in the pack + its chance
	-- ======================================================================================
	local viewLayer = new("TextButton", { Name = "PackView", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(4, 5, 7),
		BackgroundTransparency = 0.12, BorderSizePixel = 0, Visible = false, ZIndex = 40 }, root)
	local viewPanel = nil
	local function closeViewer()
		viewLayer.Visible = false
		if viewPanel then viewPanel:Destroy() viewPanel = nil end
	end
	viewLayer.MouseButton1Click:Connect(closeViewer)
	function viewer(pack)
		closeViewer()
		viewLayer.Visible = true
		local VW, VH = 1640, 920
		local p = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 560),
			Size = UDim2.fromOffset(VW, VH), BackgroundColor3 = K.panel, BorderSizePixel = 0, ZIndex = 41 }, viewLayer)
		viewPanel = p
		stroke(p, K.line2, 1)
		box(p, 0, 0, VW, 3, pack.look.top, 0, 42)
		-- left: the pack, its name + price, chance per rarity
		local art = M.PackArt(p, pack, 280)
		art.Position = UDim2.fromOffset(44, 40)
		art.ZIndex = 42
		lbl(p, pack.name, 40, 40, 460, 330, 48, K.text, F.H, nil, 42)
		lbl(p, pack.tag, 12, 41, 508, 330, 16, pack.look.top, F.MB, nil, 42)
		priceRow(p, 40, 538, pack.price, 28, 42)
		lbl(p, "CHANCE PER RARITY", 11, 41, 590, 330, 14, K.dim, F.MB, nil, 42)
		local per, order = {}, {}
		for _, o in CardShop.Odds(pack.id) do
			if not per[o.rarity] then per[o.rarity] = 0 table.insert(order, o.rarity) end
			per[o.rarity] += o.chance
		end
		table.sort(order, function(a, b) return Cards.RarityById[a].rank < Cards.RarityById[b].rank end)
		local ry = 614
		for _, rid in order do
			local R = Cards.RarityById[rid]
			lbl(p, R.name, 13, 41, ry, 150, 18, rarityTint(R), F.MB, nil, 42)
			lbl(p, ("%.1f%%"):format(per[rid] * 100), 14, 250, ry, 104, 18, K.text, F.MB, Enum.TextXAlignment.Right, 42)
			local track = box(p, 41, ry + 21, 313, 4, K.panel3, 0, 42)
			box(track, 0, 0, math.max(2, math.floor(313 * per[rid])), 4, rarityTint(R), 0, 43)
			ry += 34
		end
		box(p, 400, 30, 1, VH - 60, K.line, 0, 42)
		-- right: the 12 cards, 4 x 3
		lbl(p, "WHAT'S INSIDE", 30, 432, 26, 600, 40, K.text, F.H, nil, 42)
		lbl(p, "ONE CARD PER PACK  //  12 POSSIBLE CARDS", 11, 433, 66, 600, 14, K.dim, F.MB, nil, 42)
		local closeBtn = UI.CloseButton(p, "CLOSE", { Position = UDim2.fromOffset(VW - 152 - 28, 26), ZIndex = 43 })
		closeBtn.MouseButton1Click:Connect(closeViewer)
		local odds = CardShop.Odds(pack.id)
		table.sort(odds, function(a, b)
			local ra, rb = Cards.RarityById[a.rarity].rank, Cards.RarityById[b.rarity].rank
			if ra ~= rb then return ra > rb end
			return a.index < b.index
		end)
		local CW, CH, CG = 284, 248, 16
		for i, o in odds do
			local c, r = (i - 1) % 4, math.floor((i - 1) / 4)
			local cell = box(p, 432 + c * (CW + CG), 100 + r * (CH + CG), CW, CH, K.panel2, 0, 42)
			local R = Cards.RarityById[o.rarity]
			stroke(cell, K.line, 1)
			box(cell, 0, 0, 3, CH, rarityTint(R), 0, 43)
			local holderTask = cell
			task.spawn(function() -- one card per frame, no hitch
				task.wait((i - 1) * 0.02)
				if holderTask.Parent then
					local h = CardArt.Build(holderTask, o.id, { width = 150, anim = false, rarity = o.rarity, position = UDim2.fromOffset(16, 19) })
					h.ZIndex = 43
				end
			end)
			local card = Cards.ById[o.id]
			lbl(cell, R.name, 12, 180, 26, 100, 16, rarityTint(R), F.MB, nil, 43)
			lbl(cell, ("%.1f%%"):format(o.chance * 100), 34, 180, 46, 100, 44, K.text, F.H, nil, 43)
			lbl(cell, "CHANCE", 10, 181, 90, 100, 12, K.mute, F.MB, nil, 43)
			local nm = lbl(cell, string.upper(card and card.name or o.id), 14, 180, 150, 96, 40, K.dim, F.H, nil, 43)
			nm.TextWrapped, nm.TextYAlignment = true, Enum.TextYAlignment.Top
		end
	end

	-- ======================================================================================
	-- OPENING ANIMATION
	-- ======================================================================================
	local openGui = new("ScreenGui", { Name = "CardPackOpen", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
	new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) }, openGui)

	local function weightedPick(odds, rng)
		local total = 0
		for _, o in odds do total += o.weight end
		local x = rng:NextNumber() * total
		for _, o in odds do x -= o.weight if x <= 0 then return o end end
		return odds[#odds]
	end

	function openPack(pack, result)
		if opening then return end
		opening = true
		closeViewer()
		openGui.Enabled = true
		local L = pack.look
		local resR = Cards.RarityById[result.rarity] or Cards.Rarities[1]
		local alive = true

		local blocker = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1,
			BorderSizePixel = 0, ZIndex = 1 }, openGui)
		local stage = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080),
			BackgroundTransparency = 1, ZIndex = 2 }, openGui)
		local sc = new("UIScale", {}, stage)
		local function rescale()
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			sc.Scale = math.min(vp.X / 1920, vp.Y / 1080)
		end
		rescale()
		local camConn = workspace.CurrentCamera and workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

		-- 1) the room goes dark
		tween(blocker, ti(0.35), { BackgroundTransparency = 0.04 })
		sfx("MenuOpen")
		-- spotlight: a cone of fanned soft strips from above + a pool of light on the "floor"
		local beam = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, stage)
		local beamParts = {}
		for i = -6, 6 do
			local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, -80), Size = UDim2.fromOffset(70, 1120), Rotation = i * 2.1,
				BackgroundColor3 = rgb(255, 246, 226), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2 }, beam)
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.55, 0.84),
				NumberSequenceKeypoint.new(0.74, 1), NumberSequenceKeypoint.new(1, 1) }) }, s)
			table.insert(beamParts, { f = s, tr = 0.93 + math.abs(i) * 0.006 })
		end
		for _, b in beamParts do tween(b.f, ti(0.6), { BackgroundTransparency = b.tr }) end
		-- v5.16: the stacked "pool of light" ellipses that sat right above SKIP ROLL are gone (owner: the gradient lighting there looked bad); the
		-- beam itself now fades out before it reaches the lower part of the screen
		local poolParts = {}

		-- the pack, split along the tear line into two CanvasGroups (so the top can rip away cleanly)
		local PS = 330 / M.PACK_W -- pack shown 330 wide
		local PWd, PHd = 330, M.PACK_H * PS
		local tearPx = M.TEAR_Y * PS
		local packRoot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, -420), Size = UDim2.fromOffset(PWd, PHd),
			BackgroundTransparency = 1, ZIndex = 10 }, stage)
		local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(PWd * 1.6, PWd * 1.6),
			BackgroundColor3 = L.top, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9 }, packRoot)
		corner(glow)
		local topG = new("CanvasGroup", { Size = UDim2.fromOffset(PWd, tearPx + 1), BackgroundTransparency = 1, ZIndex = 11 }, packRoot)
		local topArt = M.PackArt(topG, pack, PWd)
		topArt.Position = UDim2.fromOffset(0, 0)
		local botG = new("CanvasGroup", { Position = UDim2.fromOffset(0, tearPx), Size = UDim2.fromOffset(PWd, PHd - tearPx + 6), BackgroundTransparency = 1, ZIndex = 11 }, packRoot)
		local botArt = M.PackArt(botG, pack, PWd)
		botArt.Position = UDim2.fromOffset(0, -tearPx)
		local packScale = new("UIScale", { Scale = 1 }, packRoot)

		-- build the carousel cards now (while the pack drops in), so the roll never hitches
		local N = 12
		local odds = CardShop.Odds(pack.id)
		local rng = Random.new()
		local winIdx = 1
		local slots = {}
		local ring = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Visible = false }, stage)
		local CWd = 230
		local buildDone = false
		task.spawn(function()
			for i = 1, N do
				local entry = (i == winIdx) and { id = result.id, rarity = result.rarity } or weightedPick(odds, rng)
				local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(CWd, CWd * 1.4), BackgroundTransparency = 1, ZIndex = 21 }, ring)
				local us = new("UIScale", { Scale = 0.5 }, holder)
				local ok = pcall(function() CardArt.Build(holder, entry.id, { width = CWd, anim = false, rarity = entry.rarity }) end)
				if not ok then lbl(holder, "?", 80, 0, 0, CWd, CWd * 1.4, WHITE, F.H, Enum.TextXAlignment.Center) end
				local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 30 }, holder)
				corner(shade, 8)
				slots[i] = { holder = holder, us = us, shade = shade }
				if i % 3 == 0 then task.wait() end
			end
			buildDone = true
		end)

		local function cleanup()
			alive = false
			if camConn then camConn:Disconnect() end
			for _, c in openGui:GetChildren() do if c.Name ~= "ModalCursor" then c:Destroy() end end
			openGui.Enabled = false
			opening = false
			refreshState()
			for _, fn in repaintFns do fn() end
		end

		task.spawn(function()
			-- 2) the pack drops into the spotlight and starts to tremble
			tween(packRoot, ti(0.65, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(960, 500) })
			tween(glow, ti(0.8), { BackgroundTransparency = 0.82 })
			task.wait(0.7)
			local t0 = os.clock()
			while os.clock() - t0 < 0.75 and alive do
				local u = (os.clock() - t0) / 0.75
				local a = 1 + u * 4
				packRoot.Rotation = math.sin(os.clock() * 48) * a * 0.5
				packRoot.Position = UDim2.fromOffset(960 + math.sin(os.clock() * 61) * a, 500 + math.cos(os.clock() * 53) * a * 0.6)
				packScale.Scale = 1 + u * 0.05
				glow.BackgroundTransparency = 0.82 - u * 0.14
				RunService.RenderStepped:Wait()
			end
			packRoot.Rotation, packRoot.Position = 0, UDim2.fromOffset(960, 500)
			if not alive then return end

			-- 3) the anime slash: a white-hot streak rips across the tear line, flash, speed lines, the top flies off
			local cutY = 500 - PHd * 1.05 / 2 + tearPx * 1.05
			-- v5.16 ANIME SLASH (owner: less blocky, more anime, less AI): ONE thin crescent drawn from short segments along a shallow arc - sharp at both
			-- ends, thickest in the middle - that is revealed tip-first in under a tenth of a second, with two thinner coloured afterimages trailing it,
			-- a glint at the tip, an impact frame (a dark blink, then the white flash), and then it thins out to a hairline and is gone. No blocks, no bars.
			local SEG = 40
			local x0, x1 = 960 - PWd * 0.98, 960 + PWd * 0.98
			local function arcPt(u, dy)
				return Vector2.new(x0 + (x1 - x0) * u, cutY + (0.5 - u) * 26 + math.sin(u * math.pi) * 9 + (dy or 0))
			end
			local layers = {
				{ th = 7, col = WHITE, tr = 0, delay = 0, dy = 0, z = 42 },
				{ th = 4, col = L.accent, tr = 0.2, delay = 0.025, dy = 6, z = 41 },
				{ th = 2.5, col = L.accent:Lerp(WHITE, 0.5), tr = 0.35, delay = 0.045, dy = -5, z = 41 },
			}
			local segs = {}
			for li, ly in layers do
				for k = 1, SEG do
					local u0, u1 = (k - 1) / SEG, k / SEG
					local a, b = arcPt(u0, ly.dy), arcPt(u1, ly.dy)
					local th = math.max(0.6, ly.th * math.sin((u0 + u1) / 2 * math.pi) ^ 0.8)
					local d = b - a
					local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
						Size = UDim2.fromOffset(d.Magnitude + 1.2, th), Rotation = math.deg(math.atan2(d.Y, d.X)), BackgroundColor3 = ly.col,
						BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = ly.z }, stage)
					corner(f)
					table.insert(segs, { f = f, u = u0, layer = li, th = th, tr = ly.tr, delay = ly.delay })
				end
			end
			sfx("CardLand")
			local REVEAL = 0.085
			local s0 = os.clock()
			while alive do
				local e = os.clock() - s0
				local done = true
				for _, sg in segs do
					local prog = (e - sg.delay) / REVEAL
					if prog < 1.05 then done = false end
					if sg.f.BackgroundTransparency >= 1 and prog >= sg.u then sg.f.BackgroundTransparency = sg.tr end
				end
				if done then break end
				RunService.RenderStepped:Wait()
			end
			-- glint at the tip (two crossed thin strokes that pop and shrink)
			local tip = arcPt(1, 0)
			for _, r in { 0, 90, 45 } do
				local g = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(tip.X, tip.Y), Size = UDim2.fromOffset(r == 45 and 26 or 54, 2),
					Rotation = r, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 44 }, stage)
				corner(g)
				tween(g, ti(0.3, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(2, 1), BackgroundTransparency = 1 })
				task.delay(0.32, function() g:Destroy() end)
			end
			-- impact frame: a dark blink first (the classic anime hit frame), then the white flash
			local blink = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 59 }, openGui)
			task.delay(0.045, function() blink:Destroy() end)
			task.wait(0.045)
			local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 60 }, openGui)
			tween(flash, ti(0.45), { BackgroundTransparency = 1 })
			-- the crescent thins to a hairline, slides on a touch and vanishes
			for _, sg in segs do
				local f = sg.f
				tween(f, ti(0.28, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(f.Size.X.Offset, 0.4), BackgroundTransparency = 1,
					Position = f.Position + UDim2.fromOffset(14, -4) })
				task.delay(0.3, function() f:Destroy() end)
			end
			-- speed lines bursting out of the cut
			for k = 1, 26 do
				local ang = math.rad(k * (360 / 26) + rng:NextNumber() * 8)
				local len = 140 + rng:NextNumber() * 320
				local r0 = 60 + rng:NextNumber() * 40
				local ln = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(960 + math.cos(ang) * r0, cutY + math.sin(ang) * r0),
					Size = UDim2.fromOffset(10, 1 + rng:NextInteger(0, 1)), Rotation = math.deg(ang), BackgroundColor3 = (k % 3 == 0) and L.accent or WHITE,
					BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 45 }, stage)
				-- v5.16: tapered (solid at the cut, fading to nothing at the tip) instead of flat rectangles
				new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 1) }) }, ln)
				tween(ln, ti(0.42, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(len, 1), Position = UDim2.fromOffset(960 + math.cos(ang) * (r0 + len * 0.6), cutY + math.sin(ang) * (r0 + len * 0.6)), BackgroundTransparency = 1 })
				task.delay(0.5, function() ln:Destroy() end)
			end
			-- the torn top flies up and spins away, light pours out of the opening
			tween(topG, ti(0.55, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(PWd * 0.55, -260), Rotation = 28, GroupTransparency = 1 })
			local burst = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(PWd / 2, tearPx + 4), Size = UDim2.fromOffset(PWd * 0.8, 10),
				BackgroundColor3 = L.accent, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 12 }, packRoot)
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, burst)
			tween(burst, ti(0.5, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(PWd * 1.2, 520), BackgroundTransparency = 0.5 })
			task.wait(0.4)
			-- the pack body drops away
			tween(packRoot, ti(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(960, 1300) })
			tween(botG, ti(0.45), { GroupTransparency = 0.6 })
			tween(burst, ti(0.4), { BackgroundTransparency = 1 })
			tween(glow, ti(0.4), { BackgroundTransparency = 1 })
			while not buildDone and alive do task.wait() end
			if not alive then return end

			-- 4) THE ROLL: cards on a circle, front cards travel left -> right, slowing down until the winner is in front
			ring.Visible = true
			local CX, CY, RX = 960, 470, 640
			local step = math.pi * 2 / N
			local TURNS = 4
			local finalBase = TURNS * math.pi * 2 - (winIdx - 1) * step
			local startBase = finalBase - TURNS * math.pi * 2 - math.pi * 0.6
			local DUR = 5.4
			local skip = false
			local skipBtn = new("TextButton", { Text = "SKIP ROLL", TextSize = 20, FontFace = F.H, TextColor3 = K.text, BackgroundColor3 = K.panel2,
				AutoButtonColor = false, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 960), Size = UDim2.fromOffset(220, 52),
				ZIndex = 50, BackgroundTransparency = 1, TextTransparency = 1 }, stage)
			local skSt = stroke(skipBtn, K.line2, 1, 1)
			hot(skipBtn, K.panel2, K.red)
			tween(skipBtn, ti(0.3), { BackgroundTransparency = 0.05, TextTransparency = 0 })
			tween(skSt, ti(0.3), { Transparency = 0 })
			skipBtn.MouseButton1Click:Connect(function() skip = true end)
			local function place(base)
				for i, s in slots do
					local th = base + (i - 1) * step
					local depth = math.cos(th) -- 1 = in front
					local x = CX + math.sin(th) * RX
					local y = CY + (1 - depth) * -40
					local scl = 0.52 + (depth + 1) / 2 * 0.53
					s.holder.Position = UDim2.fromOffset(x, y)
					s.us.Scale = scl
					s.holder.ZIndex = 21 + math.floor((depth + 1) * 20)
					s.shade.BackgroundTransparency = 0.15 + (depth + 1) / 2 * 0.85
				end
			end
			place(startBase)
			local rt0 = os.clock()
			local lastTick = math.floor(startBase / step)
			while alive do
				local u = math.clamp((os.clock() - rt0) / DUR, 0, 1)
				if skip then u = 1 end
				local e = 1 - (1 - u) ^ 4
				local base = startBase + (finalBase - startBase) * e
				place(base)
				local tick = math.floor(base / step + 0.5)
				if tick ~= lastTick then lastTick = tick sfx("CardTick") end
				if u >= 1 then break end
				RunService.RenderStepped:Wait()
			end
			if not alive then return end
			skipBtn:Destroy()

			-- 5) LANDED: the others fall away, the winner grows big, CLAIM
			for i, s in slots do
				if i ~= winIdx then
					tween(s.us, ti(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.1 })
					tween(s.shade, ti(0.3), { BackgroundTransparency = 0 })
					task.delay(0.36, function() s.holder.Visible = false end)
				end
			end
			for _, b in beamParts do tween(b.f, ti(0.5), { BackgroundColor3 = resR.glow }) end
			for _, pp in poolParts do tween(pp.f, ti(0.5), { BackgroundColor3 = resR.glow }) end
			sfx(resR.rank >= 4 and "CardRare" or "CardLand")
			local win = slots[winIdx]
			tween(win.us, ti(0.25), { Scale = 1.1 })
			task.wait(0.22)
			local flash2 = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = resR.glow:Lerp(WHITE, 0.5), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 60 }, openGui)
			tween(flash2, ti(0.5), { BackgroundTransparency = 1 })
			win.holder.Visible = false
			-- rarity rays behind the big card
			local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 470), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 22 }, stage)
			for k = 0, 11 do
				local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1100, 26), Rotation = k * 15,
					BackgroundColor3 = resR.glow, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 22 }, rays)
				new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, r)
			end
			task.spawn(function()
				while alive and rays.Parent do
					rays.Rotation += 0.25
					RunService.RenderStepped:Wait()
				end
			end)
			local bigW = 360
			local bigHolder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 470), Size = UDim2.fromOffset(bigW, bigW * 1.4),
				BackgroundTransparency = 1, ZIndex = 30 }, stage)
			local bigScale = new("UIScale", { Scale = 0.6 }, bigHolder)
			pcall(function() CardArt.Build(bigHolder, result.id, { width = bigW, anim = true, rarity = result.rarity }) end)
			tween(bigScale, ti(0.45, Enum.EasingStyle.Back), { Scale = 1 })
			local card = Cards.ById[result.id]
			local rn = lbl(stage, resR.name, 30, 0, 190, 1920, 40, rarityTint(resR), F.H, Enum.TextXAlignment.Center, 35)
			rn.Position = UDim2.fromOffset(0, 150)
			rn.TextTransparency = 1
			tween(rn, ti(0.4), { TextTransparency = 0, Position = UDim2.fromOffset(0, 168) })
			local got = lbl(stage, "NEW CARD  //  " .. string.upper(card and card.name or result.id), 14, 0, 976, 1920, 20, K.dim, F.MB, Enum.TextXAlignment.Center, 35)
			got.Position = UDim2.fromOffset(0, 742)
			-- v5.16 CLAIM (owner: it looked basic / unpolished): a rarity-coloured button with a glossy top-to-bottom gradient, a light frame + a fine top
			-- highlight, a soft pulsing glow behind it, a shine that sweeps across every couple of seconds, diamond marks either side of the word, and
			-- it pops in, grows on hover and squashes when pressed.
			local tint = resR.id == "signature" and K.red or resR.glow
			local claimHolder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 796), Size = UDim2.fromOffset(330, 74),
				BackgroundTransparency = 1, ZIndex = 50 }, stage)
			local holdScale = new("UIScale", { Scale = 0.6 }, claimHolder)
			local cGlow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 30, 1, 30), BackgroundColor3 = tint,
				BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 49 }, claimHolder)
			corner(cGlow, 18)
			local claim = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 50 }, claimHolder)
			corner(claim, 9)
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, tint:Lerp(WHITE, 0.3)), ColorSequenceKeypoint.new(0.48, tint),
				ColorSequenceKeypoint.new(1, tint:Lerp(BLACK, 0.5)) }) }, claim)
			local cStroke = stroke(claim, WHITE, 2, 1)
			local hiLine = box(claim, 10, 3, 310, 1, WHITE, 1, 51)
			local cText = lbl(claim, "CLAIM", 32, 0, 0, 330, 74, WHITE, F.H, Enum.TextXAlignment.Center, 52)
			cText.TextTransparency = 1
			local cTextStroke = stroke(cText, BLACK, 2, 1)
			cTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			local marks = {}
			for _, mx in { 92, 238 } do
				local d = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(mx, 37), Size = UDim2.fromOffset(9, 9), Rotation = 45,
					BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 52 }, claim)
				table.insert(marks, d)
			end
			local shine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(-80, 37), Size = UDim2.fromOffset(46, 180), Rotation = 22,
				BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 51 }, claim)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, shine)
			tween(holdScale, ti(0.4, Enum.EasingStyle.Back), { Scale = 1 })
			tween(claim, ti(0.3), { BackgroundTransparency = 0 })
			tween(cStroke, ti(0.3), { Transparency = 0.45 })
			tween(hiLine, ti(0.3), { BackgroundTransparency = 0.45 })
			tween(cText, ti(0.3), { TextTransparency = 0 })
			tween(cTextStroke, ti(0.3), { Transparency = 0.55 })
			for _, d in marks do tween(d, ti(0.3), { BackgroundTransparency = 0.15 }) end
			task.spawn(function() -- glow pulse + shine sweep
				local st0 = os.clock()
				while alive and claim.Parent do
					local e = os.clock() - st0
					cGlow.BackgroundTransparency = 0.72 + 0.14 * math.sin(e * 3.2)
					local u = (e % 2.4) / 0.7
					shine.Position = UDim2.fromOffset(u <= 1 and (-80 + u * 490) or -80, 37)
					RunService.RenderStepped:Wait()
				end
			end)
			local hovering = false
			claim.MouseEnter:Connect(function() hovering = true tween(holdScale, ti(0.18), { Scale = 1.06 }) tween(cStroke, ti(0.18), { Transparency = 0.05 }) end)
			claim.MouseLeave:Connect(function() hovering = false tween(holdScale, ti(0.18), { Scale = 1 }) tween(cStroke, ti(0.18), { Transparency = 0.45 }) end)
			claim.MouseButton1Down:Connect(function() tween(holdScale, ti(0.08), { Scale = 0.95 }) end)
			claim.MouseButton1Up:Connect(function() tween(holdScale, ti(0.15, Enum.EasingStyle.Back), { Scale = hovering and 1.06 or 1 }) end)
			local claimed = false
			claim.MouseButton1Click:Connect(function()
				if claimed then return end
				claimed = true
				sfx("CardPick")
				tween(bigScale, ti(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.2 })
				tween(blocker, ti(0.35), { BackgroundTransparency = 1 })
				for _, d in stage:GetDescendants() do
					if d:IsA("UIStroke") then tween(d, ti(0.3), { Transparency = 1 }) end
					if d:IsA("TextLabel") or d:IsA("TextButton") then tween(d, ti(0.3), { TextTransparency = 1 }) end
					if d:IsA("Frame") or d:IsA("TextButton") then
						if d.BackgroundTransparency < 1 then tween(d, ti(0.3), { BackgroundTransparency = 1 }) end
					end
				end
				task.wait(0.36)
				cleanup()
				say("Added to your collection: " .. (card and card.name or result.id) .. " (" .. resR.name .. ").", true)
			end)
		end)
	end

	-- ======================================================================================
	function api.Show()
		root.Visible = true
		startTimer()
		if not stateData or (stateData and CardShop.Day(workspace:GetServerTimeNow()) ~= dailyBuilt) then
			if not stateData then buildDaily() end
			refreshState()
		end
		for _, fn in repaintFns do fn() end
	end
	function api.Hide()
		root.Visible = false
		closeViewer()
		if timerConn then timerConn:Disconnect() timerConn = nil end
	end
	function api.Refresh() for _, fn in repaintFns do fn() end end
	function api.Busy() return opening end
	function api.CloseOverlay() -- ESC: closes the eye view first; returns true if it closed something
		if viewLayer.Visible then closeViewer() return true end
		return opening
	end
	api.frame = root
	return api
end

return M
