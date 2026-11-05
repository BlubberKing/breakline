-- CardArt (ModuleScript in ReplicatedStorage) - BOTH games (Lobby + Breakline). Keep the two copies identical (Lobby is the master).
-- v4.3: draws a Breakline power-up card out of plain GUI frames (no uploaded images needed).
-- v4.9 PERFORMANCE: every static card (anim = false) is drawn ONCE and kept as a template; Build then hands out CLONES of it (a clone of ~400 GUI objects is
--   many times cheaper than drawing them again, and it needs no text measuring). Small cards (<= 260 px, the collection grid + deck minis) use the LITE
--   drawing: the same picture without the faint second pen pass, with fewer paper grains and a sparser hatch (nothing else moves, the random seed is
--   unchanged). Animated cards (inspect view, card roll) are still built fresh. The cache keeps the 36 most recently used templates.
--   CardArt.Build(parent, cardId, opts) -> holder, api
--       opts.width    = card width in pixels (height is width * 1.4). Default 250.
--       opts.anim     = false turns the moving bits off (embers, rays, stripes, twinkles). Default true. Static cards come from the template cache.
--       opts.lod      = "full" | "lite" | "micro" (default when anim = false: lite up to 260 px wide, micro up to 130 px; "micro" also skips hair-thin strokes)
--       opts.cache    = false forces a fresh build
--       opts.baked    = false skips the baked sprite-sheet card (v4.9; static cards use it automatically once A.SHEETS has ids)
--       opts.position / opts.anchor = holder Position / AnchorPoint
--     api.card (the 250 x 350 card frame, scaled), api.rarity, api.setGlow(on, color)
--   CardArt.W, CardArt.H = 250, 350 (design size; everything is drawn at this size and scaled with a UIScale)
-- Look: hand-inked illustrations (wobbly double-pass strokes, cross-hatching, watercolour washes that sit a little off the lines,
-- burnt paper edges) inside a frame that gets fancier with rarity:
--   COMMON grey paper | UNCOMMON green + vine curls | RARE blue + double frame, gem, line texture
--   LEGENDARY gold + sunburst, corner brackets, sparkles | MYTHIC red + flames, rising embers, pulsing glow
--   EPIC purple + faceted amethyst light, crystal corners, violet gem (v4.9)
--   DIVINE watercolour rainbow paper + blooms, pastel prism edge, stars (v4.9) | SIGNATURE black / white op-art stripes, red slash, holo foil, split ink art
-- Every stroke is placed with a random generator seeded by the card id, so a card always looks exactly the same.
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Cards = require(script.Parent:WaitForChild("Cards"))

local A = {}
A.W, A.H = 250, 350

-- ======================================================================================
-- v4.9 BAKED CARDS (the real lag fix). Every static card (collection grid, deck minis, reels) can be ONE ImageLabel cut out of a sprite sheet
-- (4 sheets, 8 cards each, 1000 x 700) instead of 300-700 GUI frames. Only the name / description / rarity text stays live on top.
-- HOW TO TURN IT ON: upload BreaklineCards_1.png .. BreaklineCards_4.png (Studio > Asset Manager > Bulk Import, or Creator Hub > Decals),
-- copy each image's asset id and paste the numbers below (same order). Leave a 0 and that sheet's cards are simply drawn the old way.
-- If you ever change a card's art / rarity or add a card, the sheets must be re-baked (ask the AI: "re-bake the card sheets"); cards that are not
-- in BAKED_MAP (or whose rarity changed since the bake) automatically fall back to the drawn version, so nothing ever breaks.
-- ======================================================================================
A.SHEETS = { 107243050811638, 76549811722878, 125500158265679, 97063169601401 } -- <<< paste the 4 image ids here, e.g. { 1234567890, 1234567891, 1234567892, 1234567893 }
local BAKED_RARITY = { -- rarity each card had when it was baked (a changed rarity = draw it the old way until re-baked)
	steady_hands = "common",
	light_feet = "common",
	thick_skin = "common",
	deep_pockets = "common",
	long_breath = "common",
	box_hugger = "common",
	ember_heart = "common",
	scrap_plating = "common",
	lucky_coin = "common",
	ghost_step = "uncommon",
	menders_thread = "uncommon",
	hot_barrel = "uncommon",
	magnet_palms = "uncommon",
	grave_candle = "uncommon",
	scouts_eye = "uncommon",
	skeleton_key = "uncommon",
	paper_crane = "uncommon",
	tidebreaker = "rare",
	moonlit_reload = "rare",
	hollow_point = "rare",
	stormcaller = "epic",
	lantern_keeper = "epic",
	glass_cannon = "epic",
	crown_of_line = "legendary",
	sun_eater = "legendary",
	golden_hour = "legendary",
	oathblade = "legendary",
	red_serpent = "mythic",
	bloodmoon_pact = "mythic",
	halo_of_ash = "divine",
	seraphs_eye = "divine",
	the_breakline = "signature",
}
local BAKED_MAP = { -- card id = { sheet, x, y } (each card is 250 x 350 on its sheet)
	steady_hands = { 1, 0, 0 },
	light_feet = { 1, 250, 0 },
	thick_skin = { 1, 500, 0 },
	deep_pockets = { 1, 750, 0 },
	long_breath = { 1, 0, 350 },
	box_hugger = { 1, 250, 350 },
	ember_heart = { 1, 500, 350 },
	scrap_plating = { 1, 750, 350 },
	lucky_coin = { 2, 0, 0 },
	ghost_step = { 2, 250, 0 },
	menders_thread = { 2, 500, 0 },
	hot_barrel = { 2, 750, 0 },
	magnet_palms = { 2, 0, 350 },
	grave_candle = { 2, 250, 350 },
	scouts_eye = { 2, 500, 350 },
	skeleton_key = { 2, 750, 350 },
	paper_crane = { 3, 0, 0 },
	tidebreaker = { 3, 250, 0 },
	moonlit_reload = { 3, 500, 0 },
	hollow_point = { 3, 750, 0 },
	stormcaller = { 3, 0, 350 },
	lantern_keeper = { 3, 250, 350 },
	glass_cannon = { 3, 500, 350 },
	crown_of_line = { 3, 750, 350 },
	sun_eater = { 4, 0, 0 },
	golden_hour = { 4, 250, 0 },
	oathblade = { 4, 500, 0 },
	red_serpent = { 4, 750, 0 },
	bloodmoon_pact = { 4, 0, 350 },
	halo_of_ash = { 4, 250, 350 },
	seraphs_eye = { 4, 500, 350 },
	the_breakline = { 4, 750, 350 },
}
local AW, AH = 222, 168 -- art window

local rgb = Color3.fromRGB
local INK = rgb(32, 25, 21)
local PAPER = rgb(239, 229, 207)
local WHITE = Color3.new(1, 1, 1)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0) }, o) end
local function stroke(o, col, th, tr)
	return new("UIStroke", { Color = col, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function loop(o, info, goal) local t = TweenService:Create(o, info, goal) t:Play() return t end

-- v4.4: text that scales WITH the card. TextScaled + UITextSizeConstraint worked in real pixels, so the 16 px cap never grew when the card was
-- shown big (inspect screen) and the description stayed tiny. Instead we measure at the 250 x 350 design size, pick the biggest TextSize that
-- fits, and let the card's UIScale scale the plain TextSize (so it grows and shrinks exactly like the rest of the card).
local fitCache = {}
local function fitText(label, text, font, maxSize, minSize, w, h, wrapped)
	local key = text .. "|" .. maxSize .. "|" .. w .. "|" .. h .. "|" .. tostring(wrapped)
	label.TextScaled = false
	if fitCache[key] then label.TextSize = fitCache[key] return end
	local size = minSize
	for s = maxSize, minSize, -1 do
		local ok, b = pcall(function()
			local gp = Instance.new("GetTextBoundsParams")
			gp.Text, gp.Font, gp.Size, gp.Width = text, font, s, wrapped and w or 10000
			return TextService:GetTextBoundsAsync(gp)
		end)
		if not ok then size = math.min(maxSize, 14) break end
		if b.X <= w + 0.5 and b.Y <= h + 0.5 then size = s break end
	end
	fitCache[key] = size
	label.TextSize = size
end

local function pickFont(list, fallback)
	for _, name in list do
		local ok, f = pcall(function() return Font.fromEnum(Enum.Font[name]) end)
		if ok and f then return f end
	end
	return fallback
end
local F = {
	name = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	hand = pickFont({ "Kalam", "PatrickHand", "IndieFlower" }, Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)),
	mono = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold),
}
A.Fonts = F

-- v4.9: the frame styles were written for 7 rarities (1 common .. 7 signature). EPIC was added between Rare and Legendary, so the
-- drawing code keeps using the old style numbers and Epic gets its own 3.5 (everything Rare has, plus its own crystal facets / corners / gem).
local STYLE = { common = 1, uncommon = 2, rare = 3, epic = 3.5, legendary = 4, mythic = 5, divine = 6, signature = 7 }
A.Style = STYLE

local function seedOf(s)
	local h = 7
	for i = 1, #s do h = (h * 31 + string.byte(s, i)) % 2147483 end
	return h
end

-- ======================================================================================
-- drawing kit: a context draws into one parent frame, in that frame's pixel space
-- ======================================================================================
local Ctx = {}
Ctx.__index = Ctx
local function newCtx(parent, seed, ink, lite)
	return setmetatable({ p = parent, r = Random.new(seed), ink = ink or INK, lite = lite }, Ctx)
end
function Ctx:j(a) return (self.r:NextNumber() * 2 - 1) * a end

-- one straight bar (the only primitive everything is made of)
function Ctx:seg(x1, y1, x2, y2, w, col, tr)
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 0.25 then return end
	if self.lite == 2 and w < 1.7 then return end -- v4.9 MICRO (deck minis, ~100 px): hair-thin strokes are under half a pixel there, skip them
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(len + w * 0.55, w), Rotation = math.deg(math.atan2(dy, dx)), BackgroundColor3 = col or self.ink,
		BackgroundTransparency = tr or 0, BorderSizePixel = 0 }, self.p)
	if w >= 2.2 then corner(f) end
	return f
end

-- hand-inked line: bends a hair in the middle, uneven width, sometimes a faint second pass next to it
function Ctx:line(x1, y1, x2, y2, w, o)
	w = w or 2
	local col, tr = o and o.col or self.ink, o and o.tr or 0
	local dx, dy = x2 - x1, y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 0.25 then return end
	if len > 14 then
		local nx, ny = -dy / len, dx / len
		local b = self:j(math.min(1.5, len * 0.03))
		local mx, my = (x1 + x2) / 2 + nx * b, (y1 + y2) / 2 + ny * b
		self:seg(x1, y1, mx, my, w * (0.86 + self:j(0.08)), col, tr)
		self:seg(mx, my, x2, y2, w * (0.96 + self:j(0.08)), col, tr)
	else
		self:seg(x1, y1, x2, y2, w, col, tr)
	end
	if not (o and o.single) and len > 18 and self.r:NextNumber() < 0.3 then
		if self.lite then
			-- v4.9 LITE: the faint second pen pass is barely visible at card-grid size, so it is not drawn (its random numbers are still used, so nothing else moves)
			self:j(1); self:j(1); self:j(1); self:j(1)
		else
			self:seg(x1 + self:j(1), y1 + self:j(1), x2 + self:j(1), y2 + self:j(1), math.max(1, w * 0.45), col, math.min(0.92, tr + 0.55))
		end
	end
end
local function single(o) return { single = true, col = o and o.col, tr = o and o.tr } end

function Ctx:path(pts, w, closed, o)
	local n = #pts / 2
	for i = 1, n - 1 do self:line(pts[2 * i - 1], pts[2 * i], pts[2 * i + 1], pts[2 * i + 2], w, o) end
	if closed then self:line(pts[2 * n - 1], pts[2 * n], pts[1], pts[2], w, o) end
end

-- smooth line through points (Catmull-Rom). o.taper = { startMult, endMult }, o.sub = steps per span
function Ctx:curve(pts, w, o)
	local n = #pts / 2
	if n < 2 then return end
	local function P(i) i = math.clamp(i, 1, n) return pts[2 * i - 1], pts[2 * i] end
	local sub = o and o.sub or 4
	local so = single(o)
	local px, py = P(1)
	for i = 1, n - 1 do
		local x0, y0 = P(i - 1)
		local x1, y1 = P(i)
		local x2, y2 = P(i + 1)
		local x3, y3 = P(i + 2)
		for s = 1, sub do
			local t = s / sub
			local t2, t3 = t * t, t * t * t
			local x = 0.5 * (2 * x1 + (-x0 + x2) * t + (2 * x0 - 5 * x1 + 4 * x2 - x3) * t2 + (-x0 + 3 * x1 - 3 * x2 + x3) * t3)
			local y = 0.5 * (2 * y1 + (-y0 + y2) * t + (2 * y0 - 5 * y1 + 4 * y2 - y3) * t2 + (-y0 + 3 * y1 - 3 * y2 + y3) * t3)
			local ww = w
			if o and o.taper then
				local u = ((i - 1) + t) / (n - 1)
				ww = w * (o.taper[1] + (o.taper[2] - o.taper[1]) * u)
			end
			self:line(px, py, x, y, ww, so)
			px, py = x, y
		end
	end
end

