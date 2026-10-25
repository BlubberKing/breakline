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
	Souls       = 10,
	SoulsToYou  = 4,     -- how many of them fly into YOUR view when it is your own death
	BurstTime   = 0.55,  -- seconds souls fly outward
	MeetTime    = 0.45,  -- seconds they curve in to the meeting point
	MeetHeight  = 7,     -- studs above the player where they meet
	BurstRadius = 6,     -- how far out they fly (studs)
	RiseTime    = 1.9,   -- seconds the orb takes to reach the sky
	SkyHeight   = 800,   -- studs above the player the glint appears
	GlintTime   = 1.8,   -- seconds the sky glint lasts
	GlintSize   = 560,   -- pixels (screen size of the star)
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


-- a soul: glowing teardrop wisp. Head = squashed glowing ball with a tiny ghost face, tail = long tapered trail that wiggles.
local function makeSoul(pos, color, size)
	local head = softPart(Vector3.new(size, size * 1.25, size), color, pos)
	head.Transparency = 0.15
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size * 1.9, size * 1.9)
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.MaxDistance = 250
	bb.Parent = head
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(1, 1)
	halo.BackgroundColor3 = ICE
	halo.BackgroundTransparency = 0.75
	halo.BorderSizePixel = 0
	halo.Parent = bb
	local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0.5, 0); hc.Parent = halo
	for _, ex in { 0.34, 0.66 } do
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(ex, 0.45)
		eye.Size = UDim2.fromScale(0.13, 0.2)
		eye.BackgroundColor3 = Color3.fromRGB(10, 40, 90)
		eye.BorderSizePixel = 0
		eye.Parent = halo
		local ec = Instance.new("UICorner"); ec.CornerRadius = UDim.new(0.5, 0); ec.Parent = eye
	end
	local mouth = Instance.new("Frame")
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.5, 0.72)
	mouth.Size = UDim2.fromScale(0.14, 0.12)
	mouth.BackgroundColor3 = Color3.fromRGB(10, 40, 90)
	mouth.BorderSizePixel = 0
	mouth.Parent = halo
	local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0.5, 0); mc.Parent = mouth
	local tr = addTrail(head, size * 1.1, 0.6, ICE)
	tr.Transparency = NumberSequence.new(0.2, 1)
	return head
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

-- where "you" are: your character's chest, or the camera when it is your own death
local function viewerTarget(pos)
	local cam = workspace.CurrentCamera
	local plr = game:GetService("Players").LocalPlayer
	local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	if (root.Position - pos).Magnitude < 8 then -- it is your own death: fly at the lens
		return function() return cam.CFrame.Position + cam.CFrame.LookVector * 1.2 end, true
	end
	if (root.Position - pos).Magnitude > 140 then return nil end
	return function() return root.Position + Vector3.new(0, 1.5, 0) end, false
end

local function absorbPulse(at)
	local f = softPart(Vector3.one * 0.6, ICE, at)
	TweenService:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 2.6, Transparency = 1 }):Play()
	Debris:AddItem(f, 0.35)
end

