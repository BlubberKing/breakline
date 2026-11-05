-- TeamOutline v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games (Breakline + Lobby), identical copies. NEW in v4.9.
-- Replaces the old team-coloured lights on the skins: you see your TEAMMATES and your PARTY through walls with an outline.
--   * Teammate (same Team in a Breakline match)      -> cool blue outline   (TEAM_COLOR)
--   * Party member (lobby party, in either game)     -> gold outline        (PARTY_COLOR) - wins over the team colour
--   * Enemies are NEVER outlined. Your own character is never outlined.
-- The outline is a Highlight (DepthMode AlwaysOnTop, no fill) made on THIS client only, so nobody else sees it and it cannot be abused.
-- Party members: in the Lobby they come from the PartyMembers attribute (PartyService); in Breakline from the teleport data the lobby sends
-- (LobbyServer v4.9 puts every player's party member ids in it). A player who rejoins Breakline without teleport data still gets team outlines.
-- Hidden while the outlined player is dead / a soul.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local TEAM_COLOR = Color3.fromRGB(90, 200, 255)
local PARTY_COLOR = Color3.fromRGB(255, 205, 80)
local OUTLINE_TRANSPARENCY = 0.05
local FILL_TRANSPARENCY = 0.92 -- a whisper of fill so a teammate behind a wall reads as a shape, not only a line (1 = none)
local NOT_TEAMS = { Lobby = true, Spectators = true, Neutral = true } -- teams that do not count as "my team"

-- ---------- party ids ----------
local teleportParty = {}
do
	local ok, data = pcall(function() return TeleportService:GetLocalPlayerTeleportData() end)
	if ok and type(data) == "table" and type(data.party) == "table" then
		local mine = data.party[tostring(player.UserId)]
		if type(mine) == "table" then
			for _, id in mine do if tonumber(id) then teleportParty[tonumber(id)] = true end end
		end
	end
end
local function partySet()
	local set = table.clone(teleportParty)
	local raw = player:GetAttribute("PartyMembers")
	if type(raw) == "string" and raw ~= "" then
		local ok, list = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(list) == "table" then
			for _, m in list do
				local id = type(m) == "table" and tonumber(m.id) or tonumber(m)
				if id then set[id] = true end
			end
		end
	end
	set[player.UserId] = nil
	return set
end

-- ---------- outlines ----------
local function isTeammate(p)
	local myTeam = player.Team
	if not myTeam or player.Neutral or p.Neutral or NOT_TEAMS[myTeam.Name] then return false end
	return p.Team == myTeam
end

local function setOutline(p, color)
	local char = p.Character
	local hl = char and char:FindFirstChild("BL_Outline")
	if not color or not char then
		if hl then hl:Destroy() end
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local alive = hum and hum.Health > 0 and not p:GetAttribute("IsSoul")
	if not alive then
		if hl then hl.Enabled = false end
		return
	end
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = "BL_Outline"
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = FILL_TRANSPARENCY
		hl.OutlineTransparency = OUTLINE_TRANSPARENCY
		hl.Adornee = char
		hl.Parent = char
	end
	hl.Enabled = true
	if hl.OutlineColor ~= color then
		hl.OutlineColor = color
		hl.FillColor = color
	end
end

local function refresh()
	local party = partySet()
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local color = nil
			if party[p.UserId] then
				color = PARTY_COLOR
			elseif isTeammate(p) then
				color = TEAM_COLOR
			end
			setOutline(p, color)
		end
	end
end

-- cheap: a few players, 4 times a second, plus right away when something relevant changes
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	refresh()
end)
player:GetPropertyChangedSignal("Team"):Connect(refresh)
player:GetAttributeChangedSignal("PartyMembers"):Connect(refresh)
Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function() task.wait(0.2) refresh() end)
end)
for _, p in Players:GetPlayers() do
	p.CharacterAdded:Connect(function() task.wait(0.2) refresh() end)
end
refresh()
