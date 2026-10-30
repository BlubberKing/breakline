-- AbilityServer v1 (Script in ServerScriptService) - BOTH games (v3.8). Keep the two copies identical.
-- Movement abilities run on the client (AbilityClient). This script only relays the ONE thing the server cares about:
-- the character attribute "AbilityMode" ("wallrun" / "climb" / nil), so other scripts can read it:
--   * GunServer refuses shots while AbilityMode == "climb" (you cannot shoot while wall-climbing; wall-running is fine)
--   * other players' clients can see it
-- Client -> server remote: ReplicatedStorage.AbilityRemotes.State (string "" | "wallrun" | "climb").
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

local function moveOf(player)
	local raw = player:GetAttribute("LoadoutJson")
	if type(raw) ~= "string" then return "" end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	return (ok and type(t) == "table" and type(t.Move) == "string") and t.Move or ""
end

State.OnServerEvent:Connect(function(player, mode)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if mode == nil or mode == "" then
		char:SetAttribute("AbilityMode", nil)
		return
	end
	if type(mode) ~= "string" then return end
	local need = NEEDS[mode]
	if not need or moveOf(player) ~= need then return end
	char:SetAttribute("AbilityMode", mode)
end)
