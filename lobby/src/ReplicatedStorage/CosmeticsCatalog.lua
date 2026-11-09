-- CosmeticsCatalog v3 (ModuleScript in ReplicatedStorage) - LOBBY place only. NEW in v5.10. v5.11: player card BANNERS (kind "banner", from PlayerCards) + colourway helpers.
-- v5.16: POSES (kind "pose", from Poses) and TITLES (kind "title", from Titles) are sold too; Cat.OwnsPose / OwnsTitle / OwnedPoses / OwnedTitles.
-- One list of everything the cosmetics shop sells + the ownership helpers, used by CosmeticsServer (checks every purchase / equip) and CosmeticsClient (the shop + the locker).
-- Data lives in the two cosmetic modules: Skins (player skin EDITIONS, `price`) and GunSkins (gun skins, `price`). A price is { souls = n } (free currency) or { essence = n } (premium).
--   Cat.Items(kind)       kind = "skin" | "gun"  -> { { kind, id, name, sub, gun?, price, currency = "souls" | "essence", amount, card? ... } ... }  sorted cheapest first
--   Cat.Find(kind, id)    -> the item or nil
--   Cat.OwnsSkin(player, id) / Cat.OwnsGunSkin(player, id)    (free items count as owned; the rest come from the profile via the SkinsOwnedJson / GunSkinsOwnedJson attributes)
--   Cat.OwnedSkins(player) -> list of Skins ids you can wear   Cat.OwnedGunSkins(player) -> list of GunSkins ids you own
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Skins = require(RS:WaitForChild("Skins"))
local GunSkins = require(RS:WaitForChild("GunSkins"))
local PlayerCards = require(RS:WaitForChild("PlayerCards")) -- v5.11
local Poses = require(RS:WaitForChild("Poses"))   -- v5.16
local Titles = require(RS:WaitForChild("Titles")) -- v5.16

local Cat = {}

local function currencyOf(price)
	if price and price.essence then return "essence", price.essence end
	if price and price.souls then return "souls", price.souls end
	return nil, 0
end

local function skinItem(s)
	local cur, amt = currencyOf(s.price)
	return { kind = "skin", id = s.id, name = s.name, sub = s.sub, desc = s.desc, base = s.base or s.id, card = s.card, price = s.price, currency = cur, amount = amt }
end
local function gunItem(s)
	local cur, amt = currencyOf(s.price)
	return { kind = "gun", id = s.id, name = s.name, sub = s.sub, gun = s.gun, gunName = s.gunName, theme = s.theme, glow = s.glow, price = s.price, currency = cur, amount = amt }
end

local function bannerItem(b)
	local cur, amt = currencyOf(b.price)
	return { kind = "banner", id = b.id, name = b.name, anim = b.anim, price = b.price, currency = cur, amount = amt }
end

local function poseItem(p) -- v5.16
	local cur, amt = currencyOf(p.price)
	return { kind = "pose", id = p.id, name = p.name, anim = p.anim, price = p.price, currency = cur, amount = amt }
end
local function titleItem(t) -- v5.16
	local cur, amt = currencyOf(t.price)
	return { kind = "title", id = t.id, name = t.text, tier = t.tier, color = t.color, price = t.price, currency = cur, amount = amt }
end

local function sorted(list)
	table.sort(list, function(a, b)
		if a.amount ~= b.amount then return a.amount < b.amount end
		return a.id < b.id
	end)
	return list
end

Cat.byKind = { skin = {}, gun = {}, banner = {}, pose = {}, title = {} }
do
	local sk, gu, ba, po, ti = {}, {}, {}, {}, {}
	for _, s in Skins.List do
		if s.price then
			local it = skinItem(s)
			table.insert(sk, it)
			Cat.byKind.skin[s.id] = it
		end
	end
	for _, s in GunSkins.List do
		local it = gunItem(s)
		table.insert(gu, it)
		Cat.byKind.gun[s.id] = it
	end
	for _, b in PlayerCards.Banners do
		local it = bannerItem(b)
		Cat.byKind.banner[b.id] = it
		if b.price then table.insert(ba, it) end
	end
	for _, p in Poses.List do -- v5.16
		local it = poseItem(p)
		Cat.byKind.pose[p.id] = it
		if p.price then table.insert(po, it) end
	end
	for _, t in Titles.List do
		local it = titleItem(t)
		Cat.byKind.title[t.id] = it
		if t.price then table.insert(ti, it) end
	end
	Cat.lists = { skin = sorted(sk), gun = sorted(gu), banner = sorted(ba), pose = sorted(po), title = sorted(ti) }
end

function Cat.Items(kind) return Cat.lists[kind] or {} end
function Cat.Find(kind, id) return Cat.byKind[kind] and Cat.byKind[kind][id] or nil end

local function setFrom(player, attr)
	local raw = player:GetAttribute(attr)
	local set = {}
	local ok, t = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw or "[]")
	if ok and type(t) == "table" then for _, id in t do set[id] = true end end
	return set
end

function Cat.OwnsSkin(player, id)
	if not Skins.Is(id) then return false end
	if Skins.IsFree(id) then return true end
	return setFrom(player, "SkinsOwnedJson")[id] == true
end
function Cat.OwnsGunSkin(player, id)
	if not GunSkins.Is(id) then return false end
	return setFrom(player, "GunSkinsOwnedJson")[id] == true
end
function Cat.OwnedSkins(player)
	local set, out = setFrom(player, "SkinsOwnedJson"), {}
	for _, id in Skins.Order do
		if Skins.IsFree(id) or set[id] then table.insert(out, id) end
	end
	return out
end
function Cat.OwnedGunSkins(player)
	local set, out = setFrom(player, "GunSkinsOwnedJson"), {}
	for _, s in GunSkins.List do
		if set[s.id] then table.insert(out, s.id) end
	end
	return out
end

-- v5.11 player card backgrounds
function Cat.OwnsBanner(player, id)
	if not PlayerCards.Is(id) then return false end
	if PlayerCards.IsFree(id) then return true end
	return setFrom(player, "BannersOwnedJson")[id] == true
end
function Cat.OwnedBanners(player)
	local set, out = setFrom(player, "BannersOwnedJson"), {}
	for _, id in PlayerCards.Order do
		if PlayerCards.IsFree(id) or set[id] then table.insert(out, id) end
	end
	return out
end
-- v5.11 colourways: the base skins (no `base`), and every edition of one base skin
function Cat.BaseSkins()
	local out = {}
	for _, id in Skins.Order do if not Skins.Get(id).base then table.insert(out, id) end end
	return out
end
function Cat.Colourways(baseId)
	local out = {}
	for _, id in Skins.Order do
		if Skins.Get(id).base == baseId then table.insert(out, id) end
	end
	return out
end
function Cat.BaseOf(id) local s = Skins.Get(id); return s.base or s.id end

-- v5.16 poses + titles
function Cat.OwnsPose(player, id) return Poses.Owns(player, id) end
function Cat.OwnedPoses(player) return Poses.Owned(player) end
function Cat.OwnsTitle(player, id) return Titles.Owns(player, id) end
function Cat.OwnedTitles(player) return Titles.Owned(player) end

return Cat