-- ellipse / arc. Angles in degrees (0 = right, 90 = down). Full ellipses overshoot their start a little, like a quick pen circle.
-- o.rot = rotate the ellipse, o.dash = skip every other step, o.step = degrees per step
function Ctx:ellipse(cx, cy, rx, ry, w, o, a0, a1)
	local full = a0 == nil
	if full then
		a0 = self.r:NextNumber() * 360
		a1 = a0 + 372
	end
	local rot = math.rad(o and o.rot or 0)
	local c, s = math.cos(rot), math.sin(rot)
	local step = o and o.step or 15
	local segs = math.max(2, math.ceil(math.abs(a1 - a0) / step))
	local so = single(o)
	local drift = full and (self:j(0.05)) or 0
	local px, py
	for i = 0, segs do
		local u = i / segs
		local a = math.rad(a0 + (a1 - a0) * u)
		local k = 1 + drift * u
		local ex, ey = math.cos(a) * rx * k, math.sin(a) * ry * k
		local x, y = cx + ex * c - ey * s, cy + ex * s + ey * c
		if px and not (o and o.dash and i % 2 == 0) then self:line(px, py, x, y, w, so) end
		px, py = x, y
	end
end
function Ctx:arc(cx, cy, rx, ry, a0, a1, w, o) self:ellipse(cx, cy, rx, ry, w, o, a0, a1) end
function Ctx:circle(cx, cy, r, w, o) self:ellipse(cx, cy, r, r, w, o) end

function Ctx:spiral(cx, cy, r0, r1, a0, a1, w, o)
	local segs = math.max(4, math.ceil(math.abs(a1 - a0) / 14))
	local so = single(o)
	local px, py
	for i = 0, segs do
		local u = i / segs
		local a = math.rad(a0 + (a1 - a0) * u)
		local r = r0 + (r1 - r0) * u
		local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
		if px then self:line(px, py, x, y, w * (1 - 0.45 * u), so) end
		px, py = x, y
	end
end

-- watercolour wash (soft rounded blob), sits under the ink
function Ctx:wash(cx, cy, w, h, col, tr, rot)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx + self:j(1.5), cy + self:j(1.5)), Size = UDim2.fromOffset(w, h),
		Rotation = rot or 0, BackgroundColor3 = col, BackgroundTransparency = tr or 0.5, BorderSizePixel = 0 }, self.p)
	corner(f)
	return f
end
function Ctx:fill(x, y, w, h, col, tr, rot)
	return new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Rotation = rot or 0, BackgroundColor3 = col,
		BackgroundTransparency = tr or 0, BorderSizePixel = 0 }, self.p)
end
function Ctx:dot(cx, cy, r, col, tr)
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(r * 2, r * 2),
		BackgroundColor3 = col or self.ink, BackgroundTransparency = tr or 0, BorderSizePixel = 0 }, self.p)
	corner(f)
	return f
end

-- cross-hatching clipped to a rectangle
function Ctx:hatch(x, y, w, h, ang, gap, wt, tr, col)
	local clip = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, ClipsDescendants = true }, self.p)
	local sub = newCtx(clip, self.r:NextInteger(1, 99999), self.ink)
	local d = math.sqrt(w * w + h * h)
	local ca, sa = math.cos(math.rad(ang)), math.sin(math.rad(ang))
	for off = -d / 2, d / 2, (self.lite and gap * 1.4 or gap) do
		local mx, my = w / 2 - sa * off, h / 2 + ca * off
		sub:seg(mx - ca * d / 2, my - sa * d / 2, mx + ca * d / 2, my + sa * d / 2, wt or 1, col, tr or 0.45)
	end
	return clip
end

-- a row of short parallel strokes along a line (shading on a curved edge)
function Ctx:shade(x1, y1, x2, y2, count, len, ang, w, tr)
	local ca, sa = math.cos(math.rad(ang)), math.sin(math.rad(ang))
	for i = 0, count - 1 do
		local u = count == 1 and 0.5 or i / (count - 1)
		local x, y = x1 + (x2 - x1) * u + self:j(0.6), y1 + (y2 - y1) * u + self:j(0.6)
		local l = len * (0.75 + self.r:NextNumber() * 0.4)
		self:seg(x, y, x + ca * l, y + sa * l, w or 1, nil, tr or 0.35)
	end
end

-- vertical strokes from a ridge line down to y = bottom (fills the shape under a skyline)
function Ctx:under(pts, bottom, step, w, tr, col)
	local n = #pts / 2
	for i = 1, n - 1 do
		local x1, y1, x2, y2 = pts[2 * i - 1], pts[2 * i], pts[2 * i + 1], pts[2 * i + 2]
		local x = x1
		while x < x2 do
			local u = (x - x1) / math.max(0.001, x2 - x1)
			local y = y1 + (y2 - y1) * u
			self:seg(x, y + 1, x + self:j(0.6), bottom, w or 1.4, col, tr or 0.3)
			x += step
		end
	end
end

