-- GadgetClient v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v4.0.
-- Throw your 3 loadout gadgets with the keys 2 / 3 / 4 (gamepad: DPad Left / Up / Right; mobile: three buttons). The server (GadgetServer) does the
-- real work; this script only sends the aim direction and plays the visuals the server broadcasts:
--   "Boom"        frag / mine / sentry explosion: flash, fire ball, shock ring, sparks, camera shake (closer = stronger)
--   "Flash"       flashbang: if you could SEE it you are blinded: white-out that fades, colour drain + blur, stronger when you look at it
--   "ShieldBreak" the bubble shield pops: glass shards fly out
-- Refuses to throw while a menu is open, while carrying a Wall Push box, or while wall-climbing (same rules as the gun).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Remotes = RS:WaitForChild("GadgetRemotes")
local UseR, FxR = Remotes:WaitForChild("Use"), Remotes:WaitForChild("FX")
local Sfx
pcall(function() Sfx = require(RS:WaitForChild("Sfx", 3)) end)
local function sound(name, at, pitch, vol) if Sfx then pcall(Sfx.Play, name, at, pitch, vol) end end -- silent until the SoundBank has these slots

local rnd = Random.new()

------------------------------------------------------------------ throwing
local function menuOpen()
	return player:GetAttribute("GunMenuOpen") == true or player:GetAttribute("LobbyMenuOpen") == true
end
local lastThrow = 0
local function use(slot)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or menuOpen() then return end
	if player:GetAttribute("Carrying") == true or char:GetAttribute("AbilityMode") == "climb" or char:GetAttribute("Revealing") == true then return end
	if os.clock() - lastThrow < 0.2 then return end
	local id = player:GetAttribute("GadId" .. slot)
	if not id or id == "" or (player:GetAttribute("GadCount" .. slot) or 0) <= 0 then return end
	if workspace:GetServerTimeNow() < (player:GetAttribute("GadReady" .. slot) or 0) then return end
	lastThrow = os.clock()
	UseR:FireServer(slot, camera.CFrame.LookVector)
end

local KEYS = { Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local PAD = { Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadRight }
for slot = 1, 3 do
	local name = "Gadget" .. slot
	CAS:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then use(slot) end
		return Enum.ContextActionResult.Pass
	end, UIS.TouchEnabled, KEYS[slot], PAD[slot])
	CAS:SetTitle(name, "G" .. slot)
	CAS:SetPosition(name, UDim2.new(1, -95 - (slot - 1) * 70, 1, -255))
end

------------------------------------------------------------------ visuals
local fxFolder = workspace:FindFirstChild("ClientFX") or Instance.new("Folder")
if not fxFolder.Parent then fxFolder.Name = "ClientFX"; fxFolder.Parent = workspace end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in props do p[k] = v end
	p.Parent = fxFolder
	return p
end

