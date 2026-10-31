-- LobbyMotion v1 (LocalScript in StarterPlayer > StarterCharacterScripts) - LOBBY place only. NEW in v4.0.
-- Gives the lobby the SAME movement as Breakline, without any gun: sprint speed, crouch speed and the mobile / gamepad sprint toggle.
-- (Breakline's GunClient does this job there; Movement.client = slide / crouch / mantle / momentum jumps, AbilityClient = movement
--  ability, AbilityPose = wall run / climb animation are the very same files as in Breakline.)
--   walk 16 / sprint 30 (hold Shift, or the mobile Sprint button / gamepad left stick click) / crouch 9
-- Camera: the normal Roblox camera (the gun third-person system is gone). Set FIRST_PERSON = true for the Breakline first person camera;
-- it switches back to the free camera by itself while the lobby menu (PLAY screen) is open so the mouse works there.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")

local FIRST_PERSON = false
local WALK_SPEED, SPRINT_SPEED, CROUCH_SPEED = 16, 30, 9

local player = Players.LocalPlayer
local char = script.Parent
local hum = char:WaitForChild("Humanoid")

local sprintToggle = false
local function setSprintToggle(on)
	if sprintToggle == on then return end
	sprintToggle = on
	char:SetAttribute("SprintToggle", on)
	local b = CAS:GetButton("SprintToggle")
	if b then b.ImageColor3 = on and Color3.fromRGB(255, 140, 30) or Color3.new(1, 1, 1) end
end
CAS:BindAction("SprintToggle", function(_, state)
	if state == Enum.UserInputState.Begin then
		setSprintToggle(not sprintToggle)
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.ButtonL3)
CAS:SetTitle("SprintToggle", "Sprint")
CAS:SetPosition("SprintToggle", UDim2.new(1, -95, 1, -175))

local stillTime = 0
local conn
conn = RunService.Heartbeat:Connect(function(dt)
	if not char.Parent or hum.Health <= 0 then return end
	local menu = player:GetAttribute("LobbyMenuOpen") == true
	local moving = hum.MoveDirection.Magnitude > 0.1
	local shift = not menu and (UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift))
	if sprintToggle then
		stillTime = moving and 0 or stillTime + dt
		if stillTime > 0.3 then setSprintToggle(false) end
	end
	local crouching = char:GetAttribute("Crouching") == true
	local wantsSprint = (shift or sprintToggle) and moving and not crouching
	local base = crouching and CROUCH_SPEED or (wantsSprint and SPRINT_SPEED or WALK_SPEED)
	hum.WalkSpeed = base * (char:GetAttribute("AbilitySlow") or 1)
	if FIRST_PERSON then
		local want = menu and Enum.CameraMode.Classic or Enum.CameraMode.LockFirstPerson
		if player.CameraMode ~= want then player.CameraMode = want end
	end
end)
hum.Died:Connect(function()
	CAS:UnbindAction("SprintToggle")
	if conn then conn:Disconnect() end
end)
