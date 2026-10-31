-- RespawnReveal v2 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. v3.8, rebuilt in v4.1.
-- When somebody respawns in the middle of a round, MatchServer freezes + protects them and sets the character attributes
--   Revealing = true, RevealStart = server time, RevealBuild = seconds of building (then MatchConfig.REVEAL_DIVE seconds of "dive").
-- Everybody sees: the body built from the FEET UP by blue souls (RevealFX: souls spiral in and are absorbed at a climbing front, light pillar, rune rings).
-- YOU (v4.1) watch it happen: the camera hovers right BEHIND and ABOVE your own body while it is built, then a fast rapid rush (FOV kick, blur, speed
-- streaks) flies the camera back INTO your head - and the moment it lands you are in control. No waiting after that.
-- Purely visual. The server does the freeze + the protection. GunClient keeps the gun away while Revealing is set.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local C = require(RS:WaitForChild("MatchConfig"))
local RevealFX = require(RS:WaitForChild("RevealFX"))
local camera = workspace.CurrentCamera

local CAM_BIND = "BreaklineRevealCam"
local BASE_FOV = 75
local rad = math.rad

-- screen layer: soft fade-in from the spectate / death view, blur + streaks for the dive
local gui = Instance.new("ScreenGui")
gui.Name = "RevealGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 180
gui.Parent = player:WaitForChild("PlayerGui")
local veil = Instance.new("Frame")
veil.Size = UDim2.fromScale(1, 1)
veil.BackgroundColor3 = Color3.fromRGB(8, 16, 30)
veil.BackgroundTransparency = 1
veil.BorderSizePixel = 0
veil.Parent = gui
local streaks = {}
for i = 1, 22 do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Color3.fromRGB(200, 236, 255)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = gui
	streaks[i] = { f = f, a = (i / 22) * math.pi * 2 + math.random() * 0.2, w = math.random(2, 4), len = math.random(120, 260) }
end
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting

local active = {} -- char -> state
local camState -- { char, root, hum, st }

local function parts(char)
	local list = {}
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then table.insert(list, d) end
	end
	return list
end

