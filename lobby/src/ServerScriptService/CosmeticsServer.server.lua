-- CosmeticsServer v2 (Script in ServerScriptService) - LOBBY place only. NEW in v5.10.
-- v5.11: player card BANNERS can be bought (Buy("banner", id)) and the PLAYER CARD is saved here:
--     Equip("card", bannerId)              background of your lobby player card (must be free or owned)
--     Equip("show", slot 1..3, value)      a showcase slot: "skin:<Skins id>" / "gun:<GunSkins id>" / "card:<Cards id>" (must be owned) or "" = empty
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
local PlayerCards = require(RS:WaitForChild("PlayerCards")) -- v5.11
local Cards = require(RS:WaitForChild("Cards"))

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
	if (kind ~= "skin" and kind ~= "gun" and kind ~= "banner") or type(id) ~= "string" then return false, "Unknown item." end
	local item = Cat.Find(kind, id)
	if not item or not item.currency then return false, "That item is not for sale." end
	if not loaded(player) then return false, "Your data is still loading." end
	local owned
	if kind == "skin" then owned = Cat.OwnsSkin(player, id) elseif kind == "gun" then owned = Cat.OwnsGunSkin(player, id) else owned = Cat.OwnsBanner(player, id) end
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
		appendOwned(player, (kind == "skin" and "SkinsOwned") or (kind == "gun" and "GunSkinsOwned") or "BannersOwned", id)
		task.spawn(Profiles.Save, player) -- written right away, so a crash or a teleport can never lose a purchase
		ok, msg = true, "Bought " .. item.name .. "."
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
	elseif kind == "card" then -- v5.11: player card background
		if not PlayerCards.Is(id) then return false, "Unknown background." end
		if not Cat.OwnsBanner(player, id) then return false, "You do not own this background." end
		local pc = table.clone(Profiles.Get(player, "PlayerCard") or {})
		pc.bg = id
		Profiles.Set(player, "PlayerCard", pc)
		task.spawn(Profiles.Save, player)
		return true, "Background set."
	elseif kind == "show" then -- v5.11: showcase slot. id = slot number, gunId = the value
		local slot, value = tonumber(id), gunId
		if not slot or slot < 1 or slot > 3 or slot % 1 ~= 0 then return false, "Unknown slot." end
		if type(value) ~= "string" then return false, "Unknown item." end
		if value ~= "" then
			local k, iid = PlayerCards.Parse(value)
			local okOwn = false
			if k == "skin" then okOwn = Cat.OwnsSkin(player, iid)
			elseif k == "gun" then okOwn = Cat.OwnsGunSkin(player, iid)
			elseif k == "card" then
				local col = Cards.Collection(Profiles.Get(player, "Cards"))
				okOwn = Cards.Is(iid) and (col[iid] or 0) > 0
			end
			if not okOwn then return false, "You do not own that." end
		end
		local pc = table.clone(Profiles.Get(player, "PlayerCard") or {})
		local show = type(pc.show) == "table" and table.clone(pc.show) or {}
		for i = 1, 3 do if type(show[i]) ~= "string" then show[i] = "" end end
		if value ~= "" then for i = 1, 3 do if show[i] == value then show[i] = "" end end end -- the same item never shows twice
		show[slot] = value
		pc.show = show
		Profiles.Set(player, "PlayerCard", pc)
		task.spawn(Profiles.Save, player)
		return true, "Showcase updated."
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
		-- v5.11: make sure everybody has a PlayerCard table (mirrored as PlayerCardJson) and the background is still theirs
		local pc = Profiles.Get(p, "PlayerCard")
		pc = type(pc) == "table" and table.clone(pc) or {}
		if not Cat.OwnsBanner(p, pc.bg) then pc.bg = PlayerCards.Default end
		if type(pc.show) ~= "table" then pc.show = { "", "", "" } end
		Profiles.Set(p, "PlayerCard", pc)
	end)
end)

Players.PlayerRemoving:Connect(function(p) busy[p], lastCall[p] = nil, nil end)
