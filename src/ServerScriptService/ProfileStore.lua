-- ProfileStore v2.1 (v5.9: ESSENCE premium currency - GrantEssence / SpendEssence) (v2 v4.7: Owned + StarterDone for the shop) (ModuleScript in ServerScriptService) - used by BOTH games (Lobby place + Breakline place). Keep the copies identical.
-- One DataStore record per player, shared by both places. Only the keys you CHANGED are written (so the two places never overwrite each other).
--   Profiles.WaitFor(player)            -> waits until the profile is loaded, returns the data table (or nil)
--   Profiles.Get(player, key)           -> value
--   Profiles.Set(player, key, value)    -> marks the key to be saved
--   Profiles.Increment(player, key, n)  -> number keys
--   Profiles.Save(player)               -> save now (call before teleporting a player away)
--   v5.9 ESSENCE (premium currency, bought with Robux). Never change it with Set / Increment - use these two. Both write to the DataStore
--   right away (UpdateAsync on the saved value, so nothing is lost or doubled even if the other place saved in between) and yield:
--   Profiles.GrantEssence(player, amount, receiptId) -> true when the Essence is safely saved (or this receiptId was already granted).
--                                                       receiptId = the Developer Product PurchaseId: ProcessReceipt returns PurchaseGranted
--                                                       only when this returns true, so a purchase is never lost and never paid out twice.
--   Profiles.SpendEssence(player, amount)          -> true when the player had enough and the new balance is saved, false otherwise.
-- Number/string keys are mirrored to Player attributes (Souls, Essence, Wins, Losses, XP, Level, Skin) so UI + AvatarService can read them.
-- Needs: Game Settings > Security > "Enable Studio Access to API Services" ON to save from Studio.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local store = DataStoreService:GetDataStore("BreaklineProfile_v1")

-- v3.8: XP -> level (ReplicatedStorage.Levels). The Player attribute "Level" is derived from "XP" whenever XP is mirrored.
local Levels
do
	local mod = game:GetService("ReplicatedStorage"):WaitForChild("Levels", 5)
	if mod then Levels = require(mod) end
end

local DEFAULTS = {
	Souls = 0, Wins = 0, Losses = 0, XP = 0, -- XP: player level (v3.8)
	Weapon = "", Sight = "",   -- last equipped loadout (to be wired into GunServer later)
	Loadout = {},              -- lobby loadout: { Move, Weapon, Gadgets = {3}, Reserve = {3} } (item ids)
	Skin = "OPERATOR",         -- equipped skin (ReplicatedStorage.Skins). New players start with the default skin.
	SkinsOwned = {},           -- reserved: skins bought in the shop later (all 3 starter skins are free for now)
	Cards = {}, Deck = {},     -- reserved for the card system
	Owned = {},                -- v4.7 SHOP: ids of every gun / gadget / movement ability you own (LobbyCatalog ids). Mirrored as the attribute OwnedJson.
	StarterDone = false,       -- v4.7: true once the new-player pick (1 weapon + 1 movement) was made
	Essence = 0,               -- v5.9: premium currency (Robux purchases). Only GrantEssence / SpendEssence change it.
	EssenceReceipts = {},      -- v5.9: the last purchase ids already paid out (stops a repeated ProcessReceipt from granting twice)
}
local RECEIPTS_KEPT = 50

local M = {}
local cache, dirty, loading = {}, {}, {}

local function copy(v)
	if type(v) == "table" then
		local t = {}
		for k, x in v do t[k] = copy(x) end
		return t
	end
	return v
end

local function retry(fn)
	for i = 1, 5 do
		local ok, res = pcall(fn)
		if ok then return true, res end
		task.wait(i)
	end
	return false, nil
end

local function mirror(player, k, v)
	-- Weapon / Sight are NOT mirrored: GunServer owns those attributes in the match (mirroring "" used to wipe your gun = no damage)
	if k == "Weapon" or k == "Sight" then return end
	if k == "Owned" and type(v) == "table" then player:SetAttribute("OwnedJson", HttpService:JSONEncode(v)) end -- v4.7
	if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then player:SetAttribute(k, v) end
	if k == "XP" and Levels and type(v) == "number" then player:SetAttribute("Level", (Levels.FromXp(v))) end
end

