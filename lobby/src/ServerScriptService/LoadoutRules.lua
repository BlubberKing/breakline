-- LoadoutRules (ModuleScript in ServerScriptService, named "LoadoutRules") - BOTH places, keep the two copies identical. NEW in v4.7 (shop). v5.11: no duplicate gadgets / reserve items. v5.16: a gadget can not be in a gadget slot AND the reserve. v5.18: a gun can not be the PRIMARY and in the reserve.
-- The one place that decides what a saved loadout may contain:
--   * every id must be a real catalog item of the right kind (as before)
--   * and the player must OWN it (bought in the shop / given as starter gear). Until a player made the starter pick (StarterDone) nothing is
--     filtered, so old saves and Studio tests keep working; the lobby will not let them queue before the pick anyway.
-- Used by LobbyServer (SetLoadout), ShopServer (buy / starter pick) and Breakline's MatchServer (pre-game loadout change).
--   Rules.Owns(player, id)          -> bool
--   Rules.Give(player, { ids })     -> adds items to the collection (saved)
--   Rules.Clean(player, loadout)    -> a loadout table that is safe to save / play with
--   Rules.Publish(player, loadout)  -> sets the LoadoutJson attribute everybody reads
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))

local R = {}

local function ownedSet(player)
	local set = {}
	local list = Profiles.Get(player, "Owned")
	if type(list) == "table" then for _, id in list do set[id] = true end end
	return set
end

function R.Owns(player, id)
	if Profiles.Get(player, "StarterDone") ~= true then return true end
	return ownedSet(player)[id] == true
end

function R.Give(player, ids)
	local list = Profiles.Get(player, "Owned")
	if type(list) ~= "table" then return end
	local set = ownedSet(player)
	local new = table.clone(list)
	for _, id in ids do
		if Catalog.Is(id) and not set[id] then
			set[id] = true
			table.insert(new, id)
		end
	end
	Profiles.Set(player, "Owned", new)
end

function R.Clean(player, l)
	l = type(l) == "table" and l or {}
	local out = { Gadgets = {}, Reserve = {} }
	local function ok(id, kind) return Catalog.Is(id, kind) and R.Owns(player, id) end
	out.Weapon = ok(l.Weapon, "weapon") and l.Weapon or nil
	if not out.Weapon then
		-- not allowed to use that gun: fall back to the first gun they own (the default gun when they own none)
		out.Weapon = Catalog.DefaultWeapon
		for _, w in Catalog.Weapons do
			if R.Owns(player, w.id) then out.Weapon = w.id break end
		end
	end
	out.Move = ok(l.Move, "move") and l.Move or ""
	for i = 1, 3 do
		local g = type(l.Gadgets) == "table" and l.Gadgets[i]
		out.Gadgets[i] = ok(g, "gadget") and g or ""
		local r = type(l.Reserve) == "table" and l.Reserve[i]
		out.Reserve[i] = ((Catalog.Is(r, "gadget") or Catalog.Is(r, "weapon")) and R.Owns(player, r)) and r or ""
	end
	-- v5.11: no item twice - the same gadget in two gadget slots, or the same item in two RESERVE slots, is cleared (the first one stays).
	-- (The Breakline pre-game picker let you fill all three reserve slots with one item; the lobby already swapped them.)
	for _, arr in { out.Gadgets, out.Reserve } do
		local seen = {}
		for i = 1, 3 do
			if arr[i] ~= "" then
				if seen[arr[i]] then arr[i] = "" else seen[arr[i]] = true end
			end
		end
	end
	-- v5.16: an item is EITHER a gadget OR in the reserve, never both (owner). A gadget that sits in a gadget slot is taken out of the reserve.
	for i = 1, 3 do
		if out.Reserve[i] ~= "" and table.find(out.Gadgets, out.Reserve[i]) then out.Reserve[i] = "" end
	end
	-- v5.18: a gun is EITHER your PRIMARY OR in the reserve, never both (owner). The primary wins.
	for i = 1, 3 do
		if out.Reserve[i] ~= "" and out.Reserve[i] == out.Weapon then out.Reserve[i] = "" end
	end
	return out
end

function R.Publish(player, l)
	player:SetAttribute("LoadoutJson", HttpService:JSONEncode(l))
end

return R
