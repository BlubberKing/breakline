-- RespawnReveal v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in GDD v3.8.
-- When somebody respawns in the middle of a round, MatchServer freezes + protects them for MatchConfig.REVEAL_TIME (~1.4 s) and sets
-- the character attributes Revealing = true and RevealStart = server time. Every client then plays this on that character:
--   * the body is revealed from the FEET UP: a soft band of "soul light" climbs the body, everything below it is solid, above it is hidden
--   * ~16 blue souls (same look as the death souls) swoop in from around the body in a spiral and are absorbed at the climbing front,
--     each one "pays" for a slice of the body - the souls the player gave up when they died are literally rebuilding them
--   * a ring on the floor at the start, a glow at the front, a flash when the head is done
-- Purely visual (local parts). The server does the freeze + the protection; GunClient hides the gun while Revealing is set.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local C = require(RS:WaitForChild("MatchConfig"))

local BLUE, ICE = Color3.fromRGB(70, 160, 255), Color3.fromRGB(200, 236, 255)
local SOULS = 16
local BAND = 0.16 -- fraction of the body height that is the soft edge of the reveal

local fxFolder = Instance.new("Folder")
fxFolder.Name = "RevealFX"
fxFolder.Parent = workspace

local active = {} -- char -> state

local function softPart(size, color, transp)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transp or 0
	p.Size = size
	p.Parent = fxFolder
	return p
end

local function ringAt(pos, color)
	local p = softPart(Vector3.new(0.15, 1, 1), color, 0.2)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, 9, 9), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.7)
end

local function collect(st)
	st.parts = {}
	for _, d in st.char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then table.insert(st.parts, d) end
	end
end

local function partY(d)
	local part = d:IsA("BasePart") and d or d.Parent
	if part and part:IsA("BasePart") then return part.Position.Y end
	return nil
end

local function begin(char)
	if active[char] then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local rng = Random.new()
	local st = { char = char, root = root, rng = rng, souls = {}, born = os.clock(), isMe = (char == player.Character), nextCollect = 0 }
	st.start = char:GetAttribute("RevealStart") or workspace:GetServerTimeNow()
	local cf, size = char:GetBoundingBox()
	st.feet = cf.Position.Y - size.Y / 2
	st.height = math.max(size.Y, 4)
	st.x, st.z = root.Position.X, root.Position.Z
	collect(st)
	for i = 1, SOULS do
		local a = (i / SOULS) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local u = (i - 0.5) / SOULS -- 0 = feet .. 1 = head: which slice of the body this soul rebuilds
		local part = softPart(Vector3.new(0.55, 0.7, 0.55), (i % 2 == 0) and BLUE or ICE, 0.1)
		part.Shape = Enum.PartType.Ball
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = BLUE, 6, 1.2
		light.Parent = part
		table.insert(st.souls, {
			part = part, a0 = a, spin = rng:NextNumber(1.6, 2.6) * (i % 2 == 0 and 1 or -1),
			r0 = rng:NextNumber(5.5, 9), up0 = rng:NextNumber(2, 6),
			land = 0.12 + 0.72 * u + rng:NextNumber(-0.04, 0.04), -- arrival time as a fraction of the reveal
			slice = u, done = false,
		})
	end
	-- the front glow
	st.glow = softPart(Vector3.new(3.6, 0.2, 3.6), ICE, 0.55)
	st.glow.Shape = Enum.PartType.Cylinder
	st.glow.Orientation = Vector3.new(0, 0, 90)
	local gl = Instance.new("PointLight")
	gl.Color, gl.Range, gl.Brightness = BLUE, 14, 2.5
	gl.Parent = st.glow
	ringAt(Vector3.new(st.x, st.feet + 0.1, st.z), BLUE)
	active[char] = st
end

local function finish(char, st)
	active[char] = nil
	for _, d in st.parts do
		if d.Parent then d.LocalTransparencyModifier = st.isMe and 1 or 0 end -- your own body stays hidden in first person (GunClient.hideBody)
	end
	for _, s in st.souls do s.part:Destroy() end
	if st.glow then st.glow:Destroy() end
	-- done flash at the head
	local p = softPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), 0.2)
	p.Shape = Enum.PartType.Ball
	p.Position = Vector3.new(st.x, st.feet + st.height * 0.9, st.z)
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(6, 6, 6), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.4)
	ringAt(Vector3.new(st.x, st.feet + 0.1, st.z), ICE)
end

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

RunService.RenderStepped:Connect(function(dt)
	-- pick up characters that started / stopped revealing
	for _, plr in Players:GetPlayers() do
		local ch = plr.Character
		if ch and ch:GetAttribute("Revealing") == true and not active[ch] then begin(ch) end
	end
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera
	for char, st in active do
		if not char.Parent or char:GetAttribute("Revealing") ~= true or not st.root.Parent then
			finish(char, st)
			continue
		end
		local T = C.REVEAL_TIME or 1.4
		local p = math.clamp((now - st.start) / T, 0, 1)
		if os.clock() >= st.nextCollect then st.nextCollect = os.clock() + 0.25 collect(st) end

		-- progress of the front (0..1 of the body height): tied to the souls that already landed, so the souls really "pay" for it
		local landed = 0
		for _, s in st.souls do if p >= s.land then landed += 1 end end
		local target = math.clamp(landed / SOULS, 0, 1)
		st.front = (st.front or 0) + (target - (st.front or 0)) * math.min(1, dt * 14)
		if p >= 0.97 then st.front = 1 end
		local frontY = st.feet + st.height * (st.front * (1 + BAND) )

		-- body parts: solid below the front, a soft band, hidden above
		for _, d in st.parts do
			if d.Parent then
				local y = partY(d)
				if y then
					local a = (frontY - y) / (st.height * BAND)
					d.LocalTransparencyModifier = 1 - smooth(a)
					if st.isMe then -- first person: never draw the head / anything at the camera
						if (cam.CFrame.Position - (d:IsA("BasePart") and d.Position or d.Parent.Position)).Magnitude < 1.4 then d.LocalTransparencyModifier = 1 end
					end
				end
			end
		end

		-- front glow
		st.glow.CFrame = CFrame.new(st.x, math.min(frontY, st.feet + st.height * 1.02), st.z) * CFrame.Angles(0, 0, math.rad(90))
		st.glow.Transparency = 0.5 + 0.4 * (1 - math.sin(p * math.pi))

		-- souls: spiral in, absorbed at their slice
		for _, s in st.souls do
			if p >= s.land then
				if not s.done then
					s.done = true
					s.part.Transparency = 1
					s.part.PointLight.Enabled = false
				end
			else
				local life = 0.5 -- seconds each soul spends flying
				local landT = s.land * T
				local u = smooth((p * T - (landT - life)) / life)
				local fly = math.clamp((p * T - (landT - life)) / life, 0, 1)
				local ang = s.a0 + s.spin * (1 - fly) * 2.2
				local r = s.r0 * (1 - u) * (1 - u * 0.2) + 0.5 * u
				local y = st.feet + st.height * s.slice + s.up0 * (1 - u) + math.sin(os.clock() * 7 + s.a0) * 0.12
				s.part.Position = Vector3.new(st.x + math.cos(ang) * r, y, st.z + math.sin(ang) * r)
				local pulse = 0.55 + 0.25 * math.sin(os.clock() * 10 + s.a0)
				s.part.Size = Vector3.new(pulse, pulse * 1.25, pulse)
				s.part.Transparency = 0.1 + 0.8 * (1 - math.clamp(fly * 5, 0, 1))
			end
		end
	end
end)