function M.Load(player)
	if cache[player] or loading[player] then return cache[player] end
	loading[player] = true
	local ok, data = retry(function() return store:GetAsync("P_" .. player.UserId) end)
	loading[player] = nil
	if not player.Parent then return nil end
	if not ok then
		if RunService:IsStudio() then
			warn("[ProfileStore] could not load data (turn ON Game Settings > Security > Enable Studio Access to API Services). Using defaults.")
			data = nil
		else
			player:Kick("Could not load your data. Please rejoin.")
			return nil
		end
	end
	data = type(data) == "table" and data or {}
	if data.Souls == nil and type(data.Coins) == "number" then data.Souls = data.Coins end -- old saves: Coins became Souls
	if type(data.Skin) ~= "string" or data.Skin == "" then data.Skin = nil end -- empty/broken skin = default
	for k, v in DEFAULTS do
		if data[k] == nil then data[k] = copy(v) end
	end
	cache[player], dirty[player] = data, {}
	for k, v in data do mirror(player, k, v) end
	player:SetAttribute("ProfileLoaded", true)
	return data
end

function M.WaitFor(player)
	while player.Parent and not cache[player] do task.wait(0.1) end
	return cache[player]
end

function M.Get(player, key)
	local d = cache[player]
	return d and d[key]
end

function M.Set(player, key, value)
	local d = cache[player]
	if not d then return end
	d[key] = value
	dirty[player][key] = true
	mirror(player, key, value)
end

function M.Increment(player, key, n)
	local d = cache[player]
	if not d or type(d[key]) ~= "number" then return end
	M.Set(player, key, d[key] + n)
end

function M.Save(player)
	local d, keys = cache[player], dirty[player]
	if not d or not keys or next(keys) == nil then return end
	dirty[player] = {}
	local snapshot = {}
	for k in keys do snapshot[k] = copy(d[k]) end
	if RunService:IsStudio() and not pcall(function() store:GetAsync("ping") end) then return end
	local ok = retry(function()
		store:UpdateAsync("P_" .. player.UserId, function(old)
			old = type(old) == "table" and old or {}
			for k, v in snapshot do old[k] = copy(v) end
			return old
		end)
	end)
	if not ok then
		warn("[ProfileStore] could not save", player.Name)
		for k in snapshot do if dirty[player] then dirty[player][k] = true end end
	end
end

-- ===== v5.9: Essence (premium) - written straight to the DataStore =====
local function essenceUpdate(player, fn)
	local d = cache[player]
	if not d then return false end
	local result
	local ok = retry(function()
		store:UpdateAsync("P_" .. player.UserId, function(old)
			old = type(old) == "table" and old or {}
			if type(old.Essence) ~= "number" then old.Essence = 0 end
			if type(old.EssenceReceipts) ~= "table" then old.EssenceReceipts = {} end
			result = fn(old)
			if result == "nochange" then return nil end -- nothing to write (cancels the update)
			return old
		end)
	end)
	if not ok then return false end
	return result
end

function M.GrantEssence(player, amount, receiptId)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or not cache[player] then return false end
	local newBalance, receipts
	local res = essenceUpdate(player, function(old)
		if receiptId ~= nil and table.find(old.EssenceReceipts, tostring(receiptId)) then
			newBalance, receipts = old.Essence, old.EssenceReceipts
			return "nochange" -- already paid out
		end
		old.Essence += amount
		if receiptId ~= nil then
			table.insert(old.EssenceReceipts, tostring(receiptId))
			while #old.EssenceReceipts > RECEIPTS_KEPT do table.remove(old.EssenceReceipts, 1) end
		end
		newBalance, receipts = old.Essence, old.EssenceReceipts
		return "ok"
	end)
	if res == false or newBalance == nil then return false end
	local d = cache[player]
	if d then
		d.Essence, d.EssenceReceipts = newBalance, receipts
		mirror(player, "Essence", newBalance)
	end
	return true
end

function M.SpendEssence(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or not cache[player] then return false end
	if (cache[player].Essence or 0) < amount then return false end
	local newBalance
	local res = essenceUpdate(player, function(old)
		if old.Essence < amount then
			newBalance = old.Essence
			return "nochange"
		end
		old.Essence -= amount
		newBalance = old.Essence
		return "ok"
	end)
	local d = cache[player]
	if d and newBalance ~= nil then
		d.Essence = newBalance
		mirror(player, "Essence", newBalance)
	end
	return res == "ok"
end

Players.PlayerAdded:Connect(function(p) task.spawn(M.Load, p) end)
for _, p in Players:GetPlayers() do task.spawn(M.Load, p) end

Players.PlayerRemoving:Connect(function(p)
	M.Save(p)
	cache[p], dirty[p] = nil, nil
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, p in Players:GetPlayers() do task.spawn(M.Save, p) end
	end
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do task.spawn(M.Save, p) end
	if not RunService:IsStudio() then task.wait(3) end
end)

return M
