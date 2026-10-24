local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local HitFX = {}
HitFX.__index = HitFX

local WHITE = Color3.fromRGB(255, 255, 255)
local HEAD = Color3.fromRGB(255, 212, 60)
local KILL = Color3.fromRGB(255, 70, 70)
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"

local function escape(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function anchorPos(model)
	local p = model:FindFirstChild("Head") or model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	return (p and p:IsA("BasePart")) and p.Position or nil
end

local function makeLabel(parent, text, color, size)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(140, 50)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextSize = size
	l.TextColor3 = color
	l.Text = text
	local st = Instance.new("UIStroke")
	st.Thickness = 2; st.Color = Color3.new(0, 0, 0); st.Transparency = 0.25
	st.Parent = l
	local sc = Instance.new("UIScale")
	sc.Parent = l
	l.Parent = parent
	return l, sc, st
end

function HitFX.new(gui)
	local self = setmetatable({}, HitFX)
	self.gui = gui
	self.camera = workspace.CurrentCamera
	self.popups, self.combos, self.highlights, self.holes = {}, {}, {}, {}

	self.folder = Instance.new("Folder")
	self.folder.Name = "ClientFX"
	self.folder.Parent = workspace

	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one * 0.1
	anchor.Parent = self.folder
	self.anchor = anchor

	self.layer = Instance.new("Frame")
	self.layer.Size = UDim2.fromScale(1, 1)
	self.layer.BackgroundTransparency = 1
	self.layer.Parent = gui

	self:_buildHitmarker()
	self:_buildBanner()
	self.conn = RunService.RenderStepped:Connect(function(dt) self:_update(dt) end)
	return self
end

function HitFX:Destroy()
	self.conn:Disconnect()
	self.folder:Destroy()
	for _, h in self.highlights do h:Destroy() end
end

-- ===== hitmarker =====
function HitFX:_buildHitmarker()
	local hm = Instance.new("Frame")
	hm.AnchorPoint = Vector2.new(0.5, 0.5)
	hm.Position = UDim2.fromScale(0.5, 0.5)
	hm.Size = UDim2.fromOffset(40, 40)
	hm.BackgroundTransparency = 1
	hm.Visible = false
	hm.Parent = self.gui
	local scale = Instance.new("UIScale")
	scale.Parent = hm
	self.hmLines = {}
	for _, o in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.BorderSizePixel = 0
		l.Rotation = (o.X * o.Y > 0) and -45 or 45
		local st = Instance.new("UIStroke")
		st.Transparency = 0.4
		st.Parent = l
		l.Parent = hm
		table.insert(self.hmLines, { f = l, o = o })
	end
	self.hm, self.hmScale, self.hmToken = hm, scale, 0
end

function HitFX:ShowHitmarker(kind)
	local color = kind == "kill" and KILL or kind == "head" and HEAD or WHITE
	local w, h, dist = 3, 10, 9
	if kind == "head" then h, dist = 12, 10 elseif kind == "kill" then w, h, dist = 4, 16, 13 end
	for _, l in self.hmLines do
		l.f.BackgroundColor3 = color
		l.f.Size = UDim2.fromOffset(w, h)
		l.f.Position = UDim2.new(0.5, l.o.X * dist, 0.5, l.o.Y * dist)
	end
	self.hmToken += 1
	local token = self.hmToken
	self.hm.Visible = true
	self.hmScale.Scale = kind == "kill" and 2.0 or 1.6
	TweenService:Create(self.hmScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local dur = kind == "kill" and 0.45 or kind == "head" and 0.18 or 0.12
	task.delay(dur, function()
		if self.hmToken == token then self.hm.Visible = false end
	end)
end

-- ===== elimination banner =====
function HitFX:_buildBanner()
	local b = Instance.new("TextLabel")
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromScale(0.5, 0.64)
	b.Size = UDim2.fromOffset(600, 40)
	b.BackgroundTransparency = 1
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 26
	b.TextColor3 = KILL
	b.RichText = true
	b.TextTransparency = 1
	b.TextStrokeTransparency = 1
	local s = Instance.new("UIScale")
	s.Parent = b
	b.Parent = self.gui
	self.banner, self.bannerScale, self.bannerToken = b, s, 0
end

function HitFX:_showBanner(name)
	self.bannerToken += 1
	local token = self.bannerToken
	self.banner.Text = string.format('ELIMINATED  <font color="#FFFFFF">%s</font>', escape(string.upper(name)))
	self.banner.TextTransparency = 0
	self.banner.TextStrokeTransparency = 0.5
	self.bannerScale.Scale = 1.5
	TweenService:Create(self.bannerScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.4, function()
		if self.bannerToken ~= token then return end
		TweenService:Create(self.banner, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- ===== particles =====
function HitFX:_burst(pos, dir, count, p)
	if dir.Magnitude < 1e-3 then dir = Vector3.yAxis end
	local att = Instance.new("Attachment")
	att.Parent = self.anchor
	att.WorldCFrame = CFrame.lookAt(pos, pos + dir.Unit)
	local e = Instance.new("ParticleEmitter")
	e.Enabled = false
	e.Texture = p.Texture or SPARK_TEX
	e.Color = ColorSequence.new(p.Color or WHITE)
	e.LightEmission = p.LightEmission or 1
	e.LightInfluence = p.LightInfluence or 0
	e.Size = p.Size or NumberSequence.new(0.2, 0)
	e.Transparency = p.Transparency or NumberSequence.new(0, 1)
	e.Lifetime = p.Lifetime or NumberRange.new(0.15, 0.3)
	e.Speed = p.Speed or NumberRange.new(15, 30)
	e.SpreadAngle = p.Spread or Vector2.new(45, 45)
	e.Drag = p.Drag or 0
	e.Acceleration = p.Accel or Vector3.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = p.RotSpeed or NumberRange.new(0, 0)
	e.EmissionDirection = Enum.NormalId.Front
	if p.Streak then e.Orientation = Enum.ParticleOrientation.VelocityParallel end
	e.Parent = att
	e:Emit(count)
	Debris:AddItem(att, (p.Lifetime and p.Lifetime.Max or 0.3) + 1)
	return att
end

function HitFX:_flash(model, color)
	local h = self.highlights[model]
	if not h or not h.Parent then
		h = Instance.new("Highlight")
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.OutlineTransparency = 1
		h.FillTransparency = 1
		h.Adornee = model
		h.Parent = model
		self.highlights[model] = h
	end
	h.FillColor = color
	h.FillTransparency = 0.2
	TweenService:Create(h, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FillTransparency = 1 }):Play()
end

function HitFX:Tracer(from, to)
	local dist = (to - from).Magnitude
	if dist < 1 then return end
	local dir = (to - from).Unit
	local len = math.min(dist, 7)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 214, 150)
	p.Size = Vector3.new(0.045, 0.045, len)
	p.CFrame = CFrame.lookAt(from + dir * len * 0.5, to)
	p.Parent = self.folder
	local tw = TweenService:Create(p, TweenInfo.new(math.clamp(dist / 1100, 0.02, 0.4), Enum.EasingStyle.Linear),
		{ CFrame = CFrame.lookAt(to - dir * len * 0.5, to + dir) })
	tw:Play()
	tw.Completed:Once(function() p:Destroy() end)
end

-- ===== damage numbers =====
function HitFX:_popup(worldPos, dmg, head)
	local l, sc, st = makeLabel(self.layer, tostring(dmg), head and HEAD or WHITE, head and 30 or 24)
	l.Rotation = math.random(-10, 4)
	table.insert(self.popups, {
		label = l, scale = sc, stroke = st, world = worldPos, age = 0, life = 0.75,
		offset = Vector2.new(34 + math.random() * 16, -10 + math.random() * 14),
		vel = Vector2.new(150 + math.random() * 90, -230 - math.random() * 60),
	})
end

function HitFX:_combo(model, dmg, head)
	local now = os.clock()
	local c = self.combos[model]
	if not c or now - c.last > 1.2 or c.killed then
		if c then c.label:Destroy() end
		local l, sc, st = makeLabel(self.layer, "", WHITE, 34)
		c = { label = l, scale = sc, stroke = st, total = 0, last = now, killed = false }
		self.combos[model] = c
	end
	c.total += dmg
	c.last = now
	c.label.Text = tostring(c.total)
	c.label.TextColor3 = head and HEAD or WHITE
	c.scale.Scale = 1.35
end

-- ===== public =====
function HitFX:Hit(model, pos, normal, dmg, head)
	self:_flash(model, head and HEAD or WHITE)
	self:_burst(pos, normal, head and 12 or 7, {
		Color = head and HEAD or Color3.fromRGB(255, 240, 220), Size = NumberSequence.new(0.14, 0),
		Speed = NumberRange.new(14, 28), Lifetime = NumberRange.new(0.1, 0.22),
		Accel = Vector3.new(0, -50, 0), Streak = true,
	})
	self:_burst(pos, normal, 1, {
		Color = head and HEAD or WHITE, Size = NumberSequence.new(head and 1.6 or 1.1, 0),
		Speed = NumberRange.new(0, 0), Lifetime = NumberRange.new(0.07, 0.07),
	})
	self:ShowHitmarker(head and "head" or "body")
	Sfx.Play(head and "Headshot" or "Hit")
end

function HitFX:Number(model, pos, dmg, head)
	self:_popup(pos, dmg, head)
	self:_combo(model, dmg, head)
end

function HitFX:Kill(model, name)
	local c = self.combos[model]
	if c then
		c.killed = true
		c.last = os.clock()
		c.label.TextColor3 = KILL
		c.scale.Scale = 1.9
	end
	self:ShowHitmarker("kill")
	self:_showBanner(name)
	self:_flash(model, KILL)
	Sfx.Play("Kill")
	local pos = anchorPos(model)
	if not pos then return end
	self:_burst(pos, Vector3.yAxis, 40, {
		Color = Color3.fromRGB(255, 200, 60), Size = NumberSequence.new(0.35, 0.1),
		Speed = NumberRange.new(12, 26), Spread = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.6, 1.0), Accel = Vector3.new(0, -45, 0), Drag = 1.5,
		RotSpeed = NumberRange.new(-300, 300),
	})
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Anchored = true
	ring.CanCollide, ring.CanQuery, ring.CanTouch, ring.CastShadow = false, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = KILL
	ring.Transparency = 0.35
	ring.Size = Vector3.one
	ring.CFrame = CFrame.new(pos)
	ring.Parent = self.folder
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 10, Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.4)
end

