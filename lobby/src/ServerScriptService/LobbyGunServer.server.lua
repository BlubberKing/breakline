-- LobbyGunServer v1 (Script in ServerScriptService) - LOBBY place only. NEW in GDD v3.8.
-- The lobby gun is third-person and does NO damage. This script only prepares what the shared third-person gun code needs:
--   * ReplicatedStorage.GunRemotes.Fire / .Reload (RemoteEvents). ThirdPersonServer finds them and turns every Fire into the muzzle flash
--     on everyone's screen, and Reload into the reload animation. NOTHING else listens, so a shot can never hurt anybody.
--   * the Player attributes "Weapon" + "Sight" from the saved lobby loadout (LoadoutJson), so the world gun on your character is your
--     primary weapon (ThirdPersonServer rebuilds it whenever these change).
-- (The Breakline place has the real GunServer instead, which owns those remotes + attributes.)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Weapons = require(RS:WaitForChild("WeaponConfig"))

local folder = Instance.new("Folder")
folder.Name = "GunRemotes"
for _, n in { "Fire", "Reload" } do
	local r = Instance.new("RemoteEvent")
	r.Name = n
	r.Parent = folder
end
folder.Parent = RS

local function apply(p)
	local raw = p:GetAttribute("LoadoutJson")
	local id = Weapons.Default
	if type(raw) == "string" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" and type(t.Weapon) == "string" and Weapons.Weapons[t.Weapon] then id = t.Weapon end
	end
	if p:GetAttribute("Weapon") == id then return end
	p:SetAttribute("Sight", Weapons.Get(id).DefaultSight)
	p:SetAttribute("Weapon", id)
end

local function onPlayer(p)
	p:GetAttributeChangedSignal("LoadoutJson"):Connect(function() apply(p) end)
	apply(p)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