local shake = 0
local function boom(pos, radius)
	local fire = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = pos, Color = Color3.fromRGB(255, 170, 60), Transparency = 0.1 })
	TweenService:Create(fire, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 1.25, Transparency = 1 }):Play()
	local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Position = pos, Color = Color3.fromRGB(255, 250, 230), Transparency = 0 })
	TweenService:Create(core, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 0.55, Transparency = 1 }):Play()
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 210, 140), Transparency = 0.3 })
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, radius * 2.2, radius * 2.2), Transparency = 1 }):Play()
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 190, 110), radius * 1.8, 8
	light.Parent = core
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	-- sparks
	local att = fxPart({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 110, 40))
	pe.Lifetime = NumberRange.new(0.3, 0.8)
	pe.Speed = NumberRange.new(radius * 1.2, radius * 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.LightEmission = 1
	pe.Drag = 4
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(40)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 66, 62))
	smoke.Lifetime = NumberRange.new(1.0, 1.8)
	smoke.Speed = NumberRange.new(2, 7)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.25), NumberSequenceKeypoint.new(1, radius * 0.6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Rate = 0
	smoke.Parent = att
	smoke:Emit(14)
	Debris:AddItem(fire, 0.5); Debris:AddItem(core, 0.5); Debris:AddItem(ring, 0.5); Debris:AddItem(att, 2.2)
	sound("Explosion", pos, 1, 1.2)
	local d = (camera.CFrame.Position - pos).Magnitude
	shake = math.max(shake, math.clamp(1 - d / (radius * 5), 0, 1) * 1.1)
end

-- flashbang blind screen
local gui = Instance.new("ScreenGui")
gui.Name = "GadgetFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.Parent = player:WaitForChild("PlayerGui")
local white = Instance.new("Frame")
white.Size = UDim2.fromScale(1, 1)
white.BackgroundColor3 = Color3.new(1, 1, 1)
white.BackgroundTransparency = 1
white.BorderSizePixel = 0
white.Parent = gui
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0
cc.Parent = Lighting
local blind, blindMax = 0, 1 -- seconds left, seconds at the start
local peak = 0

local function flashbang(pos, range, maxTime)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	-- light + pop for everyone
	local pop = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = pos, Color = Color3.new(1, 1, 1), Transparency = 0 })
	TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.one * 16, Transparency = 1 }):Play()
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.new(1, 1, 1), 40, 12
	light.Parent = pop
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	Debris:AddItem(pop, 0.6)
	sound("FlashBang", pos, 1, 1)
	-- line of sight + distance + how much you look at it
	local eye = camera.CFrame.Position
	local to = pos - eye
	local dist = to.Magnitude
	if dist > range then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, camera, fxFolder }
	params.RespectCanCollide = true
	if workspace:Raycast(eye, to, params) then return end
	local look = camera.CFrame.LookVector
	local facing = math.clamp(look:Dot(to.Unit), -1, 1) -- 1 = staring at it
	local view = 0.35 + 0.65 * math.clamp((facing + 0.2) / 1.2, 0, 1) -- behind you still blinds a little
	local near = 1 - math.clamp(dist / range, 0, 1) * 0.7
	local t = maxTime * view * near
	if t < 0.25 then return end
	blind = math.max(blind, t)
	blindMax = math.max(blindMax, blind)
	peak = math.max(peak, math.clamp(0.55 + 0.45 * view, 0, 1))
end

local function shieldBreak(pos, radius, color)
	local att = fxPart({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos + Vector3.new(0, radius * 0.4, 0) })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color or Color3.fromRGB(100, 220, 230))
	pe.LightEmission = 0.9
	pe.Lifetime = NumberRange.new(0.5, 1.1)
	pe.Speed = NumberRange.new(radius * 1.5, radius * 3.2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 0) })
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-200, 200)
	pe.Drag = 2
	pe.Acceleration = Vector3.new(0, -20, 0)
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(60)
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, radius * 1.6, radius * 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color or Color3.fromRGB(100, 220, 230), Transparency = 0.2 })
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, radius * 2.6, radius * 2.6), Transparency = 1 }):Play()
	Debris:AddItem(att, 1.6); Debris:AddItem(ring, 0.5)
	sound("ShieldBreak", pos, 1, 1)
end

FxR.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Boom" then boom(a, b or 12)
	elseif kind == "Flash" then flashbang(a, b or 70, c or 3.5)
	elseif kind == "ShieldBreak" then shieldBreak(a, b or 9, c) end
end)

RunService.RenderStepped:Connect(function(dt)
	-- blind: hold at full white for the first 35%, then fade
	if blind > 0 then
		blind = math.max(blind - dt, 0)
		local u = blind / blindMax
		local a = u > 0.65 and peak or peak * (u / 0.65) ^ 1.4
		white.BackgroundTransparency = 1 - a
		blur.Size = 28 * a
		cc.Saturation = -0.85 * a
		if blind <= 0 then peak, blindMax = 0, 1 end
	elseif white.BackgroundTransparency < 1 then
		white.BackgroundTransparency, blur.Size, cc.Saturation = 1, 0, 0
	end
	-- camera shake from nearby explosions
	if shake > 0.01 then
		shake = shake * math.exp(-dt * 6)
		local s = shake * 0.012
		camera.CFrame = camera.CFrame * CFrame.Angles(rnd:NextNumber(-s, s), rnd:NextNumber(-s, s), rnd:NextNumber(-s, s) * 2)
	end
end)

player.CharacterAdded:Connect(function()
	blind, peak, shake = 0, 0, 0
	white.BackgroundTransparency, blur.Size, cc.Saturation = 1, 0, 0
end)
