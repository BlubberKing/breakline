-- PartyService (ModuleScript in ServerScriptService) - LOBBY place only. Required by LobbyServer.
-- Parties live in MemoryStore, so they work across lobby servers; MessagingService tells other servers when something changes.
--   record: { leader = userId, members = { {id = userId, name = "Name"}, ... } }
-- Player attributes (read by the UI): PartyId (string), PartyLeader (userId), PartyMembers (JSON of the members list).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")

local PC = require(RS:WaitForChild("PlaceConfig"))

local TTL = 1800
local parties = MemoryStoreService:GetHashMap("Parties_v1")
local playerParty = MemoryStoreService:GetHashMap("PlayerParty_v1")

local remotes = RS:FindFirstChild("LobbyRemotes") or Instance.new("Folder")
remotes.Name = "LobbyRemotes"
remotes.Parent = RS
local function remote(name)
	local r = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local InviteR, RespondR, LeaveR, KickR, NoticeR = remote("Invite"), remote("Respond"), remote("Leave"), remote("Kick"), remote("Notice")
local PromoteR = remote("Promote")
remote("Queue")
remote("SetLoadout")

local M = {}
local invites = {}   -- [targetUserId][partyId] = true (kept on the target's server)
local lastInvite = {}

local function publish(topic, data)
	pcall(function() MessagingService:PublishAsync(topic, data) end)
end

local function notice(player, text)
	NoticeR:FireClient(player, { kind = "msg", text = text })
end
M.Notice = notice

local function apply(player, id, party)
	if party then
		player:SetAttribute("PartyId", id)
		player:SetAttribute("PartyLeader", party.leader)
		player:SetAttribute("PartyMembers", HttpService:JSONEncode(party.members))
	else
		player:SetAttribute("PartyId", nil)
		player:SetAttribute("PartyLeader", nil)
		player:SetAttribute("PartyMembers", nil)
	end
end

local function isMember(party, uid)
	for _, m in party.members do if m.id == uid then return true end end
	return false
end

local function readParty(id)
	local ok, party = pcall(function() return parties:GetAsync(id) end)
	if ok then return party end
	return nil
end

-- re-read a party and update every local player that belongs to (or just left) it
local function refresh(id)
	local party = readParty(id)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("PartyId") == id then
			if party and isMember(party, p.UserId) then apply(p, id, party) else apply(p, nil, nil) end
		elseif party and isMember(party, p.UserId) then
			apply(p, id, party)
		end
	end
end

-- the party record of a player (or nil)
function M.Get(player)
	local id = player:GetAttribute("PartyId")
	if not id then return nil, nil end
	local party = readParty(id)
	if party and isMember(party, player.UserId) then return party, id end
	return nil, nil
end

local function create(player)
	local id = HttpService:GenerateGUID(false)
	local party = { leader = player.UserId, members = { { id = player.UserId, name = player.Name } } }
	local ok = pcall(function()
		parties:SetAsync(id, party, TTL)
		playerParty:SetAsync(tostring(player.UserId), id, TTL)
	end)
	if not ok then notice(player, "Could not create a party, try again.") return nil end
	apply(player, id, party)
	return party, id
end

local function leave(uid, id)
	local emptied = false
	pcall(function()
		parties:UpdateAsync(id, function(old)
			if not old then return nil end
			for i, m in old.members do
				if m.id == uid then table.remove(old.members, i) break end
			end
			if #old.members == 0 then emptied = true return nil end
			if old.leader == uid then old.leader = old.members[1].id end
			return old
		end, TTL)
	end)
	pcall(function()
		if emptied then parties:RemoveAsync(id) end
		playerParty:RemoveAsync(tostring(uid))
	end)
	publish("PartyUpdate", { id = id })
	local p = Players:GetPlayerByUserId(uid)
	if p then apply(p, nil, nil) end
	refresh(id)
end

-- ===== remotes =====
InviteR.OnServerEvent:Connect(function(player, name)
	local byId = type(name) == "number" and name % 1 == 0 and name > 0
	if not byId and (type(name) ~= "string" or #name < 3 or #name > 20) then return end
	if os.clock() - (lastInvite[player] or 0) < 2 then return end
	lastInvite[player] = os.clock()
	local party, id = M.Get(player)
	if party and party.leader ~= player.UserId then notice(player, "Only the party leader can invite.") return end
	if party and #party.members >= PC.MAX_PARTY then notice(player, "Your party is full.") return end
	local ok, uid = true, name
	if not byId then ok, uid = pcall(function() return Players:GetUserIdFromNameAsync(name) end) end
	if not ok or not uid then notice(player, "Player '" .. tostring(name) .. "' was not found.") return end
	if byId then
		local okN, n = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
		name = okN and n or "player"
	end
	if uid == player.UserId then return end
	if party and isMember(party, uid) then notice(player, name .. " is already in your party.") return end
	if not party then party, id = create(player) end
	if not party then return end
	publish("PartyInvite", { to = uid, id = id, fromName = player.Name })
	notice(player, "Invite sent to " .. name .. ".")
end)

RespondR.OnServerEvent:Connect(function(player, id, accept)
	if type(id) ~= "string" then return end
	local mine = invites[player.UserId]
	if not (mine and mine[id]) then return end
	mine[id] = nil
	if accept ~= true then return end
	local old, oldId = M.Get(player)
	if oldId then leave(player.UserId, oldId) end
	local joined = false
	pcall(function()
		parties:UpdateAsync(id, function(party)
			if not party or #party.members >= PC.MAX_PARTY or isMember(party, player.UserId) then return nil end
			table.insert(party.members, { id = player.UserId, name = player.Name })
			joined = true
			return party
		end, TTL)
	end)
	if not joined then notice(player, "That party is full or no longer exists.") return end
	pcall(function() playerParty:SetAsync(tostring(player.UserId), id, TTL) end)
	publish("PartyUpdate", { id = id })
	refresh(id)
	notice(player, "You joined the party.")
end)

LeaveR.OnServerEvent:Connect(function(player)
	local _, id = M.Get(player)
	if id then leave(player.UserId, id) end
end)

KickR.OnServerEvent:Connect(function(player, targetId)
	if type(targetId) ~= "number" then return end
	local party, id = M.Get(player)
	if not party or party.leader ~= player.UserId or targetId == player.UserId then return end
	if not isMember(party, targetId) then return end
	leave(targetId, id)
end)

PromoteR.OnServerEvent:Connect(function(player, targetId)
	if type(targetId) ~= "number" then return end
	local party, id = M.Get(player)
	if not party or party.leader ~= player.UserId or targetId == player.UserId then return end
	if not isMember(party, targetId) then return end
	pcall(function()
		parties:UpdateAsync(id, function(old)
			if old and old.leader == player.UserId and isMember(old, targetId) then old.leader = targetId return old end
			return nil
		end, TTL)
	end)
	publish("PartyUpdate", { id = id })
	refresh(id)
end)

-- ===== messages from other servers =====
pcall(function()
	MessagingService:SubscribeAsync("PartyInvite", function(msg)
		local d = msg.Data
		local p = type(d) == "table" and Players:GetPlayerByUserId(d.to)
		if not p then return end
		invites[p.UserId] = invites[p.UserId] or {}
		invites[p.UserId][d.id] = true
		NoticeR:FireClient(p, { kind = "invite", id = d.id, fromName = d.fromName })
	end)
	MessagingService:SubscribeAsync("PartyUpdate", function(msg)
		local d = msg.Data
		if type(d) == "table" and type(d.id) == "string" then refresh(d.id) end
	end)
end)

-- ===== join / leave =====
Players.PlayerAdded:Connect(function(player)
	task.spawn(function() -- back from a match: restore the party
		local ok, id = pcall(function() return playerParty:GetAsync(tostring(player.UserId)) end)
		if not ok or not id then return end
		local party = readParty(id)
		if party and isMember(party, player.UserId) and player.Parent then
			apply(player, id, party)
			pcall(function() playerParty:SetAsync(tostring(player.UserId), id, TTL) end)
		else
			pcall(function() playerParty:RemoveAsync(tostring(player.UserId)) end)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastInvite[player], invites[player.UserId] = nil, nil
	if player:GetAttribute("Teleporting") then return end -- going to a match: keep the party
	local id = player:GetAttribute("PartyId")
	if id then task.spawn(leave, player.UserId, id) end
end)

return M
