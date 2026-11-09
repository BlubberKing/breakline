-- Titles v1 (ModuleScript in ReplicatedStorage, named "Titles") - LOBBY place only. NEW in v5.16 (GDD 5.11).
-- TITLES: a short line of text that sits ABOVE your name in the lobby (LobbyNameplates) and, if you want, on your PLAYER CARD (above your name).
-- Bought in the cosmetics shop (TITLES tab), equipped in the cosmetics locker (TITLES tab). Saved in the profile: Title (the equipped id, "" = none)
-- and TitlesOwned (bought ids); mirrored as the Player attributes Title / TitlesOwnedJson.
--   Titles.List / Titles.ById[id] / Titles.Order     { id, text, color, price = nil (free) | { souls = n } | { essence = n }, tier }
--   Titles.Is(id) / Titles.IsFree(id) / Titles.Owns(player, id) / Titles.Owned(player)
--   Titles.Of(player) -> title entry or nil          the title a player wears (attribute Title)
--   Titles.Plate(parent, id, height) -> frame        a small styled plate with the title text (shop / locker pictures)
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local T = {}
local rgb = Color3.fromRGB
-- tiers only decide the colour + the little frame of the text
T.TierColor = { free = rgb(214, 218, 226), souls = rgb(130, 206, 255), essence = rgb(206, 150, 255), gold = rgb(255, 210, 110) }

T.List = {
	{ id = "rookie", text = "ROOKIE", tier = "free" },
	{ id = "first_blood", text = "FIRST BLOOD", tier = "free" },
	{ id = "box_thief", text = "BOX THIEF", tier = "souls", price = { souls = 400 } },
	{ id = "wall_breaker", text = "WALL BREAKER", tier = "souls", price = { souls = 600 } },
	{ id = "soul_collector", text = "SOUL COLLECTOR", tier = "souls", price = { souls = 800 } },
	{ id = "sharpshooter", text = "SHARPSHOOTER", tier = "souls", price = { souls = 1000 } },
	{ id = "the_line", text = "THE LINE", tier = "essence", price = { essence = 150 } },
	{ id = "voidwalker", text = "VOIDWALKER", tier = "essence", price = { essence = 250 } },
	{ id = "unbreakable", text = "UNBREAKABLE", tier = "gold", price = { essence = 400 } },
}
T.ById, T.Order = {}, {}
for _, t in T.List do
	t.color = T.TierColor[t.tier] or T.TierColor.free
	T.ById[t.id] = t
	table.insert(T.Order, t.id)
end

function T.Is(id) return type(id) == "string" and T.ById[id] ~= nil end
function T.IsFree(id) local t = T.ById[id] return t ~= nil and t.price == nil end
local function ownedList(player)
	local raw = player and player:GetAttribute("TitlesOwnedJson")
	local ok, t = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw ~= "" and raw or "[]")
	return (ok and type(t) == "table") and t or {}
end
function T.Owns(player, id)
	if not T.Is(id) then return false end
	if T.IsFree(id) then return true end
	return table.find(ownedList(player), id) ~= nil
end
function T.Owned(player)
	local list, out = ownedList(player), {}
	for _, id in T.Order do if T.IsFree(id) or table.find(list, id) then table.insert(out, id) end end
	return out
end
function T.Of(player)
	local id = player and player:GetAttribute("Title")
	return T.ById[id]
end

-- a small plate with the title (used for the shop / locker pictures). height = plate height in pixels; the text is centred.
function T.Plate(parent, id, height)
	local t = T.ById[id]
	local UI = require(RS:WaitForChild("UIKit"))
	local new, F = UI.new, UI.F
	height = height or 60
	local col = t and t.color or T.TierColor.free
	local f = new("Frame", { Name = "TitlePlate", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.86, 0, 0, height),
		BackgroundColor3 = rgb(10, 11, 15), BackgroundTransparency = 0.1, BorderSizePixel = 0 }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, f)
	new("UIStroke", { Color = col, Thickness = 1.5, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(34, 36, 46), rgb(10, 11, 15)) }, f)
	-- two small ticks either side of the text
	for _, x in { 0.08, 0.92 } do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromOffset(math.max(5, height * 0.12), math.max(5, height * 0.12)),
			Rotation = 45, BackgroundColor3 = col, BorderSizePixel = 0 }, f)
	end
	local l = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0), Position = UDim2.fromScale(0.1, 0), Text = t and t.text or "NO TITLE",
		TextScaled = true, FontFace = F.H, TextColor3 = col }, f)
	new("UITextSizeConstraint", { MaxTextSize = math.floor(height * 0.55) }, l)
	return f
end

return T