-- transform local points: rotate deg, scale sc, then move to (ox, oy)
local function place(pts, ox, oy, deg, sc)
	local a = math.rad(deg or 0)
	local c, s = math.cos(a), math.sin(a)
	sc = sc or 1
	local out = table.create(#pts)
	for i = 1, #pts, 2 do
		local x, y = pts[i] * sc, pts[i + 1] * sc
		out[i], out[i + 1] = ox + x * c - y * s, oy + x * s + y * c
	end
	return out
end

function Ctx:star(cx, cy, r1, r2, n, w, o, rot)
	local pts = {}
	for i = 0, n * 2 - 1 do
		local a = math.rad((rot or -90) + i * 180 / n)
		local r = (i % 2 == 0) and r1 or r2
		table.insert(pts, cx + math.cos(a) * r)
		table.insert(pts, cy + math.sin(a) * r)
	end
	self:path(pts, w, true, single(o))
end
function Ctx:twinkle(cx, cy, r, w, o)
	self:line(cx - r, cy, cx + r, cy, w, single(o))
	self:line(cx, cy - r, cx, cy + r, w, single(o))
	self:line(cx - r * 0.35, cy - r * 0.35, cx + r * 0.35, cy + r * 0.35, w * 0.6, single(o))
	self:line(cx - r * 0.35, cy + r * 0.35, cx + r * 0.35, cy - r * 0.35, w * 0.6, single(o))
end
function Ctx:heart(cx, cy, s, w, o)
	local pts = {}
	for i = 0, 30 do
		local t = i / 30 * math.pi * 2
		local x = 16 * math.sin(t) ^ 3
		local y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
		table.insert(pts, cx + x * s / 16)
		table.insert(pts, cy + y * s / 16)
	end
	self:path(pts, w, false, single(o))
end
function Ctx:flame(cx, base, h, wd, w, o)
	self:curve({ cx - wd * 0.5, base, cx - wd * 0.58, base - h * 0.3, cx - wd * 0.2, base - h * 0.62, cx - wd * 0.24, base - h * 0.8,
		cx + wd * 0.06, base - h, cx + wd * 0.12, base - h * 0.74, cx + wd * 0.4, base - h * 0.52, cx + wd * 0.52, base - h * 0.24, cx + wd * 0.5, base }, w, o)
	self:arc(cx, base, wd * 0.5, wd * 0.22, 0, 180, w, o)
end
function Ctx:leaf(cx, cy, len, wid, rot, w, o, rib)
	local a = {}
	local b = {}
	for i = 0, 6 do
		local t = i / 6
		local x = (t - 0.5) * len
		local y = math.sin(math.pi * t) * wid * 0.5
		table.insert(a, x) table.insert(a, -y)
		table.insert(b, x) table.insert(b, y)
	end
	self:path(place(a, cx, cy, rot), w, false, single(o))
	self:path(place(b, cx, cy, rot), w, false, single(o))
	if rib ~= false then self:path(place({ -len * 0.5, 0, len * 0.42, 0 }, cx, cy, rot), w * 0.6, false, { tr = 0.35, single = true, col = o and o.col }) end
end
function Ctx:cloud(cx, cy, wd, bumps, w, o)
	local r = wd / bumps / 2
	local x0 = cx - wd / 2 + r
	for i = 0, bumps - 1 do
		local up = (i == 0 or i == bumps - 1) and 0 or r * 0.6 * math.sin(math.pi * i / (bumps - 1))
		self:arc(x0 + i * r * 2, cy - up, r * 1.15, r * (1.05 + (i % 2) * 0.25), 180, 360, w, o)
	end
	self:curve({ cx - wd / 2 - r * 0.1, cy, cx, cy + 2, cx + wd / 2 + r * 0.1, cy }, w, o)
end
function Ctx:capsule(x1, y1, x2, y2, r, w, o)
	local dx, dy = x2 - x1, y2 - y1
	local L = math.sqrt(dx * dx + dy * dy)
	local nx, ny = -dy / L, dx / L
	self:line(x1 + nx * r, y1 + ny * r, x2 + nx * r, y2 + ny * r, w, o)
	self:line(x1 - nx * r, y1 - ny * r, x2 - nx * r, y2 - ny * r, w, o)
	local ang = math.deg(math.atan2(dy, dx))
	if not o or o.cap2 ~= false then self:arc(x2, y2, r, r, ang - 90, ang + 90, w, o) end
	if o and o.cap1 then self:arc(x1, y1, r, r, ang + 90, ang + 270, w, o) end
end
A.Ctx = newCtx

-- ======================================================================================
-- the illustrations. Each painter draws into the 222 x 168 art window: P.name(d, R) (d = drawing context, R = rarity)
-- ======================================================================================
local P = {}
local SKIN, BRASS, COPPER, STEEL = rgb(236, 196, 158), rgb(218, 172, 78), rgb(196, 112, 62), rgb(150, 160, 172)
local FIRE, GOLDW, SOUL, BLOOD = rgb(242, 128, 44), rgb(255, 212, 92), rgb(112, 208, 255), rgb(196, 36, 40)

local function ground(d, y, x0, x1)
	d:curve({ x0, y, (x0 + x1) / 2, y + d:j(2), x1, y }, 1.6, { tr = 0.1 })
	for i = 0, 7 do
		local x = x0 + (x1 - x0) * (i + 0.5) / 8
		d:line(x - 6, y + 5 + d:j(1), x + 4, y + 5 + d:j(1), 1, { tr = 0.55, single = true })
	end
end

P.hand = function(d, R)
	d:ellipse(111, 88, 68, 68, 1.2, { tr = 0.55, dash = true, step = 8 })
	d:circle(111, 88, 52, 1, { tr = 0.72 })
	for _, a in { 0, 90, 180, 270 } do
		local ca, sa = math.cos(math.rad(a)), math.sin(math.rad(a))
		d:line(111 + ca * 60, 88 + sa * 60, 111 + ca * 76, 88 + sa * 76, 1.6, { tr = 0.3 })
	end
	d:wash(112, 118, 52, 56, SKIN, 0.3)
	d:wash(112, 76, 46, 44, SKIN, 0.4)
	d:wash(78, 108, 16, 36, SKIN, 0.4, -38)
	for _, f in { { 93, 66 }, { 105, 56 }, { 117, 59 }, { 129, 70 } } do
		local x, top = f[1], f[2]
		d:capsule(x, 98, x, top + 5, 5, 2)
		d:arc(x, (top + 98) / 2 + 3, 4, 1.6, 20, 160, 1, { tr = 0.35 })
		d:arc(x, top + 9, 3, 3, 200, 340, 1, { tr = 0.45 })
	end
	d:capsule(91, 124, 73, 99, 5.5, 2)
	d:line(85, 127, 90, 152, 2)
	d:curve({ 134, 98, 136, 118, 132, 136, 129, 152 }, 2)
	d:arc(124, 132, 22, 20, 195, 250, 1.3, { tr = 0.2 })
	d:curve({ 97, 116, 110, 111, 127, 109 }, 1.2, { tr = 0.25 })
	d:shade(132, 104, 128, 146, 8, 6, 200, 1, 0.45)
	d:line(86, 152, 132, 152, 2)
	d:line(84, 166, 134, 166, 2)
	d:hatch(86, 153, 47, 12, 60, 4, 1, 0.45)
end

P.feather = function(d, R)
	local function B(t) local u = 1 - t return u * u * 64 + 2 * u * t * 92 + t * t * 164, u * u * 156 + 2 * u * t * 76 + t * t * 20 end
	local function T(t)
		local u = 1 - t
		local dx, dy = 2 * u * (92 - 64) + 2 * t * (164 - 92), 2 * u * (76 - 156) + 2 * t * (20 - 76)
		local l = math.sqrt(dx * dx + dy * dy)
		return dx / l, dy / l
	end
	for i = 0, 5 do
		local t = 0.24 + i * 0.13
		local x, y = B(t)
		local tx, ty = T(t)
		d:wash(x - ty * 7, y + tx * 7, 44, 20, R.light, 0.4, math.deg(math.atan2(ty, tx)))
	end
	local ea, eb = {}, {}
	local k = 0
	for t = 0.16, 0.985, 0.03 do
		k += 1
		local x, y = B(t)
		local tx, ty = T(t)
		local env = math.sin(math.pi * math.clamp((t - 0.12) / 0.9, 0, 1)) ^ 0.6
		local la, lb = 30 * env + 3, 21 * env + 2
		local ax, ay = (-ty + 0.85 * tx) / 1.3124, (tx + 0.85 * ty) / 1.3124
		local bx, by = (ty + 0.85 * tx) / 1.3124, (-tx + 0.85 * ty) / 1.3124
		local split = (k == 9 or k == 10)
		local ka = split and 0.7 or 1
		d:line(x, y, x + ax * la * ka, y + ay * la * ka, 1, { single = true, tr = 0.25 })
		d:line(x, y, x + bx * lb, y + by * lb, 1, { single = true, tr = 0.3 })
		if not split then
			table.insert(ea, x + ax * la) table.insert(ea, y + ay * la)
		end
		table.insert(eb, x + bx * lb) table.insert(eb, y + by * lb)
	end
	d:curve(ea, 1.5, { tr = 0.1 })
	d:curve(eb, 1.5, { tr = 0.1 })
	local px, py = B(0)
	for i = 1, 12 do
		local x, y = B(i / 12)
		d:seg(px, py, x, y, 3.4 - i * 0.2)
		px, py = x, y
	end
	d:spiral(70, 140, 6, 1, 200, 470, 1.2, { tr = 0.3 })
	d:spiral(80, 146, 5, 1, 250, 520, 1.1, { tr = 0.35 })
	for i = 0, 2 do d:curve({ 20, 40 + i * 14, 40, 36 + i * 14, 58, 41 + i * 14 }, 1, { tr = 0.45 }) end
end

P.shield = function(d, R)
	local outer = { 74, 30, 92, 26, 111, 24, 130, 26, 148, 30, 149, 62, 145, 92, 134, 116, 111, 142, 88, 116, 77, 92, 73, 62 }
	d:wash(111, 70, 70, 80, STEEL, 0.35)
	d:wash(111, 108, 44, 50, STEEL, 0.4)
	d:wash(111, 60, 24, 70, R.body, 0.35)
	d:path(outer, 2.6, true)
	local inner = {}
	for i = 1, #outer, 2 do
		inner[i] = 111 + (outer[i] - 111) * 0.84
		inner[i + 1] = 76 + (outer[i + 1] - 76) * 0.84
	end
	d:path(inner, 1.4, true, { tr = 0.15 })
	d:path({ 86, 98, 111, 70, 136, 98 }, 2.2)
	d:path({ 90, 108, 111, 82, 132, 108 }, 1.4, false, { tr = 0.2 })
	d:shade(78, 40, 88, 112, 14, 9, 10, 1, 0.45)
	for i = 1, #inner, 4 do d:dot(inner[i], inner[i + 1], 1.8) end
	d:line(126, 44, 136, 52, 1.2, { tr = 0.3 })
	d:line(98, 120, 104, 116, 1.2, { tr = 0.3 })
	d:wash(111, 156, 90, 10, INK, 0.82)
end

P.bullets = function(d, R)
	local function round(x, base, s, tr)
		local top, neck = base - 60 * s, base - 66 * s
		d:wash(x, base - 30 * s, 22 * s, 60 * s, BRASS, 0.35)
		d:wash(x, neck - 12 * s, 14 * s, 26 * s, COPPER, 0.35)
		d:line(x - 11 * s, base, x - 11 * s, top, 2)
		d:line(x + 11 * s, base, x + 11 * s, top, 2)
		d:line(x - 13 * s, base, x + 13 * s, base, 2)
		d:line(x - 12 * s, base - 6 * s, x + 12 * s, base - 6 * s, 1.2, { tr = 0.2 })
		d:line(x - 11 * s, top, x - 8 * s, neck, 1.8)
		d:line(x + 11 * s, top, x + 8 * s, neck, 1.8)
		d:arc(x, neck, 8 * s, 26 * s, 180, 360, 1.8)
		d:line(x - 8 * s, neck, x + 8 * s, neck, 1, { tr = 0.3 })
		d:shade(x + 6 * s, base - 8 * s, x + 6 * s, top + 4, 7, 4 * s, 0, 1, 0.35)
		d:line(x - 7 * s, base - 10 * s, x - 7 * s, top + 6, 1, { col = WHITE, tr = 0.4, single = true })
	end
	ground(d, 146, 30, 192)
	d:wash(111, 150, 140, 12, INK, 0.85)
	round(80, 142, 0.92)
	round(142, 142, 0.92)
	round(111, 148, 1.08)
	d:twinkle(170, 40, 7, 1.2)
	d:twinkle(52, 58, 5, 1)
end

P.wind = function(d, R)
	d:wash(111, 70, 200, 40, R.light, 0.55, -4)
	d:wash(130, 112, 170, 30, R.light, 0.65, 3)
	d:curve({ 12, 92, 50, 84, 90, 90, 128, 80, 156, 64 }, 2.2, { taper = { 0.6, 1 } })
	d:spiral(156, 50, 14, 3, 90, -220, 2.2)
	d:curve({ 28, 122, 70, 112, 110, 122, 150, 116, 184, 104 }, 2, { taper = { 0.5, 1 } })
	d:spiral(184, 92, 12, 3, 90, -210, 2)
	d:curve({ 40, 54, 70, 46, 96, 50 }, 1.6, { taper = { 0.5, 1 } })
	d:spiral(96, 40, 10, 2, 90, -200, 1.6)
	for _, l in { { 64, 70, 20 }, { 122, 100, -30 }, { 174, 134, 40 }, { 36, 140, -10 } } do
		d:wash(l[1], l[2], 18, 8, rgb(150, 190, 110), 0.35, l[3])
		d:leaf(l[1], l[2], 18, 8, l[3], 1.4)
	end
	for i = 0, 3 do d:line(150 + i * 12, 150 - i * 2, 170 + i * 12, 150 - i * 2, 1, { tr = 0.5 }) end
end

P.crate = function(d, R)
	local AMBER = rgb(255, 176, 60)
	d:wash(122, 26, 34, 34, AMBER, 0.55)
	d:wash(122, 26, 18, 18, AMBER, 0.35)
	d:wash(108, 92, 64, 64, STEEL, 0.55)
	d:wash(150, 84, 20, 60, INK, 0.75)
	d:wash(118, 54, 64, 16, STEEL, 0.4)
	for _, e in { { 78, 62, 138, 62 }, { 138, 62, 138, 122 }, { 78, 122, 138, 122 }, { 78, 62, 78, 122 } } do
		d:line(e[1], e[2], e[3], e[4], 5, { col = AMBER, tr = 0.6, single = true })
	end
	d:path({ 78, 62, 138, 62, 138, 122, 78, 122 }, 2.4, true)
	d:path({ 78, 62, 98, 46, 158, 46, 138, 62 }, 2.2, false)
	d:path({ 158, 46, 158, 106, 138, 122 }, 2.2, false)
	d:path({ 84, 68, 132, 68, 132, 116, 84, 116 }, 1.1, true, { tr = 0.35 })
	d:shade(142, 64, 142, 112, 9, 12, -38, 1, 0.4)
	d:dot(97, 87, 5.2)
	d:dot(119, 87, 5.2)
	d:dot(95.5, 85.2, 1.6, WHITE)
	d:dot(117.5, 85.2, 1.6, WHITE)
	d:arc(108, 98, 7, 5, 25, 155, 1.8)
	d:line(118, 54, 122, 31, 1.8)
	d:circle(122, 27, 4.5, 1.8)
	d:heart(62, 40, 9, 1.6, { col = BLOOD })
	d:heart(48, 58, 6, 1.2, { col = BLOOD, tr = 0.3 })
	d:wash(112, 130, 100, 12, INK, 0.8)
	ground(d, 128, 40, 186)
end

P.heart = function(d, R)
	d:wash(111, 100, 80, 70, rgb(214, 70, 60), 0.35)
	d:wash(100, 92, 30, 30, rgb(255, 160, 120), 0.45)
	d:heart(111, 98, 40, 2.6)
	d:heart(112, 99, 40, 1, { tr = 0.55 })
	d:shade(118, 126, 140, 96, 10, 10, 210, 1, 0.4)
	d:wash(111, 50, 28, 44, FIRE, 0.4)
	d:wash(111, 58, 14, 24, GOLDW, 0.35)
	d:flame(111, 74, 52, 26, 2)
	d:flame(111, 72, 28, 12, 1.4, { tr = 0.2 })
	for _, p in { { 76, 40 }, { 150, 34 }, { 160, 60 }, { 62, 66 }, { 140, 18 } } do d:dot(p[1], p[2], 1.6, FIRE, 0.1) end
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22)
		d:line(111 + math.cos(a) * 62, 96 + math.sin(a) * 56, 111 + math.cos(a) * 72, 96 + math.sin(a) * 64, 1.2, { tr = 0.45 })
	end
end

P.gear = function(d, R)
	local cx, cy = 104, 84
	local pts = {}
	local function at(a, r) table.insert(pts, cx + math.cos(math.rad(a)) * r) table.insert(pts, cy + math.sin(math.rad(a)) * r) end
	for k = 0, 9 do
		local a = k * 36
		at(a - 10, 38) at(a - 6, 48) at(a + 6, 48) at(a + 10, 38) at(a + 18, 38.5) at(a + 26, 38)
	end
	d:wash(cx, cy, 92, 92, STEEL, 0.4)
	d:wash(cx + 10, cy + 12, 40, 30, rgb(160, 96, 60), 0.6)
	d:path(pts, 2.2, true)
	d:circle(cx, cy, 24, 1.8)
	d:circle(cx, cy, 9, 2)
	d:dot(cx, cy, 3)
	for k = 0, 4 do
		local a = math.rad(k * 72 + 18)
		d:circle(cx + math.cos(a) * 31, cy + math.sin(a) * 31, 4.2, 1.4)
	end
	for k = 0, 11 do
		local a = math.rad(k * 9 - 20)
		d:line(cx + math.cos(a) * 26, cy + math.sin(a) * 26, cx + math.cos(a) * 36, cy + math.sin(a) * 36, 1, { tr = 0.45, single = true })
	end
	local hx, hy = 168, 132
	local hex = {}
	for i = 0, 5 do table.insert(hex, hx + math.cos(math.rad(i * 60)) * 14) table.insert(hex, hy + math.sin(math.rad(i * 60)) * 14) end
	d:wash(hx, hy, 26, 26, STEEL, 0.45)
	d:path(hex, 2, true)
	d:circle(hx, hy, 6, 1.4)
	d:line(150, 40, 190, 40, 1, { tr = 0.5 })
	d:line(160, 48, 196, 48, 1, { tr = 0.6 })
end

P.coin = function(d, R)
	d:wash(111, 84, 100, 100, GOLDW, 0.35)
	d:wash(124, 98, 50, 50, BRASS, 0.5)
	d:arc(117, 84, 50, 50, -75, 75, 2)
	d:line(111 + 13, 84 - 48, 117 + 13, 84 - 48, 1.6)
	d:circle(111, 84, 50, 2.4)
	d:circle(111, 84, 42, 1.4, { tr = 0.1 })
	for i = 0, 27 do
		local a = math.rad(i * (360 / 28))
		d:dot(111 + math.cos(a) * 46, 84 + math.sin(a) * 46, 1.1, nil, 0.25)
	end
	d:star(111, 84, 25, 10, 5, 2)
	d:star(111, 84, 17, 7, 5, 1, { tr = 0.5 })
	d:shade(132, 112, 148, 84, 9, 8, 200, 1, 0.4)
	d:arc(111, 84, 36, 36, 200, 250, 2, { col = WHITE, tr = 0.35 })
	d:twinkle(56, 34, 8, 1.4)
	d:twinkle(170, 140, 6, 1.2)
	d:twinkle(176, 30, 4, 1)
end

P.needle = function(d, R)
	local tx, ty, ex, ey = 168, 30, 58, 140
	local dx, dy = tx - ex, ty - ey
	local L = math.sqrt(dx * dx + dy * dy)
	local ux, uy = dx / L, dy / L
	local nx, ny = -uy, ux
	d:wash((tx + ex) / 2, (ty + ey) / 2, L, 8, STEEL, 0.45, math.deg(math.atan2(dy, dx)))
	d:line(ex + nx * 3.5, ey + ny * 3.5, tx, ty, 1.8)
	d:line(ex - nx * 3.5, ey - ny * 3.5, tx, ty, 1.8)
	d:arc(ex, ey, 3.5, 3.5, math.deg(math.atan2(dy, dx)) + 90, math.deg(math.atan2(dy, dx)) + 270, 1.8)
	d:ellipse(ex + ux * 10, ey + uy * 10, 5, 1.6, 1.3, { rot = math.deg(math.atan2(dy, dx)) })
	d:line(ex + ux * 30 + nx * 1.5, ey + uy * 30 + ny * 1.5, tx - ux * 20, ty - uy * 20, 1, { col = WHITE, tr = 0.35, single = true })
	local TH = rgb(196, 38, 48)
	d:curve({ ex + ux * 10, ey + uy * 10, 84, 122, 100, 112 }, 1.8, { col = TH })
	d:heart(120, 88, 22, 2, { col = TH })
	d:curve({ 120, 110, 140, 136, 170, 142, 196, 130, 206, 140 }, 1.8, { col = TH })
	for i = 0, 8 do d:line(20 + i * 22, 158, 32 + i * 22, 156, 1.6, { tr = 0.2 }) end
	d:line(14, 162, 210, 162, 1, { tr = 0.6 })
end

