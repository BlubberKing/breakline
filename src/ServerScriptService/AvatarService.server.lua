-- AvatarService v2 (Script in ServerScriptService) - used by BOTH games (Breakline + Lobby). Keep the two copies identical.
-- Every player spawns as a blocky operator wearing their EQUIPPED SKIN (ReplicatedStorage.Skins).
-- The skin comes from the shared profile key "Skin" (mirrored to the Player attribute "Skin" by ProfileStore; new players = Skins.Default).
-- In a match the skin's glowing accent parts take the team color; in the lobby they keep the skin's own accent color.
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local RS = game:GetService("ReplicatedStorage")
local Skins = require(RS:WaitForChild("Skins"))

StarterPlayer.LoadCharacterAppearance = false

local function accentFor(player)
	if player.Team and not player.Neutral then return player.TeamColor.Color end
	return nil -- skin's own accent
end

local function skinOf(player)
	local s = player:GetAttribute("Skin")
	return Skins.Is(s) and s or Skins.Default
end

local function dress(player, char)
	Skins.Dress(char, skinOf(player), accentFor(player))
end

local function recolor(player)
	local char = player.Character
	if not char then return end
	local A = accentFor(player) or Skins.Get(skinOf(player)).colors.Accent
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("TeamAccent") and d:IsDescendantOf(char:FindFirstChild("Gear") or char) then d.Color = A end
	end
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) dress(player, char) end)
	player:GetPropertyChangedSignal("Team"):Connect(function() recolor(player) end)
	player:GetPropertyChangedSignal("TeamColor"):Connect(function() recolor(player) end)
	-- the profile loads a moment after joining, and the lobby can change skins: re-dress when the skin changes
	player:GetAttributeChangedSignal("Skin"):Connect(function()
		local char = player.Character
		local gear = char and char:FindFirstChild("Gear")
		if char and (not gear or gear:GetAttribute("Skin") ~= skinOf(player)) then task.spawn(dress, player, char) end
	end)
	if player.Character then task.spawn(dress, player, player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do task.spawn(onPlayer, p) end
