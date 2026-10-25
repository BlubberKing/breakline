-- BoxFX: the effect when a plugged box is destroyed (client only; MatchClient calls BoxFX.Break on the "BoxBreak" remote).
-- Style: a tight, satisfying "robot shuts down" - bright flash, shockwave ring, sparks, steel shards, a puff of smoke,
-- and a pair of glowing "eyes" that flicker out. Not over the top.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local BoxFX = {}
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function neon(shape, size, color, pos, transparency)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	return p
end

local function emitter(parent, props, count)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Rate = 0
	for k, v in props do e[k] = v end
	e.Parent = parent
	e:Emit(count)
	return e
end

function BoxFX.Break(pos, teamColor)
	local color = teamColor or Color3.fromRGB(255, 190, 80)
	local hot = color:Lerp(Color3.new(1, 1, 1), 0.5)

	-- emitter anchor
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
	a.Transparency = 1
	a.Size = Vector3.one
	a.Position = pos
	a.Parent = workspace
	Debris:AddItem(a, 2.5)

	-- 1) quick white-hot core flash + brief light
	local core = neon(Enum.PartType.Ball, Vector3.one * 2, Color3.new(1, 1, 1), pos, 0.1)
	TweenService:Create(core, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 7, Transparency = 1 }):Play()
	Debris:AddItem(core, 0.25)
	local light = Instance.new("PointLight")
	light.Color = hot
	light.Range = 22
	light.Brightness = 4
	light.Shadows = false
	light.Parent = a
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()

	-- 2) flat shockwave ring (team color)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = false, false, false, false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.15, 2, 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 16, 16), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.5)

	-- 3) sparks (fast streaks) + embers (slow, lingering)
	emitter(a, {
		Texture = SPARK, Color = ColorSequence.new(hot), LightEmission = 1,
		Size = NumberSequence.new(0.28, 0), Transparency = NumberSequence.new(0, 1),
		Lifetime = NumberRange.new(0.3, 0.7), Speed = NumberRange.new(25, 50),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -70, 0), Drag = 1,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	}, 34)
	emitter(a, {
		Texture = SPARK, Color = ColorSequence.new(color), LightEmission = 1,
		Size = NumberSequence.new(0.5, 0), Transparency = NumberSequence.new(0.1, 1),
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(4, 12),
		SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 6, 0), Drag = 2,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120),
	}, 14)

	-- 4) smoke puff
	emitter(a, {
		Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(70, 74, 86)), LightEmission = 0, LightInfluence = 1,
		Size = NumberSequence.new(1.5, 5), Transparency = NumberSequence.new(0.45, 1),
		Lifetime = NumberRange.new(0.7, 1.2), Speed = NumberRange.new(3, 9),
		SpreadAngle = Vector2.new(180, 180), Drag = 3, Acceleration = Vector3.new(0, 3, 0),
		Rotation = NumberRange.new(0, 360),
	}, 8)

	-- 5) steel shards that tumble out and fall (purely visual, short-lived)
	for _ = 1, 9 do
		local s = math.random() * 0.35 + 0.2
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(s, s * 0.35, s * 0.7)
		shard.Color = Color3.fromRGB(46, 50, 62)
		shard.Material = Enum.Material.Metal
		shard.CanCollide, shard.CanQuery, shard.CanTouch, shard.CastShadow = false, false, false, false
		shard.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		shard.Parent = workspace
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.3, math.random() - 0.5).Unit
		shard.AssemblyLinearVelocity = dir * (18 + math.random() * 22)
		shard.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 20
		shard.Anchored = false
		shard.Massless = false
		-- glowing edge on a few
		if math.random() < 0.4 then shard.Color = color; shard.Material = Enum.Material.Neon end
		TweenService:Create(shard, TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.5),
			{ Transparency = 1 }):Play()
		Debris:AddItem(shard, 1.5)
	end

	-- 6) the robot's last look: two eyes that blink out, rising as it powers down
	local ghost = Instance.new("Part")
	ghost.Anchored, ghost.CanCollide, ghost.CanQuery, ghost.CanTouch = true, false, false, false
	ghost.Transparency = 1
	ghost.Size = Vector3.one
	ghost.Position = pos + Vector3.new(0, 1, 0)
	ghost.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(90, 40)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Parent = ghost
	local eyes = {}
	for _, x in { 0.28, 0.72 } do
		local e = Instance.new("Frame")
		e.AnchorPoint = Vector2.new(0.5, 0.5)
		e.Position = UDim2.fromScale(x, 0.5)
		e.Size = UDim2.fromOffset(16, 22)
		e.BackgroundColor3 = hot
		e.BorderSizePixel = 0
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = e
		e.Parent = bb
		table.insert(eyes, e)
	end
	-- flicker, then collapse to a line and fade
	task.spawn(function()
		for i = 1, 3 do
			for _, e in eyes do e.BackgroundTransparency = (i % 2 == 0) and 0.7 or 0 end
			task.wait(0.06)
		end
		for _, e in eyes do
			TweenService:Create(e, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Size = UDim2.fromOffset(22, 2), BackgroundTransparency = 1 }):Play()
		end
	end)
	TweenService:Create(ghost, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = pos + Vector3.new(0, 4, 0) }):Play()
	Debris:AddItem(ghost, 0.8)

	-- sound (3D). Reuses the existing Damaged / Impact / Kill sounds, layered + pitched low for a heavy "crunch".
	if Sfx.Has("BoxBreak") then
		Sfx.Play("BoxBreak", a)
	else
		Sfx.Play("Impact", a, 0.55, 2.2)
		Sfx.Play("Damaged", a, 0.7, 0.9)
		Sfx.Play("Kill", a, 0.8, 0.6)
	end
end

return BoxFX