P.flame = function(d, R)
	d:wash(111, 60, 90, 100, FIRE, 0.45)
	d:wash(111, 74, 50, 60, GOLDW, 0.35)
	d:wash(111, 40, 120, 60, FIRE, 0.75)
	d:flame(111, 118, 98, 72, 2.4)
	d:flame(111, 116, 64, 44, 1.8, { tr = 0.1 })
	d:flame(112, 114, 34, 20, 1.4, { tr = 0.25 })
	d:wash(111, 144, 30, 52, STEEL, 0.4)
	d:line(98, 120, 98, 168, 2.2)
	d:line(124, 120, 124, 168, 2.2)
	d:ellipse(111, 120, 13, 4, 2, nil)
	d:line(98, 136, 124, 136, 1.4, { tr = 0.2 })
	d:line(98, 140, 124, 140, 1.4, { tr = 0.2 })
	d:shade(119, 124, 119, 166, 9, 4, 0, 1, 0.4)
	for s = -1, 1, 2 do
		d:curve({ 111 + s * 56, 120, 111 + s * 62, 104, 111 + s * 56, 88, 111 + s * 62, 72 }, 1, { tr = 0.45 })
	end
	for _, p in { { 66, 38 }, { 160, 30 }, { 150, 12 }, { 72, 16 }, { 172, 58 } } do d:dot(p[1], p[2], 1.5, FIRE, 0) end
end

P.magnet = function(d, R)
	local RED = rgb(206, 58, 54)
	for a = 190, 350, 32 do
		local r = math.rad(a)
		d:wash(111 + math.cos(r) * 33, 70 + math.sin(r) * 33, 26, 26, RED, 0.4)
	end
	d:wash(78, 92, 22, 40, RED, 0.4)
	d:wash(144, 92, 22, 40, RED, 0.4)
	d:wash(78, 120, 22, 18, STEEL, 0.3)
	d:wash(144, 120, 22, 18, STEEL, 0.3)
	d:arc(111, 70, 44, 44, 180, 360, 2.4)
	d:arc(111, 70, 22, 22, 180, 360, 2)
	d:line(67, 70, 67, 130, 2.4)
	d:line(89, 70, 89, 130, 2)
	d:line(133, 70, 133, 130, 2)
	d:line(155, 70, 155, 130, 2.4)
	d:line(67, 130, 89, 130, 2.2)
	d:line(133, 130, 155, 130, 2.2)
	d:line(67, 112, 89, 112, 1.6)
	d:line(133, 112, 155, 112, 1.6)
	d:shade(142, 40, 152, 66, 6, 8, 120, 1, 0.4)
	for i, r in { 30, 42, 56 } do
		d:arc(111, 132, r, r * 0.5, 10, 170, 1.2, { dash = true, tr = 0.2 + i * 0.12, step = 12 })
	end
	for _, b in { { 100, 158, 20 }, { 126, 156, -30 }, { 112, 150, 70 } } do
		local a = math.rad(b[3])
		d:seg(b[1] - math.cos(a) * 5, b[2] - math.sin(a) * 5, b[1] + math.cos(a) * 5, b[2] + math.sin(a) * 5, 2.2)
	end
	d:twinkle(176, 40, 6, 1.2)
	d:twinkle(44, 48, 5, 1)
end

P.candle = function(d, R)
	d:wash(111, 52, 120, 100, SOUL, 0.6)
	d:wash(111, 58, 50, 50, SOUL, 0.45)
	for _, t in { { 40, 0.55 }, { 182, 0.6 } } do
		local x, tr = t[1], t[2]
		d:line(x - 14, 132, x - 14, 104, 1.4, { tr = tr })
		d:line(x + 14, 132, x + 14, 104, 1.4, { tr = tr })
		d:arc(x, 104, 14, 14, 180, 360, 1.4, { tr = tr })
		d:line(x, 98, x, 116, 1.2, { tr = tr })
		d:line(x - 6, 104, x + 6, 104, 1.2, { tr = tr })
	end
	ground(d, 134, 10, 212)
	d:wash(111, 116, 26, 70, rgb(240, 232, 214), 0.25)
	d:line(98, 82, 98, 146, 2)
	d:line(124, 82, 124, 146, 2)
	d:ellipse(111, 82, 13, 4, 1.8)
	d:curve({ 102, 84, 103, 94, 101, 100 }, 1.6)
	d:curve({ 118, 85, 119, 98, 121, 104, 120, 108 }, 1.6)
	d:shade(119, 92, 119, 144, 9, 4, 0, 1, 0.35)
	d:line(111, 82, 112, 72, 1.6)
	d:wash(111, 58, 18, 32, SOUL, 0.2)
	d:flame(112, 72, 30, 15, 1.8)
	d:dot(109, 62, 1.4)
	d:dot(115, 62, 1.4)
	d:ellipse(111, 150, 34, 8, 2)
	d:arc(150, 146, 8, 7, -70, 90, 1.8)
end

P.eye = function(d, R)
	d:circle(111, 86, 64, 1, { dash = true, tr = 0.4, step = 9 })
	d:line(10, 86, 40, 86, 1.2, { tr = 0.3 })
	d:line(182, 86, 212, 86, 1.2, { tr = 0.3 })
	d:line(111, 6, 111, 30, 1.2, { tr = 0.3 })
	d:line(111, 142, 111, 166, 1.2, { tr = 0.3 })
	d:wash(111, 84, 58, 58, rgb(70, 150, 140), 0.35)
	d:curve({ 36, 86, 70, 54, 111, 42, 152, 54, 186, 86 }, 2.6)
	d:curve({ 36, 86, 70, 112, 111, 124, 152, 112, 186, 86 }, 2.2)
	d:curve({ 52, 66, 90, 40, 132, 38, 170, 62 }, 1.2, { tr = 0.35 })
	d:circle(111, 84, 28, 2)
	for i = 0, 17 do
		local a = math.rad(i * 20)
		d:line(111 + math.cos(a) * 13, 84 + math.sin(a) * 13, 111 + math.cos(a) * 25, 84 + math.sin(a) * 25, 1, { tr = 0.4, single = true })
	end
	d:dot(111, 84, 11)
	d:dot(104, 77, 3.6, WHITE)
	for i = 0, 8 do
		local u = i / 8
		local x = 46 + u * 130
		local y = 86 - math.sin(math.pi * u) * 40
		local a = math.rad(-90 + (u - 0.5) * 100)
		d:line(x, y - 2, x + math.cos(a) * 9, y - 2 + math.sin(a) * 9, 1.4, { single = true })
	end
	d:shade(70, 108, 152, 108, 10, 5, 90, 1, 0.5)
end

P.key = function(d, R)
	local ox, oy, rot = 111, 86, 36
	local function L(pts) return place(pts, ox, oy, rot) end
	local c = L({ -62, 0 })
	d:wash(ox, oy, 150, 14, BRASS, 0.4, rot)
	d:wash(c[1], c[2], 46, 46, BRASS, 0.4)
	d:circle(c[1], c[2], 21, 2.2)
	for i = 0, 2 do
		local p = L({ -62 + math.cos(math.rad(i * 120)) * 8, math.sin(math.rad(i * 120)) * 8 })
		d:circle(p[1], p[2], 6.5, 1.5)
	end
	d:path(L({ -41, -4, 62, -4 }), 2)
	d:path(L({ -41, 4, 62, 4 }), 2)
	d:path(L({ 62, -4, 62, 4 }), 2)
	d:path(L({ -34, -8, -34, 8 }), 1.6)
	d:path(L({ -28, -8, -28, 8 }), 1.6)
	d:path(L({ 40, 4, 40, 22, 46, 22, 46, 14, 52, 14, 52, 25, 62, 25, 62, 4 }), 2)
	d:path(L({ -20, -1.5, 50, -1.5 }), 1, false, { col = WHITE, tr = 0.4, single = true })
	d:dot(40, 138, 9, INK, 0.65)
	d:fill(35, 138, 10, 18, INK, 0.65)
	d:twinkle(170, 32, 7, 1.3)
end

P.crane = function(d, R)
	d:wash(108, 84, 120, 70, R.light, 0.6)
	d:curve({ 10, 140, 50, 130, 80, 140, 120, 128 }, 1, { tr = 0.5 })
	d:cloud(46, 40, 50, 4, 1.4, { tr = 0.3 })
	d:cloud(182, 130, 44, 3, 1.4, { tr = 0.3 })
	d:wash(92, 70, 40, 60, WHITE, 0.4, -35)
	d:wash(134, 66, 40, 60, rgb(250, 220, 210), 0.35, 30)
	d:path({ 80, 104, 111, 92, 142, 104, 111, 118 }, 2, true)
	d:path({ 111, 92, 70, 38, 104, 99 }, 2, false)
	d:path({ 111, 92, 152, 30, 122, 99 }, 2, false)
	d:line(111, 92, 111, 118, 1.2, { tr = 0.3 })
	d:path({ 82, 104, 54, 64, 46, 74 }, 2, false)
	d:line(54, 64, 60, 66, 1.4)
	d:path({ 140, 104, 186, 70, 128, 106 }, 2, false)
	d:shade(124, 96, 148, 40, 8, 10, 230, 1, 0.45)
	d:shade(84, 50, 106, 96, 6, 8, 160, 1, 0.5)
	d:curve({ 20, 90, 40, 70, 54, 64 }, 1, { tr = 0.55 })
end

P.wave = function(d, R)
	local SEA = rgb(40, 92, 172)
	d:wash(80, 110, 160, 90, SEA, 0.45)
	d:wash(120, 70, 100, 70, SEA, 0.55)
	d:wash(150, 50, 40, 30, WHITE, 0.4)
	d:fill(196, 0, 26, 168, rgb(120, 110, 100), 0.55)
	for row = 0, 11 do
		local y = row * 14
		d:line(196, y, 222, y, 1.2, { tr = 0.25, single = true })
		local bx = (row % 2 == 0) and 209 or 202
		d:line(bx, y, bx, y + 14, 1.2, { tr = 0.25, single = true })
	end
	d:line(196, 0, 196, 168, 2.2)
	d:curve({ 6, 152, 40, 122, 70, 82, 104, 48, 140, 34, 168, 42, 182, 62 }, 2.6)
	d:spiral(164, 64, 18, 4, 0, 300, 2.2)
	d:curve({ 22, 150, 52, 122, 80, 88, 112, 60, 142, 50, 160, 54 }, 1.4, { tr = 0.25 })
	d:curve({ 40, 152, 66, 128, 92, 100, 120, 76, 146, 66 }, 1.2, { tr = 0.4 })
	for i = 0, 6 do
		local u = i / 6
		local x, y = 70 + u * 98, 82 - math.sin(u * math.pi * 0.9) * 46 + u * 6
		d:arc(x, y - 4, 5, 5, 200, 380, 1.4)
	end
	for i = 0, 4 do
		local y = 128 + i * 9
		d:curve({ 90 + i * 6, y, 120, y - 3, 150, y + 2, 190, y - 2 }, 1.1, { tr = 0.35 })
	end
	for _, p in { { 180, 20 }, { 188, 34 }, { 172, 12 }, { 160, 22 } } do d:circle(p[1], p[2], 2, 1, { tr = 0.2 }) end
end

-- crescent from two circles
local function circleHits(x1, y1, r1, x2, y2, r2)
	local dx, dy = x2 - x1, y2 - y1
	local dd = math.sqrt(dx * dx + dy * dy)
	local a = (r1 * r1 - r2 * r2 + dd * dd) / (2 * dd)
	local h = math.sqrt(math.max(0, r1 * r1 - a * a))
	local mx, my = x1 + dx * a / dd, y1 + dy * a / dd
	return mx + h * dy / dd, my - h * dx / dd, mx - h * dy / dd, my + h * dx / dd
end
local function crescent(d, cx, cy, r, ox, oy, r2, w)
	local px, py, qx, qy = circleHits(cx, cy, r, cx + ox, cy + oy, r2)
	local function ang(x, y, ccx, ccy) return math.deg(math.atan2(y - ccy, x - ccx)) end
	local a1, a2 = ang(px, py, cx, cy), ang(qx, qy, cx, cy)
	local b1, b2 = ang(px, py, cx + ox, cy + oy), ang(qx, qy, cx + ox, cy + oy)
	-- outer arc goes the long way round (away from the cut), inner arc the side facing the main circle
	local function norm(a) while a < 0 do a += 360 end while a >= 360 do a -= 360 end return a end
	local away = norm(math.deg(math.atan2(-oy, -ox)))
	local s, e = norm(a1), norm(a2)
	local mid1 = norm(s + norm(e - s) / 2)
	local diff = math.abs(((mid1 - away + 540) % 360) - 180)
	if diff < 90 then d:arc(cx, cy, r, r, s, s + norm(e - s), w) else d:arc(cx, cy, r, r, e, e + norm(s - e), w) end
	local s2, e2 = norm(b1), norm(b2)
	local mid2 = norm(s2 + norm(e2 - s2) / 2)
	local diff2 = math.abs(((mid2 - away + 540) % 360) - 180)
	if diff2 < 90 then d:arc(cx + ox, cy + oy, r2, r2, s2, s2 + norm(e2 - s2), w * 0.85) else d:arc(cx + ox, cy + oy, r2, r2, e2, e2 + norm(s2 - e2), w * 0.85) end
end

