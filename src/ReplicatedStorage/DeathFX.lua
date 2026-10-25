-- DeathFX: the death effect (client only; MatchClient calls DeathFX.Play on the "SoulFX" remote, everyone sees it).
--   1) a handful of blue souls burst out of the body in random directions
--   2) they curve in and meet in a point above the player (small soft flash)
--   3) they merge into one bright orb that shoots straight up into the sky with a trail + rocket-style whoosh
--   4) when it reaches the sky there is a big star-like GLINT for about a second
-- Kept light on purpose: tiny parts, short life, no screen flashes, low light range, so it never covers a gunfight.
-- Tuning numbers are in T below.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local DeathFX = {}

local T = {
	Souls       = 9,
	BurstTime   = 0.55,  -- seconds souls fly outward
	MeetTime    = 0.45,  -- seconds they curve in to the meeting point
	MeetHeight  = 7,     -- studs above the player where they meet
	BurstRadius = 6,     -- how far out they fly (studs)
	RiseTime    = 1.5,   -- seconds the orb takes to reach the sky
	SkyHeight   = 650,   -- studs above the player the glint appears
	GlintTime   = 1.1,   -- seconds the sky glint lasts
	GlintSize   = 260,   -- pixels (screen size of the star)
}

local BLUE = Color3.fromRGB(80, 170, 255)
local ICE = Color3.fromRGB(190, 230, 255)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function softPart(size, color, pos, shape)
	local p = Instance.new("Part")
	p.Shape = shape or Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	return p
end

