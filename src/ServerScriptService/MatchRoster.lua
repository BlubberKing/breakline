-- MatchRoster (ModuleScript in ServerScriptService) - BREAKLINE place only. Required by MatchServer.
-- When Breakline is opened by the lobby's matchmaker it is a RESERVED server. The matchmaker saved who plays on which team in
-- MemoryStore under this server's PrivateServerId. This module reads that roster (trusted - players cannot fake it) and
-- sends everybody back to the lobby when the match is over. In Studio it does nothing (Reserved = false).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local PC = require(RS:WaitForChild("PlaceConfig"))

local R = {}
R.Reserved = (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0) and not RunService:IsStudio()
R.Total = 0
local teamOf = {}
local bootClock = os.clock()

if R.Reserved then
	local matches = MemoryStoreService:GetHashMap("Matches")
	for _ = 1, 10 do
		local ok, data = pcall(function() return matches:GetAsync(game.PrivateServerId) end)
		if ok and type(data) == "table" then
			for teamName, ids in data do
				for _, uid in ids do
					teamOf[uid] = teamName
					R.Total += 1
				end
			end
			break
		end
		task.wait(1)
	end
	if R.Total == 0 then warn("[MatchRoster] no roster found for this server - everyone will spectate") end
end

function R.TeamOf(userId) return teamOf[userId] end

-- true once every rostered player is here, or the wait time ran out
local started = false -- once the match has been allowed to start it stays allowed (a player leaving must not cancel it)
function R.Ready()
	if not R.Reserved then return true end
	if started then return #Players:GetPlayers() >= 1 end
	local all = os.clock() - bootClock >= PC.ROSTER_WAIT
	if not all then
		all = true
		for uid in teamOf do
			if not Players:GetPlayerByUserId(uid) then all = false break end
		end
	end
	if all and #Players:GetPlayers() >= 1 then started = true end
	return started
end

local function sendToLobby(list)
	if PC.LOBBY_PLACE_ID == 0 then
		for _, p in list do p:Kick("Match over. Rejoin the game to go back to the lobby.") end
		return
	end
	for attempt = 1, 4 do
		local alive = {}
		for _, p in list do if p.Parent then table.insert(alive, p) end end
		if #alive == 0 then return end
		local ok = pcall(function() TeleportService:TeleportAsync(PC.LOBBY_PLACE_ID, alive) end)
		if ok then return end
		task.wait(2 * attempt)
	end
	for _, p in list do if p.Parent then p:Kick("Match over. Rejoin the game to go back to the lobby.") end end
end

-- one player pressed CONTINUE on the souls screen (never teleports in Studio)
function R.SendOne(player)
	if RunService:IsStudio() then return end
	task.defer(sendToLobby, { player })
end

-- Match finished: save profiles are handled by ProfileStore on leave; just send everyone home.
function R.ReturnAll()
	sendToLobby(Players:GetPlayers())
end

-- Direct joins (not through the queue) go to the lobby.
if not R.Reserved and not RunService:IsStudio() and PC.REDIRECT_PUBLIC_JOINS and PC.LOBBY_PLACE_ID ~= 0 then
	local function redirect(p) task.defer(sendToLobby, { p }) end
	Players.PlayerAdded:Connect(redirect)
	for _, p in Players:GetPlayers() do redirect(p) end
end

return R