P.moon = function(d, R)
	d:wash(100, 80, 110, 110, R.light, 0.45)
	d:wash(90, 84, 50, 90, GOLDW, 0.55, 10)
	crescent(d, 104, 80, 48, 24, -12, 42, 2.6)
	d:arc(74, 74, 6, 4, 20, 160, 1.6)
	d:line(66, 92, 72, 96, 1.4)
	d:circle(80, 112, 4, 1, { tr = 0.4 })
	d:circle(70, 56, 3, 1, { tr = 0.4 })
	d:shade(64, 60, 70, 110, 8, 7, 10, 1, 0.45)
	for _, s in { { 164, 30, 7 }, { 190, 64, 5 }, { 150, 112, 4 }, { 30, 30, 5 }, { 184, 120, 3 } } do d:star(s[1], s[2], s[3], s[3] * 0.4, 5, 1.2) end
	for _, p in { { 140, 20 }, { 200, 30 }, { 24, 70 }, { 172, 90 } } do d:dot(p[1], p[2], 1.2) end
	d:wash(120, 150, 200, 28, WHITE, 0.55)
	d:cloud(70, 154, 90, 5, 1.8)
	d:cloud(160, 148, 80, 4, 1.6, { tr = 0.2 })
end

P.storm = function(d, R)
	d:wash(111, 46, 180, 60, rgb(90, 100, 120), 0.45)
	d:wash(111, 110, 50, 100, GOLDW, 0.45, 18)
	d:wash(111, 110, 24, 60, WHITE, 0.4, 18)
	d:cloud(111, 58, 170, 6, 2.4)
	d:cloud(80, 42, 80, 4, 1.4, { tr = 0.3 })
	d:shade(40, 62, 180, 62, 22, 6, 90, 1, 0.45)
	d:path({ 116, 64, 94, 104, 112, 104, 88, 154, 136, 96, 116, 96, 132, 64 }, 2.4, true)
	d:path({ 114, 72, 100, 98 }, 1, false, { col = WHITE, tr = 0.3, single = true })
	for i = 0, 9 do
		local x = 30 + i * 18 + d:j(3)
		if x < 90 or x > 140 then d:line(x, 72 + d:j(4), x - 6, 92 + d:j(4), 1.1, { tr = 0.4, single = true }) end
	end
	for _, z in { { 70, 120 }, { 150, 132 } } do
		d:path({ z[1], z[2], z[1] + 6, z[2] - 6, z[1] + 10, z[2] + 2, z[1] + 16, z[2] - 4 }, 1.4, false, { single = true })
	end
end

P.target = function(d, R)
	local cx, cy = 98, 92
	d:wash(cx, cy, 98, 98, rgb(240, 232, 214), 0.2)
	d:wash(cx, cy, 70, 70, rgb(206, 60, 54), 0.4)
	d:wash(cx, cy, 42, 42, rgb(240, 232, 214), 0.15)
	d:wash(cx, cy, 16, 16, rgb(206, 60, 54), 0.25)
	for _, r in { 48, 35, 21 } do d:circle(cx, cy, r, 2) end
	d:dot(cx, cy, 6)
	d:shade(cx + 20, cy + 40, cx + 44, cy + 14, 10, 8, 225, 1, 0.45)
	local ax, ay = cx + 6, cy - 4
	local bx, by = 190, 22
	d:line(ax, ay, bx, by, 2.4)
	d:line(ax + 1, ay + 2, bx + 1, by + 2, 1, { tr = 0.5, single = true })
	local dx, dy = bx - ax, by - ay
	local L = math.sqrt(dx * dx + dy * dy)
	local ux, uy = dx / L, dy / L
	local nx, ny = -uy, ux
	for k = 0, 2 do
		local px, py = bx - ux * (k * 8), by - uy * (k * 8)
		d:line(px, py, px - ux * 10 + nx * 10, py - uy * 10 + ny * 10, 1.6, { col = BLOOD })
		d:line(px, py, px - ux * 10 - nx * 10, py - uy * 10 - ny * 10, 1.6, { col = BLOOD })
	end
	for i = 0, 5 do
		local a = math.rad(i * 60 + 15)
		d:line(ax + math.cos(a) * 6, ay + math.sin(a) * 6, ax + math.cos(a) * 14, ay + math.sin(a) * 14, 1.2, { single = true })
	end
end

P.lantern = function(d, R)
	d:wash(111, 86, 130, 130, SOUL, 0.6)
	d:wash(111, 86, 70, 80, SOUL, 0.45)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		d:line(111 + math.cos(a) * 54, 86 + math.sin(a) * 54, 111 + math.cos(a) * 66, 86 + math.sin(a) * 66, 1.2, { tr = 0.35 })
	end
	d:circle(111, 14, 5, 1.8)
	d:arc(111, 44, 23, 22, 180, 360, 1.8)
	d:path({ 100, 44, 111, 33, 122, 44 }, 2, false)
	d:path({ 90, 44, 132, 44, 124, 54, 98, 54 }, 2, true)
	d:wash(111, 86, 30, 62, WHITE, 0.55)
	d:path({ 96, 54, 126, 54, 126, 118, 96, 118 }, 2, true)
	d:line(106, 54, 106, 118, 1.2, { tr = 0.2 })
	d:line(116, 54, 116, 118, 1.2, { tr = 0.2 })
	d:path({ 92, 118, 130, 118, 134, 128, 88, 128 }, 2, true)
	d:hatch(97, 55, 9, 62, 70, 4, 1, 0.55)
	d:curve({ 104, 100, 103, 86, 108, 74, 111, 70, 114, 74, 119, 86, 118, 100, 114, 104, 111, 101, 108, 105, 104, 100 }, 1.6)
	d:dot(108, 85, 1.5)
	d:dot(114, 85, 1.5)
	d:wash(111, 140, 70, 8, INK, 0.85)
end

P.crystal = function(d, R)
	local ICE = rgb(150, 220, 255)
	local function shard(ox, oy, rot, sc, tr)
		local pts = place({ 0, -64, 17, -40, 17, 46, 0, 58, -17, 46, -17, -40 }, ox, oy, rot, sc)
		local fac = place({ 0, -64, 0, 58 }, ox, oy, rot, sc)
		local f2 = place({ -17, -40, 0, -28, 17, -40 }, ox, oy, rot, sc)
		local c = place({ 0, 0 }, ox, oy, rot, sc)
		d:wash(c[1], c[2], 34 * sc, 118 * sc, ICE, 0.45, rot)
		d:path(pts, 2.2, true, { tr = tr })
		d:path(fac, 1.2, false, { tr = 0.25 + (tr or 0) })
		d:path(f2, 1.2, false, { tr = 0.25 + (tr or 0) })
		local sh = place({ 4, -30, 14, -30, 4, 40, 14, 40 }, ox, oy, rot, sc)
		d:shade(sh[1], sh[2], sh[5], sh[6], 10, 8 * sc, rot, 1, 0.45)
	end
	shard(70, 104, -26, 0.7, 0.15)
	shard(152, 106, 24, 0.75, 0.15)
	shard(111, 84, 0, 1)
	d:path({ 106, 40, 112, 52, 107, 62, 114, 74 }, 1, false, { single = true })
	d:path({ 30, 150, 50, 138, 70, 146, 96, 136, 124, 144, 150, 134, 176, 146, 196, 140 }, 2)
	d:under({ 30, 150, 50, 138, 70, 146, 96, 136, 124, 144, 150, 134, 176, 146, 196, 140 }, 168, 4, 1.2, 0.45)
	d:twinkle(166, 34, 8, 1.4)
	d:twinkle(52, 52, 5, 1.1)
end

P.crown = function(d, R)
	for i = 0, 15 do
		local a = math.rad(180 + i * 12)
		d:line(111 + math.cos(a) * 66, 92 + math.sin(a) * 66, 111 + math.cos(a) * 84, 92 + math.sin(a) * 84, 1.2, { tr = 0.35 })
	end
	local top = { 66, 104, 62, 56, 74, 86, 86, 48, 98, 80, 111, 32, 124, 80, 136, 48, 148, 86, 160, 56, 156, 104 }
	d:wash(111, 84, 100, 50, GOLDW, 0.35)
	d:wash(111, 116, 96, 26, BRASS, 0.35)
	d:wash(111, 50, 30, 40, GOLDW, 0.4)
	d:path(top, 2.4, false)
	for _, t in { { 62, 56 }, { 86, 48 }, { 111, 32 }, { 136, 48 }, { 160, 56 } } do d:circle(t[1], t[2] - 4, 4.5, 1.8) end
	d:curve({ 66, 104, 111, 110, 156, 104 }, 2)
	d:curve({ 64, 128, 111, 134, 158, 128 }, 2.2)
	d:line(66, 104, 64, 128, 2)
	d:line(156, 104, 158, 128, 2)
	d:wash(111, 119, 14, 10, BLOOD, 0.3)
	d:ellipse(111, 119, 7, 5, 1.8)
	for _, x in { 84, 138 } do d:path({ x, 113, x + 5, 119, x, 125, x - 5, 119 }, 1.6, true) end
	d:shade(126, 84, 152, 100, 8, 10, 100, 1, 0.45)
	d:shade(100, 112, 150, 122, 12, 5, 70, 1, 0.45)
	d:twinkle(100, 60, 6, 1.2, { col = WHITE })
	d:wash(111, 146, 100, 10, INK, 0.8)
end

P.sun = function(d, R)
	d:wash(111, 80, 150, 150, GOLDW, 0.45)
	d:wash(111, 80, 90, 90, FIRE, 0.55)
	for i = 0, 23 do
		local a = i * 15
		local long = (i % 2 == 0)
		local r0, r1 = 44, long and 76 or 60
		local ra = math.rad(a)
		local mx, my = 111 + math.cos(ra + 0.06) * (r0 + r1) / 2, 80 + math.sin(ra + 0.06) * (r0 + r1) / 2
		d:curve({ 111 + math.cos(ra) * r0, 80 + math.sin(ra) * r0, mx, my, 111 + math.cos(ra) * r1, 80 + math.sin(ra) * r1 }, long and 2 or 1.4, { taper = { 1, 0.4 } })
	end
	d:circle(111, 80, 40, 1.2, { tr = 0.4 })
	d:circle(111, 80, 36, 2.4)
	d:dot(116, 77, 33, INK, 0.04)
	d:arc(111, 80, 36, 36, 120, 220, 2.4, { col = WHITE, tr = 0.15 })
	d:path({ 0, 150, 40, 132, 70, 142, 110, 126, 150, 140, 190, 128, 222, 138 }, 2)
	d:under({ 0, 150, 40, 132, 70, 142, 110, 126, 150, 140, 190, 128, 222, 138 }, 168, 4, 1.3, 0.4)
end

P.hourglass = function(d, R)
	for i = 0, 11 do
		local a = math.rad(i * 30 + 15)
		d:line(111 + math.cos(a) * 70, 86 + math.sin(a) * 70, 111 + math.cos(a) * 84, 86 + math.sin(a) * 84, 1.2, { tr = 0.4 })
	end
	d:wash(111, 52, 40, 22, GOLDW, 0.35)
	d:wash(111, 128, 50, 22, GOLDW, 0.3)
	d:wash(111, 27, 90, 12, rgb(140, 90, 50), 0.4)
	d:wash(111, 145, 90, 12, rgb(140, 90, 50), 0.4)
	d:path({ 68, 22, 154, 22, 154, 32, 68, 32 }, 2.2, true)
	d:path({ 68, 140, 154, 140, 154, 150, 68, 150 }, 2.2, true)
	d:hatch(69, 23, 84, 8, 30, 4, 1, 0.5)
	d:hatch(69, 141, 84, 8, 30, 4, 1, 0.5)
	d:curve({ 76, 32, 74, 60, 78, 86, 74, 112, 76, 140 }, 2.2)
	d:curve({ 146, 32, 148, 60, 144, 86, 148, 112, 146, 140 }, 2.2)
	d:curve({ 86, 32, 88, 54, 102, 76, 109, 86, 102, 96, 88, 118, 86, 140 }, 1.8)
	d:curve({ 136, 32, 134, 54, 120, 76, 113, 86, 120, 96, 134, 118, 136, 140 }, 1.8)
	d:curve({ 94, 58, 111, 62, 128, 58 }, 1.4)
	d:shade(96, 62, 126, 62, 9, 8, 90, 1, 0.4)
	for y = 90, 124, 5 do d:dot(111 + d:j(0.8), y, 0.9) end
	d:arc(111, 140, 22, 12, 180, 360, 1.6)
	d:shade(92, 134, 130, 134, 9, 5, 90, 1, 0.45)
	d:line(92, 40, 94, 70, 1, { col = WHITE, tr = 0.35, single = true })
end

