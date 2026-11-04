-- Vitals v1 (ModuleScript in ServerScriptService, named "Vitals") - BREAKLINE place only. NEW in v4.4.
-- Health + SHIELD for every player character.
--   * Every character spawns with 200 health (MaxHealth 200) and a 100 SHIELD (character attributes Shield / MaxShield).
--   * Damage goes into the shield FIRST; whatever is left goes into health. Use Vitals.Damage(humanoid, amount) instead of Humanoid:TakeDamage
--     for anything that can hurt a player (GunServer and GadgetServer do). Things without a Shield attribute (sentries) just take the damage.
--   * Character attributes the clients read (MatchHUD bars, OverheadBars): Shield, MaxShield, LastShieldHit (server time of the last hit that
--     touched the shield), LastHit (server time of the last hit of any kind).
--   * Roblox's own overhead health bar is switched off (OverheadBars replaces it).
-- Needs no setup: it initialises the first time a script requires it (GunServer / GadgetServer both do).
local Players = game:GetService("Players")

local V = {}
V.MAX_HEALTH = 200
V.MAX_SHIELD = 100

function V.Damage(hum, dmg)
	-- returns (damage dealt in total, damage that went into the shield). Health is NOT clamped here: read hum.Health afterwards for "killed".
	if not hum or hum.Health <= 0 or dmg <= 0 then return 0, 0 end
	local char = hum.Parent
	local shield = char and char:GetAttribute("Shield") or 0
	local inShield = 0
	if shield > 0 then
		inShield = math.min(shield, dmg)
		char:SetAttribute("Shield", shield - inShield)
		char:SetAttribute("LastShieldHit", workspace:GetServerTimeNow())
	end
	local rest = dmg - inShield
	local before = hum.Health
	if rest > 0 then hum:TakeDamage(rest) end
	if char then char:SetAttribute("LastHit", workspace:GetServerTimeNow()) end
	return inShield + math.min(rest, before), inShield
end

local function setup(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.MaxHealth = V.MAX_HEALTH
	hum.Health = V.MAX_HEALTH
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	char:SetAttribute("MaxShield", V.MAX_SHIELD)
	char:SetAttribute("Shield", V.MAX_SHIELD)
end

local function onPlayer(p)
	p.CharacterAdded:Connect(setup)
	if p.Character then task.spawn(setup, p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end

return V