function DeathFX.Play(pos)
	local meet = pos + Vector3.new(0, T.MeetHeight, 0)
	local body = pos + Vector3.new(0, 2.5, 0)
	local rng = Random.new()
	local getTarget, ownDeath = viewerTarget(pos)

	-- build the souls (the first few are the ones that come for you)
	local souls = {}
	for i = 1, T.Souls do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.2, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude < 0.1 then dir = Vector3.yAxis end
		dir = dir.Unit
		local out = body + dir * (T.BurstRadius * rng:NextNumber(0.6, 1.1))
		local s = makeSoul(body, (i % 2 == 0) and BLUE or ICE, rng:NextNumber(0.45, 0.7))
		local swirl = dir:Cross(Vector3.yAxis)
		if swirl.Magnitude < 0.1 then swirl = Vector3.xAxis end
		swirl = swirl.Unit * rng:NextNumber(-3, 3)
		table.insert(souls, { part = s, out = out, swirl = swirl, toYou = getTarget ~= nil and i <= T.SoulsToYou, wob = rng:NextNumber(0, 6) })
	end

	-- glow + sparks at the body
	local anchor = softPart(Vector3.one * 0.2, BLUE, body)
	anchor.Transparency = 1
	local startLight = Instance.new("PointLight")
	startLight.Color = BLUE; startLight.Range = 14; startLight.Brightness = 2; startLight.Shadows = false
	startLight.Parent = anchor
	TweenService:Create(startLight, TweenInfo.new(T.BurstTime), { Brightness = 0 }):Play()
	emit(anchor, {
		Texture = SPARK, Color = ColorSequence.new(ICE), LightEmission = 1,
		Size = NumberSequence.new(0.4, 0), Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(180, 180),
	}, 16)
	Debris:AddItem(anchor, 2)

	-- the souls that come for you: burst out a little, then home in and get absorbed
	for _, s in souls do
		if s.toYou then
			task.spawn(function()
				local t0 = os.clock()
				local total = T.BurstTime + 0.15
				while os.clock() - t0 < total do
					local a = 1 - (1 - (os.clock() - t0) / total) ^ 3
					s.part.CFrame = CFrame.new(body:Lerp(s.out, a))
					RunService.Heartbeat:Wait()
				end
				local from = s.out
				local flyT = rng:NextNumber(0.55, 0.85)
				local t1 = os.clock()
				while true do
					local a = (os.clock() - t1) / flyT
					if a >= 1 then break end
					local tgt = getTarget()
					a = a * a * (3 - 2 * a)
					local mid = from:Lerp(tgt, 0.5) + Vector3.new(math.sin(s.wob) * 2, 1.5, math.cos(s.wob) * 2)
					s.part.CFrame = CFrame.new(bez(from, mid, tgt, a))
					RunService.Heartbeat:Wait()
				end
				local final = getTarget()
				s.part:Destroy()
				if not ownDeath then absorbPulse(final) end
				s.gone = true
			end)
		end
	end

	task.spawn(function()
		-- phase 1+2: burst out (ease out), then curve into the meeting point (ease in)
		local t0 = os.clock()
		local total = T.BurstTime + T.MeetTime
		while true do
			local t = os.clock() - t0
			if t >= total then break end
			for _, s in souls do
				if not s.toYou then
					local p
					if t < T.BurstTime then
						local a = 1 - (1 - t / T.BurstTime) ^ 3
						p = body:Lerp(s.out, a) + Vector3.new(0, math.sin(t * 9 + s.wob) * 0.15, 0)
					else
						local a = (t - T.BurstTime) / T.MeetTime
						a = a * a * (3 - 2 * a)
						p = bez(s.out, s.out:Lerp(meet, 0.5) + s.swirl + Vector3.new(0, 2, 0), meet, a)
					end
					s.part.CFrame = CFrame.new(p)
				end
			end
			RunService.Heartbeat:Wait()
		end
		for _, s in souls do if not s.toYou then s.part:Destroy() end end

		-- meeting flash (quick, a bit bigger than before)
		local flash = softPart(Vector3.one * 2, Color3.new(1, 1, 1), meet)
		TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * 11, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.35)
		emit(flash, {
			Texture = SPARK, Color = ColorSequence.new(ICE), LightEmission = 1,
			Size = NumberSequence.new(0.6, 0), Transparency = NumberSequence.new(0, 1),
			Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(180, 180),
		}, 18)

		-- phase 3: the orb + rocket straight up (bigger, brighter, longer trail)
		local orb = softPart(Vector3.one * 1.6, Color3.new(1, 1, 1), meet)
		orb.Name = "SoulOrb"
		addTrail(orb, 1.8, 1.1, ICE)
		local halo = softPart(Vector3.one * 3, BLUE, meet)
		halo.Transparency = 0.7
		local weld = Instance.new("WeldConstraint")
		halo.Anchored = false
		halo.Massless = true
		local light = Instance.new("PointLight")
		light.Color = ICE; light.Range = 24; light.Brightness = 4; light.Shadows = false
		light.Parent = orb
		emit(orb, {
			Texture = SPARK, Color = ColorSequence.new(ICE, BLUE), LightEmission = 1,
			Size = NumberSequence.new(1.0, 0), Transparency = NumberSequence.new(0, 1),
			Lifetime = NumberRange.new(0.5, 1.0), Speed = NumberRange.new(3, 9), SpreadAngle = Vector2.new(25, 25),
			Rate = 90, EmissionDirection = Enum.NormalId.Bottom,
		}).Enabled = true
		weld.Part0, weld.Part1 = orb, halo
		weld.Parent = orb
		halo.CFrame = orb.CFrame

		local snd = Sfx.Play("SoulRocket", orb) or Sfx.Play("Wind", orb, 1.5, 1.3)
		if snd then
			snd.RollOffMaxDistance = 500
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
			local e = a * a
			orb.CFrame = CFrame.new(meet:Lerp(sky, e))
			orb.Size = Vector3.one * (1.6 + 1.4 * e)
			RunService.Heartbeat:Wait()
		end
		orb:Destroy()
		halo:Destroy()

		-- phase 4: the sky glint (bigger + a second, softer echo flare)
		skyGlint(sky)
		task.delay(0.18, function() skyGlint(sky + Vector3.new(0, 20, 0)) end)
	end)
end

return DeathFX
