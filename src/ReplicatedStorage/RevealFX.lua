-- RevealFX (ModuleScript in ReplicatedStorage) - BREAKLINE place only. NEW in v4.1.
-- The "souls build a body" animation, shared by:
--   * RespawnReveal  : a player respawns -> their real character is built bottom-up by souls (timed, ~1.5 s)
--   * SoulClient     : a teammate is REVIVING you -> a ghost copy of your body is built slowly (over the 8 s of the revive), right where they kneel
-- Both are purely local visuals.
--
--   local fx = RevealFX.New({
--       parts    = function() return { BasePart / Decal, ... } end,   -- what gets revealed (re-read a few times a second)
--       x = , z = , feet = , height = ,                                -- where the body stands (world)
--       progress = function() return 0..1 end,                         -- how far along the build is
--       duration = seconds that progress covers (so soul flight times are right),
--       hideNear = Camera or nil,                                      -- first person: never draw anything right at the camera
--       highlightAdornee = Instance or nil,                            -- gets a blue glow that fades out as the body is finished
--       keepHidden = bool,                                             -- own body in first person stays hidden when done
--   })
--   fx:Step(dt)        every frame
--   fx:Finish(fade)    done: restores the parts, flash + rings (fade = true plays the quiet "cancelled" fade instead)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RevealFX = {}

local BLUE, ICE = Color3.fromRGB(70, 160, 255), Color3.fromRGB(200, 236, 255)
local SOULS = 18
local BAND = 0.16 -- fraction of the body height that is the soft edge of the reveal

local fxFolder = workspace:FindFirstChild("RevealFX") or Instance.new("Folder")
if not fxFolder.Parent then fxFolder.Name = "RevealFX"; fxFolder.Parent = workspace end

local function softPart(size, color, transp, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transp or 0
	p.Size = size
	if shape then p.Shape = shape end
	p.Parent = fxFolder
	return p
end

local function ringAt(pos, color, big)
	local p = softPart(Vector3.new(0.15, 1, 1), color, 0.2, Enum.PartType.Cylinder)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, big or 9, big or 9), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.7)
end

local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function partY(d)
	local part = d:IsA("BasePart") and d or d.Parent
	if part and part:IsA("BasePart") then return part.Position.Y end
	return nil
end