P.sword = function(d, R)
	for i = 0, 4 do d:line(70 + i * 22, 0, 90 + i * 14, 120, 6, { col = WHITE, tr = 0.82, single = true }) end
	d:wash(111, 90, 24, 80, STEEL, 0.4)
	d:wash(111, 38, 30, 30, GOLDW, 0.4)
	d:circle(111, 18, 6, 2)
	d:line(106, 25, 106, 50, 2)
	d:line(116, 25, 116, 50, 2)
	for y = 28, 48, 5 do d:line(106, y, 116, y + 4, 1.2, { single = true }) end
	d:curve({ 74, 50, 90, 54, 111, 53, 132, 54, 148, 50 }, 2.2)
	d:curve({ 74, 58, 90, 60, 111, 60, 132, 60, 148, 58 }, 2.2)
	d:line(74, 50, 74, 58, 2)
	d:line(148, 50, 148, 58, 2)
	d:line(102, 60, 103, 128, 2)
	d:line(120, 60, 119, 128, 2)
	d:line(111, 64, 111, 124, 1.1, { tr = 0.3 })
	d:shade(115, 66, 115, 124, 10, 4, 0, 1, 0.45)
	d:curve({ 120, 66, 150, 70, 170, 62, 190, 72 }, 1.8, { col = BLOOD })
	d:curve({ 120, 76, 150, 80, 168, 74, 186, 82 }, 1.8, { col = BLOOD })
	d:path({ 190, 72, 182, 77, 186, 82 }, 1.6, false, { col = BLOOD })
	local rock = { 50, 150, 62, 130, 84, 122, 104, 128, 122, 126, 142, 120, 162, 132, 176, 150 }
	d:wash(112, 142, 120, 30, rgb(120, 112, 100), 0.4)
	d:path(rock, 2.2)
	d:under(rock, 168, 4, 1.2, 0.45)
	d:path({ 104, 128, 98, 138, 102, 146 }, 1.2, false, { single = true })
	d:twinkle(107, 86, 8, 1.4, { col = WHITE })
end

P.serpent = function(d, R)
	local cx, cy = 111, 88
	d:circle(cx, cy, 70, 1, { dash = true, tr = 0.4, step = 7 })
	for a = 290, 610, 20 do
		local r = math.rad(a)
		d:wash(cx + math.cos(r) * 43, cy + math.sin(r) * 43, 20, 20, BLOOD, 0.4)
	end
	d:arc(cx, cy, 50, 50, 290, 610, 2.4)
	d:arc(cx, cy, 36, 36, 296, 604, 2)
	for a = 300, 600, 12 do
		local r = math.rad(a)
		local x, y = cx + math.cos(r) * 43, cy + math.sin(r) * 43
		d:arc(x, y, 4, 4, a + 90 - 70, a + 90 + 70, 1, { tr = 0.25 })
	end
	d:shade(cx - 30, cy + 20, cx + 30, cy + 20, 10, 6, 90, 1, 0.5)
	d:wash(100, 34, 44, 20, BLOOD, 0.35)
	d:curve({ 128, 42, 120, 28, 104, 24, 88, 28, 78, 36, 86, 42, 100, 46, 118, 48, 128, 42 }, 2.2)
	d:dot(98, 31, 2.4)
	d:line(98, 28, 98, 34, 1, { col = GOLDW, single = true })
	d:path({ 80, 38, 72, 41, 76, 38, 68, 36 }, 1.2, false, { col = BLOOD, single = true })
	d:curve({ 74, 60, 78, 50, 82, 40 }, 1.8, { taper = { 1, 0.4 } })
	d:path({ 84, 42, 86, 46, 88, 42 }, 1.2, false, { single = true })
	for _, s in { { 30, 30 }, { 192, 30 }, { 30, 150 }, { 192, 150 } } do d:star(s[1], s[2], 6, 2.5, 4, 1.2) end
end

P.bloodmoon = function(d, R)
	d:wash(111, 60, 130, 120, BLOOD, 0.6)
	d:wash(111, 58, 82, 82, BLOOD, 0.3)
	d:circle(111, 58, 40, 2.4)
	for _, c in { { 96, 46, 7 }, { 124, 66, 9 }, { 118, 38, 4 }, { 100, 74, 5 } } do d:circle(c[1], c[2], c[3], 1.2, { tr = 0.25 }) end
	d:shade(126, 30, 140, 84, 9, 8, 180, 1, 0.45)
	local ridge = { 0, 140, 30, 104, 50, 120, 78, 86, 104, 118, 130, 92, 160, 124, 186, 98, 222, 132 }
	d:path(ridge, 2.2)
	d:under(ridge, 168, 3, 1.4, 0.2)
	d:path({ 78, 86, 72, 100, 80, 104 }, 1.2, false, { col = WHITE, tr = 0.4, single = true })
	for _, b in { { 40, 40, 8 }, { 58, 30, 6 }, { 176, 44, 7 }, { 164, 30, 5 } } do
		d:arc(b[1] - b[3] / 2, b[2], b[3] / 2, b[3] / 3, 200, 340, 1.4)
		d:arc(b[1] + b[3] / 2, b[2], b[3] / 2, b[3] / 3, 200, 340, 1.4)
	end
	d:wash(111, 112, 222, 20, BLOOD, 0.7)
end

P.halo = function(d, R)
	d:wash(111, 50, 110, 40, GOLDW, 0.5)
	d:wash(111, 100, 200, 80, R.light, 0.55)
	for s = -1, 1, 2 do
		for i = 0, 5 do
			local a = math.rad(-25 + i * 15)
			local len = 70 - i * 6
			local cx, cy = 111 + s * (16 + math.cos(a) * len * 0.5), 98 - math.sin(a) * len * 0.5
			d:leaf(cx, cy, len, 13, s == 1 and -math.deg(a) or 180 + math.deg(a), 1.5, nil, false)
		end
		for i = 0, 4 do
			local a = math.rad(-10 + i * 16)
			local len = 34
			local cx, cy = 111 + s * (14 + math.cos(a) * len * 0.5), 98 - math.sin(a) * len * 0.5 + 6
			d:leaf(cx, cy, len, 10, s == 1 and -math.deg(a) or 180 + math.deg(a), 1.2, { tr = 0.25 }, false)
		end
	end
	d:ellipse(111, 44, 38, 11, 2.4)
	d:ellipse(111, 44, 31, 7, 1.2, { tr = 0.3 })
	d:wash(111, 104, 14, 24, SOUL, 0.3)
	d:flame(111, 114, 26, 14, 1.6)
	for i = 1, 14 do d:dot(20 + d.r:NextNumber() * 182, 120 + d.r:NextNumber() * 44, 0.8 + d.r:NextNumber(), INK, 0.3) end
end

P.seraph = function(d, R)
	d:wash(111, 88, 150, 130, R.light, 0.5)
	d:wash(111, 92, 70, 50, GOLDW, 0.45)
	for i = 0, 15 do
		local a = math.rad(i * 22.5 + 11)
		d:line(111 + math.cos(a) * 66, 92 + math.sin(a) * 66, 111 + math.cos(a) * 86, 92 + math.sin(a) * 86, 1.4, { tr = 0.3 })
	end
	for s = -1, 1, 2 do
		for i = 0, 2 do
			local a = math.rad(10 + i * 18)
			d:leaf(111 + s * (52 + i * 4), 96 - i * 10, 36, 10, s == 1 and -math.deg(a) or 180 + math.deg(a), 1.4, nil, false)
		end
	end
	d:path({ 111, 22, 170, 128, 52, 128 }, 2.6, true)
	d:path({ 111, 34, 158, 120, 64, 120 }, 1.2, true, { tr = 0.3 })
	d:curve({ 80, 96, 96, 82, 111, 78, 126, 82, 142, 96 }, 2)
	d:curve({ 80, 96, 96, 108, 111, 112, 126, 108, 142, 96 }, 1.8)
	d:circle(111, 95, 12, 1.8)
	d:dot(111, 95, 5)
	d:dot(108, 92, 1.8, WHITE)
	d:shade(70, 124, 152, 124, 14, 5, 270, 1, 0.45)
	for _, s in { { 30, 30 }, { 192, 34 }, { 40, 150 }, { 186, 150 } } do d:twinkle(s[1], s[2], 5, 1.1) end
end

-- signature art: the wall, split by the red slash (drawn twice by Build: dark ink on white, chalk on black)
P.breakline = function(d, R)
	local RED = rgb(226, 38, 48)
	for row = 0, 7 do
		local y = 22 + row * 16
		local off = (row % 2 == 0) and 0 or 14
		d:line(28, y, 194, y, 1.4, { single = true, tr = 0.1 })
		for x = 28 + off, 194, 28 do d:line(x, y, x, y + 16, 1.4, { single = true, tr = 0.1 }) end
	end
	d:line(28, 150, 194, 150, 1.4, { single = true })
	d:path({ 28, 22, 28, 150 }, 2.2)
	d:path({ 194, 22, 194, 150 }, 2.2)
	d:hatch(29, 23, 40, 126, 45, 6, 1, 0.65)
	for _, f in { { 150, 30, 20 }, { 168, 52, -30 }, { 60, 124, 40 }, { 44, 140, -15 }, { 176, 20, 60 } } do
		d:path(place({ -5, -4, 5, -3, 3, 5, -4, 4 }, f[1], f[2], f[3]), 1.4, true)
	end
	for i = 0, 3 do d:line(150 + i * 10, 40 - i * 6, 168 + i * 12, 28 - i * 8, 1, { tr = 0.45, single = true }) end
	d:line(176, 8, 46, 160, 10, { col = RED, tr = 0.7, single = true })
	d:line(176, 8, 46, 160, 5, { col = RED, single = true })
	d:line(174, 11, 48, 157, 1.6, { col = WHITE, tr = 0.3, single = true })
end

P.footprints = function(d, R)
	d:wash(110, 92, 210, 50, SOUL, 0.75, -42)
	local rot = 47
	local bx, by = -math.sin(math.rad(rot)), math.cos(math.rad(rot)) -- toward the heel
	for i = 0, 4 do
		local u = i / 4
		local side = (i % 2 == 0) and -1 or 1
		local x, y = 48 + u * 128 + side * 7, 150 - u * 118 + side * 7
		local tr = u * 0.6
		d:ellipse(x, y, 7, 12, 1.8, { rot = rot, tr = tr })
		d:ellipse(x + bx * 16, y + by * 16, 5, 6, 1.6, { rot = rot, tr = tr })
		d:shade(x - 4, y - 2, x + 4, y + 2, 3, 5, rot + 90, 1, 0.5 + tr * 0.4)
	end
	d:spiral(186, 26, 8, 1, 0, 400, 1.2, { tr = 0.5 })
	d:spiral(200, 44, 6, 1, 90, 450, 1, { tr = 0.6 })
	d:curve({ 170, 18, 182, 10, 196, 14 }, 1, { tr = 0.55 })
end

A.Painters = P

-- ======================================================================================
-- the card
-- ======================================================================================
local function spaced(s) return (s:gsub("(.)", "%1 "):sub(1, -2)) end

local function backdrop(d, R, sig)
	local wc = sig and rgb(205, 205, 205) or R.light
	d:wash(111, 70, 200, 124, wc, 0.62)
	d:wash(66, 48, 112, 70, wc, 0.7, -12)
	if not sig then d:wash(162, 100, 120, 80, R.body, 0.84, 8) end
	for i = 1, 26 do
		local x, y, r, tr = d.r:NextNumber() * AW, d.r:NextNumber() * AH, 0.45 + d.r:NextNumber() * 0.8, 0.5 + d.r:NextNumber() * 0.4
		if not d.lite or i % 3 == 0 then d:dot(x, y, r, d.ink, tr) end -- LITE: every third paper speckle (they are under 2 px at grid size)
	end
end

local function burnEdges(parent, col)
	for i, cfg in { { 0, 0, AW, 20, 90 }, { 0, AH - 20, AW, 20, 270 }, { 0, 0, 20, AH, 0 }, { AW - 20, 0, 20, AH, 180 } } do
		local f = new("Frame", { Position = UDim2.fromOffset(cfg[1], cfg[2]), Size = UDim2.fromOffset(cfg[3], cfg[4]), BackgroundColor3 = col,
			BorderSizePixel = 0, ZIndex = 1 }, parent)
		new("UIGradient", { Rotation = cfg[5], Transparency = NumberSequence.new(0.5, 1) }, f)
	end
end

local function paintArt(window, c, R, seed, ink, paper, lite)
	window.BackgroundColor3 = paper
	local d = newCtx(window, seed, ink, lite)
	backdrop(d, R, c.rarity == "signature")
	local painter = P[c.art] or P.coin
	local ok, err = pcall(painter, d, R)
	if not ok then warn("[CardArt] art failed for", c.id, err) end
	return d
end