function HitFX:Impact(pos, normal, part)
	local hole = Instance.new("Part")
	hole.Anchored = true
	hole.CanCollide, hole.CanQuery, hole.CanTouch, hole.CastShadow = false, false, false, false
	hole.Size = Vector3.new(0.17, 0.17, 0.02)
	hole.Color = Color3.fromRGB(18, 18, 20)
	hole.CFrame = CFrame.lookAt(pos + normal * 0.012, pos + normal * 2) * CFrame.Angles(0, 0, math.random() * 6.28)
	hole.Parent = self.folder
	table.insert(self.holes, hole)
	if #self.holes > 80 then table.remove(self.holes, 1):Destroy() end

	local att = self:_burst(pos, normal, 3, {
		Texture = SMOKE_TEX, Color = part.Color:Lerp(WHITE, 0.25), LightEmission = 0, LightInfluence = 1,
		Size = NumberSequence.new(0.3, 1.1), Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(3, 6),
		Spread = Vector2.new(25, 25), Drag = 4,
	})
	self:_burst(pos, normal, 4, {
		Color = Color3.fromRGB(255, 220, 160), Size = NumberSequence.new(0.1, 0),
		Speed = NumberRange.new(12, 22), Lifetime = NumberRange.new(0.08, 0.18),
		Accel = Vector3.new(0, -60, 0), Streak = true,
	})
	Sfx.Play("Impact", att)
