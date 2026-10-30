-- LobbyGun v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in GDD v3.8.
-- Lets you use your loadout GUN in the lobby (your movement ability is AbilityClient, same as in Breakline). It is a toy:
--   * THIRD PERSON (the normal lobby camera, mouse cursor visible, you are NOT forced into first person). Aim = where the mouse points.
--   * LEFT CLICK shoots, RIGHT MOUSE (hold) = aim pose + a little zoom, R = reload. Fire rate / mag / reload / spread come from WeaponConfig.
--   * It does NOTHING to other players: nothing is ever sent that could damage anyone (LobbyGunServer only makes the muzzle flash).
--     Hitting a player shows the usual hit marker + damage number so you can see what the gun would do, but no health changes.
--   * Disabled while the lobby menu (PLAY screen) is open (LobbyClient sets the Player attribute LobbyMenuOpen).
--   * Hotbar, bottom left: [GUN: picture, name, ammo]  gap  [MOVEMENT: icon]  (gadgets are not in the lobby).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Weapons = require(RS:WaitForChild("WeaponConfig"))
local GunMath = require(RS:WaitForChild("GunMath"))
local Sfx = require(RS:WaitForChild("Sfx"))
local HitFX = require(RS:WaitForChild("HitFX"))
local UI = require(RS:WaitForChild("UIKit"))
local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local GunModels = RS:FindFirstChild("GunModels") and require(RS.GunModels) or nil
local Remotes = RS:WaitForChild("GunRemotes")
local FireRemote, ReloadRemote = Remotes:WaitForChild("Fire"), Remotes:WaitForChild("Reload")
local K, F, new = UI.C, UI.F, UI.new
local rnd = Random.new()

local BASE_FOV, AIM_FOV = 70, 56

-- ================= hotbar =================
local gui = new("ScreenGui", { Name = "LobbyGunHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20 }, player:WaitForChild("PlayerGui"))
local fx = HitFX.new(gui)
local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 36, 1, -36), Size = UDim2.fromOffset(330, 92), BackgroundTransparency = 1 }, gui)

local SLOT = 84
local function slot(x, w, key)
	local f = new("Frame", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, SLOT), BackgroundColor3 = K.void, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, bar)
	local st = new("UIStroke", { Color = K.line2, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(7, 4), Size = UDim2.fromOffset(24, 14), Text = key, TextSize = 12, FontFace = F.MB,
		TextColor3 = K.dim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 }, f)
	return f, st
end
local GUN_W, GAP = 180, 22
local gunSlot, gunStroke = slot(0, GUN_W, "LMB")
local moveSlot, moveStroke = slot(GUN_W + GAP, SLOT, "SPACE")
gunStroke.Color = K.text
local gunName = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 60), Size = UDim2.fromOffset(GUN_W - 70, 20), Text = "", TextSize = 16,
	FontFace = F.H, TextColor3 = K.text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 }, gunSlot)
local ammoLbl = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(GUN_W - 82, 52), Size = UDim2.fromOffset(74, 28), Text = "", TextSize = 24,
	FontFace = F.H, TextColor3 = K.text, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 }, gunSlot)
local reloadBack = new("Frame", { Position = UDim2.fromOffset(0, SLOT - 4), Size = UDim2.fromOffset(GUN_W, 4), BackgroundColor3 = K.panel3, BorderSizePixel = 0, Visible = false, ZIndex = 6 }, gunSlot)
local reloadFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.text, BorderSizePixel = 0, ZIndex = 7 }, reloadBack)
local picBox = new("Frame", { Position = UDim2.fromOffset(30, 6), Size = UDim2.fromOffset(GUN_W - 40, 50), BackgroundTransparency = 1, ZIndex = 3 }, gunSlot)
local moveBox = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3 }, moveSlot)
local noteLbl = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, SLOT + 4), Size = UDim2.fromOffset(330, 14), Text = "LOBBY TRAINING  -  NO DAMAGE",
	TextSize = 11, FontFace = F.M, TextColor3 = K.mute, TextXAlignment = Enum.TextXAlignment.Left }, bar)