-- corner flourishes / brackets drawn on the card (outside the art window)
local function corners(card, R, rank, seed, lite)
	local d = newCtx(card, seed + 3, R.light, lite)
	if rank == 2 then
		for _, cfg in { { 16, 16, 0 }, { 234, 16, 90 }, { 234, 334, 180 }, { 16, 334, 270 } } do
			local x, y, a = cfg[1], cfg[2], cfg[3]
			local ca, sa = math.cos(math.rad(a)), math.sin(math.rad(a))
			local function L(px, py) return x + px * ca - py * sa, y + px * sa + py * ca end
			local x1, y1 = L(0, 10)
			local x2, y2 = L(10, 0)
			d:line(x1, y1, x, y, 1.6, { single = true, tr = 0.2 })
			d:line(x, y, x2, y2, 1.6, { single = true, tr = 0.2 })
			local lx, ly = L(9, 9)
			d:leaf(lx, ly, 10, 5, a + 45, 1.2, { tr = 0.15 }, false)
		end
	elseif rank == 3.5 then
		-- EPIC: little amethyst crystal clusters in the corners
		for _, cfg in { { 18, 18, 1, 1 }, { 232, 18, -1, 1 }, { 232, 332, -1, -1 }, { 18, 332, 1, -1 } } do
			local x, y, sx, sy = cfg[1], cfg[2], cfg[3], cfg[4]
			for k, sh in { { 0, 0, 13, 45 }, { 7, -2, 8, 20 }, { -2, 7, 8, 70 } } do
				local cx, cy = x + sx * sh[1], y + sy * sh[2]
				local ang = math.rad(sx > 0 and (sy > 0 and sh[4] or -sh[4]) or (sy > 0 and 180 - sh[4] or 180 + sh[4]))
				local tx, ty = cx + math.cos(ang) * sh[3], cy + math.sin(ang) * sh[3]
				d:line(cx, cy, tx, ty, k == 1 and 3 or 2.2, { single = true, col = k == 1 and R.light or R.glow, tr = 0.05 })
			end
		end
	elseif rank >= 4 then
		local col = (rank == 4 and R.deep) or (rank == 5 and rgb(255, 204, 90)) or (rank == 6 and WHITE) or rgb(226, 38, 48)
		for _, cfg in { { 9, 9, 1, 1 }, { 241, 9, -1, 1 }, { 241, 341, -1, -1 }, { 9, 341, 1, -1 } } do
			local x, y, sx, sy = cfg[1], cfg[2], cfg[3], cfg[4]
			new("Frame", { Position = UDim2.fromOffset(math.min(x, x + sx * 24), y - (sy < 0 and 3 or 0)), Size = UDim2.fromOffset(24, 3), BackgroundColor3 = col, BorderSizePixel = 0 }, card)
			new("Frame", { Position = UDim2.fromOffset(x - (sx < 0 and 3 or 0), math.min(y, y + sy * 24)), Size = UDim2.fromOffset(3, 24), BackgroundColor3 = col, BorderSizePixel = 0 }, card)
			local dm = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + sx * 13, y + sy * 13), Size = UDim2.fromOffset(6, 6),
				Rotation = 45, BackgroundColor3 = col, BorderSizePixel = 0 }, card)
			stroke(dm, INK, 1, 0.3)
		end
	end
end

local function gem(card, R, rank)
	local size = rank >= 4 and 20 or 15
	local col = (rank == 3 and rgb(120, 200, 255)) or (rank == 3.5 and rgb(196, 120, 255)) or (rank == 4 and rgb(255, 240, 170)) or (rank == 5 and rgb(255, 70, 70))
		or (rank == 6 and rgb(255, 190, 230)) or rgb(226, 38, 48)
	if rank >= 4 then
		local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(125, 14), Size = UDim2.fromOffset(46, 22),
			BackgroundColor3 = col, BackgroundTransparency = 0.6, BorderSizePixel = 0 }, card)
		corner(glow)
	end
	local g = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(125, 14), Size = UDim2.fromOffset(size, size), Rotation = 45,
		BackgroundColor3 = WHITE, BorderSizePixel = 0 }, card)
	if rank == 6 then -- DIVINE gem: watercolour rainbow
		local w = R.wash
		new("UIGradient", { Rotation = 45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, w[1]), ColorSequenceKeypoint.new(0.3, w[3]),
			ColorSequenceKeypoint.new(0.6, w[4]), ColorSequenceKeypoint.new(1, w[6]) }) }, g)
	else
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, col) }, g)
	end
	stroke(g, INK, 1.6)
	local core = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size * 0.4, size * 0.4),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, g)
	return g, core
end

local function twinkles(parent, n, col, rng, anim, area)
	for _ = 1, n do
		local x, y = area[1] + rng:NextNumber() * area[3], area[2] + rng:NextNumber() * area[4]
		local s = 6 + rng:NextNumber() * 7
		local h = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(s * 2, s * 2), BackgroundTransparency = 1 }, parent)
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = col, BorderSizePixel = 0 }, h)
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0 }, h)
		local sc = new("UIScale", { Scale = anim and 0.2 or 0.8 }, h)
		if anim then
			loop(sc, TweenInfo.new(0.9 + rng:NextNumber() * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, rng:NextNumber() * 1.5), { Scale = 1 })
		end
	end
end

local function buildFresh(parent, id, opts, lite)
	opts = opts or {}
	local c = Cards.ById[id] or Cards.List[1]
	local R = Cards.RarityById[c.rarity]
	local rank = STYLE[c.rarity] or 1
	local sig = c.rarity == "signature"
	local width = opts.width or A.W
	local anim = opts.anim ~= false
	local seed = seedOf(c.id)
	local rng = Random.new(seed + 11)

	local holder = new("Frame", { Name = "Card_" .. c.id, BackgroundTransparency = 1, Size = UDim2.fromOffset(width, width * A.H / A.W),
		Position = opts.position or UDim2.new(), AnchorPoint = opts.anchor or Vector2.zero }, parent)
	local card = new("Frame", { Name = "Card", Size = UDim2.fromOffset(A.W, A.H), BackgroundColor3 = R.body, BorderSizePixel = 0 }, holder)
	new("UIScale", { Scale = width / A.W }, card)
	corner(card, 9)
	local outline = stroke(card, INK, 2.5)
	if sig then
		card.BackgroundColor3 = rgb(14, 14, 16)
	elseif rank == 6 then
		-- DIVINE: soft watercolour rainbow paper (pastel, light, not a hard full-saturation rainbow)
		card.BackgroundColor3 = WHITE
		local w = R.wash
		local function pale(cl, k) return cl:Lerp(rgb(255, 250, 242), k) end
		new("UIGradient", { Rotation = 62, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, pale(w[1], 0.45)), ColorSequenceKeypoint.new(0.2, pale(w[2], 0.45)), ColorSequenceKeypoint.new(0.4, pale(w[3], 0.4)),
			ColorSequenceKeypoint.new(0.6, pale(w[4], 0.45)), ColorSequenceKeypoint.new(0.8, pale(w[5], 0.45)), ColorSequenceKeypoint.new(1, pale(w[6], 0.4)) }) }, card)
	else
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, R.body:Lerp(R.light, 0.22)), ColorSequenceKeypoint.new(0.55, R.body), ColorSequenceKeypoint.new(1, R.deep) }) }, card)
	end

	-- ===== rarity texture (clipped, inset so the rounded corners stay clean) =====
	local tex = new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(242, 342), BackgroundTransparency = 1, ClipsDescendants = true }, card)
	if not sig then
		for i = 1, 50 do
			local light = rng:NextNumber() < 0.5
			local s = 1 + rng:NextInteger(0, 1)
			local px, py, tr = rng:NextNumber() * 242, rng:NextNumber() * 342, 0.55 + rng:NextNumber() * 0.3
			if not lite or i % 4 == 0 then -- LITE: every fourth paper grain (the random numbers are all still drawn)
				new("Frame", { Position = UDim2.fromOffset(px, py), Size = UDim2.fromOffset(s, s),
					BackgroundColor3 = light and R.light or R.deep, BackgroundTransparency = tr, BorderSizePixel = 0 }, tex)
			end
		end
	end
	if rank == 2 then
		local d = newCtx(tex, seed + 5, R.light, lite)
		for i = 0, 3 do d:curve({ -10, 40 + i * 90, 60, 20 + i * 90, 140, 60 + i * 90, 252, 30 + i * 90 }, 1, { tr = 0.8 }) end
	elseif rank == 3 then
		local d = newCtx(tex, seed + 5, R.light, lite)
		d:hatch(0, 0, 242, 342, 60, 7, 1, 0.86, R.light)
	elseif rank == 3.5 then
		-- EPIC: faceted amethyst light - long crossing facet lines + a soft violet glow at the top
		local d = newCtx(tex, seed + 5, R.light, lite)
		for i = 0, 7 do
			local x = -40 + i * 46 + d:j(10)
			d:seg(x, -10, x + 150 + d:j(30), 352, 1, R.light, 0.84)
			d:seg(x + 120, -10, x - 60 + d:j(30), 352, 1, R.glow, 0.88)
		end
		d:wash(121, 60, 300, 160, R.glow, 0.78)
		d:wash(121, 330, 260, 90, R.deep, 0.6)
	elseif rank == 6 then
		-- DIVINE: overlapping watercolour blooms in six soft colours, wet edges, a few pigment speckles
		local d = newCtx(tex, seed + 5, R.deep, lite)
		local w = R.wash
		for i = 1, 14 do
			local col = w[(i - 1) % #w + 1]
			local cx, cy = d.r:NextNumber() * 242, d.r:NextNumber() * 342
			local bw, bh = 70 + d.r:NextNumber() * 110, 50 + d.r:NextNumber() * 90
			local rot = d.r:NextNumber() * 180
			d:wash(cx, cy, bw, bh, col, 0.62 + d.r:NextNumber() * 0.12, rot)
			if not lite or i % 2 == 0 then
				d:wash(cx + d:j(12), cy + d:j(12), bw * 0.55, bh * 0.5, col:Lerp(WHITE, 0.25), 0.7, rot + 20) -- lighter bloom in the middle
			end
		end
		for i = 1, 18 do
			local col = w[(i - 1) % #w + 1]
			local x, y = d.r:NextNumber() * 242, d.r:NextNumber() * 342
			if not lite or i % 3 == 0 then d:dot(x, y, 1 + d.r:NextNumber() * 2.2, col:Lerp(INK, 0.15), 0.35) end
		end
	elseif rank == 4 then
		local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(121, 100), Size = UDim2.fromOffset(620, 620),
			BackgroundTransparency = 1 }, tex)
		for i = 0, 8 do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 18),
				Rotation = i * 20, BackgroundColor3 = R.light, BackgroundTransparency = 0.8, BorderSizePixel = 0 }, rays)
		end
	elseif rank == 5 then
		local d = newCtx(tex, seed + 5, rgb(255, 150, 60))
		for i = 0, 6 do
			local x = 10 + i * 37 + d:j(6)
			local h = 40 + d.r:NextNumber() * 30
			d:wash(x, 342 - h * 0.35, 30, h, (i % 2 == 0) and rgb(255, 120, 40) or rgb(255, 196, 80), 0.55)
		end
		local top = new("Frame", { Size = UDim2.fromOffset(242, 120), BackgroundColor3 = rgb(40, 0, 6), BorderSizePixel = 0 }, tex)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.55, 1) }, top)
	elseif sig then
		local rot = 32
		local stripes = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(121, 171), Size = UDim2.fromOffset(900, 900),
			Rotation = rot, BackgroundTransparency = 1 }, tex)
		local pattern = { 10, 6, 4, 6, 8, 6 } -- black / white widths, repeats every 40 px
		local x = 0
		while x < 900 do
			for i, w in pattern do
				if i % 2 == 0 then
					new("Frame", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 900), BackgroundColor3 = rgb(236, 236, 234), BorderSizePixel = 0 }, stripes)
				end
				x += w
			end
		end
		if anim then
			local per = 40 / math.cos(math.rad(rot))
			loop(stripes, TweenInfo.new(3.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Position = UDim2.fromOffset(121 + per, 171) })
		end
		local slash = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(121, 171), Size = UDim2.fromOffset(520, 9), Rotation = -58,
			BackgroundColor3 = rgb(226, 38, 48), BorderSizePixel = 0 }, tex)
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.2, BorderSizePixel = 0 }, slash)
	end

	-- ===== inner frame lines =====
	local in1 = new("Frame", { Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(236, 336), BackgroundTransparency = 1 }, card)
	corner(in1, 6)
	stroke(in1, (sig or rank == 6) and WHITE or R.light, rank == 6 and 1.5 or 1, sig and 0.2 or (rank == 6 and 0.1 or 0.45))
	if rank >= 3 then
		local in2 = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(230, 330), BackgroundTransparency = 1 }, card)
		corner(in2, 5)
		stroke(in2, sig and INK or R.deep, 1, 0.35)
	end
	if rank == 5 then
		local glow = new("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(240, 340), BackgroundTransparency = 1 }, card)
		corner(glow, 7)
		local gs = stroke(glow, R.glow, 2.5, 0.2)
		if anim then loop(gs, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.85 }) end
	end
	if rank == 3.5 then
		local glow = new("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(240, 340), BackgroundTransparency = 1 }, card)
		corner(glow, 7)
		stroke(glow, R.glow, 1.5, 0.35)
	end
	if rank == 6 then
		local w = R.wash
		local g = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, w[1]), ColorSequenceKeypoint.new(0.2, w[2]),
			ColorSequenceKeypoint.new(0.4, w[3]), ColorSequenceKeypoint.new(0.6, w[4]), ColorSequenceKeypoint.new(0.8, w[5]), ColorSequenceKeypoint.new(1, w[6]) }) }, outline)
		outline.Thickness = 3
		if anim then loop(g, TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 }) end
	end
	corners(card, R, rank, seed, lite)

	-- ===== art window =====
	local paper = sig and rgb(246, 246, 244) or PAPER:Lerp(R.light, 0.2)
	local art = new("Frame", { Name = "Art", Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(AW, AH), BackgroundColor3 = paper, BorderSizePixel = 0,
		ClipsDescendants = true }, card)
	if sig then
		local left = new("Frame", { Size = UDim2.fromOffset(AW / 2, AH), BackgroundTransparency = 1, ClipsDescendants = true }, art)
		local lc = new("Frame", { Size = UDim2.fromOffset(AW, AH), BackgroundColor3 = paper, BorderSizePixel = 0 }, left)
		paintArt(lc, c, R, seed, INK, paper, lite)
		local right = new("Frame", { Position = UDim2.fromOffset(AW / 2, 0), Size = UDim2.fromOffset(AW / 2, AH), BackgroundTransparency = 1, ClipsDescendants = true }, art)
		local rc = new("Frame", { Position = UDim2.fromOffset(-AW / 2, 0), Size = UDim2.fromOffset(AW, AH), BackgroundColor3 = rgb(16, 16, 18), BorderSizePixel = 0 }, right)
		paintArt(rc, c, R, seed, rgb(236, 236, 232), rgb(16, 16, 18), lite)
	else
		paintArt(art, c, R, seed, INK, paper, lite)
		burnEdges(art, rgb(120, 82, 48):Lerp(R.deep, 0.35))
	end
	stroke(art, INK, 2)
	do -- rough hand-inked border over the clean one
		local d = newCtx(card, seed + 7, INK, lite)
		d:line(12, 13, 238, 12.5, 1.6)
		d:line(237.5, 12, 238.5, 184, 1.6)
		d:line(238, 183, 12, 183.5, 1.6)
		d:line(12.5, 184, 13, 12, 1.6)
	end
	if rank >= 3 then gem(card, R, rank) end

	-- ===== name plate =====
	local plate = new("Frame", { Position = UDim2.fromOffset(12, 190), Size = UDim2.fromOffset(226, 34), BackgroundColor3 = sig and rgb(8, 8, 8) or rgb(22, 18, 15),
		BackgroundTransparency = sig and 0 or 0.08, BorderSizePixel = 0 }, card)
	corner(plate, 3)
	stroke(plate, sig and WHITE or R.light, 1, sig and 0.1 or 0.5)
	for _, x in { 0, 226 } do
		local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 17), Size = UDim2.fromOffset(8, 8), Rotation = 45,
			BackgroundColor3 = sig and rgb(226, 38, 48) or R.light, BorderSizePixel = 0 }, plate)
		stroke(s, INK, 1)
	end
	local nameCol = rank >= 4 and R.light or rgb(244, 240, 232)
	if sig then nameCol = WHITE end
	local nm = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 3), Size = UDim2.fromOffset(206, 28), Text = string.upper(c.name),
		FontFace = F.name, TextColor3 = nameCol }, plate)
	fitText(nm, nm.Text, F.name, 23, 10, 204, 28, false)

	-- ===== description =====
	local box = new("Frame", { Position = UDim2.fromOffset(16, 230), Size = UDim2.fromOffset(218, 76), BackgroundColor3 = sig and rgb(246, 246, 244) or rgb(242, 234, 215),
		BackgroundTransparency = 0.04, BorderSizePixel = 0 }, card)
	corner(box, 3)
	stroke(box, INK, 1.2, 0.35)
	local ds = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(9, 5), Size = UDim2.fromOffset(200, 66), Text = c.desc,
		FontFace = F.hand, TextColor3 = rgb(46, 36, 30), TextWrapped = true }, box)
	fitText(ds, c.desc, F.hand, 16, 8, 196, 64, true)

	-- ===== rarity footer =====
	local rt = spaced(R.name)
	local tw = #rt * 7.3
	if sig then
		local pill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(125, 324), Size = UDim2.fromOffset(tw + 26, 20),
			BackgroundColor3 = rgb(8, 8, 8), BorderSizePixel = 0 }, card)
		stroke(pill, WHITE, 1)
		new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = rt, FontFace = F.mono, TextSize = 12, TextColor3 = WHITE }, pill)
	else
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 313), Size = UDim2.fromOffset(250, 22), Text = rt, FontFace = F.mono,
			TextSize = 12, TextColor3 = R.label }, card)
		for _, side in { -1, 1 } do
			local inner = 125 + side * (tw / 2 + 10)
			local outer = 125 + side * 98
			new("Frame", { Position = UDim2.fromOffset(math.min(inner, outer), 323), Size = UDim2.fromOffset(math.abs(outer - inner), 1),
				BackgroundColor3 = R.label, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, card)
			local dm = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(inner, 323.5), Size = UDim2.fromOffset(5, 5), Rotation = 45,
				BackgroundColor3 = R.label, BorderSizePixel = 0 }, card)
			dm.BackgroundTransparency = 0.1
		end
	end

	-- ===== moving bits =====
	if rank == 4 then twinkles(card, 4, WHITE, rng, anim, { 20, 20, 210, 160 }) end
	if rank == 6 then twinkles(card, 6, WHITE, rng, anim, { 14, 14, 222, 320 }) end
	if rank == 3.5 then twinkles(card, 3, R.light, rng, anim, { 20, 20, 210, 160 }) end
	if rank == 5 and anim then
		for _ = 1, 10 do
			local x = 10 + rng:NextNumber() * 222
			local e = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 345), Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = (rng:NextNumber() < 0.5) and rgb(255, 170, 60) or rgb(255, 230, 140), BorderSizePixel = 0 }, tex)
			corner(e)
			loop(e, TweenInfo.new(2.2 + rng:NextNumber() * 1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, rng:NextNumber() * 2),
				{ Position = UDim2.fromOffset(x + rng:NextNumber() * 40 - 20, 150 + rng:NextNumber() * 90), BackgroundTransparency = 1 })
		end
	end
	if sig then
		local foil = new("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(244, 344), BackgroundColor3 = WHITE, BackgroundTransparency = 0.86,
			BorderSizePixel = 0 }, card)
		corner(foil, 8)
		local fg = new("UIGradient", { Rotation = 35, Offset = Vector2.new(-0.6, 0), Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 110, 120)), ColorSequenceKeypoint.new(0.25, rgb(255, 230, 120)), ColorSequenceKeypoint.new(0.5, rgb(120, 255, 190)),
			ColorSequenceKeypoint.new(0.75, rgb(120, 170, 255)), ColorSequenceKeypoint.new(1, rgb(230, 130, 255)) }) }, foil)
		if anim then loop(fg, TweenInfo.new(4.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.6, 0) }) end
	end
	-- (v4.4: the white shine sweep that crossed rare + higher cards every few seconds is gone)

	-- selection glow (pickers + the roll screen)
	local glowFrame = new("Frame", { Name = "SelGlow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 14, 1, 14),
		BackgroundTransparency = 1, Visible = false }, card)
	corner(glowFrame, 14)
	local glowStroke = stroke(glowFrame, R.glow, 4, 0.1)
	glowStroke.Name = "SelGlowStroke"

	local api = { card = card, rarity = R, data = c }
	function api.setGlow(on, col)
		glowFrame.Visible = on and true or false
		if col then glowStroke.Color = col end
	end
	return holder, api