end

-- ===== per-frame =====
function HitFX:_update(dt)
	local cam = self.camera
	local now = os.clock()

	for i = #self.popups, 1, -1 do
		local p = self.popups[i]
		p.age += dt
		local t = p.age
		if t >= p.life then
			p.label:Destroy()
			table.remove(self.popups, i)
			continue
		end
		local sp = cam:WorldToViewportPoint(p.world)
		if sp.Z <= 0 then
			p.label.Visible = false
		else
			p.label.Visible = true
			local off = p.offset + p.vel * t + Vector2.new(0, 520) * (t * t * 0.5)
			p.label.Position = UDim2.fromOffset(sp.X + off.X, sp.Y + off.Y)
		end
		local pop = math.clamp(t / 0.09, 0, 1)
		p.scale.Scale = 1 + 0.9 * (1 - pop) * (1 - pop)
		local fade = math.clamp((t - (p.life - 0.25)) / 0.25, 0, 1)
		p.label.TextTransparency = fade
		p.stroke.Transparency = 0.25 + 0.75 * fade
	end

	for model, c in self.combos do
		local since = now - c.last
		local life = c.killed and 1.6 or 1.2
		if since > life then
			c.label:Destroy()
			self.combos[model] = nil
			continue
		end
		local pos = (model.Parent and anchorPos(model)) or c.lastPos
		c.lastPos = pos
		if pos then
			local sp = cam:WorldToViewportPoint(pos)
			c.label.Visible = sp.Z > 0
			c.label.Position = UDim2.fromOffset(sp.X + 70, sp.Y - 45)
		end
		c.scale.Scale += (1 - c.scale.Scale) * (1 - math.exp(-dt * 18))
		local fade = math.clamp((since - (life - 0.3)) / 0.3, 0, 1)
		c.label.TextTransparency = fade
		c.stroke.Transparency = 0.25 + 0.75 * fade
	end
end

return HitFX