local function gunPicture(parent, id)
	for _, c in parent:GetChildren() do c:Destroy() end
	if not GunModels then return end
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(160, 162, 168),
		LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.3) }, parent)
	local ok, desc = pcall(GunModels.Describe, id, "Iron")
	if not ok or not desc then return end
	local model = new("Model", {}, vp)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = (d.Glow and K.red) or d.Color,
				Material = d.Material or Enum.Material.SmoothPlastic, Transparency = d.Transparency or 0 }, model)
			if d.Shape then p.Shape = d.Shape end
			minV, maxV = minV:Min(d.CF.Position - d.Size / 2), maxV:Max(d.CF.Position + d.Size / 2)
		end
	end
	local center = (minV + maxV) / 2
	local len = math.max(maxV.Z - minV.Z, (maxV.Y - minV.Y) * 2.2)
	local cam = new("Camera", { FieldOfView = 16 }, vp)
	local dist = (len / 2) / math.tan(math.rad(8)) / 2.2 + 1
	cam.CFrame = CFrame.lookAt(center + Vector3.new(dist, dist * 0.08, 0), center)
	vp.CurrentCamera = cam
end

-- ================= state =================
local weaponId, cfg = nil, nil
local ammo, reloading, reloadStart = 0, false, 0
local lastShot, burstLeft, burstNext = 0, 0, 0
local triggerDown, aimHeld = false, false
local lastCombat = 0
local moveId = nil

local function readLoadout()
	local raw = player:GetAttribute("LoadoutJson")
	local w, m = Catalog.DefaultWeapon, ""
	if type(raw) == "string" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			if Catalog.Is(t.Weapon, "weapon") then w = t.Weapon end
			if Catalog.Is(t.Move, "move") then m = t.Move end
		end
	end
	return w, m
end

local function refreshHotbar()
	local w, m = readLoadout()
	if w ~= weaponId then
		weaponId = w
		cfg = Weapons.Get(w)
		ammo, reloading = cfg.MagSize, false
		gunName.Text = string.upper(cfg.Name or w)
		gunPicture(picBox, w)
	end
	if m ~= moveId then
		moveId = m
		for _, c in moveBox:GetChildren() do c:Destroy() end
		local item = Catalog.ById[m]
		if item then
			local ic = UI.AbilityIcon(moveBox, m, 44, item.color)
			ic.AnchorPoint, ic.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			moveStroke.Color = item.color
		else
			new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "+", TextSize = 30, FontFace = F.H, TextColor3 = K.mute }, moveBox)
			moveStroke.Color = K.line2
		end
	end
end
player:GetAttributeChangedSignal("LoadoutJson"):Connect(refreshHotbar)
refreshHotbar()

-- ================= shooting =================
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = false
local function menuOpen() return player:GetAttribute("LobbyMenuOpen") == true end

local function myChar()
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then return ch end
end

local function muzzlePos(ch)
	local gun = ch:FindFirstChild("TPGun")
	local m = gun and gun:FindFirstChild("Muzzle", true)
	if m and m:IsA("BasePart") then return m.Position end
	local head = ch:FindFirstChild("Head")
	return head and head.Position or ch:GetPivot().Position
end

local function aimPoint(ch)
	local loc = UIS:GetMouseLocation()
	local ray = camera:ViewportPointToRay(loc.X, loc.Y)
	rayParams.FilterDescendantsInstances = { ch, camera, workspace:FindFirstChild("ClientFX") }
	local r = workspace:Raycast(ray.Origin, ray.Direction * 800, rayParams)
	return r and r.Position or (ray.Origin + ray.Direction * 800)
end

local function startReload()
	if reloading or not cfg or ammo >= cfg.MagSize or not myChar() then return end
	reloading, reloadStart = true, os.clock()
	burstLeft = 0
	ReloadRemote:FireServer(weaponId)
	pcall(Sfx.Play, "Reload", nil, nil, nil, weaponId)
end

local function shoot()
	local ch = myChar()
	if not ch or not cfg then return end
	ammo -= 1
	lastShot, lastCombat = os.clock(), os.clock()
	local from = muzzlePos(ch)
	local target = aimPoint(ch)
	local baseDir = (target - from).Unit
	local spreadDeg = (aimHeld and cfg.SpreadADS or cfg.SpreadHip) * 0.6
	rayParams.FilterDescendantsInstances = { ch, camera, workspace:FindFirstChild("ClientFX") }
	for i = 1, cfg.Pellets do
		local sp = spreadDeg + (cfg.Pellets > 1 and cfg.PelletSpread or 0)
		local dir = baseDir
		if sp > 0 then
			local a, r = rnd:NextNumber(0, math.pi * 2), math.rad(sp) * math.sqrt(rnd:NextNumber())
			local cf = CFrame.lookAt(Vector3.zero, baseDir)
			dir = (cf * CFrame.Angles(0, 0, a) * CFrame.Angles(r, 0, 0)).LookVector
		end
		local res = workspace:Raycast(from, dir * cfg.Range, rayParams)
		local hitPos = res and res.Position or from + dir * cfg.Range
		if i <= 4 or i % 2 == 0 then fx:Tracer(from, hitPos) end
		if res then
			local model = res.Instance:FindFirstAncestorOfClass("Model")
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			if hum and model ~= ch then
				-- DISPLAY ONLY: the number the gun would do. Nothing is sent to the server, health never changes.
				local head = GunMath.IsHeadshot(res.Instance)
				local dmg = math.floor(GunMath.Damage(cfg, (hitPos - from).Magnitude, head) + 0.5)
				fx:Hit(model, hitPos, res.Normal, dmg, head)
				fx:Number(model, hitPos, dmg, head)
			elseif not hum then
				fx:Impact(hitPos, res.Normal, res.Instance)
			end
		end
	end
	pcall(Sfx.Play, "Fire", nil, cfg.FirePitch, cfg.FireVolume, weaponId)
	pcall(Sfx.Play, "FireTail", nil, cfg.FirePitch, cfg.FireVolume, weaponId)
	FireRemote:FireServer(weaponId) -- the server only turns this into the muzzle flash (no damage code in the lobby)
	if ammo <= 0 then startReload() end
