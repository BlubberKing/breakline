-- ProfileStore (ModuleScript in ServerScriptService) - used by BOTH games (Lobby place + Breakline place). Keep the copies identical.
-- One DataStore record per player, shared by both places. Only the keys you CHANGED are written (so the two places never overwrite each other).
--   Profiles.WaitFor(player)            -> waits until the profile is loaded, returns the data table (or nil)
--   Profiles.Get(player, key)           -> value
--   Profiles.Set(player, key, value)    -> marks the key to be saved
--   Profiles.Increment(player, key, n)  -> number keys
--   Profiles.Save(player)               -> save now (call before teleporting a player away)
-- Number/string keys are mirrored to Player attributes (Coins, Wins, Losses, Weapon, Sight) so UI can read them.
-- Needs: Game Settings > Security > "Enable Studio Access to API Services" ON to save from Studio.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local store = DataStoreService:GetDataStore("BreaklineProfile_v1")

local DEFAULTS = {
	Coins = 0, Wins = 0, Losses = 0,
	Weapon = "", Sight = "",   -- last equipped loadout (to be wired into GunServer later)
	Cards = {}, Deck = {},     -- reserved for the card system
}

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
	if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then player:SetAttribute(k, v) end
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
