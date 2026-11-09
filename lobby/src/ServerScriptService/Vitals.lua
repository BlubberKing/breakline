-- Vitals v1 (ModuleScript in ServerScriptService, named "Vitals") - LOBBY place only. NEW in v5.17 (GDD 5.13 TRAINING ZONE).
-- The lobby version of Breakline's Vitals: NOTHING IS EVER HURT. GunServer / GadgetServer (the same code as a match) call Vitals.Damage for every hit; here it
-- only returns the damage (so the numbers, hitmarkers, damage indicators and card effects work) and keeps a VIRTUAL health pool per target so a kill can still be
-- shown (kill banner, Hot Barrel): Vitals.Killed(hum) is true once when the virtual health hit 0 (then it refills at once). Real Humanoid health never changes.
--   Vitals.Damage(hum, dmg) -> dealt, 0
--   Vitals.Killed(hum)      -> true once after a hit that would have killed the target
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CardFx = require(RS:WaitForChild("CardEffects"))

local V = {}
V.MAX_HEALTH = 250
V.RESET_AFTER = 4 -- seconds without a hit before the virtual health is full again

local virt = {}   -- humanoid -> { hp, t }
local killed = {} -- humanoid -> true (read once by Killed)

local function maxFor(hum)
	local plr = CardFx.PlayerOf(hum)
	if plr then return V.MAX_HEALTH + (CardFx.Has(plr, "thick_skin") and CardFx.THICK_SKIN_HEALTH or 0) end
	return math.max(hum.MaxHealth, 1) -- sentries / dummies: their own health
end

function V.Damage(hum, dmg)
	if not hum or hum.Health <= 0 or dmg <= 0 then return 0, 0 end
	local victim = CardFx.PlayerOf(hum)
	if victim and CardFx.Has(victim, "glass_cannon") then dmg *= CardFx.GLASS_CANNON_TAKE end
	local now = os.clock()
	local v = virt[hum]
	if not v or now - v.t > V.RESET_AFTER then v = { hp = maxFor(hum), t = now } virt[hum] = v end
	v.t = now
	v.hp -= dmg
	if v.hp <= 0 then
		killed[hum] = true
		virt[hum] = nil
	end
	return dmg, 0
end

function V.Killed(hum)
	if killed[hum] then
		killed[hum] = nil
		return true
	end
	return false
end

function V.RegenDelayFor() return 12 end
function V.MaxFor(p) return V.MAX_HEALTH + (CardFx.Has(p, "thick_skin") and CardFx.THICK_SKIN_HEALTH or 0) end

Players.PlayerRemoving:Connect(function(p)
	if p.Character then
		local h = p.Character:FindFirstChildOfClass("Humanoid")
		if h then virt[h], killed[h] = nil, nil end
	end
end)

return V
