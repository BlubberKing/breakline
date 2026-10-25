-- BoxModel: the look of a Wall Push box (shared by MatchServer = the real box, MatchClient = the first-person carry model).
-- A box is a dark steel crate with glowing edge strips, an antenna bulb, a soft light and a little animated robot FACE on all four sides.
-- Build() makes the parts. Animate() (client only) drives the face from the box's attributes:
--   State (Loose/Carried/Thrown/Plugging/Plugged), Health + MaxHealth, PlugTeam, Draining (true while the wall push is wearing it down), Seed.
local BoxModel = {}

local STEEL = Color3.fromRGB(46, 50, 62)
local EYE_IDLE = Color3.fromRGB(150, 235, 255)
local AMBER = Color3.fromRGB(255, 170, 40)
local SMOOTH = Enum.SurfaceType.Smooth
local FACES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

BoxModel.Amber = AMBER

local function corner(parent, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale, 0)
	c.Parent = parent
end

local function buildFace(body, normal)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Face_" .. normal.Name
	sg.Face = normal
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(300, 300)
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.Parent = body

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.8, 0.62)
	panel.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	panel.BorderSizePixel = 0
	panel.Parent = sg
	corner(panel, 0.18)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 5
	stroke.Color = EYE_IDLE
	stroke.Parent = panel

	local function glow(name, x, y, w, h)
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.BackgroundColor3 = EYE_IDLE
		f.BorderSizePixel = 0
		f.Parent = panel
		corner(f, 0.5)
		return f
	end
	glow("EyeL", 0.3, 0.4, 0.16, 0.34)
	glow("EyeR", 0.7, 0.4, 0.16, 0.34)
	glow("Mouth", 0.5, 0.8, 0.3, 0.1)
end

