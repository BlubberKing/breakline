-- LobbyServer (Script in ServerScriptService) - LOBBY place only.
-- Queue + matchmaker + teleport to Breakline.
--   1. A solo player or a party leader fires the "Queue" remote -> an entry goes into a MemoryStore queue.
--   2. One lobby server at a time (MemoryStore lock) packs queue entries into Red 3 / Blue 3 (parties stay together).
--   3. It reserves a Breakline server, saves the roster under that server's id, and tells every lobby server to teleport its players.
-- Teleport + ReserveServer only work in a published game, NOT in Studio's Play button.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")

local PC = require(RS:WaitForChild("PlaceConfig"))
local Party = require(script.Parent:WaitForChild("PartyService"))
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))

local queue = MemoryStoreService:GetSortedMap("Queue_v1")
local lockMap = MemoryStoreService:GetHashMap("MatchLock_v1")
local matches = MemoryStoreService:GetHashMap("Matches")   -- Breakline's MatchRoster reads this same map
local assign = MemoryStoreService:GetHashMap("Assign_v1")

local QueueR = RS:WaitForChild("LobbyRemotes"):WaitForChild("Queue")
-- v4.2: two modes. "breakline" = 3v3 wall push (PC.TEAM_SIZE per team), "1v1" = one player per team.
local MODE_SIZE = { breakline = PC.TEAM_SIZE, ["1v1"] = 1 }
local MODE_NAME = { breakline = "Breakline", ["1v1"] = "1v1" }
local queuedKey = {}   -- [userId] = queue key (only for players on THIS server)
local lastQueue = {}

local function publish(topic, data)
	pcall(function() MessagingService:PublishAsync(topic, data) end)
end

local function setQueued(ids, on, key)
	for _, uid in ids do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			p:SetAttribute("Queued", on or nil)
			p:SetAttribute("QueuedAt", on and os.time() or nil)
			queuedKey[uid] = on and key or nil
		end
	end
end

-- ===== loadout (Move, Weapon, Gadgets x3, Reserve x3) =====
-- Saved in the shared profile. The chosen Weapon is what Breakline's GunServer equips when the match starts.
local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local HttpService = game:GetService("HttpService")
local SetLoadoutR = RS:WaitForChild("LobbyRemotes"):WaitForChild("SetLoadout")
local lastLoadout = {}

local function cleanLoadout(l)
	l = type(l) == "table" and l or {}
	local out = { Gadgets = {}, Reserve = {} }
	out.Weapon = Catalog.Is(l.Weapon, "weapon") and l.Weapon or Catalog.DefaultWeapon
	out.Move = Catalog.Is(l.Move, "move") and l.Move or ""
	for i = 1, 3 do
		out.Gadgets[i] = Catalog.Is(type(l.Gadgets) == "table" and l.Gadgets[i], "gadget") and l.Gadgets[i] or ""
		local r = type(l.Reserve) == "table" and l.Reserve[i]
		out.Reserve[i] = (Catalog.Is(r, "gadget") or Catalog.Is(r, "weapon")) and r or ""
	end
	return out
end

local function publishLoadout(p, l)
	p:SetAttribute("LoadoutJson", HttpService:JSONEncode(l))
end

Players.PlayerAdded:Connect(function(p)
	task.spawn(function()
		local d = Profiles.WaitFor(p)
		if not d then return end
		local l = cleanLoadout(d.Loadout)
		if type(d.Weapon) == "string" and Catalog.Is(d.Weapon, "weapon") and (type(d.Loadout) ~= "table" or d.Loadout.Weapon == nil) then l.Weapon = d.Weapon end
		publishLoadout(p, l)
	end)
end)