local function addTrail(part, width, life, color)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a1.Position = Vector3.new(0, -width / 2, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = life
	tr.LightEmission = 1
	tr.Color = ColorSequence.new(color, BLUE)
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.FaceCamera = true
	tr.Parent = part
	return tr
end

local function emit(parent, props, count)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	if count then e:Emit(count) end
	return e
end

local function bez(a, b, c, t) -- quadratic bezier
	local u = 1 - t
	return a * (u * u) + b * (2 * u * t) + c * (t * t)
end

-- the big star glint in the sky (screen-space billboard, always visible even through geometry)
local function skyGlint(pos)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = pos
	anchor.Parent = workspace
	Debris:AddItem(anchor, T.GlintTime + 0.5)

	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(T.GlintSize, T.GlintSize)
	bb.MaxDistance = 5000
	bb.Parent = anchor

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(0.05, 0.05)
	root.BackgroundTransparency = 1
	root.Parent = bb

	local function bar(w, h, rot)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(w, h)
		f.Rotation = rot
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		local g = Instance.new("UIGradient") -- tapered ends: bright in the middle, fading out
		g.Color = ColorSequence.new(Color3.new(1, 1, 1))
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = f
		f.Parent = root
		return f
	end
	local bars = { bar(1, 0.035, 0), bar(0.035, 1, 0), bar(0.55, 0.02, 45), bar(0.55, 0.02, -45) }

	local glow = Instance.new("Frame") -- soft round core
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.22, 0.22)
	glow.BackgroundColor3 = ICE
	glow.BorderSizePixel = 0
	local gc = Instance.new("UICorner"); gc.CornerRadius = UDim.new(0.5, 0); gc.Parent = glow
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) })
	gg.Parent = glow
	glow.Parent = root

	-- twinkle in (fast), hold, fade out; the star also spins a few degrees
	TweenService:Create(root, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) }):Play()
	TweenService:Create(root, TweenInfo.new(T.GlintTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Rotation = 18 }):Play()
	task.delay(T.GlintTime * 0.45, function()
		local info = TweenInfo.new(T.GlintTime * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(root, info, { Size = UDim2.fromScale(0.15, 0.15) }):Play()
		for _, b in bars do TweenService:Create(b, info, { BackgroundTransparency = 1 }):Play() end
		TweenService:Create(glow, info, { BackgroundTransparency = 1 }):Play()
	end)
end

function DeathFX.Play(pos)
	local cam = workspace.CurrentCamera
	local meet = pos + Vector3.new(0, T.MeetHeight, 0)
	local body = pos + Vector3.new(0, 2.5, 0)
	local rng = Random.new()

	-- build the souls
	local souls = {}
	for i = 1, T.Souls do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then dir = Vector3.yAxis end
		dir = dir.Unit
		local out = body + dir * (T.BurstRadius * rng:NextNumber(0.6, 1.1))
		local s = softPart(Vector3.one * rng:NextNumber(0.35, 0.6), (i % 2 == 0) and BLUE or ICE, body)
		addTrail(s, 0.3, 0.35, ICE)
		-- the swirl: a sideways offset so the way back in curves instead of going straight
		local swirl = dir:Cross(Vector3.yAxis)
		if swirl.Magnitude < 0.1 then swirl = Vector3.xAxis end
		swirl = swirl.Unit * rng:NextNumber(-3, 3)
		table.insert(souls, { part = s, out = out, swirl = swirl })
	end

	-- little glow at the body so the souls feel like they come out of it
	local anchor = softPart(Vector3.one * 0.2, BLUE, body)
	anchor.Transparency = 1
	local startLight = Instance.new("PointLight")
	startLight.Color = BLUE; startLight.Range = 14; startLight.Brightness = 2; startLight.Shadows = false
	startLight.Parent = anchor
	TweenService:Create(startLight, TweenInfo.new(T.BurstTime), { Brightness = 0 }):Play()
	emit(anchor, {
		Texture = SPARK, Color = ColorSequence.new(ICE), LightEmission = 1,
		Size = NumberSequence.new(0.35, 0), Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(180, 180),
	}, 14)
	Debris:AddItem(anchor, 2)

	task.spawn(function()
		-- phase 1+2: burst out (ease out), then curve into the meeting point (ease in)
		local t0 = os.clock()
		local total = T.BurstTime + T.MeetTime
		while true do
			local t = os.clock() - t0
			if t >= total then break end
			for _, s in souls do
				local p
				if t < T.BurstTime then
					local a = 1 - (1 - t / T.BurstTime) ^ 3
					p = body:Lerp(s.out, a)
				else
					local a = (t - T.BurstTime) / T.MeetTime
					a = a * a * (3 - 2 * a)
					p = bez(s.out, s.out:Lerp(meet, 0.5) + s.swirl + Vector3.new(0, 2, 0), meet, a)
				end
				s.part.CFrame = CFrame.new(p)
			end
			RunService.Heartbeat:Wait()
		end
		for _, s in souls do s.part:Destroy() end

		-- meeting flash (small and quick)
		local flash = softPart(Vector3.one * 1.5, Color3.new(1, 1, 1), meet)
		TweenService:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * 8, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.3)

		-- phase 3: the orb + rocket whoosh straight up
		local orb = softPart(Vector3.one * 1.1, Color3.new(1, 1, 1), meet)
		orb.Name = "SoulOrb"
		addTrail(orb, 1.0, 0.7, ICE)
		local light = Instance.new("PointLight")
		light.Color = ICE; light.Range = 18; light.Brightness = 3; light.Shadows = false
		light.Parent = orb
		emit(orb, {
			Texture = SPARK, Color = ColorSequence.new(ICE, BLUE), LightEmission = 1,
			Size = NumberSequence.new(0.6, 0), Transparency = NumberSequence.new(0, 1),
			Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(2, 6), SpreadAngle = Vector2.new(25, 25),
			Rate = 60, EmissionDirection = Enum.NormalId.Bottom,
		}).Enabled = true

		-- a soft sound; the orb carries it so it pans/fades with distance. Uses SoulRocket if you add an ID, else the Wind sound pitched up.
		local snd = Sfx.Play("SoulRocket", orb) or Sfx.Play("Wind", orb, 1.5, 1.1)
		if snd then
			snd.RollOffMaxDistance = 400
			snd.PlaybackSpeed = 0.7
			TweenService:Create(snd, TweenInfo.new(T.RiseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { PlaybackSpeed = 2.0 }):Play()
			task.delay(T.RiseTime * 0.75, function()
				if snd.Parent then TweenService:Create(snd, TweenInfo.new(T.RiseTime * 0.3), { Volume = 0 }):Play() end
			end)
			Debris:AddItem(snd, T.RiseTime + 0.6)
		end

		local sky = meet + Vector3.new(0, T.SkyHeight, 0)
		local r0 = os.clock()
		while true do
			local a = (os.clock() - r0) / T.RiseTime
			if a >= 1 then break end
			local e = a * a -- accelerates like a rocket
			orb.CFrame = CFrame.new(meet:Lerp(sky, e))
			orb.Size = Vector3.one * (1.1 + 0.9 * e)
			RunService.Heartbeat:Wait()
		end
		orb:Destroy()

		-- phase 4: the sky glint
		skyGlint(sky)
	end)
end

return DeathFX
