-- TrainingServer v1 (Script in ServerScriptService) - LOBBY place only. NEW in v5.17 (GDD 5.13 TRAINING ZONE).
-- The TRAINING ZONE: any BasePart in Workspace named "TrainingZone" (make it big, invisible, CanCollide off is fine). A player whose character stands inside such a part gets the
-- Player attribute InTraining = true, and while it is true they can use everything they use in a match (guns, gadgets, movement ability, first person, the in-round HUD,
-- poses) - the same code as Breakline (GunServer / GadgetServer / ThirdPersonServer + Vitals) - against the other players inside the zone and the things they place.
-- NOBODY is ever hurt (lobby Vitals): only the effects, hitmarkers and damage numbers show (+ a virtual kill so kill effects and Hot Barrel work).
--   * Workspace part "EntranceTrainingZone": the LEAVE button teleports the player on top of it (put it OUTSIDE the zone).
--   * Remotes (ReplicatedStorage.TrainingRemotes): Leave (RemoteEvent) = teleport out; PickCard(cardId | "") = the card to test in the zone (any card you OWN, not only the 32 of your
--     deck). It is stored as the Player attribute MatchCard (what CardEffects / Vitals / GunServer read in a match) and cleared when you leave. It never touches your real deck.
-- Leaving the zone (walking out, teleport, dying) clears InTraining, MatchCard, HotBarrelUntil and any gadget in hand.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Cards = require(RS:WaitForChild("Cards"))

local folder = RS:FindFirstChild("TrainingRemotes") or Instance.new("Folder")
folder.Name = "TrainingRemotes"
folder.Parent = RS
local function remote(name)
	local r = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = folder
	return r
end
local LeaveR, PickR = remote("Leave"), remote("PickCard")

local ZONE_NAME, ENTRANCE_NAME = "TrainingZone", "EntranceTrainingZone"
local OUT_DELAY = 0.5 -- seconds outside the zone before it counts as left (a jump over the edge does not flicker)

-- ---------------------------------------------------------------- zones
local zones = {}
local function isZone(d) return d:IsA("BasePart") and d.Name == ZONE_NAME end
for _, d in workspace:GetDescendants() do if isZone(d) then table.insert(zones, d) end end
workspace.DescendantAdded:Connect(function(d) if isZone(d) then table.insert(zones, d) end end)
workspace.DescendantRemoving:Connect(function(d)
	local i = table.find(zones, d)
	if i then table.remove(zones, i) end
end)
local function insideAny(pos)
	for _, z in zones do
		if z.Parent then
			local rel = z.CFrame:PointToObjectSpace(pos)
			local h = z.Size / 2
			if math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z then return true end
		end
	end
	return false
end

-- ---------------------------------------------------------------- enter / leave
local outSince, graceUntil = {}, {}
local function setIn(p, on)
	if (p:GetAttribute("InTraining") == true) == on then return end
	if on then
		p:SetAttribute("TrainingCard", nil)
		p:SetAttribute("InTraining", true)
	else
		p:SetAttribute("InTraining", nil)
		p:SetAttribute("MatchCard", nil)
		p:SetAttribute("TrainingCard", nil)
		p:SetAttribute("HotBarrelUntil", nil)
		local ch = p.Character
		if ch then
			ch:SetAttribute("HeldGadget", nil)
			ch:SetAttribute("HeldSlot", nil)
		end
	end
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.15 then return end
	acc = 0
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local ch = p.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local inside = hum ~= nil and hum.Health > 0 and root ~= nil and insideAny(root.Position)
		local isIn = p:GetAttribute("InTraining") == true
		if inside and not isIn then
			if now >= (graceUntil[p] or 0) then
				outSince[p] = nil
				setIn(p, true)
			end
		elseif isIn and not inside then
			outSince[p] = outSince[p] or now
			if now - outSince[p] >= OUT_DELAY then
				outSince[p] = nil
				setIn(p, false)
			end
		else
			outSince[p] = nil
		end
	end
end)

-- ---------------------------------------------------------------- remotes
local lastAsk = {}
local function limited(p)
	if os.clock() - (lastAsk[p] or 0) < 0.25 then return true end
	lastAsk[p] = os.clock()
	return false
end

LeaveR.OnServerEvent:Connect(function(p)
	if limited(p) then return end
	if p:GetAttribute("InTraining") ~= true then return end
	local ch = p.Character
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local ent = workspace:FindFirstChild(ENTRANCE_NAME, true)
	local cf
	if ent and ent:IsA("BasePart") then
		cf = ent.CFrame * CFrame.new(0, ent.Size.Y / 2 + 3.2, 0)
	else
		warn("[TrainingServer] no part named '" .. ENTRANCE_NAME .. "' in Workspace - sending " .. p.Name .. " to the lobby spawn instead")
		local spawn = workspace:FindFirstChild("LobbySpawn", true)
		cf = spawn and spawn:IsA("BasePart") and spawn.CFrame * CFrame.new(0, 4, 0) or CFrame.new(0, 10, 0)
	end
	graceUntil[p] = os.clock() + 3 -- an entrance that sits inside the zone must not pull the player straight back in
	setIn(p, false)
	ch:PivotTo(cf)
	root.AssemblyLinearVelocity = Vector3.zero
end)

local function owned(p, id)
	local raw = p:GetAttribute("CardsJson")
	if type(raw) ~= "string" or raw == "" then return false end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(t) == "table" and (tonumber(t[id]) or 0) > 0
end
PickR.OnServerEvent:Connect(function(p, id)
	if limited(p) then return end
	if p:GetAttribute("InTraining") ~= true then return end
	if id == nil or id == "" then
		p:SetAttribute("MatchCard", nil)
		p:SetAttribute("TrainingCard", nil)
		p:SetAttribute("HotBarrelUntil", nil)
		return
	end
	if type(id) ~= "string" or not Cards.Is(id) or not owned(p, id) then return end
	p:SetAttribute("HotBarrelUntil", nil)
	p:SetAttribute("TrainingCard", id)
	p:SetAttribute("MatchCard", id) -- CardEffects / GunServer / GadgetServer / GunClient all read this attribute
end)

Players.PlayerRemoving:Connect(function(p) outSince[p], graceUntil[p], lastAsk[p] = nil, nil, nil end)
