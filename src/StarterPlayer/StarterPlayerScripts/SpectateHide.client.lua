-- SpectateHide v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v4.4.
-- While you are dead (spectating a teammate or free roaming) your own health / squad HUD, your picked-card HUD, the ammo + gadget row and the
-- movement-ability HUD are hidden, so the screen only shows the spectated view and the death bar (DeathScreen). They come back when you respawn.
-- It only switches things back on that IT switched off, so it never fights another script that disabled one of these on purpose.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local HIDE = { MatchHUD2 = true, CardHUD = true, AbilityHUD = true, GunHUD = true }
local hidden = {} -- ScreenGui -> true while WE are keeping it off

local function apply()
	local dead = player:GetAttribute("IsDead") == true
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	for _, g in pg:GetChildren() do
		if g:IsA("ScreenGui") and HIDE[g.Name] then
			if dead then
				if g.Enabled then g.Enabled = false hidden[g] = true end
			elseif hidden[g] then
				hidden[g] = nil
				g.Enabled = true
			end
		end
	end
end

player:GetAttributeChangedSignal("IsDead"):Connect(apply)
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	pg.ChildAdded:Connect(function() task.defer(apply) end)
	apply()
end)
-- cheap safety net: GunHUD / AbilityHUD are rebuilt on every respawn and the death state can flip while they are being created
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end
	acc = 0
	apply()
end)