-- size: edge length in studs. opts.Accent: edge/bulb color. opts.Viewmodel: all parts anchored, no welds/attachments (caller positions them).
-- Returns body (the main Part; everything else is a child of it), accents (parts to recolor), list ({ Part, Offset } for every decor part).
function BoxModel.Build(size, opts)
	opts = opts or {}
	local accent = opts.Accent or AMBER
	local vm = opts.Viewmodel == true

	local body = Instance.new("Part")
	body.Name = "Box"
	body.Size = Vector3.one * size
	body.Color = STEEL
	body.Material = Enum.Material.Metal
	body.TopSurface, body.BottomSurface = SMOOTH, SMOOTH
	if vm then
		body.Anchored = true
		body.CanCollide, body.CanQuery, body.CanTouch, body.CastShadow = false, false, false, false
	end

	local list, accents = {}, {}
	local function decor(name, sz, off, color, material, isAccent, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = sz
		p.Color = color
		p.Material = material
		p.TopSurface, p.BottomSurface = SMOOTH, SMOOTH
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Massless = true
		if shape then p.Shape = shape end
		if vm then
			p.Anchored = true
		else
			p.CFrame = CFrame.new(off.Position) -- placed properly by the weld
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = body, p, off
			w.Parent = p
		end
		p.Parent = body
		table.insert(list, { Part = p, Offset = off })
		if isAccent then table.insert(accents, p) end
		return p
	end

	-- 12 glowing edge strips
	local t = size * 0.075
	local h = size / 2
	local L = size + t
	for _, a in { -1, 1 } do
		for _, b in { -1, 1 } do
			decor("EdgeZ", Vector3.new(t, t, L), CFrame.new(a * h, b * h, 0), accent, Enum.Material.Neon, true)
			decor("EdgeY", Vector3.new(t, L, t), CFrame.new(a * h, 0, b * h), accent, Enum.Material.Neon, true)
			decor("EdgeX", Vector3.new(L, t, t), CFrame.new(0, a * h, b * h), accent, Enum.Material.Neon, true)
		end
	end

	-- antenna with a glowing bulb
	decor("Antenna", Vector3.new(t * 0.7, size * 0.28, t * 0.7), CFrame.new(0, h + size * 0.14, 0), STEEL, Enum.Material.Metal, false)
	decor("Bulb", Vector3.one * size * 0.2, CFrame.new(0, h + size * 0.36, 0), accent, Enum.Material.Neon, true, Enum.PartType.Ball)

	for _, n in FACES do buildFace(body, n) end

	if not vm then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = accent
		light.Range = size * 3.5
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = body
		-- hand targets for the two-handed carry pose (ThirdPersonClient points the hands here)
		for name, sx in { CarryR = 1, CarryL = -1 } do
			local a = Instance.new("Attachment")
			a.Name = name
			a.Position = Vector3.new(sx * (h + 0.02), -size * 0.04, size * 0.15)
			a.Parent = body
		end
	end
	return body, accents, list
end

function BoxModel.Recolor(accents, color)
	for _, p in accents do
		p.Color = color
	end
end

-- ===================== face animation (client) =====================
local faceCache = setmetatable({}, { __mode = "k" })

local function getFaces(body)
	local faces = faceCache[body]
	if faces and #faces == #FACES then return faces end
	faces = {}
	for _, n in FACES do
		local sg = body:FindFirstChild("Face_" .. n.Name)
		local panel = sg and sg:FindFirstChild("Panel")
		if panel then
			table.insert(faces, {
				stroke = panel:FindFirstChild("Stroke"),
				eyeL = panel:FindFirstChild("EyeL"),
				eyeR = panel:FindFirstChild("EyeR"),
				mouth = panel:FindFirstChild("Mouth"),
			})
		end
	end
	faceCache[body] = faces
	return faces
end

-- body: the part that owns the SurfaceGuis. src: the part whose attributes drive the face (defaults to body).
-- teamColors: { [teamName] = Color3 }
function BoxModel.Animate(body, src, now, teamColors)
	local faces = getFaces(body)
	if #faces == 0 then return end
	src = src or body
	local state = src:GetAttribute("State") or "Loose"
	local seed = src:GetAttribute("Seed") or 0
	local maxHp = src:GetAttribute("MaxHealth") or 1
	local hpFrac = math.clamp((src:GetAttribute("Health") or maxHp) / maxHp, 0, 1)
	local draining = src:GetAttribute("Draining") == true

	local ew, eh, mw, mh, my = 0.16, 0.34, 0.3, 0.1, 0.8
	local col = EYE_IDLE
	local shake = 0
	if state == "Carried" then
		ew, eh, mw, mh = 0.18, 0.4, 0.1, 0.1 -- wide-eyed, little "o" mouth
	elseif state == "Thrown" then
		ew, eh, mw, mh, my = 0.2, 0.08, 0.2, 0.22, 0.76 -- squeezed eyes, big "O" mouth
		col = Color3.fromRGB(255, 240, 150)
	elseif state == "Plugging" then
		eh, mw, mh = 0.2, 0.42, 0.12 -- happy
		col = Color3.fromRGB(255, 255, 255)
	elseif state == "Plugged" then
		col = (teamColors[src:GetAttribute("PlugTeam")] or EYE_IDLE):Lerp(Color3.new(1, 1, 1), 0.35)
		if hpFrac < 0.3 then
			ew, eh, mw, mh = 0.14, 0.42, 0.14 + 0.04 * math.sin(now * 18), 0.07
			shake = 0.012
		elseif hpFrac < 0.6 then
			mw, mh = 0.2, 0.06
		end
		if draining then -- the wall push is wearing this box down: worried
			eh = eh * 0.7
			mw = math.min(mw, 0.2) + 0.03 * math.sin(now * 9)
			col = col:Lerp(Color3.fromRGB(255, 120, 80), 0.5)
		end
	end
	if state ~= "Thrown" and ((now + seed * 13) % (3.4 + (seed * 7) % 2)) < 0.12 then eh = 0.04 end -- blink
	local sway = math.sin(now * 1.3 + seed * 6) * 0.012 + (shake > 0 and math.sin(now * 40) * shake or 0)

	for _, f in faces do
		if f.eyeL then
			f.eyeL.Position = UDim2.fromScale(0.3 + sway, 0.4)
			f.eyeL.Size = UDim2.fromScale(ew, eh)
			f.eyeL.BackgroundColor3 = col
		end
		if f.eyeR then
			f.eyeR.Position = UDim2.fromScale(0.7 + sway, 0.4)
			f.eyeR.Size = UDim2.fromScale(ew, eh)
			f.eyeR.BackgroundColor3 = col
		end
		if f.mouth then
			f.mouth.Position = UDim2.fromScale(0.5 + sway, my)
			f.mouth.Size = UDim2.fromScale(mw, mh)
			f.mouth.BackgroundColor3 = col
		end
		if f.stroke then f.stroke.Color = col end
	end
end

return BoxModel
