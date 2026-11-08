-- Vitals v2.1 (v5.14: power-up cards - EMBER HEART regen 1 s sooner, THICK SKIN +10 max health, GLASS CANNON takes 15% more damage; numbers in
--   ReplicatedStorage.CardEffects) (ModuleScript in ServerScriptService, named "Vitals") - BREAKLINE place only.
-- v4.7: NO MORE SHIELD. Everybody has 250 health. Health does NOT come back on its own until the player has gone REGEN_DELAY (12 s) without
--       taking any damage; after that it refills at REGEN_PER_SEC. Roblox's own default "Health" script (1 % / s regen) is removed.
-- Use Vitals.Damage(humanoid, amount) instead of Humanoid:TakeDamage for anything that can hurt a player (GunServer and GadgetServer do).
-- Anything that lowers health anyway (a script that sets Humanoid.Health directly) also restarts the 12 s timer.
-- Character attributes the clients read: LastHit (server time of the last damage). Shield attributes are no longer set.
-- Roblox's own overhead health bar is switched off (OverheadBars replaces it).
-- Needs no setup: it initialises the first time a script requires it (GunServer / GadgetServer both do).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CardFx = require(game:GetService("ReplicatedStorage"):WaitForChild("CardEffects")) -- v5.14

local V = {}
V.MAX_HEALTH = 250
V.REGEN_DELAY = 12       -- seconds without damage before health starts to come back
V.REGEN_PER_SEC = 20     -- health per second once it does

local lastDamage = {} -- [character] = os.clock() of the last damage

local function stamp(char)
	lastDamage[char] = os.clock()
	char:SetAttribute("LastHit", workspace:GetServerTimeNow())
end

-- v5.14: max health / regen delay for a player (their match card)
function V.MaxFor(p)
	return V.MAX_HEALTH + (CardFx.Has(p, "thick_skin") and CardFx.THICK_SKIN_HEALTH or 0)
end
function V.RegenDelayFor(p)
	return V.REGEN_DELAY - (CardFx.Has(p, "ember_heart") and CardFx.EMBER_HEART_REGEN_SOONER or 0)
end

function V.Damage(hum, dmg)
	-- returns (damage dealt in total, 0). Health is NOT clamped here: read hum.Health afterwards for "killed".
	if not hum or hum.Health <= 0 or dmg <= 0 then return 0, 0 end
	local char = hum.Parent
	local victim = CardFx.PlayerOf(char)
	if victim and CardFx.Has(victim, "glass_cannon") then dmg *= CardFx.GLASS_CANNON_TAKE end -- v5.14: GLASS CANNON takes more
	local before = hum.Health
	hum:TakeDamage(dmg)
	-- v5.8: report what REALLY came off. Humanoid:TakeDamage silently does nothing while the target has a ForceField (spawn / reveal
	-- protection), and the old code still reported the full hit, so the shooter saw damage numbers on a target that took none.
	local dealt = math.max(0, before - hum.Health)
	if char and dealt > 0 then stamp(char) end
	return dealt, 0
end

local function setup(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local owner = Players:GetPlayerFromCharacter(char)
	local maxHp = owner and V.MaxFor(owner) or V.MAX_HEALTH -- v5.14: THICK SKIN
	hum.MaxHealth = maxHp
	hum.Health = maxHp
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	char:SetAttribute("MaxShield", nil)
	char:SetAttribute("Shield", nil)
	lastDamage[char] = -1000
	-- Roblox's default regen script
	task.spawn(function()
		local h = char:WaitForChild("Health", 3)
		if h and h:IsA("Script") then h:Destroy() end
	end)
	-- damage that did not come through Vitals.Damage still restarts the timer
	local last = hum.Health
	hum.HealthChanged:Connect(function(hp)
		if hp < last - 0.01 then stamp(char) end
		last = hp
	end)
	char.AncestryChanged:Connect(function(_, parent) if not parent then lastDamage[char] = nil end end)
end

-- v5.14: the card is picked AFTER the character spawned, so max health follows the MatchCard attribute live
local function applyMax(p)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	local new = V.MaxFor(p)
	local old = hum.MaxHealth
	if math.abs(new - old) < 0.01 then return end
	hum.MaxHealth = new
	if new > old then hum.Health = math.min(new, hum.Health + (new - old)) else hum.Health = math.min(hum.Health, new) end
end

local function onPlayer(p)
	p.CharacterAdded:Connect(setup)
	if p.Character then task.spawn(setup, p.Character) end
	p:GetAttributeChangedSignal("MatchCard"):Connect(function() applyMax(p) end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end

-- regeneration
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then return end
	local step = acc
	acc = 0
	local now = os.clock()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and hum.Health < hum.MaxHealth and p:GetAttribute("IsDead") ~= true then
			local t = lastDamage[char]
			if t and now - t >= V.RegenDelayFor(p) then -- v5.14: EMBER HEART
				hum.Health = math.min(hum.MaxHealth, hum.Health + V.REGEN_PER_SEC * step)
			end
		end
	end
end)

return V