local function begin(char)
	if active[char] then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local cf, size = char:GetBoundingBox()
	local st = { char = char, root = root, hum = hum, isMe = (char == player.Character) }
	st.start = char:GetAttribute("RevealStart") or workspace:GetServerTimeNow()
	st.build = char:GetAttribute("RevealBuild") or C.REVEAL_BUILD
	st.from = math.clamp(char:GetAttribute("RevealFrom") or 0, 0, 0.95) -- a teammate revived you: the body was already ~86% built while they worked
	st.dive = C.REVEAL_DIVE
	st.feet = cf.Position.Y - size.Y / 2
	st.height = math.max(size.Y, 4)
	st.fx = RevealFX.New({
		parts = function() return parts(char) end,
		x = root.Position.X, z = root.Position.Z, feet = st.feet, height = st.height,
		duration = st.build,
		progress = function() return st.from + (1 - st.from) * ((workspace:GetServerTimeNow() - st.start) / st.build) end,
	})
	active[char] = st
	if st.isMe then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		st.look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
		camState = st
		camera.CameraType = Enum.CameraType.Scriptable
		veil.BackgroundTransparency = 0.15
		TweenService:Create(veil, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	end
end

local function finishMe(st)
	if camState ~= st then return end
	camState = nil
	pcall(function() RunService:UnbindFromRenderStep(CAM_BIND) end)
	local hum = st.hum
	camera.CameraType = Enum.CameraType.Custom
	if hum and hum.Parent then camera.CameraSubject = hum end
	camera.FieldOfView = BASE_FOV
	blur.Size = 0
	for _, s in streaks do s.f.BackgroundTransparency = 1 end
	veil.BackgroundTransparency = 1
end

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

-- the reveal camera (you only)
local function camStep(dt)
	local st = camState
	if not st or not st.root.Parent then return end
	local now = workspace:GetServerTimeNow()
	local t = now - st.start
	local root = st.root
	local pos = root.Position
	local look = st.look
	local up = Vector3.yAxis
	-- where the camera ends up: your eyes (the head), looking where the character faces
	local head = st.char:FindFirstChild("Head")
	local eye = head and (head.Position + up * 0.15) or (pos + up * 1.6)
	local eyeCF = CFrame.lookAt(eye, eye + look)
	-- behind + above the body, easing slowly outward while it is built
	local k = math.clamp(t / st.build, 0, 1)
	local orbit = rad(-14 + 20 * smooth(k)) -- a slow swing from the left shoulder to the right
	local back = (CFrame.Angles(0, orbit, 0) * CFrame.lookAt(Vector3.zero, look)).LookVector
	local hover = pos - back * (8.4 + 1.2 * k) + up * (5.2 + 0.6 * k)
	local aimAt = Vector3.new(pos.X, st.feet + st.height * (0.35 + 0.35 * k), pos.Z)
	local hoverCF = CFrame.lookAt(hover, aimAt)
	local fov = 62 - 4 * k
	if t <= st.build then
		camera.CFrame = hoverCF
		camera.FieldOfView = fov
		blur.Size = 0
		for _, s in streaks do s.f.BackgroundTransparency = 1 end
	else
		-- the dive: fast, accelerating rush into the head. FOV kicks wide, blur + streaks, then lands.
		local u = math.clamp((t - st.build) / st.dive, 0, 1)
		local e = u * u * u -- slow start, violent end
		local p = hoverCF.Position:Lerp(eye, e)
		local rot = hoverCF.Rotation:Lerp(eyeCF.Rotation, smooth(u * 1.15))
		camera.CFrame = CFrame.new(p) * rot
		camera.FieldOfView = fov + (BASE_FOV + 22 - fov) * math.sin(math.min(u, 1) * math.pi * 0.5) - 22 * smooth((u - 0.8) / 0.2)
		blur.Size = 22 * math.sin(u * math.pi)
		local vp = camera.ViewportSize
		local half = vp * 0.5
		local reach = math.sqrt(half.X * half.X + half.Y * half.Y)
		local amt = math.sin(u * math.pi)
		for _, s in streaks do
			local r = (0.25 + 0.8 * ((u * 1.6 + s.a * 0.3) % 1))
			s.f.Position = UDim2.fromOffset(half.X + math.cos(s.a) * reach * r, half.Y + math.sin(s.a) * reach * r)
			s.f.Size = UDim2.fromOffset(s.len * (0.5 + amt), s.w)
			s.f.Rotation = math.deg(s.a)
			s.f.BackgroundTransparency = 1 - 0.7 * amt
		end
		-- hide anything of your own body right at the camera as it lands
		local d = camera.CFrame.Position
		for _, part in st.fx.parts do
			if part.Parent then
				local at = part:IsA("BasePart") and part.Position or (part.Parent:IsA("BasePart") and part.Parent.Position)
				if at and (d - at).Magnitude < 1.5 then part.LocalTransparencyModifier = 1 end
			end
		end
		if u >= 1 then
			veil.BackgroundTransparency = 0.7
			TweenService:Create(veil, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
			finishMe(st)
		end
	end
end

local function finish(char, st)
	active[char] = nil
	st.fx:Finish(false)
	if st.isMe then
		finishMe(st)
		-- your own body stays hidden in first person again (GunClient.hideBody takes over once Revealing is false)
		for _, d in parts(char) do if d.Parent then d.LocalTransparencyModifier = 1 end end
	end
end

RunService.RenderStepped:Connect(function(dt)
	for _, plr in Players:GetPlayers() do
		local ch = plr.Character
		if ch and ch:GetAttribute("Revealing") == true and not active[ch] then begin(ch) end
	end
	for char, st in active do
		if not char.Parent or char:GetAttribute("Revealing") ~= true or not st.root.Parent then
			finish(char, st)
		else
			local now = workspace:GetServerTimeNow()
			-- the souls only fly during the build; during the dive everything is already solid
			if now - st.start <= st.build + 0.05 then st.fx:Step(dt) end
			if st.isMe and camState == st then
				if st.camBound ~= true then
					st.camBound = true
					pcall(function() RunService:UnbindFromRenderStep(CAM_BIND) end)
					RunService:BindToRenderStep(CAM_BIND, Enum.RenderPriority.Camera.Value + 3, camStep)
				end
			end
		end
	end
end)
