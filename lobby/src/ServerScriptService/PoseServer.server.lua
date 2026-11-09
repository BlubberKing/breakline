-- PoseServer v1 (Script in ServerScriptService) - BOTH games (Lobby + Breakline), keep the two copies identical. NEW in v5.16 (GDD 5.10).
-- POSES (emotes): the client asks, the server checks and sets the character attributes everybody animates from (PoseClient):
--   Character attribute Pose   = pose id while the character holds a pose (nil = not posing)
--   Character attribute PoseAt = server time the pose started (animated poses are timed from it, so everybody sees the same moment)
-- Remotes (made here, folder ReplicatedStorage.PoseRemotes, RemoteEvents): Play(slot 1..6) / Stop().
-- Rules: the pose must be on YOUR wheel (profile PoseWheel, default Poses.DefaultWheel) and owned (free or PosesOwned). Breakline: only while the
-- round is Playing, alive, not carrying a box / a soul, not reviving, not wall-climbing / wall-running, not in the respawn reveal.
-- A pose ends when the client says so (it moved / pulled out an item), when the character really moves (checked here too: walking, jumping,
-- falling), when an ability starts, or (Breakline) when the phase leaves Playing.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Poses = require(RS:WaitForChild("Poses"))
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))

local folder = RS:FindFirstChild("PoseRemotes") or Instance.new("Folder")
folder.Name = "PoseRemotes"
folder.Parent = RS
local function remote(name)
	local r = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end
local PlayR, StopR = remote("Play"), remote("Stop")

local MOVE_LIMIT = 4.5   -- studs / s of flat speed that cancels a pose (walking starts at ~16)
local GRACE = 0.35       -- seconds after the start in which movement is not checked (the character may still be settling)
local lastAsk = {}

local function matchState() return RS:FindFirstChild("MatchState") end
local function owns(player, id)
	if not Poses.Is(id) then return false end
	if Poses.IsFree(id) then return true end
	local list = Profiles.Get(player, "PosesOwned")
	return type(list) == "table" and table.find(list, id) ~= nil
end
local function wheelOf(player)
	local saved = Profiles.Get(player, "PoseWheel")
	if type(saved) ~= "table" or #saved == 0 then return table.clone(Poses.DefaultWheel) end
	return Poses.CleanWheel(saved, function(id) return owns(player, id) end)
end
local function blocked(player, char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return true end
	local ms = matchState()
	if ms and ms:GetAttribute("Phase") ~= "Playing" then return true end
	if player:GetAttribute("IsDead") == true or player:GetAttribute("Carrying") == true or player:GetAttribute("CarryingSoul") == true then return true end
	if char:GetAttribute("AbilityMode") ~= nil or char:GetAttribute("Reviving") == true or char:GetAttribute("Revealing") == true then return true end
	if char:GetAttribute("Sliding") == true or char:GetAttribute("Mantling") == true then return true end
	return false
end
local function stop(char)
	if char and char:GetAttribute("Pose") ~= nil then
		char:SetAttribute("Pose", nil)
		char:SetAttribute("PoseAt", nil)
	end
end

PlayR.OnServerEvent:Connect(function(player, slot)
	if os.clock() - (lastAsk[player] or 0) < 0.3 then return end
	lastAsk[player] = os.clock()
	local char = player.Character
	if not char or blocked(player, char) then return end
	slot = tonumber(slot)
	if not slot or slot < 1 or slot > Poses.WHEEL or slot % 1 ~= 0 then return end
	local id = wheelOf(player)[slot]
	if not id or id == "" or not owns(player, id) then return end
	char:SetAttribute("PoseAt", workspace:GetServerTimeNow())
	char:SetAttribute("Pose", id)
end)

StopR.OnServerEvent:Connect(function(player)
	stop(player.Character)
end)

-- the server's own checks (a client that never says stop still cannot walk around in a pose)
RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		if char and char:GetAttribute("Pose") ~= nil then
			local root = char:FindFirstChild("HumanoidRootPart")
			local started = char:GetAttribute("PoseAt") or now
			if not root or blocked(p, char) then
				stop(char)
			elseif now - started > GRACE then
				local v = root.AssemblyLinearVelocity
				if Vector3.new(v.X, 0, v.Z).Magnitude > MOVE_LIMIT or math.abs(v.Y) > 9 then stop(char) end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(p) lastAsk[p] = nil end)
