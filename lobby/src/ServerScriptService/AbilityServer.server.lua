-- AbilityServer v2 (Script in ServerScriptService) - BOTH games. Keep the two copies identical.
-- Movement abilities run on the client (AbilityClient). This script only relays what the server (and the other players) care about:
--   * the character attribute "AbilityMode" ("wallrun" / "climb" / nil), so other scripts can read it:
--       - GunServer refuses shots while AbilityMode == "climb" (you cannot shoot while wall-climbing; wall-running is fine)
--       - other players' clients pose you with it (AbilityPose)
--   * v2: the character attribute "WallNormal" (Vector3, the wall you are on), so every client can lean / animate you correctly.
-- Client -> server remote: ReplicatedStorage.AbilityRemotes.State (mode: string "" | "wallrun" | "climb", normal: Vector3 optional).
-- The server checks that the player's saved loadout really has the matching ability, so a modified client cannot fake it.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local folder = Instance.new("Folder")
folder.Name = "AbilityRemotes"
local State = Instance.new("RemoteEvent")
State.Name = "State"
State.Parent = folder
folder.Parent = RS

local NEEDS = { wallrun = "WRUN", climb = "WCLIMB" }
local lastSent = {}

local function moveOf(player)
	local raw = player:GetAttribute("LoadoutJson")
	if type(raw) ~= "string" then return "" end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	return (ok and type(t) == "table" and type(t.Move) == "string") and t.Move or ""
end

State.OnServerEvent:Connect(function(player, mode, normal)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if mode == nil or mode == "" then
		char:SetAttribute("AbilityMode", nil)
		char:SetAttribute("WallNormal", nil)
		return
	end
	if type(mode) ~= "string" then return end
	local need = NEEDS[mode]
	if not need or moveOf(player) ~= need then return end
	local now = os.clock()
	if now - (lastSent[player] or 0) < 0.08 and char:GetAttribute("AbilityMode") == mode then return end -- rate limit the keep-alive updates
	lastSent[player] = now
	char:SetAttribute("AbilityMode", mode)
	if typeof(normal) == "Vector3" and normal.Magnitude > 0.5 and normal.Magnitude < 1.5 then
		char:SetAttribute("WallNormal", normal.Unit)
	end
end)

Players.PlayerRemoving:Connect(function(p) lastSent[p] = nil end)
