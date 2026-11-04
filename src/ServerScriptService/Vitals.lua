-- Vitals v2 (ModuleScript in ServerScriptService, named "Vitals") - BREAKLINE place only.
-- v4.7: NO MORE SHIELD. Everybody has 250 health. Health does NOT come back on its own until the player has gone REGEN_DELAY (12 s) without
--       taking any damage; after that it refills at REGEN_PER_SEC. Roblox's own default "Health" script (1 % / s regen) is removed.
-- Use Vitals.Damage(humanoid, amount) instead of Humanoid:TakeDamage for anything that can hurt a player (GunServer and GadgetServer do).
-- Anything that lowers health anyway (a script that sets Humanoid.Health directly) also restarts the 12 s timer.
-- Character attributes the clients read: LastHit (server time of the last damage). Shield attributes are no longer set.
-- Roblox's own overhead health bar is switched off (OverheadBars replaces it).
-- Needs no setup: it initialises the first time a script requires it (GunServer / GadgetServer both do).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local V = {}
V.MAX_HEALTH = 250
V.REGEN_DELAY = 12       -- seconds without damage before health starts to come back
V.REGEN_PER_SEC = 20     -- health per second once it does

local lastDamage = {} -- [character] = os.clock() of the last damage

local function stamp(char)
	lastDamage[char] = os.clock()
	char:SetAttribute("LastHit", workspace:GetServerTimeNow())
end

function V.Damage(hum, dmg)
	-- returns (damage dealt in total, 0). Health is NOT clamped here: read hum.Health afterwards for "killed".
	if not hum or hum.Health <= 0 or dmg <= 0 then return 0, 0 end
	local char = hum.Parent
	local before = hum.Health
	hum:TakeDamage(dmg)
	if char then stamp(char) end
	return math.min(dmg, before), 0
end

local function setup(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	hum.MaxHealth = V.MAX_HEALTH
	hum.Health = V.MAX_HEALTH
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

local function onPlayer(p)
	p.CharacterAdded:Connect(setup)
	if p.Character then task.spawn(setup, p.Character) end
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
			if t and now - t >= V.REGEN_DELAY then
				hum.Health = math.min(hum.MaxHealth, hum.Health + V.REGEN_PER_SEC * step)
			end
		end
	end
end)

return V
