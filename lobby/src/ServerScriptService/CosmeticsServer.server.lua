-- CosmeticsServer v1 (Script in ServerScriptService) - LOBBY place only. NEW in v5.10.
-- BUYING + EQUIPPING for the cosmetics shop / locker. The client only ASKS; everything is checked here.
--   Remotes (made here, folder ReplicatedStorage.CosmeticsRemotes, both RemoteFunctions):
--     Buy(kind, id)            kind = "skin" (a player skin edition) | "gun" (a gun skin).  -> ok, message
--         real item with a price, not owned yet, enough of ITS currency. Souls come off with Profiles.Increment; Essence ONLY through Profiles.SpendEssence
--         (written to the DataStore right away, returns true only when it is saved), then the item is added to the saved collection and saved at once.
--     Equip(kind, id, gunId)   kind = "skin": wear skin `id` (must be owned; the 3 base skins are always owned).
--                              kind = "gun": paint gun skin `id` on its gun (must be owned); id = "" takes the skin off gunId (back to stock).  -> ok, message
-- Saved in the shared profile: SkinsOwned (list), GunSkinsOwned (list), GunSkinEquipped ({ [gunId] = skinId }), Skin (the worn skin). ProfileStore mirrors them to
-- the Player attributes SkinsOwnedJson / GunSkinsOwnedJson / GunSkinsJson / Skin, which both places read (Breakline paints your gun with GunSkinsJson).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Cat = require(RS:WaitForChild("CosmeticsCatalog"))
local Skins = require(RS:WaitForChild("Skins"))
local GunSkins = require(RS:WaitForChild("GunSkins"))
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))

local folder = RS:FindFirstChild("CosmeticsRemotes") or Instance.new("Folder")
folder.Name = "CosmeticsRemotes"
folder.Parent = RS
local function remote(name)
	local r = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
	r.Name = name
	r.Parent = folder
	return r
end
local BuyR, EquipR = remote("Buy"), remote("Equip")

local busy, lastCall = {}, {}
local function loaded(player) return Profiles.Get(player, "Loadout") ~= nil end

local function appendOwned(player, key, id)
	local list = table.clone(Profiles.Get(player, key) or {})
	if not table.find(list, id) then table.insert(list, id) end
	Profiles.Set(player, key, list)
end

BuyR.OnServerInvoke = function(player, kind, id)
	if busy[player] then return false, "One moment." end
	if os.clock() - (lastCall[player] or 0) < 0.4 then return false, "Slow down." end
	lastCall[player] = os.clock()
	if (kind ~= "skin" and kind ~= "gun") or type(id) ~= "string" then return false, "Unknown item." end
	local item = Cat.Find(kind, id)
	if not item or not item.currency then return false, "That item is not for sale." end
	if not loaded(player) then return false, "Your data is still loading." end
	local owned = (kind == "skin") and Cat.OwnsSkin(player, id) or Cat.OwnsGunSkin(player, id)
	if owned then return false, "You already own this." end

	busy[player] = true
	local ok, msg = false, "Could not complete the purchase."
	local done, err = pcall(function()
		if item.currency == "souls" then
			local souls = Profiles.Get(player, "Souls")
			if type(souls) ~= "number" or souls < item.amount then ok, msg = false, "Not enough souls." return end
			Profiles.Increment(player, "Souls", -item.amount)
		else
			if (player:GetAttribute("Essence") or 0) < item.amount then ok, msg = false, "Not enough essence." return end
			if not Profiles.SpendEssence(player, item.amount) then ok, msg = false, "Not enough essence." return end -- saved to the DataStore before it returns true
		end
		appendOwned(player, kind == "skin" and "SkinsOwned" or "GunSkinsOwned", id)
		task.spawn(Profiles.Save, player) -- written right away, so a crash or a teleport can never lose a purchase
		ok, msg = true, "Bought " .. item.name .. (item.sub and ("  -  " .. item.sub) or "") .. "."
	end)
	busy[player] = nil
	if not done then warn("[CosmeticsServer] purchase error:", err) return false, "Could not complete the purchase." end
	return ok, msg
end

EquipR.OnServerInvoke = function(player, kind, id, gunId)
	if os.clock() - (lastCall[player] or 0) < 0.15 then return false, "Slow down." end
	lastCall[player] = os.clock()
	if not loaded(player) then return false, "Your data is still loading." end
	if kind == "skin" then
		if type(id) ~= "string" or not Skins.Is(id) then return false, "Unknown skin." end
		if not Cat.OwnsSkin(player, id) then return false, "You do not own this skin." end
		Profiles.Set(player, "Skin", id)
		task.spawn(Profiles.Save, player)
		return true, "Equipped " .. Skins.Get(id).name .. "."
	elseif kind == "gun" then
		if type(id) ~= "string" then return false, "Unknown gun skin." end
		local map = table.clone(Profiles.Get(player, "GunSkinEquipped") or {})
		if id == "" then
			if type(gunId) ~= "string" or not GunSkins.GunNames[gunId] then return false, "Unknown gun." end
			map[gunId] = nil
			Profiles.Set(player, "GunSkinEquipped", map)
			task.spawn(Profiles.Save, player)
			return true, GunSkins.GunNames[gunId] .. " is back to stock."
		end
		local s = GunSkins.ById[id]
		if not s then return false, "Unknown gun skin." end
		if not Cat.OwnsGunSkin(player, id) then return false, "You do not own this gun skin." end
		map[s.gun] = id
		Profiles.Set(player, "GunSkinEquipped", map)
		task.spawn(Profiles.Save, player)
		return true, s.name .. " is on your " .. s.gunName .. "."
	end
	return false, "Unknown request."
end

-- clean the saved equipped map once the profile is in: a skin that is no longer owned / no longer exists must not stay painted on a gun
Players.PlayerAdded:Connect(function(p)
	task.spawn(function()
		local d = Profiles.WaitFor(p)
		if not d then return end
		local map = Profiles.Get(p, "GunSkinEquipped")
		if type(map) ~= "table" then return end
		local clean, changed = {}, false
		for gun, id in map do
			if type(id) == "string" and GunSkins.ById[id] and GunSkins.ById[id].gun == gun and Cat.OwnsGunSkin(p, id) then clean[gun] = id else changed = true end
		end
		if changed then Profiles.Set(p, "GunSkinEquipped", clean) end
		local worn = Profiles.Get(p, "Skin")
		if type(worn) == "string" and not Cat.OwnsSkin(p, worn) then Profiles.Set(p, "Skin", Skins.Default) end -- (an edition that is not owned falls back to OPERATOR)
	end)
end)

Players.PlayerRemoving:Connect(function(p) busy[p], lastCall[p] = nil, nil end)