end

local function trigger(now)
	if not cfg or reloading or ammo <= 0 then return end
	if cfg.FireMode == "Burst" then
		if burstLeft > 0 then
			if now >= burstNext then burstLeft -= 1; burstNext = now + 60 / cfg.BurstRPM; shoot() end
		end
		return
	end
	if now - lastShot >= 60 / cfg.RPM then shoot() end
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe or menuOpen() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		triggerDown = true
		if cfg and cfg.FireMode == "Burst" and burstLeft <= 0 and not reloading and ammo > 0 and os.clock() - lastShot >= cfg.BurstDelay then
			burstLeft, burstNext = cfg.BurstCount, 0
		end
		if cfg and cfg.FireMode ~= "Auto" and cfg.FireMode ~= "Burst" then trigger(os.clock()) end -- semi: one shot per click
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		aimHeld = true
	elseif input.KeyCode == Enum.KeyCode.R then
		startReload()
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then triggerDown = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = false end
end)

-- ================= per frame =================
local fov = BASE_FOV
RunService.RenderStepped:Connect(function(dt)
	local ch = myChar()
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local root = ch and ch:FindFirstChild("HumanoidRootPart")
	local menu = menuOpen()
	bar.Visible = not menu and ch ~= nil
	if menu or not ch or not cfg then
		triggerDown, aimHeld, burstLeft = false, false, 0
		if fov ~= BASE_FOV and camera.FieldOfView < BASE_FOV then camera.FieldOfView = BASE_FOV end
		return
	end
	local now = os.clock()
	if triggerDown and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then triggerDown = false end

	if reloading then
		local u = (now - reloadStart) / cfg.ReloadTime
		reloadBack.Visible = true
		reloadFill.Size = UDim2.fromScale(math.clamp(u, 0, 1), 1)
		if u >= 1 then reloading, ammo = false, cfg.MagSize reloadBack.Visible = false end
	else
		reloadBack.Visible = false
	end
	if triggerDown and not reloading and ch:GetAttribute("AbilityMode") ~= "climb" then
		if cfg.FireMode == "Auto" or cfg.FireMode == "Burst" then trigger(now) end
	end
	if ch:GetAttribute("AbilityMode") == "climb" then triggerDown, burstLeft = false, 0 end
	ammoLbl.Text = reloading and "..." or tostring(ammo)
	ammoLbl.TextColor3 = (ammo <= cfg.MagSize * 0.25 and not reloading) and K.redHi or K.text

	-- aim zoom (the third-person pose reads the camera FOV: below 66 = aim-down-sights pose)
	local want = (aimHeld and not reloading) and AIM_FOV or BASE_FOV
	fov += (want - fov) * math.min(1, dt * 12)
	camera.FieldOfView = fov

	-- face where you shoot / aim (otherwise the character keeps walking direction); not while wall-running / climbing
	if hum and root and (triggerDown or aimHeld or now - lastCombat < 0.8) and not ch:GetAttribute("AbilityMode") and not root.Anchored then
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.05 then
			local cur = root.CFrame
			local goal = CFrame.lookAt(cur.Position, cur.Position + flat)
			root.CFrame = cur:Lerp(goal, math.min(1, dt * 16))
		end
	end
	-- the pitch of the gun follows the camera (ThirdPersonClient reads the camera), nothing to do here
end)

player.CharacterAdded:Connect(function()
	ammo, reloading, burstLeft = cfg and cfg.MagSize or 0, false, 0
end)
