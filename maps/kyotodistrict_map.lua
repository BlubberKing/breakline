--[[ KYOTO DISTRICT v4 (bigger buildings + arches, cover in the middle, no-clip pass) - map generator for BREAKLINE (3v3 Wall Push)
 Run ONCE in the BREAKLINE place: View > Command Bar, paste this whole script, press Enter (it takes a short while, then prints "done").
 Builds ServerStorage > breaklineMaps > kyotodistrict_map (folders are created if missing). Running it again REPLACES the old kyotodistrict_map only.
 Map: 480 wide (X) x 768 long (Z), MapBounds 170 high. Ground y = 0. Red end = -Z, Blue end = +Z. Blue is an exact mirror of Red.
 Search for "local DENSITY" and set it to 0.6 gives fewer trees / small props if the match warp or the loadout recon lags.
 v4 knobs (search for them): "local BSCALE" = how much bigger every building is, "local SEN_W" = size of the red arches on the pilgrim paths,
 "local COVER_LIST" = the cover pieces in the open middle (kind, x, z, yaw, ...). ]]
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local W, L, H = 480, 768, 170
local M = Enum.Material
local C3, V3, CF, ANG = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
local rad, pi, floor, abs, sqrt, atan2, sin, cos, max, min = math.rad, math.pi, math.floor, math.abs, math.sqrt, math.atan2, math.sin, math.cos, math.max, math.min
local rng = Random.new(7421)
local VERM, VERM_D, VERM_L = C3(196, 50, 32), C3(146, 36, 26), C3(214, 76, 46)
local LACQUER = C3(34, 29, 29)
local WOOD_D, WOOD, WOOD_L, WOOD_OLD = C3(82, 62, 46), C3(120, 92, 64), C3(158, 124, 88), C3(104, 92, 78)
local BENGARA = C3(104, 50, 38)
local PLASTER, PLASTER_D = C3(228, 221, 205), C3(186, 178, 160)
local TILE, TILE_D, TILE_L = C3(70, 78, 78), C3(46, 52, 55), C3(92, 100, 98)
local STONE, STONE_D, STONE_L = C3(142, 140, 134), C3(108, 106, 102), C3(168, 165, 156)
local MOSS, MOSS_D = C3(92, 118, 72), C3(64, 88, 52)
local GOLD = C3(208, 170, 74)
local THATCH, THATCH_D = C3(152, 130, 88), C3(112, 94, 64)
local GLOW = C3(255, 196, 112)
local CEDAR, CEDAR_L, CEDAR_BARK = C3(28, 60, 42), C3(44, 86, 54), C3(88, 62, 48)
local MAPLE = { C3(196, 38, 30), C3(222, 82, 34), C3(176, 28, 36), C3(234, 150, 40), C3(206, 60, 30) }
local GINKGO = { C3(236, 192, 52), C3(222, 170, 40) }
local PINE_G = C3(46, 78, 52)
local WATER = C3(86, 150, 168)
local FLOOR_G, FLOOR_D = C3(80, 98, 62), C3(84, 70, 52)
local BLUE_NOREN = C3(34, 50, 86)
local PINE_NEEDLE, PINE_NEEDLE_D = C3(70, 94, 56), C3(54, 76, 46)
local GREEN_BOARD, GREEN_BOARD_D, GREEN_ROOF = C3(78, 112, 88), C3(56, 84, 68), C3(60, 92, 72)
local WEATHER, WEATHER_D = C3(128, 114, 98), C3(90, 80, 70)
local FIR, FIR_L, FIR_D = C3(34, 88, 54), C3(54, 116, 64), C3(24, 66, 46)
local REED, BAMBOO, BAMBOO_L = C3(150, 160, 92), C3(112, 150, 70), C3(142, 178, 88)
local BED = C3(112, 106, 96)
local bl = ServerStorage:FindFirstChild("breaklineMaps")
if not bl then
bl = Instance.new("Folder")
bl.Name = "breaklineMaps"
bl.Parent = ServerStorage
end
local old = bl:FindFirstChild("kyotodistrict_map")
if old then old:Destroy() end
local map = Instance.new("Folder")
map.Name = "kyotodistrict_map"
map:SetAttribute("DisplayName", "KYOTO DISTRICT")
local function folder(name, parent)
local f = Instance.new("Folder")
f.Name = name
f.Parent = parent or map
return f
end
local F = {
ground = folder("Ground"), paths = folder("Paths"), arch = folder("Architecture"), props = folder("Props"),
trees = folder("Trees"), detail = folder("Detail"), spawns = folder("Spawns"), backdrop = folder("Backdrop"), fx = folder("Effects"),
cover = folder("Cover"),
}
local count = 0
local function mk(parent, name, size, cf, color, mat, o)
local p = Instance.new("Part")
p.Name = name
p.Anchored = true
p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
p.Size = size
p.CFrame = cf
p.Color = color
p.Material = mat or M.SmoothPlastic
if o then
if o.shape then p.Shape = o.shape end
if o.t then p.Transparency = o.t end
if o.refl then p.Reflectance = o.refl end
if o.deco then p.CanCollide, p.CanQuery, p.CanTouch = false, false, false end
if o.nocol then p.CanCollide = false end
if o.noshadow then p.CastShadow = false end
end
p.Parent = parent
count += 1
if count % 500 == 0 then task.wait() end
return p
end
local function bx(parent, o, name, w, h, d, x, yb, z, color, mat, op, rot)
return mk(parent, name, V3(w, h, d), o * CF(x, yb + h / 2, z) * (rot or CFrame.identity), color, mat, op)
end
local function cy(parent, o, name, dia, h, x, yb, z, color, mat, op)
return mk(parent, name, V3(h, dia, dia), o * CF(x, yb + h / 2, z) * ANG(0, 0, pi / 2), color, mat, setmetatable({ shape = Enum.PartType.Cylinder }, { __index = op }))
end
local function cyh(parent, o, name, dia, len, x, yc, z, axis, color, mat, op)
local r = axis == "z" and ANG(0, pi / 2, 0) or CFrame.identity
return mk(parent, name, V3(len, dia, dia), o * CF(x, yc, z) * r, color, mat, setmetatable({ shape = Enum.PartType.Cylinder }, { __index = op }))
end
local function ball(parent, o, name, dia, x, yc, z, color, mat, op)
return mk(parent, name, V3(dia, dia, dia), o * CF(x, yc, z), color, mat, setmetatable({ shape = Enum.PartType.Ball }, { __index = op }))
end
local function beam(parent, o, name, a, b, thick, color, mat, op, thick2)
local pa, pb = o:PointToWorldSpace(a), o:PointToWorldSpace(b)
local d = pb - pa
local len = d.Magnitude
if len < 0.01 then return nil end
local up = abs(d.Unit.Y) > 0.98 and V3(1, 0, 0) or V3(0, 1, 0)
return mk(parent, name, V3(thick, thick2 or thick, len), CFrame.lookAt((pa + pb) / 2, pb, up), color, mat, op)
end
local function model(name, parent)
local m = Instance.new("Model")
m.Name = name
m.Parent = parent
return m
end
local function frame(x, z, yawDeg, y) return CF(x, y or 0, z) * ANG(0, rad(yawDeg or 0), 0) end
local function both(fn)
fn(function(x, z, yaw, y) return frame(x, z, yaw or 0, y) end, 1)
fn(function(x, z, yaw, y) return frame(x, -z, (yaw or 0) + 180, y) end, -1)
end
local DECO = { deco = true }
local NOSH = { deco = true, noshadow = true }
local function gable(parent, o, len, profile, thick, color, y0, ribColor, tileMat)
for side = -1, 1, 2 do
for i = 1, #profile - 1 do
local a, b = profile[i], profile[i + 1]
local dr, dh = a[1] - b[1], b[2] - a[2]
local sl = sqrt(dr * dr + dh * dh)
local ang = atan2(dh, dr)
local cf = o * CF(0, y0 + (a[2] + b[2]) / 2, side * (a[1] + b[1]) / 2) * ANG(side * ang, 0, 0)
mk(parent, "RoofTile", V3(len, thick, sl + 0.25), cf, color, tileMat or M.Slate)
local n = floor(len / 1.45)
for k = 0, n do
local lx = -len / 2 + 0.4 + k * ((len - 0.8) / n)
mk(parent, "TileRib", V3(0.2, 0.16, sl), cf * CF(lx, thick / 2 + 0.07, 0), ribColor or TILE_D, M.Slate, NOSH)
end
end
local e = profile[1]
bx(parent, o, "Fascia", len + 0.5, 0.8, 0.5, 0, y0 - 0.1, side * (e[1] + 0.05), LACQUER, M.WoodPlanks, nil, nil)
end
local top = profile[#profile]
bx(parent, o, "RidgeCap", len + 0.9, 0.9, 1.5, 0, y0 + top[2] - 0.15, 0, TILE_D, M.Slate)
for s = -1, 1, 2 do -- onigawara (ridge-end tiles)
bx(parent, o, "Onigawara", 0.9, 2.1, 1.7, s * (len / 2 + 0.3), y0 + top[2] - 0.2, 0, TILE_D, M.Slate)
bx(parent, o, "OnigawaraTop", 0.7, 0.8, 1.2, s * (len / 2 + 0.3), y0 + top[2] + 1.8, 0, GOLD, M.Metal, DECO)
end
end
local function gableEnd(parent, o, len, profile, y0, color, mat, steps)
local top = profile[#profile]
local function runAt(h) -- half-width of the roof at height h
for i = 1, #profile - 1 do
local a, b = profile[i], profile[i + 1]
if h >= a[2] and h <= b[2] then
local t = (h - a[2]) / max(0.001, b[2] - a[2])
return a[1] + (b[1] - a[1]) * t
end
end
return 0.2
end
steps = steps or 6
local hh = top[2] / steps
for s = -1, 1, 2 do
for i = 0, steps - 1 do
local r = runAt(i * hh + hh * 0.5) - 0.6
if r > 0.3 then bx(parent, o, "GableBoard", 0.5, hh + 0.05, r * 2, s * (len / 2 - 0.9), y0 + i * hh, 0, color, mat) end
end
end
end
local function stepRoof(parent, o, w, d, y0, courses, color, mat, corners)
local y = y0
for _, c in courses do
local cw, cd = max(0.6, w - c[1] * 2), max(0.6, d - c[1] * 2)
bx(parent, o, "RoofCourse", cw, c[2], cd, 0, y, 0, color, mat or M.Slate)
bx(parent, o, "RoofEdge", cw + 0.3, 0.28, cd + 0.3, 0, y, 0, TILE_D, M.Slate, NOSH)
y += c[2]
end
if corners then
local c1 = courses[1]
local cw, cd = w - c1[1] * 2, d - c1[1] * 2
for sx = -1, 1, 2 do
for sz = -1, 1, 2 do
bx(parent, o, "EaveUpturn", 1.7, 0.5, 1.7, sx * (cw / 2 + 0.1), y0 + 0.4, sz * (cd / 2 + 0.1), TILE_D, M.Slate, NOSH, ANG(0, rad(45), 0))
end
end
end
return y
end
local function stairs(parent, o, name, w, steps, rise, run, x, z, color, mat, dir)
for i = 1, steps do
bx(parent, o, name, w, rise * i, run, x, 0, z + dir * (i - 1) * run, color, mat or M.Cobblestone)
end
end
local function lantern(parent, o, scale, lit)
local s = scale or 1
local m = model("StoneLantern", parent)
bx(m, o, "Base", 2.4 * s, 0.5 * s, 2.4 * s, 0, 0, 0, STONE_D, M.Granite)
cy(m, o, "Pedestal", 1.4 * s, 0.9 * s, 0, 0.5 * s, 0, STONE, M.Granite)
cy(m, o, "Pole", 0.8 * s, 2.4 * s, 0, 1.4 * s, 0, STONE, M.Granite)
bx(m, o, "Plinth", 1.9 * s, 0.35 * s, 1.9 * s, 0, 3.8 * s, 0, STONE_L, M.Granite, nil, ANG(0, rad(45), 0))
bx(m, o, "Firebox", 1.3 * s, 1.3 * s, 1.3 * s, 0, 4.15 * s, 0, STONE, M.Granite)
for _, a in { 0, 90, 180, 270 } do -- glowing windows
local w = o * ANG(0, rad(a), 0)
mk(m, "Glow", V3(0.55 * s, 0.7 * s, 0.1 * s), w * CF(0, 4.75 * s, 0.68 * s), GLOW, M.Neon, { deco = true, t = lit and 0 or 0.3 })
end
bx(m, o, "RoofBase", 2.7 * s, 0.35 * s, 2.7 * s, 0, 5.45 * s, 0, STONE_D, M.Granite, nil, ANG(0, rad(45), 0))
bx(m, o, "Roof2", 1.8 * s, 0.4 * s, 1.8 * s, 0, 5.8 * s, 0, STONE_D, M.Granite, nil, ANG(0, rad(45), 0))
bx(m, o, "Roof3", 0.9 * s, 0.4 * s, 0.9 * s, 0, 6.2 * s, 0, STONE_D, M.Granite, nil, ANG(0, rad(45), 0))
ball(m, o, "Hoju", 0.7 * s, 0, 6.85 * s, 0, STONE_L, M.Granite, DECO)
if lit then
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = GLOW, 14 * s, 1.1, false
pl.Parent = m:FindFirstChild("Glow")
end
return m
end
local function torii(parent, o, width, height, nameTag)
local m = model(nameTag or "Torii", parent)
local pd = height * 0.1 -- pillar diameter
for _, sx in { -1, 1 } do
local x = sx * width / 2
bx(m, o, "Footing", pd * 1.5, 0.5, pd * 1.5, x, 0, 0, STONE_D, M.Granite)
cy(m, o, "PillarBase", pd * 1.08, height * 0.12, x, 0.5, 0, LACQUER, M.SmoothPlastic)
cy(m, o, "Pillar", pd, height * 0.86, x, 0.5 + height * 0.12, 0, VERM, M.SmoothPlastic)
cy(m, o, "PillarTop", pd * 1.04, 0.35, x, height - 0.4, 0, LACQUER, M.SmoothPlastic, DECO)
end
local ny = height * 0.74
bx(m, o, "Nuki", width + pd * 2.4, pd * 0.55, pd * 0.62, 0, ny, 0, VERM, M.SmoothPlastic) -- tie beam through both pillars
bx(m, o, "Gakuzuka", pd * 0.4, height * 0.17, pd * 0.7, 0, ny + pd * 0.55, 0, VERM_D, M.SmoothPlastic)
bx(m, o, "Plaque", pd * 1.9, height * 0.16, pd * 0.3, 0, ny + pd * 0.56, 0.0, LACQUER, M.SmoothPlastic, nil)
for _, sx in { -1, 1 } do
bx(m, o, "Kusabi", pd * 0.4, pd * 0.9, pd * 0.7, sx * (width / 2 - pd * 0.9), ny - pd * 0.9, 0, LACQUER, M.WoodPlanks, DECO)
end
local ky = height - pd * 0.15
bx(m, o, "Shimaki", width + pd * 3.4, pd * 0.7, pd * 0.9, 0, ky - pd * 0.5, 0, VERM, M.SmoothPlastic)
bx(m, o, "KasagiCentre", width + pd * 1.4, pd * 0.62, pd * 1.5, 0, ky + 0.15, 0, LACQUER, M.SmoothPlastic)
for _, sx in { -1, 1 } do -- the roof ends sweep UP
bx(m, o, "KasagiWing", pd * 3.2, pd * 0.62, pd * 1.5, sx * (width / 2 + pd * 1.7 + 0.5), ky + 0.55, 0, LACQUER, M.SmoothPlastic, nil, ANG(0, 0, sx * rad(14)))
end
return m
end
local function komainu(parent, o, scale)
local s = scale or 1
local m = model("Komainu", parent)
bx(m, o, "Pedestal", 2.6 * s, 2 * s, 3 * s, 0, 0, 0, STONE_D, M.Granite)
bx(m, o, "PedestalCap", 2.9 * s, 0.3 * s, 3.3 * s, 0, 2 * s, 0, STONE, M.Granite)
bx(m, o, "Body", 1.5 * s, 1.4 * s, 2.2 * s, 0, 2.3 * s, 0, STONE, M.Slate)
bx(m, o, "Chest", 1.2 * s, 1.5 * s, 0.9 * s, 0, 2.8 * s, 0.9 * s, STONE, M.Slate)
bx(m, o, "Head", 1.3 * s, 1.1 * s, 1.1 * s, 0, 4.0 * s, 1.0 * s, STONE_L, M.Slate)
bx(m, o, "Snout", 0.9 * s, 0.5 * s, 0.7 * s, 0, 4.0 * s, 1.75 * s, STONE_L, M.Slate)
bx(m, o, "Mane", 1.5 * s, 0.4 * s, 0.7 * s, 0, 4.9 * s, 0.8 * s, STONE_D, M.Slate)
bx(m, o, "Tail", 0.6 * s, 1.1 * s, 0.6 * s, 0, 2.6 * s, -1.2 * s, STONE_D, M.Slate, nil, ANG(rad(-25), 0, 0))
for _, sx in { -0.5, 0.5 } do bx(m, o, "Leg", 0.4 * s, 1.6 * s, 0.5 * s, sx * s, 2.3 * s, 1.0 * s, STONE, M.Slate) end
return m
end
local function cedar(parent, x, z, h, rngv, gy)
local m = model("Cedar", parent)
local o = CF(x, gy or 0, z) * ANG(0, rad(rngv:NextInteger(0, 359)), 0)
local tr = h * 0.045
cy(m, o, "Trunk", tr * 1.9, h * 0.34, 0, -0.2, 0, CEDAR_BARK, M.Wood, nil)
cy(m, o, "Trunk2", tr * 1.2, h * 0.65, 0, h * 0.3, 0, CEDAR_BARK, M.Wood, DECO)
local tiers = 7
local base = h * 0.17
for i = 1, tiers do
local t = (i - 1) / (tiers - 1)
local r = (h * 0.22) * (1 - t * 0.86)
local col = (i % 2 == 0) and CEDAR or CEDAR_L
cy(m, o, "Foliage", r * 2, h * 0.07, rngv:NextNumber(-0.4, 0.4), base + t * h * 0.78, rngv:NextNumber(-0.4, 0.4), col, M.Grass, NOSH)
cy(m, o, "FoliageU", r * 1.3, h * 0.05, 0, base + t * h * 0.78 + h * 0.06, 0, col, M.Grass, NOSH)
end
return m
end
local function maple(parent, x, z, h, rngv, palette, gy)
local m = model("Momiji", parent)
local o = CF(x, gy or 0, z) * ANG(0, rad(rngv:NextInteger(0, 359)), 0)
local tr = h * 0.05
cy(m, o, "Trunk", tr * 1.8, h * 0.5, 0, -0.2, 0, CEDAR_BARK, M.Wood, nil)
local top = V3(0, h * 0.5, 0)
local nb = 4
local cols = palette or MAPLE
for i = 1, nb do
local a = (i / nb) * pi * 2 + rngv:NextNumber(-0.4, 0.4)
local reach = h * rngv:NextNumber(0.2, 0.32)
local tip = V3(cos(a) * reach, h * rngv:NextNumber(0.72, 0.92), sin(a) * reach)
beam(m, o, "Branch", top, tip, tr * 0.75, CEDAR_BARK, M.Wood, DECO)
local pick = cols[rngv:NextInteger(1, #cols)]
local d = h * rngv:NextNumber(0.36, 0.5)
ball(m, o, "Leaves", d, tip.X, tip.Y, tip.Z, pick, M.Grass, NOSH)
ball(m, o, "LeavesB", d * 0.7, tip.X + rngv:NextNumber(-2, 2), tip.Y + d * 0.28, tip.Z + rngv:NextNumber(-2, 2), cols[rngv:NextInteger(1, #cols)], M.Grass, NOSH)
end
ball(m, o, "Crown", h * 0.5, 0, h * 0.78, 0, cols[rngv:NextInteger(1, #cols)], M.Grass, NOSH)
for _ = 1, 4 do
local a, r = rngv:NextNumber(0, pi * 2), rngv:NextNumber(2, h * 0.4)
cy(m, o, "LeafLitter", rngv:NextNumber(2.5, 5), 0.06, cos(a) * r, 0.04, sin(a) * r, cols[rngv:NextInteger(1, #cols)], M.Grass, NOSH)
end
return m
end
local function pine(parent, o, h) -- matsu (garden pine): leaning trunk, every cloud pad hangs on its own branch (no floating pads)
local m = model("Matsu", parent)
local P0, P1, P2 = V3(0, -0.2, 0), V3(1.6, h * 0.55, 0.4), V3(-0.4, h * 0.88, 0)
beam(m, o, "Trunk", P0, P1, h * 0.09, CEDAR_BARK, M.Wood)
beam(m, o, "Trunk2", P1, P2, h * 0.07, CEDAR_BARK, M.Wood)
local function trunkAt(y) -- trunk centre at height y
if y <= P1.Y then local t = (y - P0.Y) / (P1.Y - P0.Y) return V3(P0.X + (P1.X - P0.X) * t, y, P0.Z + (P1.Z - P0.Z) * t) end
local t = min(1, (y - P1.Y) / (P2.Y - P1.Y))
return V3(P1.X + (P2.X - P1.X) * t, y, P1.Z + (P2.Z - P1.Z) * t)
end
local pads = { { 3.4, 0.6, 2.4 }, { -1.5, 0.78, 1.6 }, { 0.4, 0.95, -1.8 }, { 4.6, 0.4, -1.2 } }
for _, p in pads do
local py = h * p[2]
local pad = h * 0.1
beam(m, o, "Branch", trunkAt(py), V3(p[1], py + pad * 0.5, p[3]), h * 0.045, CEDAR_BARK, M.Wood, DECO)
cy(m, o, "Pad", h * 0.42, pad, p[1], py, p[3], PINE_G, M.Grass, NOSH)
cy(m, o, "PadTop", h * 0.28, h * 0.08, p[1], py + pad, p[3], CEDAR_L, M.Grass, NOSH)
end
cy(m, o, "Crown", h * 0.3, h * 0.08, P2.X, P2.Y - 0.1, P2.Z, CEDAR_L, M.Grass, NOSH)
return m
end
local function conifer(parent, x, y, z, h, rngv, c1, c2)
local m = model("Fir", parent)
local o = CF(x, y, z) * ANG(0, rad(rngv:NextInteger(0, 359)), 0)
c1, c2 = c1 or FIR, c2 or FIR_L
local tr = max(0.7, h * 0.04)
cy(m, o, "Trunk", tr * 1.9, h * 0.3, 0, -0.3, 0, CEDAR_BARK, M.Wood)
cy(m, o, "Trunk2", tr * 1.1, h * 0.7, 0, h * 0.25, 0, CEDAR_BARK, M.Wood, DECO)
local tiers = 8
for i = 1, tiers do
local t = (i - 1) / (tiers - 1)
local r = (h * 0.2) * (1 - t * 0.9)
local yy = h * 0.14 + t * h * 0.8
local col = (i % 2 == 0) and c1 or c2
cy(m, o, "Tier", r * 2, h * 0.075, 0, yy, 0, col, M.Grass, NOSH)
cy(m, o, "TierTop", r * 1.25, h * 0.06, rngv:NextNumber(-0.2, 0.2), yy + h * 0.07, rngv:NextNumber(-0.2, 0.2), col == c1 and c2 or c1, M.Grass, NOSH)
end
return m
end
local function rock(parent, o, w, h, d, color)
local m = model("Rock", parent)
mk(m, "Boulder", V3(w, h, d), o * CF(0, h * 0.4, 0) * ANG(rad(rng:NextInteger(-8, 8)), rad(rng:NextInteger(0, 90)), rad(rng:NextInteger(-8, 8))), color or STONE_D, M.Slate)
mk(m, "BoulderTop", V3(w * 0.7, h * 0.55, d * 0.7), o * CF(rng:NextNumber(-0.4, 0.4), h * 0.78, rng:NextNumber(-0.4, 0.4)) * ANG(rad(rng:NextInteger(-12, 12)), rad(rng:NextInteger(0, 90)), rad(rng:NextInteger(-12, 12))), color or STONE, M.Slate)
bx(m, o, "Moss", w * 0.62, 0.22, d * 0.62, 0, h * 1.02, 0, MOSS, M.Grass, DECO)
return m
end
local function post(parent, o, x, z, h, dia, yb, color)
yb = yb or 0
bx(parent, o, "Footing", dia * 1.5, 0.45, dia * 1.5, x, yb, z, STONE_D, M.Granite)
return cy(parent, o, "Pillar", dia, h, x, yb + 0.45, z, color or VERM, M.SmoothPlastic)
end
local holedWall
local function machiya(parent, o, w, d, op)
op = op or {}
local m = model(op.name or "Machiya", parent)
local h1, h2 = 4.6, 3.8
local lat = op.latticeColor or BENGARA
bx(m, o, "Foundation", w, 0.7, d, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "BackWall", w, h1 + h2, 0.5, 0, 0.7, -d / 2 + 0.25, PLASTER_D, M.Concrete)
for _, sx in { -1, 1 } do
bx(m, o, "SideWall", 0.5, h1 + h2, d, sx * (w / 2 - 0.25), 0.7, 0, PLASTER, M.Concrete)
for _, py in { 0.7, h1 + 0.7 } do bx(m, o, "SideTimber", 0.65, 0.35, d, sx * (w / 2 - 0.25), py, 0, WOOD_D, M.Wood, DECO) end
for k = 0, 3 do bx(m, o, "SidePost", 0.65, h1 + h2, 0.4, sx * (w / 2 - 0.25), 0.7, -d / 2 + 0.3 + k * (d - 0.6) / 3, WOOD_D, M.Wood, DECO) end
end
bx(m, o, "Floor", w - 1, 0.4, d - 1, 0, 0.7, 0, WOOD, M.WoodPlanks, nil)
bx(m, o, "FloorUpper", w - 1, 0.4, d - 1, 0, 0.7 + h1, 0, WOOD, M.WoodPlanks, DECO)
local fz = d / 2 - 0.15
local doorX = op.doorX or -w * 0.2
local doorW = op.doorW or 2.4
holedWall(m, o, "FrontPlinth", w, 1.1, 0.4, 0, 0.7, fz, WOOD_D, M.WoodPlanks, { { doorX, doorW, 0, 1.1 } })
local n = floor((w - 0.6) / 0.62)
for i = 0, n do
local x = -w / 2 + 0.5 + i * ((w - 1) / n)
if abs(x - doorX) > doorW / 2 + 0.2 then
bx(m, o, "KoshiSlat", 0.24, h1 - 1.2, 0.34, x, 1.8, fz + 0.1, lat, M.Wood, nil)
end
end
bx(m, o, "KoshiRailTop", w, 0.3, 0.45, 0, 0.7 + h1 - 0.3, fz + 0.05, WOOD_D, M.Wood)
bx(m, o, "KoshiRailMid", w, 0.2, 0.4, 0, 3.2, fz + 0.05, WOOD_D, M.Wood, DECO)
bx(m, o, "DoorHeader", doorW + 0.6, 0.35, 0.5, doorX, 0.7 + h1 - 0.38, fz + 0.05, WOOD_D, M.Wood) -- v4: door 3.6 -> 4.5 tall before scaling
bx(m, o, "DoorShadow", doorW, h1 - 0.9, 0.3, doorX, 0.8, fz - 0.15, C3(28, 22, 20), M.SmoothPlastic, DECO)
if not op.noNoren then -- noren curtain: split cloth with a pale stripe
for k = -1, 1, 2 do
bx(m, o, "Noren", doorW * 0.46, 1.9, 0.08, doorX + k * doorW * 0.25, 0.7 + h1 - 3.0, fz + 0.4, BLUE_NOREN, M.Fabric, DECO)
end
bx(m, o, "NorenMark", 0.5, 0.5, 0.05, doorX, 0.7 + h1 - 2.4, fz + 0.46, PLASTER, M.Fabric, DECO)
end
gable(m, o * CF(0, 0, d / 2 - 0.1), w + 0.8, { { 2.3, 0 }, { 0, 1.0 } }, 0.38, op.tile or TILE, 0.7 + h1 - 0.05, TILE_D) -- hisashi (the back half hides inside the wall)
bx(m, o, "UpperFront", w, h2 - 0.4, 0.45, 0, 0.7 + h1 + 0.2, fz, PLASTER, M.Concrete)
bx(m, o, "UpperBeam", w, 0.4, 0.55, 0, 0.7 + h1, fz + 0.03, WOOD_D, M.Wood)
local nw = max(1, floor(w / 4.2))
for i = 1, nw do
local x = -w / 2 + (i - 0.5) * (w / nw)
bx(m, o, "WindowFrame", 2.5, 1.9, 0.3, x, 0.7 + h1 + 1.3, fz + 0.25, WOOD_D, M.Wood, nil)
bx(m, o, "WindowDark", 2.1, 1.5, 0.2, x, 0.7 + h1 + 1.5, fz + 0.3, C3(42, 36, 32), M.SmoothPlastic, DECO)
for k = 0, 4 do bx(m, o, "Mushiko", 0.14, 1.5, 0.2, x - 0.8 + k * 0.4, 0.7 + h1 + 1.5, fz + 0.42, lat, M.Wood, DECO) end
end
local span = d / 2 + 1.5
local prof = { { span, 0 }, { span * 0.58, 0.9 }, { 0, 3.1 } }
local rm = model("Roof", m)
gable(rm, o, w + 1.4, prof, 0.42, op.tile or TILE, 0.7 + h1 + h2 - 0.1, TILE_D)
gableEnd(rm, o, w + 1.4, prof, 0.7 + h1 + h2 - 0.1, PLASTER, M.Concrete, 5)
if not op.noLantern then
ball(m, o, "PaperLantern", 1.15, doorX + doorW / 2 + 1.0, 0.7 + h1 - 1.7, fz + 0.9, C3(210, 50, 36), M.Neon, { deco = true, t = 0.05 })
bx(m, o, "LanternCap", 0.5, 0.12, 0.5, doorX + doorW / 2 + 1.0, 0.7 + h1 - 1.1, fz + 0.9, LACQUER, M.SmoothPlastic, DECO)
end
bx(m, o, "Kanban", 0.2, 1.7, 1.1, -w / 2 + 0.2, 0.7 + h1 - 2.5, fz + 1.1, WOOD_L, M.WoodPlanks, DECO)
return m
end
local function pavilion(parent, o, w, d, h, color)
local m = model("Pavilion", parent)
local px, pz = w / 2 - 0.7, d / 2 - 0.7
for _, sx in { -1, 1 } do
for _, sz in { -1, 1 } do post(m, o, sx * px, sz * pz, h, 1.1, 0, color or WOOD_D) end
end
for _, sx in { -1, 1 } do bx(m, o, "Beam", 0.6, 0.7, d - 0.6, sx * px, h + 0.4, 0, WOOD_D, M.Wood) end
for _, sz in { -1, 1 } do bx(m, o, "BeamX", w - 0.6, 0.7, 0.6, 0, h + 0.4, sz * pz, WOOD_D, M.Wood) end
local span = d / 2 + 1.6
local prof = { { span, 0 }, { span * 0.55, 0.8 }, { 0, 2.8 } }
gable(m, o, w + 1.8, prof, 0.4, TILE, h + 1.1, TILE_D)
gableEnd(m, o, w + 1.8, prof, h + 1.1, PLASTER_D, M.Concrete, 4)
return m
end
local function pagoda(parent, o)
local m = model("Sanjunoto", parent)
local plat = model("Platform", m)
bx(plat, o, "Terrace", 26, 1.6, 26, 0, 0, 0, STONE_D, M.Cobblestone)
bx(plat, o, "TerraceCap", 27, 0.35, 27, 0, 1.6, 0, STONE_L, M.Granite)
stairs(plat, o, "Step", 8, 5, 0.32, 1.3, 0, 13.2, STONE, M.Granite, -1)
local y = 1.95
local sizes = { 14.5, 11.5, 8.8 }
local heights = { 6.6, 5.6, 5.0 }
for i = 1, 3 do
local s, hgt = sizes[i], heights[i]
bx(m, o, "Base" .. i, s + 0.8, 0.6, s + 0.8, 0, y, 0, WOOD_D, M.Wood)
bx(m, o, "Core" .. i, s - 2.2, hgt, s - 2.2, 0, y + 0.6, 0, PLASTER, M.Concrete)
for gx = 0, 3 do
for _, sz in { -1, 1 } do
cy(m, o, "Pillar", 0.9, hgt, -s / 2 + 0.7 + gx * ((s - 1.4) / 3), y + 0.6, sz * (s / 2 - 0.7), VERM, M.SmoothPlastic)
cy(m, o, "PillarS", 0.9, hgt, sz * (s / 2 - 0.7), y + 0.6, -s / 2 + 0.7 + gx * ((s - 1.4) / 3), VERM, M.SmoothPlastic)
end
end
for _, a in { 0, 90, 180, 270 } do
local w = o * ANG(0, rad(a), 0)
bx(m, w, "Window", s * 0.34, hgt * 0.5, 0.35, 0, y + 0.6 + hgt * 0.25, s / 2 - 1.05, C3(44, 34, 30), M.WoodPlanks, DECO)
for k = -2, 2 do bx(m, w, "Lattice", 0.12, hgt * 0.5, 0.4, k * s * 0.07, y + 0.6 + hgt * 0.25, s / 2 - 0.98, VERM_D, M.Wood, DECO) end
bx(m, w, "Rail", s - 0.6, 0.3, 0.3, 0, y + 0.6 + 1.0, s / 2 + 0.3, VERM_D, M.Wood, DECO)
end
bx(m, o, "Beam" .. i, s + 1.4, 0.55, s + 1.4, 0, y + 0.6 + hgt, 0, WOOD_D, M.Wood)
local top = stepRoof(m, o, s + 8.4 - i * 0.6, s + 8.4 - i * 0.6, y + 0.6 + hgt + 0.5,
{ { 0, 0.55 }, { 0.9, 0.55 }, { 1.9, 0.7 }, { 3.0, 0.8 }, { 4.2, 0.9 }, { 5.2, 0.9 } }, TILE, M.Slate, true)
y = top
end
cy(m, o, "SorinMast", 0.5, 8.5, 0, y - 0.4, 0, GOLD, M.Metal)
for i = 0, 8 do cy(m, o, "SorinRing", 2.4 - i * 0.18, 0.2, 0, y + 0.8 + i * 0.7, 0, GOLD, M.Metal, DECO) end
ball(m, o, "SorinJewel", 1.1, 0, y + 7.4, 0, GOLD, M.Metal, DECO)
cy(m, o, "SorinBase", 1.8, 0.8, 0, y - 0.3, 0, GOLD, M.Metal, DECO)
return m
end
local function niomon(parent, o)
local m = model("Niomon", parent)
bx(m, o, "Podium", 32, 1.6, 17, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "PodiumCap", 33, 0.3, 18, 0, 1.6, 0, STONE_L, M.Granite)
bx(m, o, "Threshold", 10.6, 0.4, 17, 0, 1.6, 0, STONE, M.Granite, DECO)
local y0 = 1.9
local cols = { -13, -5.4, 5.4, 13 }
for _, x in cols do
for _, z in { -6, 6 } do
cy(m, o, "Column", 1.9, 9.2, x, y0, z, VERM, M.SmoothPlastic)
cy(m, o, "ColumnBase", 2.3, 0.6, x, y0, z, LACQUER, M.SmoothPlastic, DECO)
end
bx(m, o, "TieBeam", 1.0, 0.8, 13, x, y0 + 7.0, 0, VERM_D, M.SmoothPlastic)
end
for _, z in { -6, 6 } do
bx(m, o, "Lintel", 28.6, 1.1, 1.2, 0, y0 + 8.9, z, VERM, M.SmoothPlastic)
bx(m, o, "LintelLow", 28.6, 0.5, 0.9, 0, y0 + 6.4, z, VERM_D, M.SmoothPlastic, DECO)
end
for _, sx in { -1, 1 } do
local cx = sx * 9.2
bx(m, o, "CageBack", 6.8, 7.4, 0.6, cx, y0, -6, WOOD_D, M.WoodPlanks)
bx(m, o, "CageSide", 0.6, 7.4, 12, sx * 12.5, y0, 0, WOOD_D, M.WoodPlanks)
for k = 0, 6 do bx(m, o, "CageSlatF", 0.2, 6.4, 0.3, cx - 3.0 + k * 1.0, y0 + 0.5, 6.1, LACQUER, M.Wood, DECO) end
bx(m, o, "CageSlatFRail", 6.8, 0.3, 0.4, cx, y0 + 3.2, 6.1, LACQUER, M.Wood, DECO)
local g = o * CF(cx, y0, 0) * ANG(0, sx * rad(-8), 0)
bx(m, g, "NioLegs", 2.2, 2.6, 1.4, 0, 0, 0, STONE_D, M.Slate)
bx(m, g, "NioTorso", 2.8, 3.0, 1.7, 0, 2.6, 0, sx < 0 and VERM_L or VERM_D, M.Slate)
bx(m, g, "NioHead", 1.5, 1.5, 1.4, 0, 5.6, 0, sx < 0 and VERM_L or VERM_D, M.Slate)
bx(m, g, "NioBrow", 1.7, 0.3, 0.4, 0, 6.6, 0.6, LACQUER, M.Slate, DECO)
bx(m, g, "NioArmUp", 0.8, 2.6, 0.8, sx * 1.9, 4.4, 0.4, sx < 0 and VERM_L or VERM_D, M.Slate, nil, ANG(rad(-30), 0, sx * rad(14)))
bx(m, g, "NioArmLow", 0.8, 2.2, 0.8, -sx * 1.9, 2.8, 0.2, sx < 0 and VERM_L or VERM_D, M.Slate)
bx(m, g, "NioPedestal", 4.4, 0.7, 3.2, 0, -0.1, 0, STONE, M.Granite, DECO)
end
stairs(m, o, "ApproachStep", 10.6, 4, 0.475, 1.1, 0, 12.4, STONE, M.Granite, -1)
stairs(m, o, "ApproachStep", 10.6, 4, 0.475, 1.1, 0, -12.4, STONE, M.Granite, 1)
local ud = y0 + 9.6
bx(m, o, "UpperDeck", 30.5, 0.9, 15.5, 0, ud - 0.5, 0, WOOD, M.WoodPlanks)
bx(m, o, "UpperDeckEdge", 31.2, 0.5, 16.2, 0, ud - 0.8, 0, WOOD_D, M.Wood, DECO)
for _, x in { -13, -6.5, 0, 6.5, 13 } do
for _, z in { -6.2, 6.2 } do cy(m, o, "UpperColumn", 1.3, 6.2, x, ud + 0.4, z, VERM, M.SmoothPlastic) end
end
for _, z in { -7.4, 7.4 } do
bx(m, o, "KoranTop", 30.8, 0.4, 0.45, 0, ud + 1.9, z, VERM_D, M.SmoothPlastic)
bx(m, o, "KoranMid", 30.8, 0.3, 0.3, 0, ud + 1.0, z, VERM_D, M.SmoothPlastic, DECO)
for i = 0, 15 do bx(m, o, "KoranBalusters", 0.3, 1.5, 0.3, -15 + i * 2.0, ud + 0.4, z, VERM, M.SmoothPlastic, DECO) end
end
for _, sx in { -1, 1 } do
for _, sz in { -1, 1 } do
bx(m, o, "KoranEnd", 0.45, 0.4, 4.6, sx * 15.2, ud + 1.9, sz * 5.1, VERM_D, M.SmoothPlastic)
bx(m, o, "KoranEndLow", 0.3, 0.3, 4.6, sx * 15.2, ud + 1.0, sz * 5.1, VERM_D, M.SmoothPlastic, DECO)
end
end
bx(m, o, "UpperTie", 29, 0.9, 1.3, 0, ud + 6.5, -6.2, VERM, M.SmoothPlastic)
bx(m, o, "UpperTie", 29, 0.9, 1.3, 0, ud + 6.5, 6.2, VERM, M.SmoothPlastic)
for _, sz in { -1, 1 } do
beam(m, o, "SkirtRoof", V3(0, ud - 0.7, sz * 8.0), V3(0, ud - 2.7, sz * 13.0), 32.5, TILE, M.Slate, nil, 0.5)
beam(m, o, "SkirtEdge", V3(0, ud - 2.55, sz * 12.9), V3(0, ud - 2.55, sz * 13.4), 33, TILE_D, M.Slate, DECO, 0.8)
end
stepRoof(m, o, 36, 22, ud + 6.9, { { 0, 0.7 }, { 1.2, 0.7 }, { 2.6, 0.9 }, { 4.2, 1.1 }, { 6.0, 1.3 }, { 8.0, 1.5 }, { 10.2, 1.6 }, { 12.4, 1.8 } }, TILE, M.Slate, true)
bx(m, o, "RoofRidge", 14, 1.2, 2.2, 0, ud + 6.9 + 9.9, 0, TILE_D, M.Slate)
for _, sx in { -1, 1 } do bx(m, o, "Shachi", 1.4, 3.0, 1.4, sx * 7.4, ud + 6.9 + 11.4, 0, GOLD, M.Metal, DECO) end
bx(m, o, "Plaque", 4.6, 2.6, 0.35, 0, ud + 2.8, 7.0, LACQUER, M.WoodPlanks, DECO)
bx(m, o, "PlaqueInset", 3.8, 1.8, 0.2, 0, ud + 3.2, 7.2, GOLD, M.Metal, DECO)
local N = 16
for _, sx in { -1, 1 } do
local so = o * CF(sx * 15.9, 0, 0) * ANG(0, sx * rad(90), 0) -- local +Z points AWAY from the gate
for i = 1, N do
bx(m, so, "GateStair", 5.6, 0.745 * i, 0.9, 0, 0, (N - i) * 0.9 + 0.2, WOOD, M.WoodPlanks)
end
bx(m, so, "StairStringer", 0.4, 1.0, N * 0.9 + 0.6, -3.0, 0.2, N * 0.45, VERM_D, M.SmoothPlastic, DECO)
bx(m, so, "StairStringer", 0.4, 1.0, N * 0.9 + 0.6, 3.0, 0.2, N * 0.45, VERM_D, M.SmoothPlastic, DECO)
end
return m
end
local function glow(parent, o, x, y, z, color, range, bright)
local p = mk(parent, "LightPoint", V3(0.3, 0.3, 0.3), o * CF(x, y, z), color, M.Neon, { deco = true, t = 1, noshadow = true })
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = color, range, bright, false
pl.Parent = p
return p
end
local function rail(parent, o, axis, fixed, a, b, yb, color, hgt)
hgt = hgt or 3.1
local len, mid = b - a, (a + b) / 2
local function put(w, h, d, y, c, mat, op)
if axis == "x" then return bx(parent, o, "Rail", len, h, d, mid, y, fixed, c, mat, op)
else return bx(parent, o, "Rail", d, h, len, fixed, y, mid, c, mat, op) end
end
put(0, 0.45, 0.5, yb + hgt - 0.45, color, M.SmoothPlastic)
put(0, 0.3, 0.3, yb + hgt * 0.55, color, M.SmoothPlastic)
put(0, 1.0, 0.35, yb, color == VERM and VERM_D or color, M.SmoothPlastic) -- kick board (solid, low cover)
local n = max(1, floor(len / 1.7))
for i = 0, n do
local t = a + i * (len / n)
if axis == "x" then bx(parent, o, "Baluster", 0.3, hgt - 0.5, 0.3, t, yb + 0.9, fixed, color, M.SmoothPlastic, DECO)
else bx(parent, o, "Baluster", 0.3, hgt - 0.5, 0.3, fixed, yb + 0.9, t, color, M.SmoothPlastic, DECO) end
end
end
local function hondo(parent, o)
local m = model("Hondo_Butai", parent)
local Y, HALF, DEPTH = 11, 28, 28
local sub = model("Stilts", m)
local cols = {}
for i = -4, 4 do cols[#cols + 1] = i * 6.75 end
local rows = { 2, 8, 14, 20, 26 }
for _, z in rows do
for _, x in cols do
cy(sub, o, "KeyakiPillar", 1.8, Y - 0.6, x, 0, z, WOOD_OLD, M.Wood)
cy(sub, o, "PillarFoot", 2.6, 0.45, x, 0, z, STONE_D, M.Cobblestone)
cy(sub, o, "PillarBand", 2.0, 0.35, x, 5.4, z, WOOD_D, M.Wood, DECO)
end
bx(sub, o, "NukiLow", HALF * 2, 0.7, 0.8, 0, 7.0, z, WOOD_D, M.Wood)
bx(sub, o, "NukiHigh", HALF * 2, 0.7, 0.8, 0, 9.2, z, WOOD_D, M.Wood)
end
for _, x in cols do
bx(sub, o, "TieLow", 0.8, 0.7, 25, x, 7.0, 14, WOOD_D, M.Wood, DECO)
bx(sub, o, "TieHigh", 0.8, 0.7, 25, x, 9.2, 14, WOOD_D, M.Wood, DECO)
end
for _, x in { -1, 1 } do -- diagonal braces under the front edge
beam(sub, o, "Brace", V3(x * 24, 7.4, 26), V3(x * 24, 10.0, 28.6), 0.5, WOOD_D, M.Wood, DECO)
end
bx(m, o, "Joists", HALF * 2 + 2, 0.7, DEPTH + 0.8, 0, Y - 0.9, DEPTH / 2 - 0.2, WOOD_D, M.Wood)
bx(m, o, "Deck", HALF * 2 + 2, 0.4, DEPTH + 0.8, 0, Y - 0.4, DEPTH / 2 - 0.2, WOOD, M.WoodPlanks)
for i = 0, 30 do
bx(m, o, "PlankLine", 0.14, 0.06, DEPTH + 0.6, -HALF - 0.5 + i * ((HALF * 2 + 1) / 30), Y - 0.02, DEPTH / 2 - 0.2, WOOD_D, M.WoodPlanks, NOSH)
end
bx(m, o, "FrontBeam", HALF * 2 + 2.4, 0.7, 0.9, 0, Y - 1.1, DEPTH + 0.6, WOOD_D, M.Wood, DECO)
rail(m, o, "x", DEPTH + 0.2, -HALF - 0.6, HALF + 0.6, Y, VERM_D)
for _, sx in { -1, 1 } do
rail(m, o, "z", sx * (HALF + 0.6), 14.6, 17, Y, VERM_D)
rail(m, o, "z", sx * (HALF + 0.6), 25, DEPTH + 0.2, Y, VERM_D)
for _, z in { 17, 25 } do -- newel posts at the stair mouth
cy(m, o, "Newel", 0.9, 3.6, sx * (HALF + 0.6), Y, z, VERM, M.SmoothPlastic)
ball(m, o, "NewelCap", 1.1, sx * (HALF + 0.6), Y + 3.9, z, GOLD, M.Metal, DECO)
end
end
local hall = model("HondoHall", m)
bx(hall, o, "HallBack", HALF * 2, 10, 0.6, 0, Y, 0.3, PLASTER, M.Concrete)
for _, x in cols do bx(hall, o, "BackPost", 0.9, 10, 0.9, x, Y, 0.6, WOOD_D, M.Wood) end
bx(hall, o, "BackBeamLow", HALF * 2, 0.5, 0.8, 0, Y + 3.2, 0.5, WOOD_D, M.Wood, DECO)
bx(hall, o, "Naijin", 20, 8.6, 8, 0, Y, 4, WOOD_D, M.WoodPlanks)
bx(hall, o, "NaijinPlinth", 21, 1.0, 9, 0, Y, 4.2, LACQUER, M.WoodPlanks, DECO)
bx(hall, o, "NaijinDoors", 7.6, 6.0, 0.3, 0, Y + 1.3, 8.1, GOLD, M.Metal, DECO)
bx(hall, o, "NaijinDoorSplit", 0.25, 6.0, 0.4, 0, Y + 1.3, 8.2, LACQUER, M.Wood, DECO)
for _, sx in { -1, 1 } do
bx(hall, o, "NaijinPanel", 4.4, 5.2, 0.25, sx * 6.2, Y + 1.6, 8.1, BENGARA, M.WoodPlanks, DECO)
cy(hall, o, "Pillar", 1.2, 8.6, sx * 10, Y, 8.4, VERM_D, M.SmoothPlastic)
glow(hall, o, sx * 4.2, Y + 7.2, 8.6, GLOW, 22, 0.9)
end
bx(hall, o, "NaijinEave", 22, 0.5, 2.4, 0, Y + 8.6, 8.8, TILE_D, M.Slate, DECO)
local zf = 14
for _, x in cols do
cy(hall, o, "HallPillar", 1.4, 10.2, x, Y, zf, WOOD_D, M.Wood)
cy(hall, o, "PillarCap", 1.9, 0.5, x, Y + 9.7, zf, VERM_D, M.SmoothPlastic, DECO)
end
bx(hall, o, "HallLintel", HALF * 2, 1.0, 1.0, 0, Y + 8.7, zf, VERM_D, M.SmoothPlastic)
bx(hall, o, "HallLintelLow", HALF * 2, 0.45, 0.8, 0, Y + 7.3, zf, VERM_D, M.SmoothPlastic, DECO)
for i = 1, #cols - 1 do
local xm = (cols[i] + cols[i + 1]) / 2
if abs(xm) > 7 then
bx(hall, o, "ShutterLow", 5.2, 2.4, 0.3, xm, Y, zf, WOOD_D, M.WoodPlanks)
for k = 0, 5 do bx(hall, o, "Shitomi", 0.18, 3.4, 0.2, xm - 2.2 + k * 0.88, Y + 2.4, zf, LACQUER, M.Wood, DECO) end
bx(hall, o, "ShitomiRail", 5.2, 0.25, 0.3, xm, Y + 4.0, zf, LACQUER, M.Wood, DECO)
bx(hall, o, "ShitomiRail", 5.2, 0.25, 0.3, xm, Y + 5.8, zf, LACQUER, M.Wood, DECO)
end
end
for _, sx in { -1, 1 } do -- the hall ends are closed with lattice walls so it stays a room
bx(hall, o, "EndWallLow", 0.4, 3.0, 13.6, sx * (HALF - 0.2), Y, 7.3, PLASTER, M.Concrete)
for k = 0, 6 do bx(hall, o, "EndSlat", 0.25, 4.0, 0.2, sx * (HALF - 0.2), Y + 3.0, 1.2 + k * 2.0, LACQUER, M.Wood, DECO) end
end
local eave = model("EavePillars", m)
for _, x in { -24, -12, 0, 12, 24 } do
cy(eave, o, "EavePillar", 1.3, 10.2, x, Y, 20, WOOD_D, M.Wood)
cy(eave, o, "EavePillarCap", 1.7, 0.45, x, Y + 9.8, 20, VERM_D, M.SmoothPlastic, DECO)
end
bx(eave, o, "EaveBeam", HALF * 2, 0.9, 0.9, 0, Y + 8.9, 20, WOOD_D, M.Wood)
bx(eave, o, "EaveBeamLow", HALF * 2, 0.4, 0.7, 0, Y + 7.5, 20, VERM_D, M.SmoothPlastic, DECO)
for _, x in { -18, -6, 6, 18 } do glow(eave, o, x, Y + 6.5, 19.5, GLOW, 26, 0.8) end
bx(m, o, "Saisen", 4.0, 1.7, 1.9, 0, Y, 17.2, WOOD_D, M.Wood)
for k = 0, 6 do bx(m, o, "SaisenSlat", 3.7, 0.12, 0.2, 0, Y + 1.5, 16.4 + k * 0.28, WOOD_L, M.Wood, DECO) end
local profile = { { 13.5, 0 }, { 9.5, 1.5 }, { 5, 4.8 }, { 0, 9.0 } }
local rf = o * CF(0, 0, 9)
gable(m, rf, HALF * 2 + 6, profile, 0.75, TILE, Y + 10.4, TILE_D, M.Slate)
gableEnd(m, rf, HALF * 2 + 6, profile, Y + 10.4, PLASTER_D, M.Concrete, 7)
local N = 15
for _, sx in { -1, 1 } do
local so = o * CF(sx * (HALF + 0.5), 0, 21) * ANG(0, sx * rad(90), 0) -- local +Z of so = away from the stage (+-X)
for i = 1, N do
bx(m, so, "StageStair", 8, 0.7333 * i, 1.0, 0, 0, (N - i) * 1.0 + 0.5, WOOD, M.WoodPlanks)
end
for _, side in { -1, 1 } do
bx(m, so, "StairStringer", 0.5, 1.2, N + 0.6, side * 4.2, 0, N / 2 + 0.3, VERM_D, M.SmoothPlastic, DECO)
beam(m, so, "StairRail", V3(side * 4.2, Y + 3.0, 0.2), V3(side * 4.2, 3.4, N + 0.6), 0.4, VERM_D, M.SmoothPlastic)
for i = 1, N, 2 do bx(m, so, "StairBaluster", 0.28, 3.0, 0.28, side * 4.2, 0.73 * i, (N - i) + 0.5, VERM, M.SmoothPlastic, DECO) end
end
end
return m
end
local function tsuijibei(parent, o, len, h)
h = h or 5.2
local m = model("Tsuijibei", parent)
bx(m, o, "Base", len, 1.0, 1.9, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "Wall", len, h - 1.9, 1.4, 0, 1.0, 0, PLASTER, M.Concrete)
for k = 0, 3 do bx(m, o, "Stripe", len + 0.04, 0.16, 1.46, 0, 1.0 + (h - 1.9) * (0.45 + k * 0.17), 0, PLASTER_D, M.Concrete, DECO) end
bx(m, o, "CapSlab", len + 0.7, 0.35, 2.5, 0, h - 0.9, 0, TILE, M.Slate)
bx(m, o, "CapRidge", len + 0.7, 0.55, 1.1, 0, h - 0.55, 0, TILE_D, M.Slate)
local n = floor(len / 1.6)
for k = 0, n do bx(m, o, "CapRib", 0.2, 0.2, 2.4, -len / 2 + 0.2 + k * ((len - 0.4) / max(1, n)), h - 0.55, 0, TILE_L, M.Slate, NOSH) end
return m
end
local function emaStand(parent, o, w)
w = w or 7
local m = model("EmaRack", parent)
for _, sx in { -1, 1 } do cy(m, o, "Post", 0.7, 5.6, sx * (w / 2), 0, 0, WOOD_D, M.Wood) end
bx(m, o, "Board", w - 0.4, 3.4, 0.5, 0, 0.9, 0, WOOD, M.WoodPlanks)
bx(m, o, "BoardTrim", w, 0.4, 0.7, 0, 0.7, 0, WOOD_D, M.Wood, DECO)
bx(m, o, "Rail", w, 0.4, 0.6, 0, 4.3, 0, WOOD_D, M.Wood)
for row = 0, 2 do
for k = 0, floor(w / 1.1) - 1 do
local px = -w / 2 + 0.9 + k * 1.1
bx(m, o, "Ema", 0.85, 0.7, 0.14, px, 1.2 + row * 1.0, 0.33, rng:NextInteger(1, 2) == 1 and WOOD_L or PLASTER_D, M.Wood, DECO, ANG(0, 0, rad(rng:NextInteger(-7, 7))))
bx(m, o, "EmaCord", 0.05, 0.4, 0.05, px, 1.9 + row * 1.0, 0.33, VERM, M.Fabric, DECO)
end
end
local roof = o * CF(0, 5.5, 0)
gable(m, roof, w + 1.4, { { 1.5, 0 }, { 0, 0.9 } }, 0.25, TILE, 0, TILE_D, M.Slate)
return m
end
local function karesansui(parent, o, w, d)
local m = model("Karesansui", parent)
bx(m, o, "Border", w + 1.4, 0.5, d + 1.4, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "Gravel", w, 0.58, d, 0, 0, 0, C3(206, 202, 190), M.Sand)
for i = 0, floor(w / 1.1) - 1 do
bx(m, o, "Rake", 0.2, 0.05, d - 0.6, -w / 2 + 0.8 + i * 1.1, 0.58, 0, C3(174, 170, 160), M.Sand, NOSH)
end
for k, p in { { -w * 0.22, -d * 0.12, 3.4, 2.8, 2.6 }, { w * 0.18, d * 0.2, 2.4, 1.9, 2.0 }, { w * 0.28, -d * 0.26, 1.6, 1.2, 1.5 } } do
for r = 1, 2 do cy(m, o, "RakeRing", p[3] * (1.5 + r * 0.8), 0.06, p[1], 0.58, p[2], C3(190, 186, 174), M.Sand, NOSH) end
cy(m, o, "MossIsland", p[3] * 1.5, 0.3, p[1], 0.58, p[2], MOSS, M.Grass, DECO)
rock(m, o * CF(p[1], 0.6, p[2]), p[3], p[4], p[5], k == 1 and STONE_D or STONE)
end
pine(m, o * CF(-w * 0.34, 0.6, d * 0.28), 7.5)
return m
end
local function bellTower(parent, o)
local m = model("ShoroBellTower", parent)
bx(m, o, "Plinth", 11, 1.6, 11, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "PlinthCap", 11.8, 0.3, 11.8, 0, 1.6, 0, STONE_L, M.Granite)
stairs(m, o, "Step", 5, 3, 0.53, 1.0, 0, 6.5, STONE, M.Granite, -1)
local y = 1.9
for _, sx in { -1, 1 } do
for _, sz in { -1, 1 } do
cy(m, o, "Post", 1.0, 8.4, sx * 4.2, y, sz * 4.2, WOOD_D, M.Wood)
cy(m, o, "PostBase", 1.4, 0.4, sx * 4.2, y, sz * 4.2, STONE, M.Granite, DECO)
beam(m, o, "Brace", V3(sx * 4.2, y + 5.2, sz * 4.2), V3(sx * 4.2 * 0.5, y + 7.6, sz * 4.2 * 0.5), 0.35, WOOD, M.Wood, DECO)
end
end
for _, v in { { "x", 4.2 }, { "x", -4.2 }, { "z", 4.2 }, { "z", -4.2 } } do
if v[1] == "x" then bx(m, o, "Rail", 9.4, 0.5, 0.5, 0, y + 7.0, v[2], WOOD_D, M.Wood) bx(m, o, "RailLow", 9.4, 0.4, 0.4, 0, y + 2.4, v[2], WOOD, M.Wood, DECO)
else bx(m, o, "Rail", 0.5, 0.5, 9.4, v[2], y + 7.0, 0, WOOD_D, M.Wood) bx(m, o, "RailLow", 0.4, 0.4, 9.4, v[2], y + 2.4, 0, WOOD, M.Wood, DECO) end
end
stepRoof(m, o, 13.4, 13.4, y + 8.4, { { 0, 0.5 }, { 1.4, 0.7 }, { 2.8, 0.9 }, { 4.2, 1.1 }, { 5.4, 1.3 } }, TILE, M.Slate, true)
cy(m, o, "BellHanger", 0.5, 0.9, 0, y + 7.4, 0, GOLD, M.Metal, DECO)
cy(m, o, "Bell", 2.6, 3.6, 0, y + 3.9, 0, C3(92, 84, 64), M.Metal)
cy(m, o, "BellLip", 3.0, 0.5, 0, y + 3.8, 0, C3(70, 62, 48), M.Metal, DECO)
beam(m, o, "Shumoku", V3(-3.8, y + 4.4, 3.4), V3(-0.5, y + 4.4, 0.6), 0.55, WOOD_L, M.Wood, DECO)
rock(m, o * CF(7.6, 0, -2), 2.4, 1.6, 2.2)
return m
end
local function haiden(parent, o)
local m = model("Haiden", parent)
local W2, D2 = 34, 12
bx(m, o, "StoneBase", W2 + 2, 1.4, D2 + 2, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "StoneCap", W2 + 2.8, 0.3, D2 + 2.8, 0, 1.4, 0, STONE_L, M.Granite)
bx(m, o, "Floor", W2, 0.4, D2, 0, 1.7, 0, WOOD, M.WoodPlanks)
stairs(m, o, "Step", 8, 4, 0.425, 1.1, 0, D2 / 2 + 5.0, STONE, M.Granite, -1)
local y = 2.1
for i = -5, 5 do
cy(m, o, "Pillar", 1.1, 7.6, i * (W2 - 2.4) / 10, y, D2 / 2 - 1.0, VERM, M.SmoothPlastic)
cy(m, o, "PillarBack", 1.1, 7.6, i * (W2 - 2.4) / 10, y, -D2 / 2 + 1.0, VERM, M.SmoothPlastic)
end
bx(m, o, "BackWall", W2 - 1, 6.4, 0.5, 0, y, -D2 / 2 + 0.6, PLASTER, M.Concrete)
bx(m, o, "Lintel", W2, 0.9, 1.0, 0, y + 7.0, D2 / 2 - 1.0, VERM_D, M.SmoothPlastic)
bx(m, o, "LintelLow", W2, 0.4, 0.8, 0, y + 5.4, D2 / 2 - 1.0, VERM, M.SmoothPlastic, DECO)
for i = -5, 4 do bx(m, o, "Frieze", 2.6, 0.9, 0.2, (i + 0.5) * (W2 - 2.4) / 10, y + 6.0, D2 / 2 - 1.0, GOLD, M.Metal, DECO) end
gable(m, o, W2 + 4, { { 10, 0 }, { 6.6, 1.3 }, { 3, 3.6 }, { 0, 5.6 } }, 0.7, TILE, y + 7.7, TILE_D, M.Slate)
gableEnd(m, o, W2 + 4, { { 10, 0 }, { 6.6, 1.3 }, { 3, 3.6 }, { 0, 5.6 } }, y + 7.7, PLASTER_D, M.Concrete, 5)
for i = -5, 5 do for _, sz in { -1, 1 } do bx(m, o, "RoofStrut", 0.6, 2.8, 0.6, i * (W2 - 2.4) / 10, y + 7.4, sz * (D2 / 2 - 1.0), VERM_D, M.SmoothPlastic, DECO) end end
for _, sx in { -1, 1 } do -- chigi: crossed gable finials
for _, a in { -28, 28 } do
bx(m, o, "Chigi", 0.35, 3.4, 0.35, sx * (W2 / 2 + 2.4), y + 14.6, 0, WOOD_L, M.Wood, DECO, ANG(0, 0, rad(a)))
end
end
glow(m, o, -8, y + 5.6, D2 / 2 - 1.4, GLOW, 22, 0.9)
glow(m, o, 8, y + 5.6, D2 / 2 - 1.4, GLOW, 22, 0.9)
return m
end
local function pond(parent, o, w, d)
local m = model("KoiPond", parent)
bx(m, o, "Bed", w, 0.2, d, 0, 0, 0, C3(54, 70, 72), M.Slate, DECO)
mk(m, "Water", V3(w - 0.8, 0.1, d - 0.8), o * CF(0, 0.16, 0), WATER, M.Glass, { deco = true, t = 0.35, refl = 0.15, noshadow = true })
for i = 0, floor(w / 2.4) do
local x = -w / 2 + 0.6 + i * 2.4
for _, sz in { -1, 1 } do rock(m, o * CF(x, 0, sz * (d / 2 - 0.4)), rng:NextNumber(1.8, 2.6), rng:NextNumber(1.2, 1.9), rng:NextNumber(1.8, 2.6)) end
end
for i = 1, floor(d / 2.4) - 1 do
local z = -d / 2 + 0.6 + i * 2.4
for _, sx in { -1, 1 } do rock(m, o * CF(sx * (w / 2 - 0.4), 0, z), rng:NextNumber(1.8, 2.6), rng:NextNumber(1.2, 1.9), rng:NextNumber(1.8, 2.6)) end
end
for k = 1, 5 do cy(m, o, "SteppingStone", 1.9, 0.4, -4 + k * 1.3, 0.1, math.sin(k * 1.7) * 1.8, STONE, M.Granite, DECO) end
for k = 1, 3 do -- koi
bx(m, o, "Koi", 0.5, 0.1, 1.3, rng:NextNumber(-w / 3, w / 3), 0.2, rng:NextNumber(-d / 3, d / 3), k == 2 and C3(240, 240, 232) or C3(236, 110, 40), M.SmoothPlastic, DECO, ANG(0, rad(rng:NextInteger(0, 359)), 0))
end
return m
end
local function mountain(parent, x, z, w, h, d, color, tilt)
local o = CF(x, 0, z) * ANG(0, rad(tilt or 0), 0)
mk(parent, "Ridge", V3(w, h * 2, d), o * CF(0, -h * 0.1, 0), color, M.Slate, { shape = Enum.PartType.Ball, deco = true, noshadow = true })
mk(parent, "RidgePeak", V3(w * 0.5, h * 2.1, d * 0.6), o * CF(w * 0.12, -h * 0.05, d * 0.05), color:Lerp(C3(255, 255, 255), 0.06), M.Slate, { shape = Enum.PartType.Ball, deco = true, noshadow = true })
end
local function mesa(parent, o, x, z, w, d, y0, y1, topColor, topMat, faceColor, faceMat)
local m = model("Terrace", parent)
bx(m, o, "TerraceBody", w, y1 - y0 - 0.3, d, x, y0, z, faceColor or STONE_D, faceMat or M.Slate)
bx(m, o, "TerraceLip", w + 0.5, 0.5, d + 0.5, x, y1 - 0.8, z, STONE_L, M.Cobblestone, NOSH)
bx(m, o, "TerraceTop", w - 0.4, 0.3, d - 0.4, x, y1 - 0.3, z, topColor or PINE_NEEDLE, topMat or M.Grass)
return m
end
local function climb(parent, o, ex, ez, dx, dz, w, n, rise, run, baseY, color, mat)
local m = model("Steps", parent)
for i = 1, n do
local dist = (n - i) * run + run / 2
local cx, cz = ex + dx * dist, ez + dz * dist
local sw, sd = w, run
if dx ~= 0 then sw, sd = run, w end
bx(m, o, "Step", sw, rise * i, sd, cx, baseY, cz, color or STONE, mat or M.Granite)
end
return m
end
local function flight(parent, o, w, a, b, rail, color)
local m = model("Flight", parent)
color = color or WOOD_D
local dy = b.Y - a.Y
local n = max(2, math.ceil(abs(dy) / 0.7))
local dx, dz = b.X - a.X, b.Z - a.Z
local hl = sqrt(dx * dx + dz * dz)
local th = atan2(dx, dz)
local ux, uz = sin(th), cos(th)
local px, pz = cos(th), -sin(th)
local run = hl / n
for i = 0, n do
local t = i / n
local x, y, z = a.X + dx * t, a.Y + dy * t, a.Z + dz * t
mk(m, "Tread", V3(w, 0.3, run + 0.5), o * CF(x, y - 0.15, z) * ANG(0, th, 0), WOOD, M.WoodPlanks)
end
for _, s in { -1, 1 } do
local off = s * (w / 2 - 0.25)
beam(m, o, "Stringer", V3(a.X + px * off, a.Y - 0.55, a.Z + pz * off), V3(b.X + px * off, b.Y - 0.55, b.Z + pz * off), 0.5, WOOD_D, M.Wood, nil, 0.7)
if rail then
local n2 = max(2, math.ceil(hl / 3))
for k = 0, n2 do
local t = k / n2
local x, y, z = a.X + dx * t + px * off, a.Y + dy * t, a.Z + dz * t + pz * off
bx(m, o, "RailPost", 0.3, 3.0, 0.3, x, y - 0.1, z, color, M.Wood, DECO)
end
beam(m, o, "Handrail", V3(a.X + px * off, a.Y + 2.8, a.Z + pz * off), V3(b.X + px * off, b.Y + 2.8, b.Z + pz * off), 0.3, color, M.Wood, DECO)
end
end
return m
end
function holedWall(parent, o, name, w, h, t, x, yb, z, color, mat, holes, op)
holes = holes or {}
table.sort(holes, function(p, q) return p[1] < q[1] end)
local cur, right = x - w / 2, x + w / 2
local function piece(x0, x1, y0, y1)
if x1 - x0 > 0.02 and y1 - y0 > 0.02 then bx(parent, o, name, x1 - x0, y1 - y0, t, (x0 + x1) / 2, yb + y0, z, color, mat, op) end
end
for _, hl in holes do
local a, b = x + hl[1] - hl[2] / 2, x + hl[1] + hl[2] / 2
piece(cur, a, 0, h)
piece(a, b, 0, hl[3])
piece(a, b, hl[4], h)
cur = b
end
piece(cur, right, 0, h)
end
local function plainGable(parent, o, len, profile, thick, color, y0, ribColor, mat, barge)
for side = -1, 1, 2 do
for i = 1, #profile - 1 do
local a, b = profile[i], profile[i + 1]
local dr, dh = a[1] - b[1], b[2] - a[2]
local sl = sqrt(dr * dr + dh * dh)
local ang = atan2(dh, dr)
local cf = o * CF(0, y0 + (a[2] + b[2]) / 2, side * (a[1] + b[1]) / 2) * ANG(side * ang, 0, 0)
mk(parent, "Roof", V3(len, thick, sl + 0.25), cf, color, mat or M.Slate)
local n = floor(len / 1.3)
for k = 0, n do
mk(parent, "Batten", V3(0.16, 0.14, sl), cf * CF(-len / 2 + 0.3 + k * ((len - 0.6) / n), thick / 2 + 0.06, 0), ribColor or TILE_D, M.Wood, NOSH)
end
end
end
local top = profile[#profile]
bx(parent, o, "Ridge", len + 0.4, 0.5, 1.0, 0, y0 + top[2] - 0.1, 0, ribColor or TILE_D, M.Wood)
if barge then -- bargeboards on both gable ends
for s = -1, 1, 2 do
for side = -1, 1, 2 do
local a, b = profile[1], top
local dr, dh = a[1] - b[1], b[2] - a[2]
local sl = sqrt(dr * dr + dh * dh)
local ang = atan2(dh, dr)
mk(parent, "Bargeboard", V3(0.35, 0.8, sl + 0.4), o * CF(s * (len / 2 + 0.1), y0 + (a[2] + b[2]) / 2 - 0.1, side * (a[1] + b[1]) / 2) * ANG(side * ang, 0, 0), barge, M.Wood, NOSH)
end
end
end
end
local function crate(parent, o, x, z, s, yb)
local c = bx(parent, o, "Crate", s, s, s, x, yb or 0, z, WOOD_L, M.WoodPlanks, nil, ANG(0, rad(rng:NextInteger(-20, 20)), 0))
bx(parent, o, "CrateBand", s + 0.06, 0.18, s + 0.06, x, (yb or 0) + s * 0.5 - 0.09, z, WOOD_D, M.Wood, DECO, ANG(0, rad(0), 0))
return c
end
local function lodge(parent, o, w, d, op)
op = op or {}
local m = model(op.name or "Lodge", parent)
local h1, h2 = 5.2, op.upper and 4.6 or 0
local y0 = 1.2
local bw = op.board or GREEN_BOARD
bx(m, o, "Foundation", w + 0.8, 0.9, d + 0.8, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "Floor", w - 0.4, 0.3, d - 0.4, 0, 0.9, 0, WOOD, M.WoodPlanks)
local doorX = op.doorX or 0
local frontHoles = { { doorX, 3.0, 0, 4.9 } } -- v4: door 4.2 -> 4.9 tall before scaling
for _, wx in { -w * 0.3, w * 0.3 } do if abs(wx - doorX) > 3.2 then frontHoles[#frontHoles + 1] = { wx, 2.4, 1.5, 3.7 } end end
holedWall(m, o, "WallFront", w, h1, 0.5, 0, y0, d / 2 - 0.25, bw, M.WoodPlanks, frontHoles)
holedWall(m, o, "WallBack", w, h1, 0.5, 0, y0, -d / 2 + 0.25, bw, M.WoodPlanks, { { -w * 0.25, 2.4, 1.5, 3.7 }, { w * 0.25, 2.4, 1.5, 3.7 } })
for _, sx in { -1, 1 } do
holedWall(m, o * CF(sx * (w / 2 - 0.25), 0, 0) * ANG(0, rad(90), 0), "WallSide", d, h1, 0.5, 0, y0, 0, bw, M.WoodPlanks, { { 0, 2.6, 1.5, 3.7 } })
end
for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
bx(m, o, "CornerPost", 0.9, h1 + h2 + 0.2, 0.9, sx * (w / 2 - 0.2), y0 - 0.2, sz * (d / 2 - 0.2), GREEN_BOARD_D, M.Wood)
end end
for _, wx in { -w * 0.3, w * 0.3 } do
if abs(wx - doorX) > 3.2 then
bx(m, o, "Sill", 3.0, 0.3, 0.8, wx, y0 + 1.3, d / 2 + 0.05, WOOD_D, M.Wood, DECO)
bx(m, o, "Shutter", 1.1, 2.2, 0.15, wx - 1.9, y0 + 1.5, d / 2 + 0.2, GREEN_BOARD_D, M.WoodPlanks, DECO)
bx(m, o, "Shutter", 1.1, 2.2, 0.15, wx + 1.9, y0 + 1.5, d / 2 + 0.2, GREEN_BOARD_D, M.WoodPlanks, DECO)
end
end
bx(m, o, "DoorHood", 4.4, 0.4, 1.8, doorX, y0 + 5.0, d / 2 + 0.7, WOOD_D, M.Wood) -- small canopy over the door
for _, sx in { -1, 1 } do bx(m, o, "HoodBracket", 0.3, 1.4, 0.3, doorX + sx * 2.0, y0 + 3.1, d / 2 + 1.3, WOOD_D, M.Wood, DECO) end
local yTop = y0 + h1
if op.upper then
bx(m, o, "UpperFloor", w, 0.5, d, 0, yTop, 0, WOOD, M.WoodPlanks)
local uy = yTop + 0.5
local udx = op.balconyDoor or doorX
holedWall(m, o, "UpperFront", w, h2 - 0.5, 0.5, 0, uy, d / 2 - 0.25, bw, M.WoodPlanks, { { udx, 3.0, 0, 3.6 }, { udx + w * 0.3 * (udx > 0 and -1 or 1), 2.4, 1.0, 3.2 } })
holedWall(m, o, "UpperBack", w, h2 - 0.5, 0.5, 0, uy, -d / 2 + 0.25, bw, M.WoodPlanks, { { 0, 3, 1.0, 3.2 } })
for _, sx in { -1, 1 } do
holedWall(m, o * CF(sx * (w / 2 - 0.25), 0, 0) * ANG(0, rad(90), 0), "UpperSide", d, h2 - 0.5, 0.5, 0, uy, 0, bw, M.WoodPlanks, { { 0, 2.6, 1.0, 3.2 } })
end
local bd = 3.6
bx(m, o, "BalconyDeck", w + 0.6, 0.4, bd, 0, uy - 0.4, d / 2 + bd / 2 - 0.2, WOOD, M.WoodPlanks)
bx(m, o, "BalconyBeam", w + 0.6, 0.5, 0.5, 0, uy - 0.9, d / 2 + bd - 0.3, WOOD_D, M.Wood)
for _, px in { -w / 2 + 0.2, 0, w / 2 - 0.2 } do cy(m, o, "BalconyPost", 0.7, uy - 0.9, px, 0, d / 2 + bd - 0.5, WOOD_D, M.Wood) end
rail(m, o, "x", d / 2 + bd - 0.2, -w / 2 - 0.2, w / 2 + 0.2, uy, GREEN_BOARD_D, 3.0)
rail(m, o, "z", -w / 2 - 0.3, d / 2 - 0.2, d / 2 + bd - 0.1, uy, GREEN_BOARD_D, 3.0)
rail(m, o, "z", w / 2 + 0.3, d / 2 + bd - 0.1 - 1.4, d / 2 + bd - 0.1, uy, GREEN_BOARD_D, 3.0) -- the other side stays open for the stairs
local fl = (uy / 0.7) * 1.15
flight(m, o, 3.2, V3(w / 2 + 0.2 + fl, 0.0, d / 2 + bd * 0.45), V3(w / 2 + 0.55, uy, d / 2 + bd * 0.45), true, GREEN_BOARD_D)
bx(m, o, "Landing", 1.4, 0.4, 3.2, w / 2 + 0.55, uy - 0.4, d / 2 + bd * 0.45, WOOD, M.WoodPlanks)
yTop = uy + h2 - 0.5
end
local prof = { { d / 2 + 1.6, 0 }, { d / 2 * 0.5, 1.9 }, { 0, 3.7 } }
plainGable(m, o, w + 1.8, prof, 0.5, GREEN_ROOF, yTop, GREEN_BOARD_D, M.Slate, WOOD_D)
for s = -1, 1, 2 do -- gable-end boards so the triangles are closed
local steps = 5
for i = 0, steps - 1 do
local hh = 3.7 / steps
local r = (d / 2 + 1.6) * (1 - (i + 0.5) / steps) * 0.98 - 0.4
local run = max(0.3, (d / 2 + 1.6) - ((d / 2 + 1.6 - 0) * ((i + 0.5) * hh) / 3.7) * 0.9) - 0.5
if run > 0.3 then bx(m, o, "GableBoard", 0.5, hh + 0.05, run * 2, s * (w / 2 - 0.1), yTop + i * hh, 0, bw, M.WoodPlanks) end
end
end
for _ = 1, 6 do
local sd = rng:NextInteger(0, 1) == 0 and -1 or 1
local t = rng:NextNumber(0.25, 0.8)
local ry = yTop + 1.9 * (1 - t) * 0 + (3.7 * (1 - t))
bx(m, o, "RoofMoss", rng:NextNumber(1.5, 3.5), 0.12, rng:NextNumber(1.5, 2.6), rng:NextNumber(-w / 2 + 1.5, w / 2 - 1.5), ry - 0.05, sd * (d / 2 + 1.6) * t * 0.9, MOSS_D, M.Grass, NOSH, ANG(sd * rad(-30), 0, 0))
end
bx(m, o, "Chimney", 1.5, 5.5, 1.5, -w * 0.28, yTop, -d * 0.2, STONE_D, M.Cobblestone)
bx(m, o, "ChimneyCap", 2.0, 0.4, 2.0, -w * 0.28, yTop + 5.5, -d * 0.2, STONE, M.Granite)
crate(m, o, w * 0.3, -d / 2 + 1.5, 1.8, y0 + 0.3 - 0.3)
crate(m, o, w * 0.3 + 1.9, -d / 2 + 1.2, 1.4, y0)
bx(m, o, "Bench", 4, 1.1, 1.2, -w * 0.15, y0, -d / 2 + 1.2, WOOD_D, M.Wood)
return m
end
local function shack(parent, o, w, d, op)
op = op or {}
local m = model(op.name or "Shack", parent)
local h = 4.4
bx(m, o, "Rubble", w + 1, 0.7, d + 1, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "Floor", w - 0.4, 0.3, d - 0.4, 0, 0.7, 0, WOOD_OLD, M.WoodPlanks)
local yb = 1.0
local col, col2 = op.color or WEATHER, op.color2 or WEATHER_D
holedWall(m, o, "WallFront", w, h, 0.4, 0, yb, d / 2 - 0.2, col, M.WoodPlanks, { { op.doorX or 1.0, 2.8, 0, 4.2 }, { -w * 0.28, 2.0, 1.4, 3.3 } })
holedWall(m, o, "WallBack", w, h, 0.4, 0, yb, -d / 2 + 0.2, col2, M.WoodPlanks, { { w * 0.1, 3.4, 0, 3.0 } }) -- a big gap where boards fell off
for _, sx in { -1, 1 } do
holedWall(m, o * CF(sx * (w / 2 - 0.2), 0, 0) * ANG(0, rad(90), 0), "WallSide", d, h, 0.4, 0, yb, 0, sx == 1 and col2 or col, M.WoodPlanks, { { sx * 1.0, 2.6, 1.5, 3.3 } })
end
for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
bx(m, o, "Post", 0.7, h + 0.4, 0.7, sx * (w / 2 - 0.15), yb - 0.2, sz * (d / 2 - 0.15), WOOD_D, M.Wood)
end end
for k = 1, 4 do
local fx = rng:NextNumber(-w / 2 + 1.2, w / 2 - 1.2)
beam(m, o, "NailedPlank", V3(fx - 1.2, yb + 0.6, d / 2 + 0.05), V3(fx + 1.2, yb + 3.5, d / 2 + 0.05), 0.5, WEATHER_D, M.WoodPlanks, DECO, 0.14)
end
local run = d / 2 + 1.2
local rise = 2.7
local ry = yb + h
local ln = sqrt(run * run + rise * rise)
local ang = atan2(rise, run)
for side = -1, 1, 2 do
for i = -floor(w / 2), floor(w / 2) do
beam(m, o, "Rafter", V3(i * 1.0, ry, side * run), V3(i * 1.0, ry + rise, 0), 0.35, WOOD_D, M.Wood, DECO, 0.5)
end
local seg = 3
local sw = (w + 1.4) / seg
for k = 0, seg - 1 do
if not (side == 1 and k == 1) and not (side == -1 and k == 2) then
local lift = (rng:NextInteger(0, 2) == 0) and rng:NextNumber(0.2, 0.7) or 0
mk(m, "RoofSheet", V3(sw - 0.15, 0.25, ln + 0.2), o * CF(-(w + 1.4) / 2 + sw * (k + 0.5), ry + rise / 2 + 0.2 + lift, side * run / 2) * ANG(side * ang, rad(rng:NextInteger(-2, 2)), 0), TILE_D, M.CorrodedMetal)
end
end
end
bx(m, o, "RidgeBeam", w + 1.4, 0.5, 0.6, 0, ry + rise - 0.1, 0, WOOD_D, M.Wood)
bx(m, o, "Tarp", (w + 1.4) / 3 - 0.3, 0.1, ln, -(w + 1.4) / 2 + (w + 1.4) / 3 * 1.5, ry + rise / 2 + 0.55, run / 2 * -1, C3(62, 98, 128), M.Fabric, DECO, ANG(rad(-math.deg(ang)), 0, 0))
for s = -1, 1, 2 do
for i = 0, 3 do
local hh = rise / 4
local rr = (run - 0.5) * (1 - (i + 0.5) / 4)
if rng:NextNumber(0, 1) > 0.25 then bx(m, o, "GableBoard", 0.4, hh, rr * 2, s * (w / 2 - 0.2), ry + i * hh, 0, col, M.WoodPlanks) end
end
end
crate(m, o, -w / 2 - 1.3, d / 2 - 1.2, 1.7)
crate(m, o, -w / 2 - 1.2, d / 2 - 3.2, 1.3)
cy(m, o, "Barrel", 1.7, 2.2, w / 2 + 1.3, 0, d / 2 - 0.6, WOOD, M.Wood)
cy(m, o, "BarrelBand", 1.8, 0.2, w / 2 + 1.3, 0.5, d / 2 - 0.6, WEATHER_D, M.Metal, DECO)
cy(m, o, "BarrelBand", 1.8, 0.2, w / 2 + 1.3, 1.6, d / 2 - 0.6, WEATHER_D, M.Metal, DECO)
return m
end
local function kura(parent, o, w, d, op)
op = op or {}
local m = model(op.name or "Kura", parent)
local h = 7.4
bx(m, o, "Plinth", w + 0.8, 0.9, d + 0.8, 0, 0, 0, STONE_D, M.Granite)
bx(m, o, "Floor", w - 0.4, 0.3, d - 0.4, 0, 0.9, 0, WOOD_OLD, M.WoodPlanks)
local y0 = 1.2
holedWall(m, o, "WallFront", w, h, 0.7, 0, y0, d / 2 - 0.35, PLASTER, M.Concrete, { { op.doorX or 0, 3.2, 0, 5.4 }, { -w * 0.32, 1.3, 5.6, 6.6 }, { w * 0.32, 1.3, 5.6, 6.6 } })
holedWall(m, o, "WallBack", w, h, 0.7, 0, y0, -d / 2 + 0.35, PLASTER_D, M.Concrete, { { 0, 1.3, 4.4, 6.0 } })
for _, sx in { -1, 1 } do holedWall(m, o * CF(sx * (w / 2 - 0.35), 0, 0) * ANG(0, rad(90), 0), "WallSide", d, h, 0.7, 0, y0, 0, PLASTER, M.Concrete, { { 0, 1.3, 4.4, 6.0 } }) end
for _, sz in { -1, 1 } do
bx(m, o, "NamakoBand", w + 0.1, 1.9, 0.12, 0, y0, sz * (d / 2 + 0.02), LACQUER, M.Slate, DECO)
for k = 0, floor(w / 1.2) do bx(m, o, "NamakoJoint", 0.12, 1.9, 0.18, -w / 2 + 0.4 + k * 1.2, y0, sz * (d / 2 + 0.03), PLASTER, M.Concrete, DECO) end
end
bx(m, o, "DoorLeaf", 1.6, 4.4, 0.35, (op.doorX or 0) + 2.3, y0, d / 2 + 0.7, LACQUER, M.WoodPlanks, nil, ANG(0, rad(-65), 0))
for _, wx in { -w * 0.32, w * 0.32 } do for k = -1, 1 do bx(m, o, "Bar", 0.1, 1.6, 0.14, wx + k * 0.35, y0 + 4.4, d / 2 + 0.02, LACQUER, M.Wood, DECO) end end
local run = d / 2 + 2.0
local prof = { { run, 0 }, { run * 0.5, 1.8 }, { 0, 4.0 } }
local ry = y0 + h
gable(m, o, w + 2.2, prof, 0.6, TILE_D, ry + 0.5, TILE, M.Slate)
bx(m, o, "EaveBeam", w + 1.4, 0.5, d + 0.8, 0, ry, 0, WOOD_D, M.Wood)
gableEnd(m, o, w + 2.2, prof, ry + 0.5, PLASTER, M.Concrete, 5)
crate(m, o, -w * 0.28, -d / 2 + 1.7, 1.9, y0)
crate(m, o, -w * 0.28 + 2.1, -d / 2 + 1.4, 1.5, y0)
bx(m, o, "Shelf", w * 0.6, 2.4, 0.8, w * 0.08, y0, -d / 2 + 1.0, WOOD_D, M.Wood)
return m
end
local function teahouse(parent, o, w, d, op)
op = op or {}
local m = model(op.name or "Teahouse", parent)
bx(m, o, "Deck", w, 1.2, d, 0, 0, 0, WOOD, M.WoodPlanks)
bx(m, o, "DeckSkirt", w + 0.5, 0.5, d + 0.5, 0, 0, 0, STONE_D, M.Cobblestone)
local h = 6.6
local eo = o * CF(0, 1.2, 0)
local px, pz = w / 2 - 0.7, d / 2 - 0.7
for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do post(m, eo, sx * px, sz * pz, h, 1.0, 0, WOOD_D) end end
bx(m, eo, "BackWall", w - 1, h - 0.6, 0.5, 0, 0.45, -pz, PLASTER, M.Concrete)
for k = -1, 1, 2 do bx(m, eo, "SideWall", 0.5, h - 0.6, d * 0.4, k * px, 0.45, -pz + d * 0.2 - 0.35, PLASTER, M.Concrete) end
holedWall(m, eo, "Counter", w - 1.4, 2.4, 0.9, 0, 0.45, pz - 0.3, WOOD, M.WoodPlanks, { { -w * 0.18, 2.4, 0, 0 } })
for _, sx in { -1, 1 } do bx(m, eo, "BeamL", 0.6, 0.7, d - 0.6, sx * px, h + 0.4, 0, WOOD_D, M.Wood) end
for _, sz in { -1, 1 } do bx(m, eo, "BeamF", w - 0.6, 0.7, 0.6, 0, h + 0.4, sz * pz, WOOD_D, M.Wood) end
local span = d / 2 + 2.0
local prof = { { span, 0 }, { span * 0.55, 0.9 }, { 0, 3.0 } }
gable(m, eo, w + 2.2, prof, 0.45, TILE, h + 1.1, TILE_D)
gableEnd(m, eo, w + 2.2, prof, h + 1.1, PLASTER_D, M.Concrete, 4)
for k = 0, 2 do bx(m, eo, "Noren", (w - 2) / 3 - 0.3, 2.4, 0.15, -w / 2 + 1.4 + k * ((w - 2) / 3 + 0.1), h - 3.2, pz + 0.1, BLUE_NOREN, M.Fabric, DECO) end
bx(m, eo, "NorenRod", w - 2, 0.3, 0.3, 0, h - 0.9, pz + 0.1, WOOD_D, M.Wood, DECO)
for _, bxp in { -w * 0.3, w * 0.3 } do
bx(m, eo, "BenchBase", 3.6, 1.2, 1.0, bxp, -1.2, pz + 4.0, STONE_D, M.Cobblestone)
bx(m, eo, "Bench", 4.2, 1.0, 1.4, bxp, 0, pz + 4.0, WOOD_D, M.Wood)
bx(m, eo, "Felt", 4.0, 0.2, 1.3, bxp, 1.0, pz + 4.0, VERM, M.Fabric, DECO)
end
if not op.noParasol then -- v4: the street teahouses have no side parasol (it stuck into the next house)
cy(m, o, "ParasolPole", 0.35, 6.4, w / 2 + 3.0, 0, d / 2 + 2.0, WOOD_L, M.Wood)
cy(m, o, "ParasolBase", 1.8, 0.4, w / 2 + 3.0, 0, d / 2 + 2.0, STONE_D, M.Granite, DECO)
cy(m, o, "Parasol", 6.4, 0.3, w / 2 + 3.0, 6.2, d / 2 + 2.0, VERM, M.Fabric)
cy(m, o, "ParasolTop", 3.8, 0.3, w / 2 + 3.0, 6.45, d / 2 + 2.0, VERM_L, M.Fabric, DECO)
end
return m
end
local function hokora(parent, o)
local m = model("Hokora", parent)
bx(m, o, "Base", 6, 0.8, 6, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "Body", 3.2, 2.8, 3.0, 0, 0.8, -0.4, WOOD_D, M.WoodPlanks)
bx(m, o, "Door", 1.4, 2.0, 0.15, 0, 0.9, 1.15, VERM_D, M.WoodPlanks, DECO)
for _, sx in { -1, 1 } do cy(m, o, "Post", 0.5, 3.0, sx * 1.8, 0.8, 1.2, VERM, M.SmoothPlastic) end
gable(m, o, 4.6, { { 2.6, 0 }, { 1.3, 0.8 }, { 0, 1.8 } }, 0.3, TILE, 3.7, TILE_D)
for _, sx in { -1, 1 } do
bx(m, o, "FoxBase", 1.2, 0.8, 1.2, sx * 2.2, 0.8, 2.3, STONE, M.Granite)
bx(m, o, "Fox", 0.8, 1.4, 0.9, sx * 2.2, 1.6, 2.3, STONE_L, M.Slate)
bx(m, o, "FoxHead", 0.7, 0.6, 0.9, sx * 2.2, 3.0, 2.5, STONE_L, M.Slate)
bx(m, o, "FoxEar", 0.2, 0.5, 0.2, sx * 2.2 - 0.2, 3.6, 2.4, STONE_L, M.Slate, DECO)
bx(m, o, "FoxEar", 0.2, 0.5, 0.2, sx * 2.2 + 0.2, 3.6, 2.4, STONE_L, M.Slate, DECO)
bx(m, o, "FoxBib", 0.9, 0.5, 0.2, sx * 2.2, 2.5, 2.8, VERM, M.Fabric, DECO)
end
return m
end
local function jizo(parent, o)
local m = model("Jizo", parent)
bx(m, o, "Base", 1.8, 0.7, 1.8, 0, 0, 0, STONE_D, M.Granite)
cy(m, o, "Body", 1.1, 1.8, 0, 0.7, 0, STONE, M.Slate)
ball(m, o, "Head", 1.0, 0, 2.9, 0, STONE_L, M.Slate)
cy(m, o, "Bib", 1.2, 0.5, 0, 1.8, 0, VERM, M.Fabric, DECO)
cy(m, o, "Hat", 1.1, 0.35, 0, 3.25, 0, VERM_D, M.Fabric, DECO)
return m
end
local function floorHole(parent, o, name, w, d, yb, thick, hx0, hx1, hz0, hz1, color, mat)
bx(parent, o, name, hx0 + w / 2, thick, d, (hx0 - w / 2) / 2, yb, 0, color, mat)
bx(parent, o, name, w / 2 - hx1, thick, d, (hx1 + w / 2) / 2, yb, 0, color, mat)
bx(parent, o, name, hx1 - hx0, thick, d / 2 - hz1, (hx0 + hx1) / 2, yb, (hz1 + d / 2) / 2, color, mat)
bx(parent, o, name, hx1 - hx0, thick, hz0 + d / 2, (hx0 + hx1) / 2, yb, (hz0 - d / 2) / 2, color, mat)
end
local function watchtower(parent, o)
local m = model("Yagura_Watchtower", parent)
local lv = { 5.0, 10.0, 15.0 }
for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
cy(m, o, "Leg", 1.1, 17.0, sx * 4.4, -0.3, sz * 4.4, WEATHER_D, M.Wood)
bx(m, o, "Footing", 2.4, 0.7, 2.4, sx * 4.4, 0, sz * 4.4, STONE_D, M.Cobblestone)
end end
for i, y in lv do
if i == 1 then bx(m, o, "Floor1", 10.4, 0.5, 10.4, 0, y - 0.5, 0, WOOD, M.WoodPlanks)
elseif i == 2 then floorHole(m, o, "Floor2", 10.4, 10.4, y - 0.5, 0.5, -4.8, 4.4, 1.3, 3.9, WOOD, M.WoodPlanks)
else floorHole(m, o, "Floor3", 10.4, 10.4, y - 0.5, 0.5, -4.4, 4.8, -3.9, -1.3, WOOD, M.WoodPlanks) end
bx(m, o, "Joist" .. i, 10.4, 0.5, 0.6, 0, y - 1.0, -4.4, WOOD_D, M.Wood, DECO)
bx(m, o, "Joist" .. i, 10.4, 0.5, 0.6, 0, y - 1.0, 4.4, WOOD_D, M.Wood, DECO)
local lo = (i == 1) and 0.3 or lv[i - 1]
for _, a in { 0, 90, 180, 270 } do
local w = o * ANG(0, rad(a), 0)
beam(m, w, "Brace", V3(-4.4, lo + 0.3, 4.9), V3(4.4, y - 1.2, 4.9), 0.45, WEATHER_D, M.Wood, DECO)
beam(m, w, "Brace", V3(4.4, lo + 0.3, 4.9), V3(-4.4, y - 1.2, 4.9), 0.45, WEATHER_D, M.Wood, DECO)
end
if i < 3 then
rail(m, o, "x", -5.0, -5.2, 5.2, y, WEATHER_D, 3.0)
rail(m, o, "z", 5.0, -5.2, 5.2, y, WEATHER_D, 3.0)
rail(m, o, "z", -5.0, -5.2, 5.2, y, WEATHER_D, 3.0)
if i == 1 then
rail(m, o, "x", 5.0, -5.2, -3.4, y, WEATHER_D, 3.0)
rail(m, o, "x", 5.0, 1.4, 5.2, y, WEATHER_D, 3.0)
else
rail(m, o, "x", 5.0, -5.2, 5.2, y, WEATHER_D, 3.0)
end
end
end
local ty = lv[3]
holedWall(m, o, "LookoutFront", 10.4, 4.6, 0.5, 0, ty, 4.95, WEATHER, M.WoodPlanks, { { 0, 6.4, 1.6, 3.4 } })
holedWall(m, o, "LookoutBack", 10.4, 4.6, 0.5, 0, ty, -4.95, WEATHER, M.WoodPlanks, { { 0, 6.4, 1.6, 3.4 } })
for _, sx in { -1, 1 } do holedWall(m, o * CF(sx * 4.95, 0, 0) * ANG(0, rad(90), 0), "LookoutSide", 10.4, 4.6, 0.5, 0, ty, 0, WEATHER, M.WoodPlanks, { { 0, 6.4, 1.6, 3.4 } }) end
local prof = { { 7.2, 0 }, { 3.6, 1.7 }, { 0, 4.0 } }
plainGable(m, o, 12.4, prof, 0.5, GREEN_ROOF, ty + 4.6, GREEN_BOARD_D, M.Slate, WOOD_D)
for s = -1, 1, 2 do for i = 0, 3 do bx(m, o, "GableBoard", 0.5, 1.0, max(0.6, (7.2 - 0.9 - i * 1.7) * 2 * 0.62), s * 5.2, ty + 4.6 + i * 1.0, 0, WEATHER, M.WoodPlanks) end end
flight(m, o, 3.0, V3(-1.0, 0, 5.0 + 9.2), V3(-1.0, lv[1], 5.5), true, WEATHER_D)  -- ground -> level 1 (outside, south)
flight(m, o, 2.6, V3(-4.4, lv[1], 2.6), V3(4.2, lv[2], 2.6), false, WEATHER_D)        -- level 1 -> 2 (inside)
flight(m, o, 2.6, V3(4.4, lv[2], -2.6), V3(-4.2, lv[3], -2.6), false, WEATHER_D)      -- level 2 -> 3 (inside)
return m
end
local function bridge(parent, o, len, w, bedY, op)
op = op or {}
local m = model(op.name or "PlankBridge", parent)
local col = op.color or WOOD
local n = floor(len / 2.0)
for i = 0, n - 1 do
local skip = op.broken and (i == floor(n * 0.4) or i == floor(n * 0.4) + 1 or i == floor(n * 0.7))
if not skip then bx(m, o, "Plank", 2.0 - 0.08, 0.3, w, -len / 2 + 1.0 + i * 2.0, 0.1, 0, col, M.WoodPlanks, nil, ANG(0, rad(rng:NextNumber(-1, 1)), 0)) end
end
for _, sz in { -1, 1 } do
bx(m, o, "Girder", len, 0.7, 0.8, 0, -0.6, sz * (w / 2 - 0.5), WOOD_D, M.Wood)
end
local piers = { -len / 2 + 6, 0, len / 2 - 6 }
for _, px in piers do
for _, sz in { -1, 1 } do
cy(m, o, "Pier", 1.2, -0.6 - bedY + 0.3, px, bedY - 0.3, sz * (w / 2 - 0.5), WEATHER_D, M.Wood)
end
bx(m, o, "PierCap", 1.6, 0.6, w, px, -1.2, 0, WOOD_D, M.Wood)
end
for _, sz in { -1, 1 } do
local z = sz * (w / 2 - 0.1)
local rc = op.railColor or VERM_D
for k = 0, floor(len / 4) do
local px = -len / 2 + 0.6 + k * ((len - 1.2) / floor(len / 4))
if not (op.broken and sz == 1 and k == 3) then bx(m, o, "RailPost", 0.5, 3.0, 0.5, px, 0.3, z, rc, M.Wood) end
end
if op.broken and sz == 1 then
bx(m, o, "TopRail", len * 0.4, 0.4, 0.4, -len * 0.3, 3.0, z, rc, M.Wood)
bx(m, o, "TopRail", len * 0.3, 0.4, 0.4, len * 0.33, 3.0, z, rc, M.Wood)
bx(m, o, "DangleRail", len * 0.15, 0.4, 0.4, -len * 0.06, 2.0, z, rc, M.Wood, nil, ANG(0, 0, rad(35)))
else
bx(m, o, "TopRail", len, 0.4, 0.45, 0, 3.0, z, rc, M.Wood)
bx(m, o, "MidRail", len, 0.25, 0.3, 0, 1.7, z, rc, M.Wood, DECO)
end
end
return m
end
local function waterwheel(parent, o, R, width)
local m = model("Waterwheel", parent)
local n = 16
local seg = 2 * R * sin(pi / n) + 0.35
cyh(m, o, "Axle", 1.0, width + 6, 0, 0, 0, "x", WOOD_D, M.Wood)
for _, sx in { -1, 1 } do
local ox = sx * (width / 2 - 0.3)
for i = 0, n - 1 do
local a = i * (2 * pi / n)
local y, z = cos(a) * R, sin(a) * R
mk(m, "Rim", V3(0.7, 0.5, seg), o * CF(ox, y, z) * ANG(a, 0, 0), WOOD_OLD, M.Wood)
if i % 2 == 0 then beam(m, o, "Spoke", V3(ox, 0, 0), V3(ox, y, z), 0.45, WOOD_D, M.Wood, DECO) end
end
cyh(m, o, "Hub", 1.8, 0.8, ox, 0, 0, "x", WOOD_D, M.Wood)
end
for i = 0, n - 1 do
local a = i * (2 * pi / n)
local y, z = cos(a) * (R + 0.4), sin(a) * (R + 0.4)
mk(m, "Paddle", V3(width - 0.4, 0.3, 1.5), o * CF(0, y, z) * ANG(a + rad(25), 0, 0), WOOD, M.WoodPlanks)
end
return m
end
local function jetty(parent, o, len, bedY)
local m = model("Jetty", parent)
for i = 0, floor(len) - 1 do bx(m, o, "Plank", 4.0, 0.25, 0.95, 0, 0.2, i + 0.5, WOOD, M.WoodPlanks, nil, ANG(0, rad(rng:NextNumber(-2, 2)), 0)) end
for _, sx in { -1, 1 } do bx(m, o, "Stringer", 0.5, 0.5, len, sx * 1.7, -0.3, len / 2, WOOD_D, M.Wood) end
for k = 0, floor(len / 3) do
for _, sx in { -1, 1 } do
local z = 0.6 + k * 3
cy(m, o, "Pile", 0.7, 0.4 - bedY, sx * 1.8, bedY - 0.2, z, WEATHER_D, M.Wood)
end
end
return m
end
local function boat(parent, o)
local m = model("Rowboat", parent)
bx(m, o, "Keel", 1.6, 0.4, 7.6, 0, 0, 0, WEATHER_D, M.Wood)
for _, sx in { -1, 1 } do
bx(m, o, "Hull", 0.35, 1.5, 7.8, sx * 1.2, 0.2, 0, WEATHER, M.WoodPlanks, nil, ANG(0, 0, sx * rad(-18)))
bx(m, o, "Gunwale", 0.35, 0.3, 6.0, sx * 1.55, 1.5, 0, WOOD_D, M.Wood, DECO)
end
bx(m, o, "Bow", 1.6, 1.3, 0.35, 0, 0.3, 3.8, WEATHER, M.WoodPlanks, nil, ANG(rad(10), 0, 0))
bx(m, o, "Stern", 2.6, 1.4, 0.35, 0, 0.3, -3.8, WEATHER, M.WoodPlanks, nil)
bx(m, o, "Thwart", 3.0, 0.3, 0.7, 0, 1.0, 0.5, WOOD, M.WoodPlanks)
return m
end
local function bamboo(parent, x, z, y, n, spread)
local m = model("BambooClump", parent)
local o = CF(x, y or 0, z)
cy(m, o, "Mound", spread * 2 + 1.5, 0.5, 0, -0.2, 0, MOSS_D, M.Grass, NOSH)
for i = 1, n do
local a, r = rng:NextNumber(0, 6.283), rng:NextNumber(0, spread)
local h = rng:NextNumber(13, 24)
local sx, sz = cos(a) * r, sin(a) * r
cy(m, o, "Stalk", rng:NextNumber(0.55, 0.9), h, sx, 0, sz, BAMBOO, M.Wood)
for k = 1, floor(h / 4.5) do cy(m, o, "Node", 0.78, 0.22, sx, k * 4.5, sz, BAMBOO_L, M.Wood, NOSH) end
ball(m, o, "Leaves", rng:NextNumber(3.2, 4.6), sx + rng:NextNumber(-0.4, 0.4), h, sz + rng:NextNumber(-0.4, 0.4), BAMBOO_L, M.Grass, NOSH)
end
return m
end
local function water(parent, x, z, w, d, yb, h)
return mk(parent, "Water", V3(w, h, d), CF(x, yb + h / 2, z), WATER, M.SmoothPlastic, { t = 0.45, refl = 0.12, deco = true, noshadow = true })
end
local function logpile(parent, o)
local m = model("LogPile", parent)
local rows = { 4, 3, 2 }
for r, cnt in rows do
for i = 0, cnt - 1 do
cyh(m, o, "Log", 1.5, 6.0, (i - (cnt - 1) / 2) * 1.5 * 0 , 0.8 + (r - 1) * 1.25, (i - (cnt - 1) / 2) * 1.5, "x", WOOD, M.Wood)
end
end
for _, s in { -3.2, 3.2 } do bx(m, o, "Stake", 0.4, 3.0, 5.6, s, 0, 0, WOOD_D, M.Wood, DECO) end
return m
end
local function fence(parent, o, len, h)
h = h or 3.0
local m = model("Fence", parent)
local n = max(1, floor(len / 3))
for i = 0, n do bx(m, o, "FencePost", 0.5, h + 0.4, 0.5, -len / 2 + i * len / n, 0, 0, WEATHER_D, M.Wood) end
for _, ry in { h * 0.35, h * 0.8 } do bx(m, o, "FenceRail", len, 0.3, 0.3, 0, ry, 0.2, WEATHER, M.Wood) end
return m
end
F.terrain = folder("Terrain")
F.mountains = folder("Mountains")
local DENSITY = 1.0 -- 0.5 = half as many trees / small props (fewer parts), 1.0 = full
local function warnf(...) warn("[KyotoDistrict v4] " .. string.format(...)) end
local HX, HZ = W / 2, L / 2
local TERR = { bumps = {}, pads = {}, blocks = {}, paths = {} }
local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function sstep(a, b, x) local t = clamp((x - a) / (b - a), 0, 1) return t * t * (3 - 2 * t) end
local function lerp(a, b, t) return a + (b - a) * t end
local function nz(x, z, s, off) return math.noise(x / s + off * 7.31, z / s + off * 3.17, 0.5) end
local function riverX(a) return 168 + 9 * sin(a / 52) end
local function riverW(x, a)
local hw = 11 + 14 * (1 - sstep(70, 124, a))
local w = 1 - sstep(hw - 1, hw + 9, abs(x - riverX(a)))
return w * sstep(50, 66, a) * (1 - sstep(338, 352, a))
end
function TERR.mtn(x, a)
local s = max(abs(x) - HX, a - HZ)
if s <= -46 then return 0, s end
local base
if s < 0 then
base = 34 * ((s + 46) / 46) ^ 1.7
else
local t = clamp(s / 190, 0, 1)
base = 34 + 165 * (1 - (1 - t) ^ 2)
base = base * (1 - sstep(215, 345, s))
end
local ridged = 1 - abs(nz(x, a, 95, 3)) * 2.2
local amp = 0.62 * (ridged - 0.45) + 0.2 * nz(x, a, 41, 9) * 2
return base * (1 + amp * sstep(-46, 40, s)), s
end
function TERR.bump(cx, ca, rx, ra, h, p) TERR.bumps[#TERR.bumps + 1] = { cx, ca, rx, ra, h, p or 2 } end
function TERR.pad(x0, x1, a0, a1, y, m) TERR.pads[#TERR.pads + 1] = { x0, x1, a0, a1, y, m or 10 } end
function TERR.baseNoPads(x, a)
local h = TERR.mtn(x, a)
h = h + sstep(50, 110, a) * (5 * nz(x, a, 64, 1) + 2 * nz(x, a, 30, 2))
for _, b in TERR.bumps do
local dx, da = (x - b[1]) / b[3], (a - b[2]) / b[4]
local d2 = dx * dx + da * da
if d2 < 1 then h = h + b[5] * (1 - d2) ^ b[6] end
end
local w = riverW(x, a)
if w > 0 then h = h * (1 - w) + (-3.2) * w end
return h
end
function TERR.H(x, z)
local a = abs(z)
local h = TERR.baseNoPads(x, a)
local pads = TERR.pads
local forced
for i = 1, #pads do
local p = pads[i]
local dx, da = max(p[1] - x, x - p[2], 0), max(p[3] - a, a - p[4], 0)
if dx == 0 and da == 0 then
forced = p[5]
else
local dist = sqrt(dx * dx + da * da)
if dist < p[6] then h = lerp(h, p[5], 1 - sstep(0, p[6], dist)) end
end
end
return forced or h
end
local Hf = TERR.H
function TERR.normalY(x, z)
local gx = (Hf(x + 2, z) - Hf(x - 2, z)) / 4
local gz = (Hf(x, z + 2) - Hf(x, z - 2)) / 4
return 1 / sqrt(1 + gx * gx + gz * gz)
end
local GRASS = { C3(80, 98, 62), C3(86, 104, 64), C3(75, 93, 58) }
local ROCKS = { C3(112, 110, 104), C3(98, 96, 92), C3(126, 122, 114), C3(88, 90, 90) }
function TERR.style(x, z, h, ny)
local n = nz(x, z, 38, 5)
local n2 = nz(x, z, 13, 8)
if h < -0.9 then return BED:Lerp(C3(86, 98, 90), 0.4 + n), M.Slate end
if h > 128 + n * 40 and ny > 0.5 then return C3(238, 242, 248), M.Snow end
if h > 128 + n * 40 then return C3(206, 212, 220), M.Snow end
if ny < 0.66 or h > 92 + n * 24 then return ROCKS[1 + floor((n + 0.5) * 3.99) % 4]:Lerp(C3(60, 58, 56), clamp(n2 + 0.2, 0, 0.5)), M.Slate end
if ny < 0.8 then return C3(112, 104, 84):Lerp(MOSS_D, clamp(n + 0.4, 0, 1)), M.Ground end
if h > 52 then return C3(104, 118, 82):Lerp(C3(138, 130, 98), clamp(n + 0.4 + (h - 52) / 120, 0, 1)), M.Grass end
local c = (n > 0.1) and MOSS or ((n < -0.12) and PINE_NEEDLE_D or FLOOR_G)
return c:Lerp(C3(104, 126, 72), clamp(n2 + 0.3, 0, 0.35)), M.Grass
end
local function wedgePart(parent, size, cf, color, mat, deco)
local p = Instance.new("WedgePart")
p.Anchored = true
p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
p.Size = size
p.CFrame = cf
p.Color = color
p.Material = mat
if deco then p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false end
p.Parent = parent
count += 1
if count % 500 == 0 then task.wait() end
return p
end
local function tri(parent, a, b, c, color, mat, thick, deco)
local ab, ac, bc = b - a, c - a, c - b
local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
if abd > acd and abd > bcd then c, a = a, c elseif acd > bcd and acd > abd then a, b = b, a end
ab, ac, bc = b - a, c - a, c - b
local cr = ac:Cross(ab)
if cr.Magnitude < 0.5 then return end
local right = cr.Unit
local up = bc:Cross(right).Unit
local back = bc.Unit
local height = abs(ab:Dot(up))
local n = right.Y < 0 and -right or right
local off = n * (-thick / 2)
local l1, l2 = abs(ab:Dot(back)), abs(ac:Dot(back))
if height < 0.05 or l1 < 0.05 or l2 < 0.05 then return end
wedgePart(parent, V3(thick, height, l1), CFrame.fromMatrix((a + b) / 2 + off, right, up, back), color, mat, deco)
wedgePart(parent, V3(thick, height, l2), CFrame.fromMatrix((a + c) / 2 + off, -right, up, -back), color, mat, deco)
end
TERR.tri = tri
function TERR.mesh(parent, x0, x1, z0, z1, cs, skip, thick, deco, mergeFlat)
local nx, nz2 = floor((x1 - x0) / cs + 0.5), floor((z1 - z0) / cs + 0.5)
local hv = {}
for i = 0, nx do
hv[i] = {}
for j = 0, nz2 do hv[i][j] = Hf(x0 + i * cs, z0 + j * cs) end
end
local flat, done = {}, {}
local nTri = 0
for i = 0, nx - 1 do
flat[i], done[i] = {}, {}
for j = 0, nz2 - 1 do
local cx, cz = x0 + (i + 0.5) * cs, z0 + (j + 0.5) * cs
local inSkip = skip and cx > skip[1] and cx < skip[2] and cz > skip[3] and cz < skip[4]
local a, b, c, d = hv[i][j], hv[i + 1][j], hv[i][j + 1], hv[i + 1][j + 1]
local hi, lo = max(a, b, c, d), min(a, b, c, d)
if inSkip then
done[i][j] = true
elseif hi - lo < 0.02 then
if deco and hi < 0.25 then done[i][j] = true -- outer rim: the apron covers it
else
local g = nz(cx, cz, 60, 4)
flat[i][j] = (hi < -1.5) and 0 or ((g > 0.12) and 1 or ((g < -0.12) and 3 or 2))
flat[i][j] = flat[i][j] .. ":" .. string.format("%.2f", hi)
end
end
end
end
for j = 0, nz2 - 1 do
for i = 0, nx - 1 do
local key = flat[i][j]
if key and not done[i][j] then
local ww = 1
while i + ww < nx and flat[i + ww][j] == key and not done[i + ww][j] do ww += 1 end
local hh = 1
local ok = true
while ok and j + hh < nz2 do
for k = 0, ww - 1 do if flat[i + k][j + hh] ~= key or done[i + k][j + hh] then ok = false break end end
if ok then hh += 1 end
end
for k = 0, ww - 1 do for l = 0, hh - 1 do done[i + k][j + l] = true end end
local cls, hs = string.match(key, "(%d):(.+)")
local y = tonumber(hs)
local col, mat
if cls == "0" then col, mat = BED:Lerp(C3(86, 98, 90), 0.3), M.Slate
else col, mat = GRASS[tonumber(cls)], M.Grass end
mk(parent, "GroundFlat", V3(ww * cs, 3, hh * cs), CF(x0 + (i + ww / 2) * cs, y - 1.5, z0 + (j + hh / 2) * cs), col, mat, deco and { deco = true } or nil)
end
end
end
for i = 0, nx - 1 do
for j = 0, nz2 - 1 do
if not done[i][j] then
local px, pz = x0 + i * cs, z0 + j * cs
local a, b, c, d = hv[i][j], hv[i + 1][j], hv[i][j + 1], hv[i + 1][j + 1]
local A, B, C, D = V3(px, a, pz), V3(px + cs, b, pz), V3(px, c, pz + cs), V3(px + cs, d, pz + cs)
local t1, t2
if abs(a - d) < abs(b - c) then t1, t2 = { A, B, D }, { A, D, C } else t1, t2 = { A, B, C }, { B, D, C } end
for _, t in { t1, t2 } do
local cxm, czm = (t[1].X + t[2].X + t[3].X) / 3, (t[1].Z + t[2].Z + t[3].Z) / 3
local hm = (t[1].Y + t[2].Y + t[3].Y) / 3
local nrm = (t[2] - t[1]):Cross(t[3] - t[1]).Unit
local ny = abs(nrm.Y)
local col, mat = TERR.style(cxm, czm, hm, ny)
tri(parent, t[1], t[2], t[3], col, mat, thick, deco)
nTri += 1
end
end
end
end
return nTri
end
function TERR.pathStrip(parent, pts, width, color, mat, thick, name)
for i = 1, #pts - 1 do
local p, q = pts[i], pts[i + 1]
local dx, dz = q[1] - p[1], q[2] - p[2]
local len = sqrt(dx * dx + dz * dz)
local steps = max(1, floor(len / 3.2))
local seg = len / steps
local th = atan2(dx, dz)
local ux, uz = dx / len, dz / len
for k = 0, steps - 1 do
local t = (k + 0.5) / steps
local x, z = p[1] + dx * t, p[2] + dz * t
local h1, h2 = Hf(x - ux * seg / 2, z - uz * seg / 2), Hf(x + ux * seg / 2, z + uz * seg / 2)
local hc = (h1 + h2) / 2
local pitch = atan2(h2 - h1, seg)
mk(parent, name or "PathSlab", V3(width, thick or 0.6, seg + 0.9), CF(x, hc + 0.1, z) * ANG(0, th, 0) * ANG(-pitch, 0, 0), (k % 2 == 0) and color or color:Lerp(C3(90, 88, 84), 0.25), mat or M.Cobblestone, NOSH)
end
end
end
local P = {}
local SAKURA_C = { C3(250, 196, 210), C3(244, 170, 192), C3(255, 214, 224), C3(236, 150, 178) }
local POT_C = { C3(150, 96, 64), C3(96, 104, 112), C3(176, 140, 96), C3(70, 90, 110), C3(190, 120, 70) }
local function at(o, x, y, z, yaw) return o * CF(x, y, z) * ANG(0, rad(yaw or 0), 0) end
P.at = at
function P.barrel(parent, o, x, z, yb)
cy(parent, o, "Barrel", 1.7, 2.2, x, yb, z, WOOD, M.Wood)
cy(parent, o, "BarrelBand", 1.8, 0.18, x, yb + 0.5, z, WEATHER_D, M.Metal, DECO)
cy(parent, o, "BarrelBand", 1.8, 0.18, x, yb + 1.6, z, WEATHER_D, M.Metal, DECO)
end
function P.sack(parent, o, x, z, yb, s)
s = s or 1
bx(parent, o, "RiceSack", 1.5 * s, 1.2 * s, 1.0 * s, x, yb, z, C3(204, 186, 140), M.Fabric, nil, ANG(0, rad(rng:NextInteger(0, 180)), 0))
bx(parent, o, "SackTie", 0.5 * s, 0.25 * s, 0.4 * s, x, yb + 1.1 * s, z, C3(150, 120, 80), M.Fabric, DECO)
end
function P.table(parent, o, x, z, yb, w, d, h)
h = h or 1.3
bx(parent, o, "TableTop", w, 0.25, d, x, yb + h - 0.25, z, WOOD_D, M.WoodPlanks)
for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do
bx(parent, o, "TableLeg", 0.3, h - 0.2, 0.3, x + sx * (w / 2 - 0.3), yb, z + sz * (d / 2 - 0.3), WOOD_D, M.Wood, DECO)
end end
end
function P.cushion(parent, o, x, z, yb, col)
bx(parent, o, "Zabuton", 1.6, 0.3, 1.6, x, yb, z, col or VERM_D, M.Fabric, DECO)
end
function P.shelf(parent, f, w, h, pots)
bx(parent, f, "ShelfBack", w, h, 0.3, 0, 0, 0, WOOD_D, M.WoodPlanks)
for _, sx in { -1, 1 } do bx(parent, f, "ShelfSide", 0.3, h, 1.0, sx * (w / 2 - 0.15), 0, 0.5, WOOD_D, M.Wood) end
for k = 0, 2 do
local y = 0.5 + k * (h - 1.0) / 2
bx(parent, f, "ShelfBoard", w - 0.2, 0.25, 1.0, 0, y, 0.5, WOOD, M.WoodPlanks)
for i = 1, pots do
local px = -w / 2 + 1.0 + (i - 1) * (w - 2.0) / max(1, pots - 1)
local c = POT_C[rng:NextInteger(1, #POT_C)]
if rng:NextInteger(0, 1) == 0 then cy(parent, f, "Pot", 0.8, 0.9, px, y + 0.25, 0.5, c, M.Slate, DECO)
else ball(parent, f, "Jar", 0.9, px, y + 0.7, 0.5, c, M.Concrete, DECO) end
end
end
end
function P.futon(parent, f)
bx(parent, f, "Futon", 3.4, 0.5, 6.6, 0, 0, 0, PLASTER, M.Fabric)
bx(parent, f, "Pillow", 2.2, 0.5, 1.2, 0, 0.5, -2.4, C3(214, 206, 188), M.Fabric, DECO)
bx(parent, f, "Blanket", 3.5, 0.3, 3.8, 0, 0.5, 1.2, ({ BLUE_NOREN, VERM_D, MOSS_D })[rng:NextInteger(1, 3)], M.Fabric, DECO)
end
function P.irori(parent, f, lit)
for _, s in { -1, 1 } do
bx(parent, f, "HearthStone", 3.6, 0.5, 0.6, 0, 0, s * 1.5, STONE_D, M.Granite)
bx(parent, f, "HearthStone", 0.6, 0.5, 3.6, s * 1.5, 0, 0, STONE_D, M.Granite)
end
bx(parent, f, "Ash", 2.4, 0.3, 2.4, 0, 0, 0, C3(70, 66, 62), M.Slate)
local c = mk(parent, "Coals", V3(1.3, 0.2, 1.3), f * CF(0, 0.4, 0), C3(255, 120, 40), M.Neon, { deco = true })
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = C3(255, 150, 70), 16, 0.9, false
pl.Parent = c
ball(parent, f, "Kettle", 1.3, 0, 1.15, 0, LACQUER, M.Metal, DECO)
cy(parent, f, "KettleLid", 0.5, 0.3, 0, 1.75, 0, LACQUER, M.Metal, DECO)
end
function P.andon(parent, f)
bx(parent, f, "AndonBase", 1.3, 0.25, 1.3, 0, 0, 0, WOOD_D, M.Wood)
local g = mk(parent, "AndonPaper", V3(1.0, 1.7, 1.0), f * CF(0, 1.1, 0), GLOW, M.Neon, { deco = true, t = 0.25 })
for _, sx in { -1, 1 } do for _, sz in { -1, 1 } do bx(parent, f, "AndonPost", 0.18, 1.8, 0.18, sx * 0.5, 0.25, sz * 0.5, WOOD_D, M.Wood, DECO) end end
bx(parent, f, "AndonCap", 1.3, 0.2, 1.3, 0, 2.0, 0, WOOD_D, M.Wood, DECO)
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = GLOW, 15, 0.8, false
pl.Parent = g
end
function P.screen(parent, f, w)
local pw = w / 3
for i = -1, 1 do
bx(parent, f, "ScreenPanel", pw, 4.4, 0.15, i * pw * 0.94, 0, (i == 0) and 0 or 0.3, PLASTER, M.Fabric, nil, ANG(0, rad(i * 18), 0))
bx(parent, f, "ScreenPaint", pw * 0.7, 1.6, 0.18, i * pw * 0.94, 1.6, (i == 0) and 0 or 0.3, ({ BLUE_NOREN, VERM_D, MOSS_D })[i + 2], M.Fabric, DECO, ANG(0, rad(i * 18), 0))
end
end
function P.neko(parent, f) -- maneki-neko on a little stand
bx(parent, f, "NekoStand", 1.3, 0.8, 1.3, 0, 0, 0, WOOD_D, M.Wood)
ball(parent, f, "NekoBody", 1.1, 0, 1.35, 0, PLASTER, M.SmoothPlastic, DECO)
ball(parent, f, "NekoHead", 0.9, 0, 2.2, 0, PLASTER, M.SmoothPlastic, DECO)
for _, sx in { -1, 1 } do bx(parent, f, "NekoEar", 0.25, 0.35, 0.2, sx * 0.3, 2.6, 0, PLASTER, M.SmoothPlastic, DECO) end
bx(parent, f, "NekoPaw", 0.3, 0.9, 0.3, 0.55, 1.7, 0.2, PLASTER, M.SmoothPlastic, DECO)
bx(parent, f, "NekoBib", 0.7, 0.25, 0.2, 0, 1.75, 0.5, VERM, M.Fabric, DECO)
ball(parent, f, "NekoCoin", 0.35, 0, 1.2, 0.55, GOLD, M.Metal, DECO)
end
function P.vending(parent, f, col)
bx(parent, f, "VendingBody", 3.4, 6.2, 2.6, 0, 0, 0, col or C3(200, 40, 40), M.SmoothPlastic)
local g = mk(parent, "VendingPanel", V3(2.5, 3.6, 0.12), f * CF(-0.1, 3.4, 1.32), C3(214, 236, 255), M.Neon, { deco = true })
for r = 0, 2 do for c = 0, 3 do
bx(parent, f, "Bottle", 0.45, 1.0, 0.1, -1.2 + c * 0.62, 2.9 + r * 1.1, 1.4, ({ VERM, BLUE_NOREN, MOSS, GOLD })[(r + c) % 4 + 1], M.SmoothPlastic, DECO)
end end
bx(parent, f, "VendingSlot", 2.2, 0.7, 0.2, 0, 0.5, 1.3, LACQUER, M.SmoothPlastic, DECO)
bx(parent, f, "VendingPad", 0.5, 1.6, 0.2, 1.4, 3.0, 1.32, C3(60, 60, 64), M.SmoothPlastic, DECO)
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = C3(200, 230, 255), 16, 0.9, false
pl.Parent = g
end
function P.rickshaw(parent, f)
bx(parent, f, "Seat", 3.0, 0.5, 2.6, 0, 1.9, 0, VERM_D, M.Fabric)
bx(parent, f, "SeatBack", 3.0, 2.0, 0.4, 0, 2.4, -1.1, VERM_D, M.Fabric)
bx(parent, f, "Chassis", 3.2, 0.4, 3.4, 0, 1.5, 0, LACQUER, M.Wood)
for _, sx in { -1, 1 } do
cyh(parent, f, "Wheel", 3.4, 0.3, sx * 1.9, 1.7, 0, "x", LACQUER, M.Wood)
cyh(parent, f, "WheelHub", 0.7, 0.5, sx * 1.9, 1.7, 0, "x", GOLD, M.Metal, DECO)
beam(parent, f, "Shaft", V3(sx * 1.2, 1.5, 0.5), V3(sx * 1.0, 1.1, 5.4), 0.28, WOOD_D, M.Wood)
bx(parent, f, "HoodRib", 0.25, 2.6, 0.25, sx * 1.4, 2.2, -1.0, LACQUER, M.Wood, DECO)
end
bx(parent, f, "Hood", 3.2, 0.3, 2.6, 0, 4.7, -0.4, LACQUER, M.Fabric, nil, ANG(rad(-14), 0, 0))
bx(parent, f, "ShaftBar", 2.4, 0.3, 0.3, 0, 1.0, 5.4, WOOD_D, M.Wood, DECO)
end
function P.laundry(parent, f, len)
for _, sx in { -1, 1 } do bx(parent, f, "LaundryPole", 0.4, 7.2, 0.4, sx * len / 2, 0, 0, WOOD_D, M.Wood) end
bx(parent, f, "LaundryRope", len, 0.15, 0.15, 0, 6.6, 0, LACQUER, M.Fabric, DECO)
local n = max(2, floor(len / 2.4))
for i = 1, n do
local c = ({ PLASTER, BLUE_NOREN, VERM_L, C3(232, 214, 120), MOSS })[rng:NextInteger(1, 5)]
bx(parent, f, "Cloth", 1.5, rng:NextNumber(2.4, 3.6), 0.1, -len / 2 + 1.2 + (i - 1) * (len - 2.4) / (n - 1), 6.7 - 3.6, 0.1, c, M.Fabric, DECO)
end
end
function P.koinobori(parent, f, h)
cy(parent, f, "KoiPole", 0.45, h, 0, 0, 0, WOOD_L, M.Wood)
ball(parent, f, "KoiBall", 1.0, 0, h + 0.5, 0, GOLD, M.Metal, DECO)
local cols = { C3(30, 30, 34), VERM, C3(70, 130, 190), C3(232, 180, 60) }
for i = 1, 4 do
local y = h - 1.6 - (i - 1) * 2.5
local len = 5.2 - i * 0.35
cyh(parent, f, "Koi", 2.0 - i * 0.12, len, len / 2 + 0.2, y, 0, "x", cols[i], M.Fabric, DECO)
cyh(parent, f, "KoiRing", 0.3, 0.3, 0.1, y, 0, "x", GOLD, M.Metal, DECO)
end
end
function P.stringLights(parent, pa, pb, sag, n, col)
local prev
for i = 0, n do
local t = i / n
local p = pa:Lerp(pb, t) - V3(0, sag * 4 * t * (1 - t), 0)
if prev then beam(parent, CFrame.identity, "Rope", prev, p, 0.14, LACQUER, M.Fabric, DECO) end
if i > 0 and i < n then
local lc = ({ VERM_L, C3(255, 214, 120), C3(236, 120, 90) })[(i % 3) + 1]
ball(parent, CF(p.X, p.Y - 0.9, p.Z), "ChochinStem", 0.2, 0, 0.45, 0, LACQUER, M.Fabric, DECO)
ball(parent, CF(p.X, p.Y - 0.9, p.Z), "Chochin", 1.2, 0, 0, 0, lc, M.Neon, { deco = true, t = 0.1 })
end
prev = p
end
end
function P.campfire(parent, f)
for k = 0, 7 do
local a = k / 8 * pi * 2
bx(parent, f, "FireStone", 0.9, 0.7, 0.9, cos(a) * 1.8, 0, sin(a) * 1.8, STONE_D, M.Slate, nil, ANG(0, a, 0))
end
for k = 0, 2 do cyh(parent, f * ANG(0, k * pi / 3, 0), "Log", 0.7, 3.2, 0, 0.55, 0, "x", WOOD_D, M.Wood, DECO) end
local base = mk(parent, "FireBase", V3(1, 0.4, 1), f * CF(0, 0.9, 0), C3(255, 140, 50), M.Neon, { deco = true, t = 0.6 })
local fi = Instance.new("Fire")
fi.Size, fi.Heat = 5, 6
fi.Parent = base
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = C3(255, 150, 70), 24, 1.2, false
pl.Parent = base
end
function P.well(parent, f)
cy(parent, f, "WellRing", 4.2, 1.8, 0, 0, 0, STONE_D, M.Cobblestone)
cy(parent, f, "WellWater", 3.2, 0.2, 0, 1.55, 0, C3(40, 70, 86), M.Glass, DECO)
for _, sx in { -1, 1 } do bx(parent, f, "WellPost", 0.4, 4.6, 0.4, sx * 2.0, 1.6, 0, WOOD_D, M.Wood) end
bx(parent, f, "WellBeam", 4.8, 0.4, 0.5, 0, 6.0, 0, WOOD_D, M.Wood)
gable(parent, f * CF(0, 5.8, 0), 5.6, { { 2.4, 0 }, { 0, 1.5 } }, 0.3, TILE, 0.4, TILE_D)
cy(parent, f, "WellBucket", 1.0, 0.9, 0.6, 4.4, 0, WOOD, M.Wood, DECO)
beam(parent, f, "WellRope", V3(0.6, 5.9, 0), V3(0.6, 5.2, 0), 0.1, LACQUER, M.Fabric, DECO)
end
function P.haystack(parent, f)
cy(parent, f, "Hay", 4.4, 0.9, 0, -0.2, 0, THATCH_D, M.Fabric)
cy(parent, f, "Hay", 3.8, 1.8, 0, 0.7, 0, THATCH, M.Fabric)
cy(parent, f, "Hay", 2.6, 1.3, 0, 2.5, 0, THATCH, M.Fabric, DECO)
ball(parent, f, "HayTop", 1.7, 0, 3.9, 0, THATCH_D, M.Fabric, DECO)
end
function P.bench(parent, f, len)
bx(parent, f, "BenchSeat", len, 0.4, 1.5, 0, 1.4, 0, WOOD, M.WoodPlanks)
for _, sx in { -1, 1 } do bx(parent, f, "BenchLeg", 0.5, 1.5, 1.2, sx * (len / 2 - 0.6), 0, 0, WOOD_D, M.Wood, DECO) end
end
function P.signpost(parent, f)
bx(parent, f, "SignPole", 0.5, 5.6, 0.5, 0, 0, 0, WOOD_D, M.Wood)
bx(parent, f, "SignBoard", 3.8, 1.1, 0.25, 0.9, 4.2, 0.3, WOOD_L, M.WoodPlanks, nil, ANG(0, rad(10), 0))
bx(parent, f, "SignBoard", 3.2, 1.1, 0.25, -0.7, 2.9, 0.3, WOOD_L, M.WoodPlanks, nil, ANG(0, rad(-12), 0))
end
function P.stoneLanternRow(parent, pts, scale)
for _, p in pts do lantern(parent, CF(p[1], p[3], p[2]) * ANG(0, rad(p[4] or 0), 0), scale or 1, true) end
end
function P.sakura(parent, x, z, h, rngv, gy)
local m = model("Sakura", parent)
local o = CF(x, gy or 0, z) * ANG(0, rad(rngv:NextInteger(0, 359)), 0)
local BARK = C3(70, 52, 46)
cy(m, o, "Trunk", h * 0.1, h * 0.45, 0, -0.4, 0, BARK, M.Wood)
cy(m, o, "Trunk2", h * 0.07, h * 0.4, 0, h * 0.4, 0, BARK, M.Wood, DECO)
for i = 1, 5 do
local a = i / 5 * pi * 2 + rngv:NextNumber(-0.3, 0.3)
local reach = h * rngv:NextNumber(0.28, 0.4)
local px, pz = cos(a) * reach, sin(a) * reach
local py = h * rngv:NextNumber(0.58, 0.72)
beam(m, o, "Branch", V3(0, h * 0.42, 0), V3(px, py, pz), h * 0.045, BARK, M.Wood, DECO)
ball(m, o, "Bloom", h * rngv:NextNumber(0.34, 0.44), px, py + h * 0.05, pz, SAKURA_C[rngv:NextInteger(1, 4)], M.Fabric, NOSH)
end
ball(m, o, "BloomTop", h * 0.46, 0, h * 0.8, 0, SAKURA_C[rngv:NextInteger(1, 4)], M.Fabric, NOSH)
return m
end
function P.cheapPine(parent, x, gy, z, h, c1, c2)
local o = CF(x, gy, z)
cy(parent, o, "Trunk", max(0.7, h * 0.05), h * 0.35, 0, -0.3, 0, CEDAR_BARK, M.Wood, NOSH)
cy(parent, o, "Tier", h * 0.38, h * 0.3, 0, h * 0.2, 0, c1, M.Grass, NOSH)
cy(parent, o, "Tier", h * 0.27, h * 0.28, 0, h * 0.44, 0, c2, M.Grass, NOSH)
cy(parent, o, "Tier", h * 0.16, h * 0.3, 0, h * 0.66, 0, c1, M.Grass, NOSH)
end
function P.crag(parent, x, gy, z, s, col)
local o = CF(x, gy, z) * ANG(0, rad(rng:NextInteger(0, 359)), 0)
for k = 1, 4 do
local w = s * rng:NextNumber(0.5, 0.9) / k ^ 0.4
local h = s * rng:NextNumber(1.2, 2.0) / k ^ 0.3
mk(parent, "Crag", V3(w, h, w * rng:NextNumber(0.7, 1.2)), o * CF(rng:NextNumber(-s * 0.4, s * 0.4), h * 0.35, rng:NextNumber(-s * 0.4, s * 0.4)) * ANG(rad(rng:NextInteger(-12, 12)), rad(rng:NextInteger(0, 90)), rad(rng:NextInteger(-12, 12))), (k % 2 == 0) and (col or STONE_D) or (col or STONE), M.Slate, NOSH)
end
end
local function hut(parent, o, w, d)
local m = model("ThatchHut", parent)
bx(m, o, "Base", w + 0.6, 0.5, d + 0.6, 0, 0, 0, STONE_D, M.Cobblestone)
bx(m, o, "Floor", w - 0.3, 0.3, d - 0.3, 0, 0.5, 0, WOOD_OLD, M.WoodPlanks)
local dx = w * 0.12
holedWall(m, o, "WallFront", w, 4.6, 0.4, 0, 0.8, d / 2 - 0.2, WOOD_OLD, M.WoodPlanks, { { dx, 2.2, 0, 4.3 }, { -w * 0.3, 1.6, 1.4, 3.0 } })
holedWall(m, o, "WallBack", w, 4.6, 0.4, 0, 0.8, -d / 2 + 0.2, WOOD_OLD, M.WoodPlanks, { { 0, 1.6, 1.4, 3.0 } })
for _, sx in { -1, 1 } do
holedWall(m, o * CF(sx * (w / 2 - 0.2), 0, 0) * ANG(0, rad(90), 0), "WallSide", d, 4.6, 0.4, 0, 0.8, 0, WOOD_OLD, M.WoodPlanks, { { 0, 1.6, 1.4, 3.0 } })
end
for i = 0, floor(w / 1.1) do bx(m, o, "Batten", 0.2, 4.6, 0.12, -w / 2 + 0.3 + i * 1.1, 0.8, d / 2 + 0.07, WOOD_D, M.Wood, DECO) end
local prof = { { d / 2 + 1.1, 0 }, { d / 2 * 0.55, 1.5 }, { 0, 3.3 } }
gable(m, o, w + 1.3, prof, 0.7, THATCH, 5.4, THATCH_D, M.Fabric)
gableEnd(m, o, w + 1.3, prof, 5.4, WOOD_OLD, M.WoodPlanks, 4)
for _ = 1, 5 do
bx(m, o, "ThatchBundle", rng:NextNumber(0.8, 1.6), 0.5, rng:NextNumber(1, 2), rng:NextNumber(-w / 2, w / 2), 6.0 + rng:NextNumber(0, 1.2), rng:NextNumber(-d / 2, d / 2), THATCH_D, M.Fabric, DECO, ANG(rad(rng:NextInteger(-15, 15)), rad(rng:NextInteger(0, 40)), 0))
end
P.irori(m, at(o, w * 0.15, 0.8, -d * 0.1))
P.futon(m, at(o, -w / 2 + 2.4, 0.8, -d / 2 + 4.0))
P.shelf(m, at(o, 0, 0.8, -d / 2 + 0.5), min(5, w - 3), 4.2, 3)
P.andon(m, at(o, w / 2 - 1.3, 0.8, -d / 2 + 1.3))
P.barrel(m, o, -w / 2 - 1.3, d / 2 - 0.8, 0)
return m
end
function P.furnish(kind, m, o, w, d, fy, op)
local k = op.shop or kind
local hx, hz = w / 2, d / 2
if kind == "machiya" then
if k == "pottery" then
cy(m, at(o, 0, fy, -1), "WheelBase", 1.6, 1.0, 0, 0, 0, STONE_D, M.Granite)
cy(m, at(o, 0, fy, -1), "WheelDisc", 2.6, 0.2, 0, 1.0, 0, C3(150, 110, 80), M.Slate, DECO)
bx(m, o, "PotterStool", 1.4, 0.9, 1.4, 0, fy, 1.4, WOOD, M.Wood)
P.shelf(m, at(o, 0, fy, -hz + 0.6), min(6, w - 3), 4.2, 4)
P.shelf(m, at(o, -hx + 0.9, fy, 0, 90), 6, 4.2, 4)
bx(m, o, "Kiln", 3.2, 3.0, 3.0, hx - 2.4, fy, -hz + 2.4, STONE_D, M.Cobblestone)
bx(m, o, "KilnDome", 2.6, 0.8, 2.4, hx - 2.4, fy + 3.0, -hz + 2.4, STONE, M.Cobblestone, DECO)
cy(m, o, "KilnFlue", 0.9, 3.0, hx - 2.4, fy + 3.2, -hz + 1.6, STONE_D, M.Granite, DECO)
local g = mk(m, "KilnGlow", V3(1.4, 0.9, 0.2), o * CF(hx - 2.4, fy + 1.0, -hz + 3.95), C3(255, 130, 50), M.Neon, { deco = true })
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = C3(255, 140, 60), 15, 0.8, false
pl.Parent = g
elseif k == "sweets" then
bx(m, o, "Counter", w * 0.62, 1.7, 1.4, -w * 0.12, fy, hz - 3.4, WOOD, M.WoodPlanks)
bx(m, o, "CounterTop", w * 0.62 + 0.3, 0.2, 1.8, -w * 0.12, fy + 1.7, hz - 3.4, WOOD_D, M.Wood, DECO)
for i = 0, 4 do
cy(m, o, "Mochi", 0.9, 0.35, -w * 0.12 - w * 0.25 + i * w * 0.125, fy + 1.9, hz - 3.4, ({ PLASTER, SAKURA_C[2], MOSS, PLASTER_D })[i % 4 + 1], M.SmoothPlastic, DECO)
end
P.neko(m, at(o, w * 0.18, fy + 1.9, hz - 3.4))
P.shelf(m, at(o, 0, fy, -hz + 0.6), min(6.5, w - 3), 4.2, 5)
P.barrel(m, o, -hx + 1.3, -hz + 1.6, fy)
P.sack(m, o, hx - 1.4, -hz + 1.4, fy)
P.andon(m, at(o, hx - 1.4, fy, 0))
elseif k == "inn" then
P.futon(m, at(o, -w * 0.25, fy, -hz + 4.0))
P.futon(m, at(o, w * 0.25, fy, -hz + 4.0))
P.screen(m, at(o, 0, fy, -hz + 4.0, 90), 6.0)
P.table(m, o, -w * 0.28, 1.8, fy, 3.0, 2.0, 1.1)
P.cushion(m, o, -w * 0.28, 3.6, fy)
P.cushion(m, o, -w * 0.28 - 1.8, 1.8, fy, BLUE_NOREN)
P.andon(m, at(o, hx - 1.3, fy, -hz + 1.3))
P.andon(m, at(o, -hx + 1.3, fy, -hz + 1.3))
P.shelf(m, at(o, w * 0.28, fy, hz - 3.0, 180), 4.5, 4.2, 2)
elseif k == "dye" then
for i, c in { C3(36, 54, 110), C3(150, 40, 40), C3(64, 120, 96) } do
local vx = (i - 2) * (w * 0.28)
cy(m, o, "DyeVat", 3.2, 2.0, vx, fy, -hz + 3.2, WOOD, M.Wood)
cy(m, o, "DyeLiquid", 2.7, 0.15, vx, fy + 1.9, -hz + 3.2, c, M.SmoothPlastic, DECO)
cy(m, o, "VatBand", 3.3, 0.18, vx, fy + 0.7, -hz + 3.2, WEATHER_D, M.Metal, DECO)
end
bx(m, o, "DryingRod", w - 0.8, 0.3, 0.3, 0, fy + 4.2, -hz + 7.0, WOOD_D, M.Wood)
for i = 1, 5 do
local ch = rng:NextNumber(2.6, 3.6)
bx(m, o, "HangingCloth", 1.5, ch, 0.1, -w / 2 + 1.6 + (i - 1) * (w - 3.2) / 4, fy + 4.2 - ch, -hz + 7.0, ({ BLUE_NOREN, PLASTER, C3(60, 90, 150), VERM_D })[i % 4 + 1], M.Fabric, DECO)
end
bx(m, o, "RodPostL", 0.4, 4.5, 0.4, -hx + 0.6, fy, -hz + 7.0, WOOD_D, M.Wood, DECO)
bx(m, o, "RodPostR", 0.4, 4.5, 0.4, hx - 0.6, fy, -hz + 7.0, WOOD_D, M.Wood, DECO)
else -- tea shop
P.irori(m, at(o, w * 0.12, fy, -hz + 3.4))
P.table(m, o, -w / 2 + 3.4, -1.0, fy, 2.8, 3.4, 1.0)
P.cushion(m, o, -w / 2 + 3.4, 1.7, fy)
P.cushion(m, o, -w / 2 + 3.4, -3.8, fy, BLUE_NOREN)
P.shelf(m, at(o, -w * 0.18, fy, -hz + 0.6), min(5, w - 3), 4.2, 4)
P.neko(m, at(o, (op.doorX or -w * 0.2) + 2.6, fy, hz - 1.4))
P.andon(m, at(o, hx - 1.3, fy, -hz + 1.3))
end
elseif kind == "lodge" or kind == "onsenhouse" then
local y0 = fy
bx(m, o, "HearthBody", 3.4, 3.2, 2.0, -w * 0.28, y0, -d * 0.2 - 2.2, STONE_D, M.Cobblestone)
bx(m, o, "HearthMantle", 3.8, 0.35, 2.4, -w * 0.28, y0 + 3.2, -d * 0.2 - 2.2, STONE, M.Granite, DECO)
local g = mk(m, "HearthFire", V3(1.6, 1.0, 0.2), o * CF(-w * 0.28, y0 + 0.9, -d * 0.2 - 1.15), C3(255, 130, 50), M.Neon, { deco = true })
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness, pl.Shadows = C3(255, 150, 70), 18, 1.0, false
pl.Parent = g
for _, sx in { -1, 1 } do
local f = at(o, sx * (hx - 2.4), y0, hz * 0.2, 0)
bx(m, f, "BunkPost", 0.35, 5.0, 0.35, -1.4, 0, -3.0, WOOD_D, M.Wood, DECO)
bx(m, f, "BunkPost", 0.35, 5.0, 0.35, 1.4, 0, -3.0, WOOD_D, M.Wood, DECO)
bx(m, f, "BunkPost", 0.35, 5.0, 0.35, -1.4, 0, 3.0, WOOD_D, M.Wood, DECO)
bx(m, f, "BunkPost", 0.35, 5.0, 0.35, 1.4, 0, 3.0, WOOD_D, M.Wood, DECO)
bx(m, f, "BunkLow", 3.2, 0.4, 6.8, 0, 1.0, 0, WOOD, M.WoodPlanks)
bx(m, f, "BunkHigh", 3.2, 0.4, 6.8, 0, 3.3, 0, WOOD, M.WoodPlanks)
bx(m, f, "Mattress", 3.0, 0.4, 6.4, 0, 1.4, 0, C3(150, 140, 120), M.Fabric, DECO)
bx(m, f, "Mattress", 3.0, 0.4, 6.4, 0, 3.7, 0, SAKURA_C[2]:Lerp(C3(120, 90, 90), 0.5), M.Fabric, DECO)
end
P.table(m, o, 0, -hz + 3.6, y0, 4.2, 2.4, 1.6)
for _, sx in { -1, 1 } do bx(m, o, "Stool", 1.2, 1.1, 1.2, sx * 3.0, y0, -hz + 3.6, WOOD, M.Wood, DECO) end
P.andon(m, at(o, 0, y0, hz - 2.0))
elseif kind == "shack" then
P.table(m, o, -hx + 2.6, -hz + 2.4, fy, 3.0, 2.0, 1.5)
bx(m, o, "StoveBody", 1.8, 2.6, 1.8, hx - 1.6, fy, -hz + 1.6, LACQUER, M.CorrodedMetal)
cy(m, o, "StovePipe", 0.55, 1.6, hx - 1.6, fy + 2.6, -hz + 1.6, LACQUER, M.CorrodedMetal, DECO)
bx(m, o, "NetPile", 2.8, 1.0, 2.2, -hx + 2.2, fy, hz - 3.0, C3(150, 150, 120), M.Fabric, DECO, ANG(0, rad(20), 0))
bx(m, o, "Hammock", 0.2, 0.3, 5.0, 0, fy + 3.0, -hz + 1.2, C3(190, 170, 130), M.Fabric, DECO, ANG(0, rad(90), 0))
crate(m, o, 0.5, -hz + 1.6, 1.7, fy)
P.sack(m, o, hx - 1.5, 0.5, fy)
P.andon(m, at(o, -hx + 1.2, fy, -1.0))
elseif kind == "kura" then
for i = 0, 2 do P.sack(m, o, hx - 1.4 - i * 1.7, -hz + 1.6, fy) end
for i = 0, 1 do P.sack(m, o, hx - 2.2 - i * 1.7, -hz + 1.6, fy + 1.2) end
for i = 0, 1 do P.sack(m, o, hx - 1.4 - i * 1.7, -hz + 2.9, fy) end
P.barrel(m, o, -hx + 1.5, hz - 2.2, fy)
P.barrel(m, o, -hx + 3.4, hz - 2.0, fy)
P.shelf(m, at(o, -hx + 0.9, fy, 0, 90), min(6, d - 3), 5.6, 4)
P.andon(m, at(o, hx - 1.3, fy, hz - 2.4))
elseif kind == "teahouse" then
P.irori(m, at(o, w * 0.18, fy, -d * 0.2))
P.table(m, o, -w * 0.22, -d * 0.12, fy, 3.2, 2.4, 1.0)
P.cushion(m, o, -w * 0.22, 1.2, fy)
P.cushion(m, o, -w * 0.22 - 2.3, -d * 0.12, fy, BLUE_NOREN)
P.cushion(m, o, -w * 0.22 + 2.3, -d * 0.12, fy, BLUE_NOREN)
P.shelf(m, at(o, -w * 0.25, fy, -d / 2 + 1.4), 5, 4.4, 4)
P.neko(m, at(o, w / 2 - 2.2, fy, d / 2 - 2.0))
elseif kind == "mill" then
for i = 0, 3 do P.sack(m, o, -hx + 1.4 + (i % 2) * 1.7, -hz + 1.5 + floor(i / 2) * 1.2, fy) end
cy(m, o, "MillstoneLow", 3.6, 0.7, 2.0, fy, -1.0, STONE, M.Granite)
cy(m, o, "MillstoneTop", 3.4, 0.6, 2.0, fy + 0.7, -1.0, STONE_L, M.Granite)
cy(m, o, "MillShaft", 0.5, 4.2, 2.0, fy + 1.3, -1.0, WOOD_D, M.Wood, DECO)
bx(m, o, "Hopper", 1.6, 1.2, 1.6, 2.0, fy + 5.0, -1.0, WOOD, M.WoodPlanks, DECO)
P.barrel(m, o, -hx + 1.4, hz - 2.0, fy)
P.andon(m, at(o, hx - 1.3, fy, hz - 2.0))
end
end
function P.groundBuilding(m, o, w, d, th, doorLocalX, noStoop)
local oy = o.Position.Y
local lowest = oy
for _, sx in { -1, 0, 1 } do for _, sz in { -1, 0, 1 } do
local p = o * V3(sx * (w / 2 + 0.4), 0, sz * (d / 2 + 0.4))
lowest = min(lowest, Hf(p.X, p.Z))
end end
if oy - lowest > 0.3 then
local hgt = oy - lowest + 0.7
bx(m, o, "StonePlinth", w + 0.9, hgt, d + 0.9, 0, -hgt + 0.05, 0, STONE_D, M.Cobblestone)
end
if noStoop then return end
local dxw = doorLocalX or 0
local rise = 0.62
for k = 1, 14 do
local lz = d / 2 + 0.7 + (k - 1) * 1.15
local p = o * V3(dxw, 0, lz)
local g = Hf(p.X, p.Z)
local top = th - k * rise
if oy + top < g + 0.12 then break end
local bottom = g - 0.5 - oy
bx(m, o, "DoorStep", 3.4, top - bottom, 1.15, dxw, bottom, lz, STONE, M.Cobblestone)
end
end
local function onsen(parent, o, w, d)
local m = model("Onsen", parent)
local hd = 11
local fb = at(o, 0, 0, d / 2 - hd / 2)
lodge(m, fb, w, hd, { name = "BathHouse", board = WOOD_L, doorX = 0 })
P.furnish("lodge", m, fb, w, hd, 1.2, {})
local pz = -d / 2 + (d - hd) / 2 - 0.5
local pw, pd = w - 2, d - hd - 3
for _, s in { -1, 1 } do
bx(m, o, "PoolRim", pw + 2, 1.4, 1.4, 0, 0, pz + s * (pd / 2 + 0.7), STONE_D, M.Cobblestone)
bx(m, o, "PoolRim", 1.4, 1.4, pd, s * (pw / 2 + 0.7), 0, pz, STONE_D, M.Cobblestone)
end
bx(m, o, "PoolFloor", pw, 0.8, pd, 0, 0, pz, STONE, M.Slate)
mk(m, "HotWater", V3(pw - 0.2, 0.2, pd - 0.2), o * CF(0, 1.0, pz), C3(150, 214, 220), M.Glass, { deco = true, t = 0.35, refl = 0.1, noshadow = true })
for i = 1, 6 do
local px, pz2 = rng:NextNumber(-pw / 2, pw / 2), pz + rng:NextNumber(-pd / 2, pd / 2)
ball(m, o, "SteamPuff", rng:NextNumber(2.2, 3.4), px, 2.6 + rng:NextNumber(0, 1.6), pz2, C3(250, 250, 250), M.SmoothPlastic, { deco = true, t = 0.82, noshadow = true })
end
for _, sx in { -1, 1 } do
rock(m, at(o, sx * (pw / 2 + 1.8), 0, pz + pd * 0.2), 3.4, 2.2, 3.0)
lantern(m, at(o, sx * (pw / 2 + 2.2), 0, pz - pd * 0.3), 1.0, true)
end
local bz = -d / 2 + 0.3
for i = 0, floor((w + 4) / 0.9) do
cy(m, o, "BambooPost", 0.6, 7.0, -w / 2 - 2 + i * 0.9, 0, bz, BAMBOO, M.Wood)
end
bx(m, o, "FenceRail", w + 4, 0.35, 0.4, 0, 2.2, bz + 0.1, WOOD_D, M.Wood, DECO)
bx(m, o, "FenceRail", w + 4, 0.35, 0.4, 0, 5.2, bz + 0.1, WOOD_D, M.Wood, DECO)
return m
end
local function twin(fn)
fn(function(x, z, yaw, y) return frame(x, z, yaw or 0, y) end, 1)
fn(function(x, z, yaw, y) return frame(x, -z, 180 - (yaw or 0), y) end, -1)
end
local function sides(fn) fn(1) fn(-1) end
local SITES = {}
local function addBlock(x0, x1, a0, a1) TERR.blocks[#TERR.blocks + 1] = { x0, x1, a0, a1 } end
local function pf(x, a, yaw, s, dy)
local z = -a * s
return CF(x, Hf(x, z) + (dy or 0), z) * ANG(0, rad(s == 1 and (yaw or 0) or (180 - (yaw or 0))), 0)
end
local function pav(x, a, w, d, color, mat, y)
sides(function(s) bx(F.paths, CFrame.identity, "Paving", w, 0.14, d, x, y or 0, -a * s, color, mat or M.Cobblestone, NOSH) end)
end
TERR.bump(-150, 96, 48, 56, 22)          -- watch hill
TERR.bump(-212, 58, 40, 44, 15)
TERR.bump(-196, 168, 46, 40, 17)
TERR.bump(-165, 250, 96, 126, 76, 1.5)   -- THE MOUNTAIN (west): shoulder with a shelf at half height, then the summit
TERR.bump(-192, 292, 50, 52, 22, 1.5)    -- summit cap
TERR.bump(-108, 326, 40, 44, 14)
TERR.bump(-62, 130, 36, 32, 11)          -- shrine knolls beside the avenue
TERR.bump(62, 130, 36, 32, 11)
TERR.bump(60, 266, 30, 30, 9)
TERR.bump(-62, 262, 30, 28, 8)
TERR.bump(112, 240, 34, 70, 20)          -- the hill Sannenzaka street climbs
TERR.bump(106, 306, 34, 34, 17)          -- temple knoll at the top of the street
TERR.bump(226, 150, 28, 64, 18)          -- Kamo bluffs (east bank)
TERR.bump(228, 292, 28, 56, 24)
TERR.bump(228, 66, 24, 30, 10)
TERR.bump(130, 334, 34, 36, 12)
TERR.pad(-(HX - 40), HX - 40, 0, 46, 0, 40)
TERR.pad(-14, 14, 0, 300, 0, 34)
TERR.pad(-66, 66, 286, HZ, 0, 14)
addBlock(-16, 16, 0, 300); addBlock(-70, 70, 286, HZ)
local SHELF_Y = 36
TERR.pad(-176, -114, 186, 246, SHELF_Y, 22)
local SUMMIT_Y = floor(TERR.baseNoPads(-192, 292)) - 2
TERR.pad(-204, -180, 280, 304, SUMMIT_Y, 16)
addBlock(-176, -114, 186, 246); addBlock(-204, -180, 280, 304)
TERR.pad(-116, -78, 54, 122, 0, 10); addBlock(-118, -76, 52, 124)
-- v4 (owner: "you can barely fit in the buildings"): every building is built at its old size and then scaled up as one model about its ground centre
-- (walls, doors, ceilings, furniture, roof - all of it). The site (flat pad, no-tree block, overlap warnings) uses the NEW size.
local BSCALE = {
machiya = 1.35, lodge = 1.35, kura = 1.3, teahouse = 1.3, shack = 1.35, mill = 1.2, hut = 1.35, onsen = 1.2,
watchtower = 1.3, haiden = 1.2, pavilion = 1.25, hokora = 1.25, bell = 1.15, pagoda = 1.1,
}
local function site(kind, x, a, yaw, w, d, op)
op = op or {}
local sc = BSCALE[kind] or 1
local fw, fd = w * sc, d * sc
if abs(sin(rad(yaw))) > 0.7 then fw, fd = fd, fw end
local mg = op.margin or 3
local hx, ha = fw / 2 + mg, fd / 2 + mg
local y = op.y
if not y then
y = -1e9
for i = -2, 2 do for j = -2, 2 do y = max(y, TERR.baseNoPads(x + i * (hx + 4) / 2, a + j * (ha + 4) / 2)) end end
y = max(0, math.ceil(y * 2) / 2)
end
local s = { kind = kind, x = x, a = a, yaw = yaw, w = w, d = d, op = op, y = y, hx = hx, ha = ha, sc = sc }
if not op.nopad then TERR.pad(x - hx - 1, x + hx + 1, a - ha - 1, a + ha + 1, y, 9) end
addBlock(x - hx - 2, x + hx + 2, a - ha - 2, a + ha + 2)
for _, o2 in SITES do
if abs(o2.x - x) < o2.hx + hx - 1.5 and abs(o2.a - a) < o2.ha + ha - 1.5 then warnf("sites overlap: %s / %s", tostring(o2.op.name or o2.kind), tostring(op.name or kind)) end
end
SITES[#SITES + 1] = s
return s
end
local function S(kind, x, a, yaw, w, d, op) return site(kind, x, a, yaw, w, d, op) end
local function riverOff(a) return 28 + 12 * (1 - sstep(70, 140, a)) end
local function rbank(a, west) return riverX(a) + (west and -riverOff(a) or (riverOff(a) + 2)) end
do
local aa = { 72, 96, 120, 144, 168, 192, 216, 240, 264 } -- v4: 24 apart (was 22) - the bigger houses need the room
local west = {
{ "machiya", 13, 12, { name = "Machiya_Tea", doorX = -3, doorW = 3.0, shop = "tea" } },
{ "teahouse", 12, 9, { name = "Teahouse_Street" } },
{ "machiya", 15, 12, { name = "Machiya_Pottery", doorX = 3.5, doorW = 2.6, latticeColor = WOOD_D, shop = "pottery" } },
{ "kura", 10, 10, { name = "Kura_Rice" } },
{ "machiya", 11, 12, { name = "Machiya_Sweets", doorX = 2.5, doorW = 2.4, shop = "sweets" } },
{ "machiya", 16, 12, { name = "Machiya_Inn", doorX = -4, doorW = 3.4, latticeColor = C3(80, 52, 40), shop = "inn" } },
{ "lodge", 14, 11, { name = "Inn_Sannenzaka", doorX = 0, board = C3(96, 70, 54) } },
{ "machiya", 10, 12, { name = "Machiya_Dye", doorX = 0, doorW = 2.8, latticeColor = BLUE_NOREN, shop = "dye" } },
{ "machiya", 14, 12, { name = "Machiya_Tea2", doorX = 2, doorW = 2.8, shop = "tea" } },
}
local east = {
{ "kura", 10, 10, { name = "Kura_Sake" } },
{ "machiya", 13, 12, { name = "Machiya_Dye2", doorX = 2, doorW = 2.8, latticeColor = BLUE_NOREN, shop = "dye" } },
{ "teahouse", 12, 9, { name = "Teahouse_Plaza" } },
{ "machiya", 15, 12, { name = "Machiya_Kiln", doorX = -3.5, doorW = 2.6, latticeColor = WOOD_D, shop = "pottery" } },
{ "machiya", 10, 12, { name = "Machiya_Matcha", doorX = 1, doorW = 2.6, shop = "tea" } },
{ "lodge", 15, 11, { name = "Lodge_Street", doorX = 2, board = WOOD } },
{ "machiya", 12, 12, { name = "Machiya_Mochi", doorX = -2.5, doorW = 2.4, shop = "sweets" } },
{ "kura", 10, 10, { name = "Kura_Tea" } },
{ "machiya", 16, 12, { name = "Machiya_Ryokan", doorX = 4, doorW = 3.4, latticeColor = C3(80, 52, 40), shop = "inn" } },
}
-- Every street house is built with its old w x d, then scaled by BSCALE. Measured offline: roof eaves add ~EXTRA studs to each side (before scaling), so the
-- width is capped so that the REAL half-width stays under HALF (the alley between two houses stays >= 4.5 studs: the lanterns, string lights and
-- fights fit in it); the depth is capped so the back wall stays clear of the river-bank row. The street-side wall stays exactly where it was.
local HALF, DMAX = 9.75, 13.5
local EXTRA = { machiya = 1.45, lodge = 1.1, kura = 1.9, teahouse = 1.9 }
local function row(r, x0, sgn, yaw, aPos, dmax) -- sgn +1 = west row (grows toward -x), -1 = east row (grows toward +x)
local kind, w, d, op = r[1], r[2], r[3], r[4]
local sc = BSCALE[kind] or 1
local d2 = math.min(d, (dmax or DMAX) / sc)
op.margin = 1.2
op.noParasol = true
S(kind, x0 + sgn * (d - d2 * sc) / 2, aPos, yaw, math.min(w, 2 * (HALF / sc - (EXTRA[kind] or 1.5))), d2, op)
end
for i, a in aa do
row(west[i], 84, 1, 90, a)
row(east[i], 116, -1, -90, a, (a >= 216) and 11 or nil) -- the river bends toward the street down here
end
S("hokora", 100, 306, 180, 7, 7, { name = "Hokora_Kodaiji" })
S("bell", 82, 304, 90, 11, 11, {})
end
do
local west = {
{ 106, "shack", 12, 9, { name = "Shack_Riverside_A", doorX = 2 } }, { 134, "shack", 9, 8, { name = "Shack_Riverside_B", doorX = -1.5 } },
{ 170, "shack", 14, 10, { name = "Shack_Riverside_C", doorX = 3 } }, { 196, "shack", 10, 8, { name = "Shack_Riverside_D", doorX = 0 } },
{ 236, "mill", 16, 11, { name = "Mill_House", doorX = -3 } }, { 258, "kura", 10, 9, { name = "Kura_Warehouse" } },
{ 296, "shack", 12, 9, { name = "Shack_Riverside_E", doorX = 1 } }, { 318, "shack", 11, 9, { name = "Shack_Riverside_F", doorX = -1 } },
}
local east = {
{ 108, "shack", 10, 8, { name = "Shack_Bank_A", doorX = 1 } }, { 130, "shack", 12, 9, { name = "Shack_Bank_B", doorX = -2 } },
{ 168, "teahouse", 14, 10, { name = "Teahouse_Bluff" } }, { 190, "shack", 11, 8, { name = "Shack_Bank_C", doorX = 2 } },
{ 232, "shack", 10, 8, { name = "Shack_Bank_D", doorX = -1 } }, { 254, "lodge", 14, 10, { name = "Lodge_Bank", doorX = 2, board = C3(104, 138, 98) } },
{ 298, "hut", 9, 7, {} }, { 318, "shack", 11, 9, { name = "Shack_Bank_E", doorX = 1 } },
}
local function bank(r, isWest)
local kind, w, d = r[2], r[3], r[4]
local sc = BSCALE[kind] or 1
local d2 = math.min(d, ((isWest and r[1] >= 226) and 9.5 or 12) / sc) -- depth cap: the back wall must stay clear of the street row behind it
S(kind, rbank(r[1], isWest) + (isWest and 1 or -1) * (d - d2 * sc) / 2, r[1], isWest and 90 or -90, w, d2, r[5]) -- the river-side wall stays where it was
end
for _, r in west do bank(r, true) end
for _, r in east do bank(r, false) end
end
do
S("lodge", -176, 62, 90, 16, 11, { name = "Lodge_Pinewood", board = WOOD, doorX = 3 })
S("lodge", -150, 142, 90, 20, 12, { name = "Lodge_Highland", upper = true, doorX = -3 })
S("onsen", -188, 114, 90, 14, 28, { name = "Onsen_Highland" })
S("hut", -214, 150, 90, 9, 7, {})
S("watchtower", -150, 96, 0, 10.4, 10.4, { name = "Watchtower_Hill", y = floor(TERR.baseNoPads(-150, 96) - 2.5) })
S("hokora", -86, 146, 90, 7, 7, { name = "Hokora_Plaza" })
S("lodge", -78, 226, 90, 16, 11, { name = "Lodge_Birch", board = C3(104, 138, 98), doorX = -2 })
S("hut", -82, 252, 90, 9, 7, {})
S("lodge", -78, 290, 90, 16, 11, { name = "Lodge_Cedar", board = WOOD, doorX = 2 })
S("hut", -84, 318, 90, 9, 7, {})
S("haiden", -160, 216, 90, 34, 12, { y = SHELF_Y, name = "MountainHall" })
S("pavilion", -130, 200, 90, 8, 6, { y = SHELF_Y, name = "Chozuya" })
S("hokora", -120, 230, 90, 7, 7, { y = SHELF_Y, name = "Hokora_Shelf" })
S("watchtower", -190, 292, 0, 10.4, 10.4, { y = SUMMIT_Y, name = "Watchtower_Summit" })
S("hokora", -174, 302, 0, 7, 7, { y = SUMMIT_Y, name = "Hokora_Summit" })
end
do
S("karesansui", -32, 96, 0, 22, 16, {})
S("pond", 32, 96, 0, 20, 16, {})
S("teahouse", -46, 192, 90, 14, 10, { name = "Teahouse_Garden" })
S("pagoda", 56, 206, 0, 27, 27, { name = "Pagoda_Mid" })
S("bell", -50, 262, 0, 11, 11, {})
S("hokora", -62, 130, 0, 7, 7, { name = "Hokora_Knoll" })
S("hokora", 62, 130, 0, 7, 7, { name = "Hokora_KnollE" })
S("hut", 60, 270, 20, 9, 7, {})
end
local INNER_TRIS = 0
do
INNER_TRIS = TERR.mesh(F.terrain, -HX, HX, -HZ, HZ, 8, nil, 2.2, false)
TERR.mesh(F.mountains, -320, 320, -480, 480, 16, { -HX, HX, -HZ, HZ }, 6, true)
TERR.mesh(F.mountains, -608, 608, -768, 768, 32, { -320, 320, -480, 480 }, 8, true)
for _, z0 in { -1800, 200 } do
mk(F.backdrop, "ApronW", V3(1400, 4, 1800), CF(-608 - 700, -2, z0 + 900), C3(66, 88, 58), M.Grass, DECO)
mk(F.backdrop, "ApronE", V3(1400, 4, 1800), CF(608 + 700, -2, z0 + 900), C3(66, 88, 58), M.Grass, DECO)
end
mk(F.backdrop, "ApronS", V3(1216, 4, 1400), CF(0, -2, -768 - 700), C3(66, 88, 58), M.Grass, DECO)
mk(F.backdrop, "ApronN", V3(1216, 4, 1400), CF(0, -2, 768 + 700), C3(66, 88, 58), M.Grass, DECO)
end
do
for a = 54, 346, 8 do
local am = a + 4
local hw = 11 + 14 * (1 - sstep(70, 124, am))
sides(function(s) water(F.fx, riverX(am), -am * s, (hw + 6.5) * 2, 8.4, -3.0, 2.2) end)
end
sides(function(s)
for i = 1, 9 do
local an = i / 9 * pi * 2
local rx, rz = riverX(346) + cos(an) * 16, (-346 + sin(an) * 14) * s
if sin(an) < 0.4 then rock(F.props, CF(rx, Hf(rx, rz), rz), rng:NextNumber(3, 5), rng:NextNumber(2.5, 4), rng:NextNumber(3, 5)) end -- (none on the bridge side)
end
for i = 1, 12 do
local rx, rz = riverX(56) + (i - 6.5) * 4.6, -(52 + rng:NextNumber(0, 4)) * s
rock(F.props, CF(rx, Hf(rx, rz), rz), rng:NextNumber(2.5, 4.5), rng:NextNumber(2, 3.5), rng:NextNumber(2.5, 4.5))
end
end)
end
local PATHS = {}
local PATH_A, PATH_B
local function path(pts, width, color, mat, name, torii)
PATHS[#PATHS + 1] = { pts = pts, w = width }
sides(function(s)
local wp = {}
for i, p in pts do wp[i] = { p[1], -p[2] * s } end
TERR.pathStrip(F.paths, wp, width, color, mat, 0.6, name)
end)
end
do
local PAVE, PAVE_D = C3(122, 120, 112), C3(98, 96, 90)
pav(0, 24, 14, 48, PAVE, M.Cobblestone)                       -- avenue across the wall band
pav(0, 173, 14, 254, PAVE, M.Cobblestone)
pav(0, 173, 14.4, 254, PAVE_D, M.Slate, -0.02)
pav(0, 331, 92, 64, C3(204, 200, 188), M.Sand)               -- shrine courtyard (white gravel)
pav(0, 331, 16, 64, C3(140, 138, 130), M.Granite, 0.02)      -- processional slabs
pav(-32, 96, 30, 24, C3(110, 108, 100), M.Cobblestone, -0.01) -- garden court
pav(32, 96, 30, 24, C3(110, 108, 100), M.Cobblestone, -0.01)
path({ { 100, 60 }, { 100, 150 }, { 100, 240 }, { 100, 292 } }, 17, C3(128, 124, 116), M.Slate, "StreetSlab")
path({ { 100, 292 }, { 100, 296 } }, 20, C3(120, 118, 108), M.Cobblestone, "TempleLanding")
PATH_A = { { -14, 166 }, { -44, 170 }, { -72, 166 }, { -92, 172 }, { -102, 182 }, { -94, 192 }, { -108, 200 }, { -100, 210 }, { -112, 214 }, { -124, 214 } }
PATH_B = { { -124, 214 }, { -134, 226 }, { -146, 240 }, { -150, 252 }, { -164, 260 }, { -178, 268 }, { -168, 280 }, { -182, 288 }, { -192, 292 } }
path(PATH_A, 5.5, C3(140, 134, 120), M.Cobblestone, "PilgrimPath")
path(PATH_B, 5, C3(140, 134, 120), M.Cobblestone, "SummitPath")
path({ { 50, 94 }, { 70, 88 }, { 90, 70 } }, 5, FLOOR_D, M.Ground, "Trail")
path({ { -16, 192 }, { -34, 192 } }, 4, FLOOR_D, M.Ground, "Trail")
path({ { -164, 62 }, { -170, 90 }, { -168, 118 }, { -146, 134 } }, 4.5, FLOOR_D, M.Ground, "Trail")
path({ { 116, 106 }, { 128, 112 }, { rbank(106, true) + 8, 112 } }, 4, FLOOR_D, M.Ground, "Trail")
end
do
for _, s in SITES do
sides(function(side)
local z = -s.a * side
local yaw = (side == 1) and s.yaw or (180 - s.yaw)
local o = CF(s.x, s.y, z) * ANG(0, rad(yaw), 0)
local k, op, w, d = s.kind, s.op, s.w, s.d
local sc = s.sc or 1
local m
local gbArgs
local function gbq(...) gbArgs = table.pack(...) end -- queued gbq(m, o, w, d, th, doorX, noStoop)
if k == "machiya" then
m = machiya(F.arch, o, w, d, op)
gbq(m, o, w, d, 0.7, op.doorX or -w * 0.2)
P.furnish("machiya", m, o, w, d, 1.1, op)
elseif k == "lodge" then
m = lodge(F.arch, o, w, d, op)
gbq(m, o, w, d, 0.9, op.doorX or 0)
P.furnish("lodge", m, o, w, d, 1.2, op)
elseif k == "shack" or k == "mill" then
m = shack(F.arch, o, w, d, op)
gbq(m, o, w, d, 0.7, op.doorX or 1.0)
P.furnish(k, m, o, w, d, 1.0, op)
if k == "mill" then
local ofs = d / 2 * sc + 6.5 -- the wheel hangs off the (now bigger) river-side wall
bx(F.arch, CF(s.x + ofs - 3.2, s.y, z), "WheelBracket", 6.4, 0.8, 0.8, 0, 3.1, 0, WEATHER_D, M.Wood)
waterwheel(F.arch, CF(s.x + ofs, 3.5, z), 6.5, 1.6)
cy(F.arch, CF(s.x + ofs + 4.4, 0, z), "WheelPier", 1.0, 6.8, 0, -3.4, 0, WEATHER_D, M.Wood)
end
elseif k == "kura" then
m = kura(F.arch, o, w, d, op)
gbq(m, o, w, d, 0.9, op.doorX or 0)
P.furnish("kura", m, o, w, d, 1.2, op)
elseif k == "teahouse" then
m = teahouse(F.arch, o, w, d, op)
gbq(m, o, w, d, 0, 0, true)
P.furnish("teahouse", m, o, w, d, 1.2, op)
elseif k == "hut" then
m = hut(F.arch, o, w, d)
gbq(m, o, w, d, 0.5, w * 0.12)
elseif k == "onsen" then
m = onsen(F.arch, o, w, d)
gbq(m, o, w, d, 0, 0, true)
elseif k == "hokora" then
m = hokora(F.arch, o)
gbq(m, o, 6, 6, 0, 0, true)
elseif k == "watchtower" then
m = watchtower(F.arch, o)
gbq(m, o, 9.5, 9.5, 0, 0, true)
elseif k == "haiden" then
m = haiden(F.arch, o)
gbq(m, o, 36, 14, 0, 0, true)
elseif k == "bell" then
m = bellTower(F.arch, o)
gbq(m, o, 11, 11, 0, 0, true)
elseif k == "pagoda" then
m = pagoda(F.arch, o)
gbq(m, o, 26, 26, 0, 0, true)
elseif k == "pavilion" then
m = pavilion(F.arch, o, w, d, 6.4, VERM)
gbq(m, o, w, d, 0, 0, true)
elseif k == "karesansui" then
m = karesansui(F.arch, o, w, d)
elseif k == "pond" then
m = pond(F.arch, o, w, d)
end
if m and sc ~= 1 then m.WorldPivot = o m:ScaleTo(sc) end
if m and gbArgs then P.groundBuilding(m, gbArgs[2], gbArgs[3] * sc, gbArgs[4] * sc, gbArgs[5] * sc, (gbArgs[6] or 0) * sc, gbArgs[7]) end
if m and op.name then m.Name = op.name end
end)
end
end
twin(function(f)
local function g(x, z, yaw, y) return f(x, z - 208, yaw, y) end -- the v1 shrine pieces, moved to the new Red end
niomon(F.arch, g(0, -100, 0))
haiden(F.arch, g(0, -152, 0))
torii(F.arch, g(0, -122, 0), 18, 16, "CourtyardTorii")
for _, sx in { -1, 1 } do
komainu(F.props, g(sx * 13, -137, sx * -20), 1.2)
lantern(F.props, g(sx * 6, -129, 0), 1.2, true)
lantern(F.props, g(sx * 25, -112, 0), 1.1, true)
lantern(F.props, g(sx * 25, -148, 0), 1.1, true)
tsuijibei(F.arch, g(sx * 36, -100, 0), 8.4, 5.4)
tsuijibei(F.arch, g(sx * 40.8, -140, 90), 36, 5.4)
tsuijibei(F.arch, g(sx * 40.8, -104.5, 90), 11, 5.4)
pavilion(F.arch, g(sx * 30, -138, 0), 8, 6, 6.4, VERM)
pine(F.trees, g(sx * 37, -128, 0), 9)
rock(F.props, g(sx * 36, -156, 0), 6, 4, 5)
jizo(F.props, g(sx * 12, -84, sx * 10))
end
tsuijibei(F.arch, g(0, -162, 0), 82.8, 5.4)
for i, z in { -64, -104, -144, -184, -224, -262 } do
torii(F.arch, f(0, z, 0), 11.5, 13.5, "AvenueTorii" .. i)
for _, sx in { -1, 1 } do lantern(F.props, f(sx * 8.2, z + 8, 0), 1.15, true) end
end
for z = -84, -250, -40 do
for _, sx in { -1, 1 } do lantern(F.props, f(sx * 9.4, z - 18, 0), 1.0, true) end
end
hondo(F.arch, f(-112, -88, 90))
end)
sides(function(s)
for _, sx in { -1, 1 } do
local kx = sx * 62
emaStand(F.props, pf(kx, 144, 0, s), 7)
lantern(F.props, pf(kx - 7, 126, 0, s), 1.0, true)
lantern(F.props, pf(kx + 7, 126, 0, s), 1.0, true)
jizo(F.props, pf(kx - 4, 120, 10, s))
jizo(F.props, pf(kx + 4, 120, -10, s))
rock(F.props, pf(kx + (sx == 1 and -14 or -16), 124, rng:NextInteger(0, 180), s), 5, 3.6, 4.6)
end
pine(F.trees, pf(-46, 104, 0, s), 9); pine(F.trees, pf(46, 104, 0, s), 8)
rock(F.props, pf(-22, 108, 20, s), 4, 3, 4); rock(F.props, pf(15, 78, 40, s), 4, 3, 4.4)
lantern(F.props, pf(-18, 88, 0, s), 1.0, true); lantern(F.props, pf(18, 88, 0, s), 1.0, true)
jizo(F.props, pf(-92, 150, 20, s)); jizo(F.props, pf(-80, 150, -20, s)); jizo(F.props, pf(-86, 140, 0, s))
lantern(F.props, pf(-96, 140, 0, s), 1.1, true); lantern(F.props, pf(-76, 140, 0, s), 1.1, true)
jizo(F.props, pf(94, 292, 15, s)); jizo(F.props, pf(106, 292, -15, s))
lantern(F.props, pf(92, 286, 0, s), 1.1, true); lantern(F.props, pf(108, 286, 0, s), 1.1, true)
torii(F.arch, pf(100, 279, 0, s), 16, 14, "StreetTorii")
torii(F.arch, pf(100, 51, 0, s), 16, 14, "StreetTorii")
end)
local function along(pts, spacing, fn)
local carry = 0
for i = 1, #pts - 1 do
local p, q = pts[i], pts[i + 1]
local dx, da = q[1] - p[1], q[2] - p[2]
local len = sqrt(dx * dx + da * da)
local pos = carry
while pos < len do
local t = pos / len
fn(p[1] + dx * t, p[2] + da * t, dx / len, da / len)
pos += spacing
end
carry = pos - len
end
end
-- v4 RED ARCHES (SenbonTorii) on the pilgrim paths. Owner: "you can barely fit under them" + "they clip into the mountain and the watch tower".
-- Now: bigger (SEN_W x SEN_H), the gate stands on the LOWER of its two feet (the higher foot is buried, nothing floats), and a gate is SKIPPED when
-- (a) it would stand inside / right next to any building (the summit tower), (b) the slope across the path is too steep, or (c) the ground pokes into
-- the doorway (needs 6.2 studs of headroom under the crossbeam).
local SEN_W, SEN_H = 8.8, 10.8 -- was 6.4 x 7.6
local senN, senSkipped = 0, 0
local senWhy = { building = 0, slope = 0, ground = 0 }
local function inSite(x, a, m)
for _, st in SITES do
if abs(x - st.x) < st.hx + m and abs(a - st.a) < st.ha + m then return true end
end
return false
end
sides(function(s)
for _, pts in { PATH_A, PATH_B } do
local k = 0
along(pts, 9.5, function(x, a, dx, da)
k += 1
if k < 3 then return end
if inSite(x, a, SEN_W / 2 + 3.5) then senSkipped += 1 return end
local z = -a * s
local th = atan2(dx, -da * s) -- local +Z of the gate runs along the path
local base = CF(x, 0, z) * ANG(0, th, 0)
local pl, pr = base * V3(-SEN_W / 2, 0, 0), base * V3(SEN_W / 2, 0, 0)
local hl, hr, hc = Hf(pl.X, pl.Z), Hf(pr.X, pr.Z), Hf(x, z)
local lo = min(hl, hr, hc)
if max(hl, hr, hc) - lo > SEN_H * 0.55 then senSkipped += 1 senWhy.slope += 1 return end
local cap = lo + SEN_H * 0.74 - 6.2
for _, lx in { -0.4, -0.2, 0, 0.2, 0.4 } do
for _, lz in { -1.2, 0, 1.2 } do
local q = base * V3(lx * SEN_W, 0, lz)
if Hf(q.X, q.Z) > cap + 0.8 then senSkipped += 1 senWhy.ground += 1 return end
end
end
senN += 1
local f = CF(x, lo - 0.25, z) * ANG(0, th, 0)
torii(F.arch, f, SEN_W, SEN_H, "SenbonTorii")
if k % 3 == 0 then
local side = (k % 6 == 0) and 1 or -1
local p = f * V3(side * (SEN_W / 2 + 2.4), 0, 0)
lantern(F.props, CF(p.X, Hf(p.X, p.Z), p.Z) * ANG(0, th, 0), 0.9, true)
end
end)
end
end)
if senSkipped > 0 then warnf("%d red arches built, %d skipped (%d next to a building, %d side slope too steep, %d ground poking into the doorway)", senN, senSkipped, senWhy.building, senWhy.slope, senWhy.ground) end
local function jettyAt(a, west, len)
local x = riverX(a) + (west and -22 or 22)
sides(function(s)
local z = -a * s
jetty(F.arch, CF(x, 0, z) * ANG(0, rad(west and 90 or -90), 0), len or 15, -3.4)
boat(F.props, CF(riverX(a) + (west and -9 or 9), -0.6, z + 4.5 * s) * ANG(0, rad(90), 0))
end)
end
sides(function(s)
for _, a in { 84, 132, 180, 228 } do
local z = -a * s
local pa, pb = V3(90.8, Hf(90.8, z) + 11.5, z), V3(109.2, Hf(109.2, z) + 11.5, z)
for _, p in { pa, pb } do cy(F.props, CF(p.X, Hf(p.X, z), z), "StringPole", 0.55, 11.6, 0, -0.2, 0, WOOD_D, M.Wood) end
P.stringLights(F.props, pa, pb, 2.4, 8)
end
for i, a in { 108, 156, 204, 252 } do
lantern(F.props, pf(i % 2 == 0 and 91.3 or 108.7, a, 0, s), 1.1, true)
end
P.vending(F.props, pf(92.2, 58.5, 90, s), C3(196, 44, 44))
P.vending(F.props, pf(107.8, 58.5, -90, s), C3(44, 96, 190))
P.rickshaw(F.props, pf(103.5, 92, -20, s))
P.rickshaw(F.props, pf(96, 214, 15, s))
P.laundry(F.props, pf(62, 166, 90, s), 12)
P.laundry(F.props, pf(46, 166, 90, s), 12)
P.koinobori(F.props, pf(91.5, 284, 0, s), 17)
P.koinobori(F.props, pf(108.5, 284, 0, s), 15)
P.neko(F.props, pf(104, 58.5, 0, s))
P.signpost(F.props, pf(-18, 160, 15, s))
P.signpost(F.props, pf(98, 55, -20, s))
P.signpost(F.props, pf(-96, 150, 30, s))
P.signpost(F.props, pf(-110, 190, 160, s))
P.campfire(F.props, pf(-184, 90, 0, s))
P.campfire(F.props, pf(-174, 134, 0, s))
P.campfire(F.props, pf(-208, 176, 0, s))
P.campfire(F.props, pf(rbank(120, true) + 9, 120, 0, s))
P.campfire(F.props, pf(rbank(197, false) - 9, 199, 0, s))
P.campfire(F.props, pf(-120, 224, 0, s))
P.well(F.props, pf(rbank(150, true) + 9, 156, 0, s))
P.well(F.props, pf(-148, 160, 0, s))
P.well(F.props, pf(86, 286, 0, s))
P.haystack(F.props, pf(-228, 172, 0, s)); P.haystack(F.props, pf(-232, 120, 0, s)); P.haystack(F.props, pf(rbank(298, false) + 9, 284, 0, s))
for _, p in { { 10.2, 120 }, { -10.2, 120 }, { 10.2, 236 }, { -10.2, 236 }, { 10.2, 280 }, { -10.2, 280 }, { 10.2, 66 }, { -10.2, 66 } } do
P.bench(F.props, pf(p[1], p[2], p[1] > 0 and 90 or -90, s), 6)
end
for _, a in { 296, 320, 344 } do lantern(F.props, pf(-58, a, 0, s), 1.2, true); lantern(F.props, pf(58, a, 0, s), 1.2, true) end
for _, x in { -60, -45, 60, 45, 140, -140, -208, 182 } do
rock(F.props, pf(x, 58 + (x % 3) * 3, rng:NextInteger(0, 180), s), 5, 3.2, 4.2)
lantern(F.props, pf(x + 8, 62, 0, s), 1.0, true)
end
for i = 1, 14 do
local a = rng:NextNumber(58, 110)
local x = riverX(a) + rng:NextNumber(-14, 14)
cy(F.fx, CF(x, 0, -a * s), "FloatLantern", 1.2, 0.5, 0, -0.9, 0, VERM_L, M.Neon, { deco = true, noshadow = true })
end
end)
jettyAt(120, true); jettyAt(184, true); jettyAt(246, true)
jettyAt(142, false); jettyAt(211, false); jettyAt(270, false)
for _, br in { { 86, 66, "Bridge_Lake" }, { 150, 46, "Bridge_Mid" }, { 214, 46, "Bridge_Broken", true }, { 278, 46, "Bridge_Mill" }, { 334, 42, "Bridge_Spring" } } do
sides(function(s)
bridge(F.arch, CF(riverX(br[1]), 0, -br[1] * s), br[2], 8, -3.4, { name = br[3], broken = br[4], color = br[4] and WEATHER or nil })
end)
end

------------------------------------------------------------------ v4 COVER in the big open middle (where the wall starts)
-- Owner: "scatter around some cover and wooden cover pieces for players to take cover behind in the big middle open area".
-- Everything stands on the flat middle pad (ground y = 0, |x| < 200, |z| < 46). Nothing is placed within 14 studs of the 3 box holes' lanes right at the
-- wall (z within 14 of the wall), nor on the avenue paving (|x| < 9). Each entry is for ONE quarter (x > 0, Red half); the code mirrors it to x < 0 and to the
-- Blue half. kinds: "wall" (len, height) wooden barricade | "stone" (len) plaster wall | "crates" (size) crate stack + barrels | "rock" (w, h, d) |
-- "hay" straw bales.   { kind, x, z, yaw (degrees), a, b, c }
local function crateBox(parent, o, x, yb, z, sz, yaw)
local c = bx(parent, o, "Crate", sz, sz, sz, x, yb, z, WOOD_L, M.WoodPlanks, nil, ANG(0, rad(yaw), 0))
bx(parent, o, "CrateBand", sz + 0.06, 0.2, sz + 0.06, x, yb + sz * 0.5 - 0.1, z, WOOD_D, M.Wood, DECO, ANG(0, rad(yaw), 0))
bx(parent, o, "CrateBrace", sz + 0.05, sz * 0.12, sz + 0.05, x, yb + sz * 0.2, z, WOOD, M.Wood, DECO, ANG(0, rad(yaw), 0))
return c
end
local function woodWall(parent, o, len, h)
local m = model("WoodBarricade", parent)
local nPost = max(2, floor(len / 3) + 1)
local step = (len - 1) / (nPost - 1)
for i = 0, nPost - 1 do bx(m, o, "Post", 0.9, h + 0.5, 0.9, -len / 2 + 0.5 + i * step, -0.1, 0, WOOD_D, M.Wood) end
local rows = max(2, floor(h / 1.15))
local bh = h / rows
for r = 0, rows - 1 do
local jit = (r % 2 == 0) and 0 or 0.35
bx(m, o, "Plank", len - 0.2 - jit, bh - 0.08, 0.45, jit / 2, r * bh + 0.04, 0.5, (r % 2 == 0) and WOOD or WOOD_L, M.WoodPlanks)
end
bx(m, o, "TopBeam", len + 0.3, 0.35, 1.2, 0, h + 0.1, 0.1, WOOD_D, M.Wood)
for _, sx in { -1, 1 } do -- rear braces (decoration only, they do not block)
beam(m, o, "Brace", V3(sx * (len / 2 - 0.5), 0, -2.6), V3(sx * (len / 2 - 0.5), h * 0.8, -0.5), 0.35, WOOD_D, M.Wood, DECO)
end
return m
end
local function crateStack(parent, o, sz)
local m = model("CrateStack", parent)
crateBox(m, o, -sz * 0.56, 0, 0, sz, 3)
crateBox(m, o, sz * 0.56, 0, 0, sz, -3)
crateBox(m, o, 0, sz, 0, sz, 5)
local bx0 = sz * 1.12 + 1.7 -- barrels stand beside the stack, clear of the crates
for i, dz in { -0.9, 1.2 } do
cy(m, o, "Barrel", 2.6, 3.2, bx0 + (i - 1) * 0.4, 0, dz * 1.2, WOOD, M.Wood)
cy(m, o, "BarrelBand", 2.7, 0.2, bx0 + (i - 1) * 0.4, 0.7, dz * 1.2, WEATHER_D, M.Metal, DECO)
cy(m, o, "BarrelBand", 2.7, 0.2, bx0 + (i - 1) * 0.4, 2.3, dz * 1.2, WEATHER_D, M.Metal, DECO)
end
return m
end
local function hayBales(parent, o)
local m = model("HayBales", parent)
for i = -1, 1 do cyh(m, o, "Bale", 3.2, 3.4, i * 3.4, 1.6, 0, "z", THATCH, M.Grass) end
for _, bxp in { -1.7, 1.7 } do cyh(m, o, "Bale", 3.2, 3.4, bxp, 4.31, 0, "z", THATCH_D, M.Grass) end
return m
end
local COVER_LIST = {
-- row A, close to the wall: full-height wooden barricades, a low one between them, short flank walls turned 90 degrees
{ "wall", 26, -15, 0, 9, 6.4 }, { "wall", 60, -15, 0, 9, 3.8 }, { "wall", 100, -15, 0, 9, 6.4 }, { "wall", 168, -15, 0, 9, 3.8 },
{ "wall", 42, -23, 90, 7, 6.4 }, { "wall", 116, -24, 90, 7, 6.4 }, { "wall", 147, -23, 90, 7, 3.8 },
-- row B: crate stacks with barrels
{ "crates", 18, -28, 0, 3.4 }, { "crates", 54, -29, 0, 3.4 }, { "crates", 90, -28, 0, 3.4 }, { "crates", 126, -29, 0, 3.4 }, { "crates", 160, -28, 0, 3.4 },
-- row C: plaster walls + boulders
{ "stone", 34, -36, 0, 12 }, { "stone", 80, -36, 0, 12 }, { "stone", 140, -36, 0, 12 }, { "stone", 180, -33, 0, 12 },
{ "rock", 63, -38, 20, 8, 6, 7 }, { "rock", 106, -38, 70, 8, 6, 7 }, { "rock", 168, -40, 0, 8, 6, 7 },
-- row D, far from the wall: low wooden walls + straw bales (mantle / crouch cover)
{ "wall", 17, -41, 0, 6, 3.8 }, { "wall", 44, -43, 0, 8, 3.8 }, { "wall", 96, -43, 0, 8, 3.8 }, { "wall", 190, -41, 0, 6, 3.8 },
{ "hay", 77, -43, 0 }, { "hay", 124, -43, 0 }, { "hay", 156, -43, 0 },
}
local COVER_R = { wall = 5, stone = 7, crates = 8, rock = 6, hay = 5 } -- rough clearance radius (used for the tree-free blocks + the overlap check)
local coverN = 0
twin(function(f)
for _, c in COVER_LIST do
for _, sx in { -1, 1 } do
local kind, x, z, yaw = c[1], c[2] * sx, c[3], c[4] * sx
local o = f(x, z, yaw)
if kind == "wall" then woodWall(F.cover, o, c[5], c[6])
elseif kind == "stone" then tsuijibei(F.cover, o, c[5], 6.2)
elseif kind == "crates" then crateStack(F.cover, o, c[5])
elseif kind == "rock" then rock(F.cover, o, c[5], c[6], c[7])
elseif kind == "hay" then hayBales(F.cover, o) end
coverN += 1
end
end
end)
for _, c in COVER_LIST do -- keep trees / scatter away from the cover
for _, sx in { -1, 1 } do
local r = COVER_R[c[1]]
addBlock(c[2] * sx - r, c[2] * sx + r, -c[3] - r, -c[3] + r)
end
end
do -- overlap check: cover against cover (rough circles) + the avenue paving + the wall lane
for i, c in COVER_LIST do
if abs(c[2]) - COVER_R[c[1]] < 9 then warnf("cover #%d (%s at x=%d) touches the avenue", i, c[1], c[2]) end
if abs(c[3]) - 2 < 14 and (abs(abs(c[2]) - 134) < 12) then warnf("cover #%d is in a box-hole lane", i) end
for j = i + 1, #COVER_LIST do
local d = COVER_LIST[j]
local dist = sqrt((c[2] - d[2]) ^ 2 + (c[3] - d[3]) ^ 2)
if dist < (COVER_R[c[1]] + COVER_R[d[1]]) * 0.6 then warnf("cover #%d (%s) and #%d (%s) are close (%.1f studs)", i, c[1], j, d[1], dist) end
end
end
end
local function inRiver(x, a) return riverW(x, a) > 0.002 or (abs(x - riverX(a)) < 24 and a > 44 and a < 352) end
local function freeSpot(x, a, r)
if abs(x) > HX - 3 or a > HZ - 3 then return false end
if inRiver(x, a) then return false end
for _, b in TERR.blocks do
if x > b[1] - r and x < b[2] + r and a > b[3] - r and a < b[4] + r then return false end
end
for _, pth in PATHS do
local pts = pth.pts
for i = 1, #pts - 1 do
local p, q = pts[i], pts[i + 1]
local dx, da = q[1] - p[1], q[2] - p[2]
local l2 = dx * dx + da * da
local t = clamp(((x - p[1]) * dx + (a - p[2]) * da) / l2, 0, 1)
local ex, ea = p[1] + dx * t - x, p[2] + da * t - a
if ex * ex + ea * ea < (pth.w / 2 + r) ^ 2 then return false end
end
end
return abs(x - 100) > 12 + r or a < 56 or a > 300
end
local placed = {}
local function spaced(x, a, r)
for _, p in placed do if (p[1] - x) ^ 2 + (p[2] - a) ^ 2 < r * r then return false end end
return true
end
local function scatter(count, x0, x1, a0, a1, minDist, clearR, okfn, make)
local n = 0
for _ = 1, floor(count * DENSITY) * 12 do
if n >= floor(count * DENSITY) then break end
local x, a = rng:NextNumber(x0, x1), rng:NextNumber(a0, a1)
if freeSpot(x, a, clearR) and spaced(x, a, minDist) then
local h = Hf(x, -a)
local ny = TERR.normalY(x, -a)
if okfn(x, a, h, ny) then
placed[#placed + 1] = { x, a }
n += 1
make(x, a, h)
end
end
end
return n
end
local FIRS = { { FIR, FIR_L }, { C3(60, 96, 64), C3(80, 120, 74) }, { C3(40, 84, 58), C3(62, 108, 70) } }
sides(function(s)
scatter(230, -236, -72, 52, 376, 9.5, 5, function(x, a, h, ny) return ny > 0.76 and h < 62 end, function(x, a, h)
local pal = FIRS[rng:NextInteger(1, 3)]
conifer(F.trees, x, h, -a * s, rng:NextNumber(18, 34), rng, pal[1], pal[2])
end)
scatter(180, -236, -72, 80, 376, 8, 4, function(x, a, h, ny) return ny > 0.62 and h >= 40 and h < 104 end, function(x, a, h)
P.cheapPine(F.trees, x, h, -a * s, rng:NextNumber(16, 28), FIR, FIR_L)
end)
scatter(70, 135, 236, 52, 376, 9, 5, function(x, a, h, ny) return ny > 0.72 and h > 1 end, function(x, a, h)
local pal = FIRS[rng:NextInteger(1, 3)]
conifer(F.trees, x, h, -a * s, rng:NextNumber(16, 28), rng, pal[1], pal[2])
end)
scatter(150, -236, 236, 52, 380, 8.5, 3, function(x, a, h, ny) return (abs(x) > HX - 52 or a > HZ - 52) and h > 3 and ny > 0.5 end, function(x, a, h)
P.cheapPine(F.trees, x, h, -a * s, rng:NextNumber(20, 34), CEDAR, CEDAR_L)
end)
scatter(32, -66, 76, 54, 290, 12, 6, function(x, a, h, ny) return abs(x) > 17 and ny > 0.85 end, function(x, a, h)
local pal = (rng:NextInteger(1, 4) == 1) and GINKGO or MAPLE
maple(F.trees, x, -a * s, rng:NextNumber(13, 19), rng, pal, h)
for _ = 1, 5 do
local an, r = rng:NextNumber(0, 6.28), rng:NextNumber(2, 10)
local lx, lz = x + cos(an) * r, -a * s + sin(an) * r
if TERR.normalY(lx, lz) > 0.95 then cy(F.detail, CFrame.identity, "Leaf", rng:NextNumber(0.5, 1.0), 0.04, lx, Hf(lx, lz) + 0.08, lz, MAPLE[rng:NextInteger(1, #MAPLE)], M.Fabric, NOSH) end
end
end)
for _, k in { { -62, 130 }, { 62, 130 }, { 60, 266 }, { -62, 262 } } do
scatter(9, k[1] - 28, k[1] + 28, k[2] - 24, k[2] + 24, 8, 4, function(x, a, h, ny) return ny > 0.8 and abs(x) > 17 end, function(x, a, h)
P.sakura(F.trees, x, -a * s, rng:NextNumber(13, 18), rng, h)
end)
end
scatter(14, 90, 125, 300, 332, 9, 4, function(x, a, h, ny) return ny > 0.8 end, function(x, a, h) P.sakura(F.trees, x, -a * s, rng:NextNumber(12, 17), rng, h) end)
scatter(6, -52, 52, 70, 120, 14, 8, function(x, a, h, ny) return abs(x) > 17 end, function(x, a, h) pine(F.trees, CF(x, h, -a * s) * ANG(0, rad(rng:NextInteger(0, 359)), 0), rng:NextNumber(8, 11)) end)
scatter(34, 122, 236, 60, 346, 11, 5, function(x, a, h, ny) return ny > 0.85 and h > -0.5 end, function(x, a, h)
bamboo(F.trees, x, -a * s, h, rng:NextInteger(8, 13), rng:NextNumber(2.2, 3.4))
end)
scatter(10, -236, -70, 60, 200, 11, 5, function(x, a, h, ny) return ny > 0.85 end, function(x, a, h) bamboo(F.trees, x, -a * s, h, rng:NextInteger(8, 12), rng:NextNumber(2.2, 3.2)) end)
scatter(60, -236, 236, 52, 376, 18, 6, function(x, a, h, ny) return h > 1 and ny > 0.55 end, function(x, a, h)
rock(F.props, CF(x, h - 0.4, -a * s) * ANG(0, rad(rng:NextInteger(0, 180)), 0), rng:NextNumber(4, 8), rng:NextNumber(3, 6), rng:NextNumber(4, 8))
end)
scatter(110, -230, 230, 50, 370, 9, 3, function(x, a, h, ny) return ny > 0.99 and h > -0.2 and h < 0.4 end, function(x, a, h)
local c = ({ MOSS, MOSS_D, FLOOR_D, C3(104, 122, 74) })[rng:NextInteger(1, 4)]
cy(F.detail, CFrame.identity, "Patch", rng:NextNumber(4, 12), 0.06, x, h + 0.04, -a * s, c, M.Grass, NOSH)
end)
end)
do
local forestN, cragN = 0, 0
for _ = 1, floor(2600 * DENSITY) do
local x, z = rng:NextNumber(-470, 470), rng:NextNumber(-640, 640)
local a = abs(z)
local s = max(abs(x) - HX, a - HZ)
if s > 4 and s < 190 then
local h = Hf(x, z)
local ny = TERR.normalY(x, z)
if ny > 0.62 and h < 108 and forestN < 700 * DENSITY and spaced(x, a, 10) then
placed[#placed + 1] = { x, a }
forestN += 1
P.cheapPine(F.mountains, x, h, z, rng:NextNumber(26, 46), (rng:NextInteger(1, 2) == 1) and CEDAR or FIR_D, (rng:NextInteger(1, 2) == 1) and CEDAR_L or FIR)
end
end
end
for _ = 1, floor(900 * DENSITY) do
local x, z = rng:NextNumber(-520, 520), rng:NextNumber(-700, 700)
local s = max(abs(x) - HX, abs(z) - HZ)
if s > 6 and s < 260 and cragN < 70 * DENSITY then
local h = Hf(x, z)
if h > 60 then
cragN += 1
P.crag(F.mountains, x, h - 1.5, z, rng:NextNumber(10, 20), (h > 130) and C3(190, 196, 204) or STONE_D)
end
end
end
for _ = 1, floor(120 * DENSITY) do
local x, z = rng:NextNumber(-HX + 3, HX - 3), rng:NextNumber(-HZ + 3, HZ - 3)
local a = abs(z)
if a > 52 and max(abs(x) - HX, a - HZ) > -22 and freeSpot(abs(x) < 70 and 999 or x, a, 1) then
local h = Hf(x, z)
if h > 14 then P.crag(F.props, x, h - 1.4, z, rng:NextNumber(6, 11), STONE_D) end
end
end
end
for _, team in { { "RedSpawn", -340 }, { "BlueSpawn", 340 } } do
for _, x in { -20, 0, 20 } do
local p = Instance.new("Part")
p.Name = team[1]
p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
p.Transparency = 1
p.Size = V3(6, 1, 6)
p.CFrame = CF(x, 0.5, team[2])
p.Parent = F.spawns
end
end
local bounds = Instance.new("Part")
bounds.Name = "MapBounds"
bounds.Anchored, bounds.CanCollide, bounds.CanQuery, bounds.CanTouch = true, false, false, false
bounds.Transparency = 1
bounds.Size = V3(W, H, L)
bounds.CFrame = CF(0, H / 2, 0)
bounds.Parent = map
do
local worst = 0
for _, s in SITES do
local lo, hi = 1e9, -1e9
for i = -1, 1 do for j = -1, 1 do
local h = Hf(s.x + i * (s.hx - 3), -(s.a + j * (s.ha - 3)))
lo, hi = min(lo, h), max(hi, h)
end end
if s.y - lo > 4.5 then warnf("%s at (%.0f, %.0f): plinth %.1f studs tall (steep spot)", tostring(s.op.name or s.kind), s.x, s.a, s.y - lo) end
if hi - s.y > 0.9 then warnf("%s at (%.0f, %.0f): ground pokes %.1f above the floor", tostring(s.op.name or s.kind), s.x, s.a, hi - s.y) end
end
end
if DEBUG_HMAP then
local hdr = "a\\x  "
for x = -240, 240, 20 do hdr = hdr .. string.format("%5d", x) end
print(hdr)
for a = 20, 380, 20 do
local row = string.format("%4d ", a)
for x = -240, 240, 20 do row = row .. string.format("%5.0f", TERR.baseNoPads(x, a)) end
print(row)
end
end
if DEBUG_SITES then
for _, s in SITES do
local lo, hi = 1e9, -1e9
for i = -1, 1 do for j = -1, 1 do
local h = Hf(s.x + i * (s.hx - 3), -(s.a + j * (s.ha - 3)))
lo, hi = min(lo, h), max(hi, h)
end end
print(string.format("SITE %-18s %-10s x=%6.1f a=%6.1f y=%5.1f lo=%5.1f hi=%5.1f", tostring(s.op.name or ""), s.kind, s.x, s.a, s.y, lo, hi))
for pi_, pth in PATHS do
local pts = pth.pts
for i = 1, #pts - 1 do
local p, q = pts[i], pts[i + 1]
local dx, da = q[1] - p[1], q[2] - p[2]
local l2 = dx * dx + da * da
local t = clamp(((s.x - p[1]) * dx + (s.a - p[2]) * da) / l2, 0, 1)
local ex, ea = p[1] + dx * t - s.x, p[2] + da * t - s.a
if abs(ex) < s.hx + pth.w / 2 - 1 and abs(ea) < s.ha + pth.w / 2 - 1 then print("   PATH CROSSES", pi_, s.op.name or s.kind) break end
end
end
end
end
map.Parent = bl
print(string.format("[KyotoDistrict v4] %d cover pieces in the middle, %d red arches on the paths.", coverN, senN))
print(string.format("[KyotoDistrict v4] done: %d parts (%d terrain triangles). Map is in ServerStorage > breaklineMaps > kyotodistrict_map", count, INNER_TRIS))
