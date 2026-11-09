-- SettingsServer v1 (Script in ServerScriptService) - BOTH games (Lobby + Breakline), keep the two copies identical. NEW in v5.17 (GDD 5.12).
-- Saves the player's SETTINGS (ReplicatedStorage.Settings): the client sends the table of its values, this checks + clamps it (Settings.Clean),
-- stores it in the shared profile key "Settings" and mirrors it as the Player attribute SettingsJson (ProfileStore does that when the key is set).
-- Remote: ReplicatedStorage.SettingsRemotes.Save (RemoteEvent, one table). Rate limited to one save per 0.4 s.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Settings = require(RS:WaitForChild("Settings"))
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))

local folder = RS:FindFirstChild("SettingsRemotes") or Instance.new("Folder")
folder.Name = "SettingsRemotes"
folder.Parent = RS
local SaveR = folder:FindFirstChild("Save") or Instance.new("RemoteEvent")
SaveR.Name = "Save"
SaveR.Parent = folder

local last = {}
SaveR.OnServerEvent:Connect(function(player, t)
	if os.clock() - (last[player] or 0) < 0.4 then return end
	last[player] = os.clock()
	if type(t) ~= "table" then return end
	local clean = Settings.Clean(t)
	Profiles.WaitFor(player)
	Profiles.Set(player, "Settings", clean)
end)
Players.PlayerRemoving:Connect(function(p) last[p] = nil end)