-- a soul orb with a short glowing tail
local function makeSoul(i, rng)
	local part = softPart(Vector3.new(0.55, 0.7, 0.55), (i % 2 == 0) and BLUE or ICE, 0.1, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = BLUE, 6, 1.2
	light.Parent = part
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 0.28, 0), Vector3.new(0, -0.28, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.32
	tr.MinLength = 0.05
	tr.Color = ColorSequence.new(ICE, BLUE)
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	tr.LightEmission = 1
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	tr.Parent = part
	return part
end

function RevealFX.New(o)
	local rng = Random.new()
	local self = { o = o, souls = {}, born = os.clock(), nextCollect = 0, front = 0, finished = false }
	self.x, self.z, self.feet, self.height = o.x, o.z, o.feet, math.max(o.height or 5, 4)
	self.duration = math.max(o.duration or 1.5, 0.3)
	self.parts = o.parts()
	for i = 1, SOULS do
		local a = (i / SOULS) * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local u = (i - 0.5) / SOULS -- 0 = feet .. 1 = head: which slice of the body this soul rebuilds
		table.insert(self.souls, {
			part = makeSoul(i, rng), a0 = a, spin = rng:NextNumber(1.6, 2.6) * (i % 2 == 0 and 1 or -1),
			r0 = rng:NextNumber(5.5, 9.5), up0 = rng:NextNumber(2, 7),
			land = 0.1 + 0.78 * u + rng:NextNumber(-0.03, 0.03), slice = u, done = false,
		})
	end
	-- front glow (a disc that climbs the body)
	self.glow = softPart(Vector3.new(3.6, 0.2, 3.6), ICE, 0.55, Enum.PartType.Cylinder)
	local gl = Instance.new("PointLight")
	gl.Color, gl.Range, gl.Brightness = BLUE, 14, 2.5
	gl.Parent = self.glow
	local sp = Instance.new("ParticleEmitter") -- sparkles rising off the front
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(ICE, BLUE)
	sp.LightEmission = 1
	sp.Rate = 55
	sp.Lifetime = NumberRange.new(0.5, 1.0)
	sp.Speed = NumberRange.new(1, 4)
	sp.SpreadAngle = Vector2.new(60, 60)
	sp.EmissionDirection = Enum.NormalId.Right -- (the glow is a rotated cylinder, +X of the part = up in the world)
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sp.Parent = self.glow
	-- a light pillar around the body + two turning rune rings on the floor
	self.pillar = softPart(Vector3.new(self.height * 1.5, 3.6, 3.6), BLUE, 0.9, Enum.PartType.Cylinder)
	self.rings = {}
	for i = 1, 2 do
		local d = i == 1 and 6.4 or 4.2
		local r = softPart(Vector3.new(0.12, d, d), i == 1 and BLUE or ICE, 0.35, Enum.PartType.Cylinder)
		table.insert(self.rings, { part = r, speed = i == 1 and 1.4 or -2.1, ticks = {} })
		for k = 1, 6 do -- six little tick marks around each ring
			local t = softPart(Vector3.new(0.14, 0.14, 0.7), ICE, 0.2)
			table.insert(self.rings[i].ticks, { part = t, a = (k / 6) * math.pi * 2, r = d / 2 })
		end
	end
	ringAt(Vector3.new(self.x, self.feet + 0.1, self.z), BLUE, 11)
	if o.highlightAdornee then
		local hl = Instance.new("Highlight")
		hl.FillColor, hl.OutlineColor = BLUE, ICE
		hl.FillTransparency, hl.OutlineTransparency = 0.35, 0.2
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = o.highlightAdornee
		hl.Parent = o.highlightAdornee
		self.hl = hl
	end
	setmetatable(self, { __index = RevealFX })
	return self
end

function RevealFX:Step(dt)
	if self.finished then return end
	local o = self.o
	local p = math.clamp(o.progress(), 0, 1)
	local T = self.duration
	if os.clock() >= self.nextCollect then
		self.nextCollect = os.clock() + 0.25
		self.parts = o.parts()
	end
	-- the front is tied to the souls that already landed, so the souls really "pay" for the body
	local landed = 0
	for _, s in self.souls do if p >= s.land then landed += 1 end end
	local target = math.clamp(landed / SOULS, 0, 1)
	self.front += (target - self.front) * math.min(1, dt * 12)
	if p >= 0.985 then self.front = 1 end
	local frontY = self.feet + self.height * (self.front * (1 + BAND))
	local cam = workspace.CurrentCamera
	for _, d in self.parts do
		if d.Parent then
			local y = partY(d)
			if y then
				local a = (frontY - y) / (self.height * BAND)
				d.LocalTransparencyModifier = 1 - smooth(a)
				if o.hideNear and cam and (cam.CFrame.Position - (d:IsA("BasePart") and d.Position or d.Parent.Position)).Magnitude < 1.4 then
					d.LocalTransparencyModifier = 1
				end
			end
		end
	end
	local c = Vector3.new(self.x, 0, self.z)
	local fy = math.min(frontY, self.feet + self.height * 1.02)
	self.glow.CFrame = CFrame.new(c.X, fy, c.Z) * CFrame.Angles(0, 0, math.rad(90))
	self.glow.Transparency = 0.5 + 0.4 * (1 - math.sin(p * math.pi))
	-- pillar breathes, brighter in the middle of the build
	self.pillar.CFrame = CFrame.new(c.X, self.feet + self.height * 0.75, c.Z) * CFrame.Angles(0, 0, math.rad(90))
	self.pillar.Transparency = 0.9 + 0.08 * (1 - math.sin(p * math.pi)) + 0.02 * math.sin(os.clock() * 9)
	for _, rg in self.rings do
		local ang = os.clock() * rg.speed
		rg.part.CFrame = CFrame.new(c.X, self.feet + 0.12, c.Z) * CFrame.Angles(0, ang, math.rad(90))
		rg.part.Transparency = 0.35 + 0.5 * smooth((p - 0.8) / 0.2)
		for _, t in rg.ticks do
			t.part.CFrame = CFrame.new(c.X, self.feet + 0.14, c.Z) * CFrame.Angles(0, ang + t.a, 0) * CFrame.new(0, 0, -t.r)
			t.part.Transparency = 0.2 + 0.8 * smooth((p - 0.8) / 0.2)
		end
	end
	if self.hl then
		self.hl.FillTransparency = 0.35 + 0.65 * smooth((p - 0.15) / 0.85)
		self.hl.OutlineTransparency = 0.2 + 0.8 * smooth((p - 0.55) / 0.45)
	end
	-- souls: spiral in, absorbed at their slice
	local life = 0.5 / T -- flight time as a share of the whole build
	local t = os.clock()
	for _, s in self.souls do
		if p >= s.land then
			if not s.done then
				s.done = true
				s.part.Transparency = 1
				local l = s.part:FindFirstChildOfClass("PointLight")
				if l then l.Enabled = false end
				local tr = s.part:FindFirstChildOfClass("Trail")
				if tr then tr.Enabled = false end
			end
		else
			local fly = math.clamp((p - (s.land - life)) / life, 0, 1)
			local u = smooth(fly)
			local ang = s.a0 + s.spin * (1 - fly) * 2.2
			local r = s.r0 * (1 - u) * (1 - u * 0.2) + 0.5 * u
			local y = self.feet + self.height * s.slice + s.up0 * (1 - u) + math.sin(t * 7 + s.a0) * 0.12
			s.part.Position = Vector3.new(c.X + math.cos(ang) * r, y, c.Z + math.sin(ang) * r)
			local pulse = 0.55 + 0.25 * math.sin(t * 10 + s.a0)
			s.part.Size = Vector3.new(pulse, pulse * 1.25, pulse)
			s.part.Transparency = 0.1 + 0.8 * (1 - math.clamp(fly * 5, 0, 1))
		end
	end
end

-- done. quiet = true: the build was cancelled (a revive that was let go): everything just fades.
function RevealFX:Finish(quiet)
	if self.finished then return end
	self.finished = true
	local o = self.o
	for _, d in self.parts do
		if d.Parent then d.LocalTransparencyModifier = (o.keepHidden and 1) or (quiet and 1) or 0 end
	end
	for _, s in self.souls do s.part:Destroy() end
	if self.hl then self.hl:Destroy() end
	local function fadeOut(part)
		if not part or not part.Parent then return end
		TweenService:Create(part, TweenInfo.new(quiet and 0.35 or 0.25), { Transparency = 1 }):Play()
		Debris:AddItem(part, 0.5)
	end
	fadeOut(self.glow); fadeOut(self.pillar)
	for _, rg in self.rings do
		fadeOut(rg.part)
		for _, t in rg.ticks do fadeOut(t.part) end
	end
	if quiet then return end
	local p = softPart(Vector3.new(1, 1, 1), Color3.new(1, 1, 1), 0.2, Enum.PartType.Ball)
	p.Position = Vector3.new(self.x, self.feet + self.height * 0.9, self.z)
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(6, 6, 6), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.4)
	ringAt(Vector3.new(self.x, self.feet + 0.1, self.z), ICE, 13)
end

return RevealFX
