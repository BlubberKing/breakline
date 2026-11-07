-- Crown v1 (ModuleScript in ReplicatedStorage) - used by BOTH games (Lobby: the floating win-streak crown above players; Breakline: the crown above the winning team).
-- Keep the two copies identical. NEW in v5.10.
--   Crown.Build(parent, opts) -> Model        a gold crown: an 8-sided band, 8 spikes (4 tall with a gem on top, 4 short), 4 gems on the band.
--       opts = { tier = 1 | 2 | 3, anchored = true | false, scale = 1 }
--       The model's PrimaryPart is "Root" (centre of the band, +Y up, the front is -Z). anchored = false welds everything to Root (use a Weld to a head).
--   Crown.TierFor(streak) -> 1 (1-2 wins in a row) | 2 (3-4) | 3 (5+): the gem colour changes (ruby / sapphire / amethyst + sparkles)
--   Crown.Width = about 1.25 studs at scale 1
local Crown = {}

local V3, CF = Vector3.new, CFrame.new
local rad = math.rad
local GOLD, GOLD_DARK = Color3.fromRGB(255, 204, 84), Color3.fromRGB(214, 160, 52)
local GEMS = { Color3.fromRGB(235, 52, 74), Color3.fromRGB(70, 150, 255), Color3.fromRGB(190, 110, 255) }
Crown.Width = 1.25

function Crown.TierFor(streak)
	streak = tonumber(streak) or 0
	if streak >= 5 then return 3 elseif streak >= 3 then return 2 end
	return 1
end

function Crown.Build(parent, opts)
	opts = opts or {}
	local s = opts.scale or 1
	local tier = math.clamp(opts.tier or 1, 1, 3)
	local anchored = opts.anchored ~= false
	local gem = GEMS[tier]
	local model = Instance.new("Model")
	model.Name = "Crown"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V3(0.2, 0.2, 0.2) * s
	root.Transparency = 1
	root.Anchored = anchored
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless, root.CastShadow = false, false, false, true, false
	root.Parent = model
	model.PrimaryPart = root

	local function add(size, cf, color, mat, shape, refl)
		local p = Instance.new("Part")
		p.Name = "CrownPart"
		if shape then p.Shape = shape end
		p.Size = size * s
		p.Color = color
		p.Material = mat or Enum.Material.Metal
		if refl then p.Reflectance = refl end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
		p.Anchored = anchored
		p.CFrame = root.CFrame * CF(cf.Position * s) * cf.Rotation
		if not anchored then
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = root, p
			w.Parent = p
		end
		p.Parent = model
		return p
	end

	-- band: 8 flat segments around a ring of radius R
	local R, bandH = 0.5, 0.26
	local segLen = 2 * (R + 0.04) * math.tan(math.pi / 8) + 0.02
	for i = 0, 7 do
		local a = i * math.pi / 4
		local pos = V3(math.sin(a) * R, 0, -math.cos(a) * R)
		local face = CFrame.lookAt(pos, pos + V3(math.sin(a), 0, -math.cos(a)))
		add(V3(segLen, bandH, 0.09), face, GOLD, Enum.Material.Metal, nil, 0.18)
		add(V3(segLen, 0.05, 0.1), face * CF(0, -bandH * 0.5 + 0.025, 0), GOLD_DARK, Enum.Material.Metal, nil, 0.1) -- lower rim
	end
	-- spikes: a diamond standing on the band at every 45 degrees, tall at the 4 cardinals
	for i = 0, 7 do
		local a = i * math.pi / 4
		local tall = i % 2 == 0
		local h = tall and 0.44 or 0.26
		local d = tall and 0.26 or 0.2
		local pos = V3(math.sin(a) * R, bandH * 0.5 + h * 0.5 - d * 0.35, -math.cos(a) * R)
		local face = CFrame.lookAt(pos, pos + V3(math.sin(a), 0, -math.cos(a)))
		add(V3(d, h, 0.08), face * CFrame.Angles(0, 0, 0), GOLD, Enum.Material.Metal, nil, 0.18)
		add(V3(d * 0.72, d * 0.72, 0.08), face * CF(0, h * 0.5 - d * 0.1, 0) * CFrame.Angles(0, 0, rad(45)), GOLD, Enum.Material.Metal, nil, 0.18) -- sharpens the tip
		if tall then
			local g = add(V3(0.12, 0.12, 0.12), CF(pos + V3(math.sin(a) * 0.03, h * 0.5 + 0.02, -math.cos(a) * 0.03)), gem, Enum.Material.Neon, Enum.PartType.Ball)
			g.Transparency = 0.05
		end
	end
	-- four gems on the band (front, back, left, right)
	for i = 0, 3 do
		local a = i * math.pi / 2
		local pos = V3(math.sin(a) * (R + 0.06), 0, -math.cos(a) * (R + 0.06))
		local face = CFrame.lookAt(pos, pos + V3(math.sin(a), 0, -math.cos(a)))
		add(V3(0.15, 0.15, 0.05), face * CFrame.Angles(0, 0, rad(45)), gem, Enum.Material.Neon)
	end
	if tier >= 3 then -- 5+ wins: it sparkles
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), gem)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28 * s), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.7, 1.3)
		e.Rate = 7
		e.Speed = NumberRange.new(0.2, 0.7)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Parent = root
	end
	model.Parent = parent
	return model
end

return Crown
