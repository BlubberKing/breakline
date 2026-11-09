-- CosmeticsServer v4 (Script in ServerScriptService) - LOBBY place only. NEW in v5.10.
-- v5.16: POSES + TITLES.
--     Buy("pose", id) / Buy("title", id)          (souls via Increment, essence only via SpendEssence; saved in PosesOwned / TitlesOwned)
--     Equip("wheel", slot 1..6, poseId | "")      a slot of the pose wheel (T in game + lobby), saved in PoseWheel (the same pose never sits in two slots)
--     Equip("title", id | "")                     the title over your name ("" = none), saved in Title
--     Equip("cardpose", slot 1..3, poseId | "")   the pose a COSTUME in a showcase slot of your player card holds (saved in PlayerCard.poses)
--     Equip("cardtitle", true | false)            show your title on your player card (PlayerCard.showTitle, default on)
--   Putting a new item into a showcase slot clears that slot's pose. Wording: player skins are called COSTUMES in every message.
-- v5.13: Equip("place") also keeps the REPOSITION angle (yaw / pitch, degrees; a power-up card is limited to PlayerCards.CARD_TILT), and putting a
--        NEW item into a showcase slot resets that slot's angle to straight (the old angle belonged to the old item). Spot / size / turn stay.
-- v5.12: the 3 showcase items on the player card are free to move / resize / turn:
--     Equip("place", slot 1..3, { x, y, s, r, yaw, pitch })   where the item of that slot sits on the card (PlayerCards.CleanPlace clamps it), saved in PlayerCard.pos
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
local Poses = require(RS:WaitForChild("Poses"))   -- v5.16
local Titles = require(RS:WaitForChild("Titles")) -- v5.16

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
	if (kind ~= "skin" and kind ~= "gun" and kind ~= "banner" and kind ~= "pose" and kind ~= "title") or type(id) ~= "string" then return false, "Unknown item." end
	local item = Cat.Find(kind, id)
	if not item or not item.currency then return false, "That item is not for sale." end
	if not loaded(player) then return false, "Your data is still loading." end
	local owned
	if kind == "skin" then owned = Cat.OwnsSkin(player, id) elseif kind == "gun" then owned = Cat.OwnsGunSkin(player, id)
	elseif kind == "pose" then owned = Cat.OwnsPose(player, id) elseif kind == "title" then owned = Cat.OwnsTitle(player, id)
	else owned = Cat.OwnsBanner(player, id) end
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
		appendOwned(player, (kind == "skin" and "SkinsOwned") or (kind == "gun" and "GunSkinsOwned") or (kind == "pose" and "PosesOwned")
			or (kind == "title" and "TitlesOwned") or "BannersOwned", id)
		task.spawn(Profiles.Save, player) -- written right away, so a crash or a teleport can never lose a purchase
		ok, msg = true, "Bought " .. item.name .. "."
	end)
	busy[player] = nil
	if not done then warn("[CosmeticsServer] purchase error:", err) return false, "Could not complete the purchase." end
	return ok, msg
end