end

-- ======================================================================================
-- v4.9 baked card: one ImageLabel from the sheet + the live text (about 8 objects instead of 300-700)
-- ======================================================================================
local function bakedImage(id)
	local m = BAKED_MAP[id]
	local c = Cards.ById[id]
	if not m or not c or BAKED_RARITY[id] ~= c.rarity then return nil end
	local sheet = tonumber(A.SHEETS[m[1]])
	if not sheet or sheet <= 0 then return nil end
	return "rbxassetid://" .. sheet, m[2], m[3]
end
function A.IsBaked(id) return bakedImage(id) ~= nil end

local function buildBaked(parent, id, opts)
	local img, ox, oy = bakedImage(id)
	if not img then return nil end
	local c = Cards.ById[id]
	local R = Cards.RarityById[c.rarity]
	local rank = STYLE[c.rarity] or 1
	local sig = c.rarity == "signature"
	local width = opts.width or A.W
	local holder = new("Frame", { Name = "Card_" .. c.id, BackgroundTransparency = 1, Size = UDim2.fromOffset(width, width * A.H / A.W),
		Position = opts.position or UDim2.new(), AnchorPoint = opts.anchor or Vector2.zero })
	local card = new("Frame", { Name = "Card", Size = UDim2.fromOffset(A.W, A.H), BackgroundTransparency = 1 }, holder)
	new("UIScale", { Scale = width / A.W }, card)
	new("ImageLabel", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromOffset(A.W, A.H), Image = img,
		ImageRectOffset = Vector2.new(ox, oy), ImageRectSize = Vector2.new(A.W, A.H) }, card)
	local nameCol = rank >= 4 and R.light or rgb(244, 240, 232)
	if sig then nameCol = WHITE end
	local nm = new("TextLabel", { Name = "CardName", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 193), Size = UDim2.fromOffset(206, 28),
		Text = string.upper(c.name), FontFace = F.name, TextColor3 = nameCol }, card)
	fitText(nm, nm.Text, F.name, 23, 10, 204, 28, false)
	local ds = new("TextLabel", { Name = "CardDesc", BackgroundTransparency = 1, Position = UDim2.fromOffset(25, 235), Size = UDim2.fromOffset(200, 66),
		Text = c.desc, FontFace = F.hand, TextColor3 = rgb(46, 36, 30), TextWrapped = true }, card)
	fitText(ds, c.desc, F.hand, 16, 8, 196, 64, true)
	local rt = spaced(R.name)
	if sig then
		new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(125, 324), Size = UDim2.fromOffset(#rt * 7.3 + 26, 20),
			Text = rt, FontFace = F.mono, TextSize = 12, TextColor3 = WHITE }, card)
	else
		new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 313), Size = UDim2.fromOffset(250, 22), Text = rt, FontFace = F.mono,
			TextSize = 12, TextColor3 = R.label }, card)
	end
	local glowFrame = new("Frame", { Name = "SelGlow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 14, 1, 14),
		BackgroundTransparency = 1, Visible = false }, card)
	corner(glowFrame, 14)
	local glowStroke = stroke(glowFrame, R.glow, 4, 0.1)
	glowStroke.Name = "SelGlowStroke"
	holder.Parent = parent
	local api = { card = card, rarity = R, data = c, baked = true }
	function api.setGlow(on, col)
		glowFrame.Visible = on and true or false
		if col then glowStroke.Color = col end
	end
	return holder, api
end

-- ======================================================================================
-- v4.9 template cache
-- ======================================================================================
local TEMPLATE_MAX = 36
local templates, tplOrder, tplBuilding = {}, {}, {}
local function touch(key)
	local i = table.find(tplOrder, key)
	if i then table.remove(tplOrder, i) end
	table.insert(tplOrder, key)
end
local function evict()
	while #tplOrder > TEMPLATE_MAX do
		local k = table.remove(tplOrder, 1)
		local t = templates[k]
		templates[k] = nil
		if t then t:Destroy() end
	end
end
local function getTemplate(id, lite)
	local key = id .. ":" .. tostring(lite or "full")
	local t = templates[key]
	if t then touch(key) return t end
	if tplBuilding[key] then -- another thread is drawing it right now (the first draw can yield while it measures text)
		local t0 = os.clock()
		while tplBuilding[key] and os.clock() - t0 < 5 do task.wait() end
		t = templates[key]
		if t then touch(key) return t end
		return nil
	end
	tplBuilding[key] = true
	local ok, holder = pcall(buildFresh, nil, id, { width = A.W, anim = false }, lite)
	tplBuilding[key] = nil
	if not ok or not holder then
		warn("[CardArt] template failed for", id, holder)
		return nil
	end
	holder.Name = "CardTemplate"
	templates[key] = holder
	touch(key)
	evict()
	return holder
end

function A.Build(parent, id, opts)
	opts = opts or {}
	local width = opts.width or A.W
	local anim = opts.anim ~= false
	-- level of detail: false = full, 1 = lite, 2 = micro
	local lite = false
	if opts.lod == "micro" then lite = 2
	elseif opts.lod == "lite" then lite = 1
	elseif opts.lod == nil and not anim then
		if width <= 130 then lite = 2 elseif width <= 260 then lite = 1 end
	end
	if not anim and opts.baked ~= false then
		local h, api = buildBaked(parent, id, opts)
		if h then return h, api end
	end
	if anim or opts.cache == false then
		return buildFresh(parent, id, opts, lite)
	end
	local tpl = getTemplate(id, lite)
	if not tpl then return buildFresh(parent, id, opts, lite) end
	local c = Cards.ById[id] or Cards.List[1]
	local R = Cards.RarityById[c.rarity]
	local holder = tpl:Clone()
	holder.Name = "Card_" .. c.id
	holder.Size = UDim2.fromOffset(width, width * A.H / A.W)
	holder.Position = opts.position or UDim2.new()
	holder.AnchorPoint = opts.anchor or Vector2.zero
	local card = holder:FindFirstChild("Card")
	local us = card and card:FindFirstChildOfClass("UIScale")
	if us then us.Scale = width / A.W end
	holder.Parent = parent
	local glowFrame = card and card:FindFirstChild("SelGlow")
	local glowStroke = glowFrame and glowFrame:FindFirstChild("SelGlowStroke")
	local api = { card = card, rarity = R, data = c }
	function api.setGlow(on, col)
		if glowFrame then glowFrame.Visible = on and true or false end
		if col and glowStroke then glowStroke.Color = col end
	end
	return holder, api
end

-- drops every cached template (call it if you ever change the card art at run time)
function A.ClearCache()
	for _, t in templates do t:Destroy() end
	table.clear(templates)
	table.clear(tplOrder)
end

return A