SetLoadoutR.OnServerEvent:Connect(function(player, l)
	if os.clock() - (lastLoadout[player] or 0) < 0.15 then return end
	lastLoadout[player] = os.clock()
	if type(l) ~= "table" then return end
	local clean = cleanLoadout(l)
	if not Profiles.Get(player, "Loadout") then return end -- profile not loaded yet
	Profiles.Set(player, "Loadout", clean)
	Profiles.Set(player, "Weapon", clean.Weapon) -- what Breakline reads
	publishLoadout(player, clean)
end)
-- ===== skins (Skins tab) =====
-- Saved in the shared profile as "Skin" (ProfileStore mirrors it to the Player attribute "Skin"; AvatarService re-dresses the character).
local Skins = require(RS:WaitForChild("Skins"))
local SetSkinR = RS:WaitForChild("LobbyRemotes"):WaitForChild("SetSkin")
local lastSkin = {}
SetSkinR.OnServerEvent:Connect(function(player, id)
	if os.clock() - (lastSkin[player] or 0) < 0.3 then return end
	lastSkin[player] = os.clock()
	if not Skins.Is(id) then return end
	if not Profiles.Get(player, "Loadout") then return end -- profile not loaded yet
	Profiles.Set(player, "Skin", id)
end)

Players.PlayerRemoving:Connect(function(p) lastLoadout[p] = nil lastSkin[p] = nil end)

-- ===== queue remote =====
QueueR.OnServerEvent:Connect(function(player, on, modeId)
	if os.clock() - (lastQueue[player] or 0) < 1 then return end
	lastQueue[player] = os.clock()
	if PC.BREAKLINE_PLACE_ID == 0 then Party.Notice(player, "Set BREAKLINE_PLACE_ID in PlaceConfig first.") return end

	modeId = (modeId == "1v1") and "1v1" or "breakline"
	local teamSize = MODE_SIZE[modeId]
	local party, id = Party.Get(player)
	local ids = { player.UserId }
	local key = "solo_" .. player.UserId
	if party then
		if party.leader ~= player.UserId then Party.Notice(player, "Only the party leader can start the search.") return end
		ids, key = {}, id
		for _, m in party.members do table.insert(ids, m.id) end
	end

	if on == true then
		if #ids > teamSize then Party.Notice(player, modeId == "1v1" and "1v1 is solo only. Leave your party to queue for it." or "Your party is bigger than a team.") return end
		local ok = pcall(function()
			queue:SetAsync(key, { ids = ids, mode = modeId }, PC.QUEUE_TIMEOUT, os.time())
		end)
		if not ok then Party.Notice(player, "Matchmaking is busy, try again.") return end
		setQueued(ids, true, key)
		publish("QueueState", { ids = ids, on = true, key = key })
	else
		pcall(function() queue:RemoveAsync(key) end)
		setQueued(ids, false)
		publish("QueueState", { ids = ids, on = false })
	end
end)

pcall(function()
	MessagingService:SubscribeAsync("QueueState", function(msg)
		local d = msg.Data
		if type(d) == "table" and type(d.ids) == "table" then setQueued(d.ids, d.on, d.key) end
	end)
end)

-- ===== teleport =====
local function teleportGroup(code, list)
	local go = {}
	for _, p in list do
		if p.Parent and not p:GetAttribute("Teleporting") then
			p:SetAttribute("Teleporting", true)
			p:SetAttribute("Queued", nil)
			queuedKey[p.UserId] = nil
			task.spawn(function()
				pcall(function() assign:RemoveAsync(tostring(p.UserId)) end)
				pcall(Profiles.Save, p)
			end)
			table.insert(go, p)
		end
	end
	if #go == 0 then return end
	local opts = Instance.new("TeleportOptions")
	opts.ReservedServerAccessCode = code
	local ok, err = pcall(function() TeleportService:TeleportAsync(PC.BREAKLINE_PLACE_ID, go, opts) end)
	if not ok then
		warn("[Lobby] teleport failed:", err)
		for _, p in go do
			p:SetAttribute("Teleporting", nil)
			Party.Notice(p, "Teleport failed. Press PLAY to try again.")
		end
	end
end

TeleportService.TeleportInitFailed:Connect(function(player)
	player:SetAttribute("Teleporting", nil)
	Party.Notice(player, "Teleport failed. Press PLAY to try again.")
end)