local lastPlace = {}
EquipR.OnServerInvoke = function(player, kind, id, gunId)
	if kind == "place" then -- v5.12: its own (shorter) rate limit, so moving items never blocks an equip
		if os.clock() - (lastPlace[player] or 0) < 0.12 then return false, "Slow down." end
		lastPlace[player] = os.clock()
	else
		if os.clock() - (lastCall[player] or 0) < 0.15 then return false, "Slow down." end
		lastCall[player] = os.clock()
	end
	if not loaded(player) then return false, "Your data is still loading." end
	if kind == "skin" then
		if type(id) ~= "string" or not Skins.Is(id) then return false, "Unknown costume." end
		if not Cat.OwnsSkin(player, id) then return false, "You do not own this costume." end
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
		local changed = show[slot] ~= value
		show[slot] = value
		pc.show = show
		if changed then -- v5.13: a new item starts straight (keeps its spot, size and turn)
			local pos = {}
			for i = 1, 3 do pos[i] = PlayerCards.CleanPlace(type(pc.pos) == "table" and pc.pos[i] or nil, i, (PlayerCards.Parse(show[i]))) end
			pos[slot].yaw, pos[slot].pitch = 0, 0
			pc.pos = pos
			-- v5.16: and without a pose (the pose belonged to the old costume; only costumes can hold one)
			local poses = type(pc.poses) == "table" and table.clone(pc.poses) or {}
			for i = 1, 3 do if type(poses[i]) ~= "string" then poses[i] = "" end end
			poses[slot] = ""
			pc.poses = poses
		end
		Profiles.Set(player, "PlayerCard", pc)
		task.spawn(Profiles.Save, player)
		return true, "Showcase updated."
	elseif kind == "place" then -- v5.12: where a showcase item sits on the card. id = slot number, gunId = { x, y, s, r }
		local slot, t = tonumber(id), gunId
		if not slot or slot < 1 or slot > 3 or slot % 1 ~= 0 then return false, "Unknown slot." end
		if type(t) ~= "table" then return false, "Bad placement." end
		local pc = table.clone(Profiles.Get(player, "PlayerCard") or {})
		local show = type(pc.show) == "table" and pc.show or {}
		local pos = {}
		for i = 1, 3 do pos[i] = PlayerCards.CleanPlace(type(pc.pos) == "table" and pc.pos[i] or nil, i, (PlayerCards.Parse(show[i]))) end
		-- v5.13: + the REPOSITION angle (yaw / pitch); the kind of item in the slot decides the limit (cards only lean a little)
		pos[slot] = PlayerCards.CleanPlace({ x = t.x, y = t.y, s = t.s, r = t.r, yaw = t.yaw, pitch = t.pitch }, slot, (PlayerCards.Parse(show[slot])))
		pc.pos = pos
		Profiles.Set(player, "PlayerCard", pc)
		task.spawn(Profiles.Save, player)
		return true, "Placed."
	elseif kind == "wheel" then -- v5.16: a slot of the pose wheel. id = slot 1..6, gunId = pose id or ""
		local slot, poseId = tonumber(id), gunId
		if not slot or slot < 1 or slot > Poses.WHEEL or slot % 1 ~= 0 then return false, "Unknown slot." end
		if type(poseId) ~= "string" then return false, "Unknown pose." end
		if poseId ~= "" and not Cat.OwnsPose(player, poseId) then return false, "You do not own this pose." end
		local saved = Profiles.Get(player, "PoseWheel")
		local wheel = (type(saved) == "table" and #saved > 0) and Poses.CleanWheel(saved, function(p) return Cat.OwnsPose(player, p) end) or table.clone(Poses.DefaultWheel)
		if poseId ~= "" then for i = 1, Poses.WHEEL do if wheel[i] == poseId then wheel[i] = wheel[slot] end end end -- already on the wheel: the two slots swap
		wheel[slot] = poseId
		Profiles.Set(player, "PoseWheel", wheel)
		task.spawn(Profiles.Save, player)
		return true, poseId == "" and "Slot emptied." or (Poses.ById[poseId].name .. " is on slot " .. slot .. ".")
	elseif kind == "title" then -- v5.16: the title over your name. id = title id or ""
		if type(id) ~= "string" then return false, "Unknown title." end
		if id ~= "" then
			if not Titles.Is(id) then return false, "Unknown title." end
			if not Cat.OwnsTitle(player, id) then return false, "You do not own this title." end
		end
		Profiles.Set(player, "Title", id)
		task.spawn(Profiles.Save, player)
		return true, id == "" and "Title removed." or ("Title set: " .. Titles.ById[id].text .. ".")
	elseif kind == "cardpose" then -- v5.16: the pose a costume in a showcase slot holds. id = slot 1..3, gunId = pose id or ""
		local slot, poseId = tonumber(id), gunId
		if not slot or slot < 1 or slot > 3 or slot % 1 ~= 0 then return false, "Unknown slot." end
		if type(poseId) ~= "string" then return false, "Unknown pose." end
		local pc = table.clone(Profiles.Get(player, "PlayerCard") or {})
		local show = type(pc.show) == "table" and pc.show or {}
		if PlayerCards.Parse(show[slot]) ~= "skin" then return false, "Only a costume can hold a pose." end
		if poseId ~= "" and not Cat.OwnsPose(player, poseId) then return false, "You do not own this pose." end
		local poses = type(pc.poses) == "table" and table.clone(pc.poses) or {}
		for i = 1, 3 do if type(poses[i]) ~= "string" then poses[i] = "" end end
		poses[slot] = poseId
		pc.poses = poses
		Profiles.Set(player, "PlayerCard", pc)
		task.spawn(Profiles.Save, player)
		return true, poseId == "" and "Pose removed." or "Pose set."
	elseif kind == "cardtitle" then -- v5.16: show the title on the player card (on / off)
		local pc = table.clone(Profiles.Get(player, "PlayerCard") or {})
		pc.showTitle = id == true
		Profiles.Set(player, "PlayerCard", pc)
		task.spawn(Profiles.Save, player)
		return true, pc.showTitle and "Title shown on your card." or "Title hidden on your card."
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
		local pos = {} -- v5.12: placements of the showcase items (checked / defaults); v5.13: + the REPOSITION angle
		for i = 1, 3 do pos[i] = PlayerCards.CleanPlace(type(pc.pos) == "table" and pc.pos[i] or nil, i, (PlayerCards.Parse(pc.show[i]))) end
		pc.pos = pos
		-- v5.16: showcase poses (only a costume slot keeps one, and only an owned pose) + the title switch (default on)
		local poses = {}
		for i = 1, 3 do
			local pz = type(pc.poses) == "table" and pc.poses[i] or ""
			poses[i] = (type(pz) == "string" and PlayerCards.Parse(pc.show[i]) == "skin" and Cat.OwnsPose(p, pz)) and pz or ""
		end
		pc.poses = poses
		if type(pc.showTitle) ~= "boolean" then pc.showTitle = true end
		Profiles.Set(p, "PlayerCard", pc)
		-- v5.16: the pose wheel (defaults for a new save, owned poses only) + a title that is no longer owned is taken off
		local wheel = Profiles.Get(p, "PoseWheel")
		local cleanW = (type(wheel) == "table" and #wheel > 0) and Poses.CleanWheel(wheel, function(id) return Cat.OwnsPose(p, id) end) or table.clone(Poses.DefaultWheel)
		Profiles.Set(p, "PoseWheel", cleanW)
		local title = Profiles.Get(p, "Title")
		if type(title) ~= "string" or (title ~= "" and not Cat.OwnsTitle(p, title)) then Profiles.Set(p, "Title", "") end
	end)
end)

Players.PlayerRemoving:Connect(function(p) busy[p], lastCall[p], lastPlace[p] = nil, nil, nil end)