pcall(function()
	MessagingService:SubscribeAsync("MatchFound", function(msg)
		local d = msg.Data
		if type(d) ~= "table" or type(d.ids) ~= "table" then return end
		local mine = {}
		for _, uid in d.ids do
			local p = Players:GetPlayerByUserId(uid)
			if p then table.insert(mine, p) end
		end
		teleportGroup(d.code, mine)
	end)
end)

-- fallback in case a message was missed: queued players look for their assignment
task.spawn(function()
	while true do
		task.wait(4)
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("Queued") and not p:GetAttribute("Teleporting") then
				local ok, code = pcall(function() return assign:GetAsync(tostring(p.UserId)) end)
				if ok and code then teleportGroup(code, { p }) end
			end
		end
	end
end)

-- ===== matchmaker =====
local function matchMode(items, modeId)
	local size = MODE_SIZE[modeId]
	local teams = { Red = {}, Blue = {} }
	local usedKeys, seen = {}, {}
	for _, it in items do
		local v = it.value
		local itMode = (type(v) == "table" and v.mode == "1v1") and "1v1" or "breakline" -- old entries without a mode = breakline
		local ids = type(v) == "table" and v.ids
		if itMode == modeId and type(ids) == "table" and #ids >= 1 and #ids <= size then
			local clash = false
			for _, uid in ids do if seen[uid] then clash = true end end -- same player twice (stale entry)
			if not clash then
				local pick
				for _, name in { "Red", "Blue" } do
					if #teams[name] + #ids <= size and (not pick or #teams[name] < #teams[pick]) then pick = name end
				end
				if pick then
					for _, uid in ids do table.insert(teams[pick], uid) seen[uid] = true end
					table.insert(usedKeys, it.key)
				end
			end
		end
	end
	if #teams.Red < size or #teams.Blue < size then return end

	local okS, code, serverId = pcall(function() return TeleportService:ReserveServer(PC.BREAKLINE_PLACE_ID) end)
	if not okS then warn("[Lobby] ReserveServer failed:", code) return end
	local all = {}
	for _, uid in teams.Red do table.insert(all, uid) end
	for _, uid in teams.Blue do table.insert(all, uid) end
	local saved = pcall(function() matches:SetAsync(serverId, { Red = teams.Red, Blue = teams.Blue, Mode = MODE_NAME[modeId] }, 3600) end)
	if not saved then return end
	for _, k in usedKeys do pcall(function() queue:RemoveAsync(k) end) end
	for _, uid in all do pcall(function() assign:SetAsync(tostring(uid), code, 120) end) end
	publish("MatchFound", { code = code, ids = all })
	print("[Lobby] match made (" .. modeId .. "):", #teams.Red, "vs", #teams.Blue)
end

local function tryMatch()
	local got = false
	local ok = pcall(function()
		lockMap:UpdateAsync("lock", function(old)
			got = (old == nil)
			if got then return game.JobId end
			return nil
		end, 8)
	end)
	if not (ok and got) then return end

	local okR, items = pcall(function() return queue:GetRangeAsync(Enum.SortDirection.Ascending, 50) end)
	if not okR or type(items) ~= "table" then return end
	matchMode(items, "breakline")
	matchMode(items, "1v1")
end

task.spawn(function()
	task.wait(math.random() * 3)
	while true do
		pcall(tryMatch)
		task.wait(3)
	end
end)

-- leaving the lobby while queued (not teleporting) cancels the search
Players.PlayerRemoving:Connect(function(player)
	lastQueue[player] = nil
	local key = queuedKey[player.UserId]
	if key and not player:GetAttribute("Teleporting") then
		pcall(function() queue:RemoveAsync(key) end)
		local party = Party.Get(player)
		local ids = { player.UserId }
		if party then ids = {} for _, m in party.members do table.insert(ids, m.id) end end
		setQueued(ids, false)
		publish("QueueState", { ids = ids, on = false })
	end
	queuedKey[player.UserId] = nil
end)
