local Builder = {}

local C = {
	Body = Color3.fromRGB(42, 44, 52), Dark = Color3.fromRGB(22, 23, 27),
	Metal = Color3.fromRGB(90, 94, 104), Accent = Color3.fromRGB(255, 122, 28),
	Glove = Color3.fromRGB(28, 28, 32), Sleeve = Color3.fromRGB(58, 70, 98),
	Flash = Color3.fromRGB(255, 196, 110),
	Glass = Color3.fromRGB(120, 185, 255), Reticle = Color3.fromRGB(255, 45, 45),
}
Builder.Colors = C

-- ===== SIGHT TUNING =====
local SIGHT_Y = 0.44        -- reticle center height above the bore
local HOOD_Z = -0.02        -- hood position along the gun
local HOOD_DEPTH = 0.17     -- hood length
local HOOD_IN = 0.112       -- inner radius of the window
local HOOD_WALL = 0.026     -- hood wall thickness
local EYE_DIST = 0.62       -- distance from your eye to the reticle when aiming (bigger = sight looks smaller)
local GLASS_Z = HOOD_Z - HOOD_DEPTH / 2 + 0.02
local RETICLE_Z = GLASS_Z + 0.004

local function reticleGui(part, style, color)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back -- faces the camera
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 1000
	sg.LightInfluence = 0
	sg.Brightness = 4
	sg.AlwaysOnTop = false
	sg.Parent = part

	local function frame(w, h, transp, round, rot)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transp
		f.BorderSizePixel = 0
		f.Rotation = rot or 0
		if round then
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = f
		end
		f.Parent = sg
		return f
	end
	local function ring(d, thick, transp)
		local f = frame(d, d, 1, true)
		local s = Instance.new("UIStroke")
		s.Color, s.Thickness, s.Transparency = color, thick, transp
		s.Parent = f
	end

	if style == "Holo" then
		ring(70, 7, 0.85)
		ring(64, 2.5, 0.05)
		frame(9, 9, 0.7, true)
		frame(4, 4, 0, true)
	elseif style == "Chevron" then
		local glow = frame(26, 26, 0.9, true); glow.Position = UDim2.new(0.5, 0, 0.5, 5)
		local a = frame(14, 3, 0, false, -45); a.Position = UDim2.new(0.5, -5, 0.5, 5)
		local b = frame(14, 3, 0, false, 45); b.Position = UDim2.new(0.5, 5, 0.5, 5)
	elseif style ~= "None" then -- "Dot" (default)
		frame(20, 20, 0.88, true)
		frame(10, 10, 0.6, true)
		frame(5, 5, 0, true)
	end
	return sg
end

function Builder.Build(opts)
	opts = opts or {}
	local V, CF, ANG, rad = Vector3.new, CFrame.new, CFrame.Angles, math.rad
	local SP, NEON, METAL = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Metal

	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local groups = { gun = {}, mag = {}, left = {}, flash = {} }

	local function add(group, size, offset, color, material, extra)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = size
		p.Color = color or C.Body
		p.Material = material or SP
		if extra then for k, v in extra do p[k] = v end end
		p.Parent = model
		table.insert(groups[group], { Part = p, Offset = offset })
		return p
	end

	-- Receiver
	add("gun", V(0.3, 0.38, 1.3), CF(0, 0, 0))
	add("gun", V(0.32, 0.12, 1.0), CF(0, -0.2, -0.05), C.Dark)
	add("gun", V(0.2, 0.06, 1.25), CF(0, 0.22, -0.05), C.Dark) -- top rail (top = 0.25)
	add("gun", V(0.31, 0.04, 0.55), CF(0, 0.08, -0.25), C.Accent, NEON)
	add("gun", V(0.06, 0.1, 0.22), CF(0.17, 0.08, 0.1), C.Metal, METAL)
	-- Handguard + barrel
	add("gun", V(0.27, 0.3, 0.9), CF(0, 0.02, -1.08))
	add("gun", V(0.28, 0.04, 0.7), CF(0, -0.07, -1.1), C.Accent, NEON)
	add("gun", V(0.7, 0.11, 0.11), CF(0, 0.06, -1.78) * ANG(0, rad(90), 0), C.Metal, METAL, { Shape = Enum.PartType.Cylinder })
	add("gun", V(0.17, 0.17, 0.24), CF(0, 0.06, -2.17), C.Dark)
	-- Grip, trigger guard, stock
	add("gun", V(0.2, 0.44, 0.24), CF(0, -0.36, 0.42) * ANG(rad(-14), 0, 0), C.Dark)
	add("gun", V(0.06, 0.06, 0.3), CF(0, -0.28, 0.12), C.Metal, METAL)
	add("gun", V(0.22, 0.3, 0.7), CF(0, -0.04, 1.0))
	add("gun", V(0.24, 0.42, 0.1), CF(0, -0.08, 1.38), C.Dark)
	add("gun", V(0.23, 0.04, 0.5), CF(0, 0.12, 1.0), C.Accent, NEON)

	-- ===== Compact reflector sight =====
	local outer = HOOD_IN + HOOD_WALL
	local center = CF(0, SIGHT_Y, HOOD_Z)
	local side = 2 * outer * math.tan(rad(22.5)) + 0.004
	for i = 0, 7 do -- octagonal hood, flat top/bottom
		add("gun", V(side, HOOD_WALL, HOOD_DEPTH), center * ANG(0, 0, rad(i * 45)) * CF(0, HOOD_IN + HOOD_WALL / 2, 0), C.Dark)
	end
	-- visor lip over the front
	add("gun", V(side + 0.03, 0.014, 0.06), CF(0, SIGHT_Y + outer + 0.004, HOOD_Z - HOOD_DEPTH / 2 + 0.02), C.Dark)
	-- accent strip on top
	add("gun", V(0.05, 0.006, HOOD_DEPTH * 0.6), CF(0, SIGHT_Y + outer + 0.002, HOOD_Z + 0.03), C.Accent, NEON)
	-- mount + clamp
	local mountY = SIGHT_Y - outer - 0.02
	add("gun", V(0.17, 0.06, HOOD_DEPTH + 0.04), CF(0, mountY, HOOD_Z), C.Body)
	add("gun", V(0.03, 0.045, 0.09), CF(0.1, mountY - 0.005, HOOD_Z + 0.02), C.Metal, METAL)
	add("gun", V(0.012, 0.02, 0.12), CF(0.118, mountY - 0.01, HOOD_Z + 0.05), C.Metal, METAL)
	-- brightness knob
	add("gun", V(0.04, 0.065, 0.065), CF(outer + 0.018, SIGHT_Y - 0.03, HOOD_Z + 0.01), C.Metal, METAL, { Shape = Enum.PartType.Cylinder })
	-- lens (round, tinted)
	add("gun", V(0.004, (HOOD_IN + 0.008) * 2, (HOOD_IN + 0.008) * 2), CF(0, SIGHT_Y, GLASS_Z) * ANG(0, rad(90), 0),
		C.Glass, SP, { Shape = Enum.PartType.Cylinder, Transparency = 0.82, Reflectance = 0.25 })
	-- reticle plane
	local reticlePart = add("gun", V(0.2, 0.2, 0.002), CF(0, SIGHT_Y, RETICLE_Z), C.Dark, SP, { Transparency = 1 })
	local reticle = reticleGui(reticlePart, opts.Reticle or "Dot", opts.ReticleColor or C.Reticle)

	-- Muzzle point (invisible, holds light + smoke)
	local muzzleOffset = CF(0, 0.06, -2.32)
	local muzzle = add("gun", V(0.05, 0.05, 0.05), muzzleOffset, C.Dark, SP, { Transparency = 1 })

	-- Right arm (moves with the gun)
	local rHand = V(0.03, -0.36, 0.44)
	local rDir = V(0.45, -0.5, 1).Unit
	add("gun", V(0.24, 0.26, 0.34), CF(rHand) * ANG(rad(-14), 0, 0), C.Glove)
	add("gun", V(0.34, 0.34, 1.7), CFrame.lookAt(rHand + rDir * 1.0, rHand + rDir * 2), C.Sleeve)
	add("gun", V(0.36, 0.36, 0.16), CFrame.lookAt(rHand + rDir * 0.2, rHand + rDir), C.Dark)

	-- Left arm (animated separately for reloads)
	local leftPivot = CF(-0.08, -0.17, -1.05)
	local lDir = V(-0.6, -0.55, 1).Unit
	add("left", V(0.24, 0.24, 0.36), ANG(0, 0, rad(-25)), C.Glove)
	add("left", V(0.34, 0.34, 1.9), CFrame.lookAt(lDir * 1.1, lDir * 2), C.Sleeve)
	add("left", V(0.36, 0.36, 0.16), CFrame.lookAt(lDir * 0.2, lDir), C.Dark)

	-- Magazine (animated separately)
	local magPivot = CF(0, -0.24, -0.28)
	add("mag", V(0.2, 0.34, 0.3), CF(0, -0.17, 0), C.Dark)
	add("mag", V(0.2, 0.34, 0.3), CF(0, -0.44, -0.07) * ANG(rad(-16), 0, 0), C.Dark)
	add("mag", V(0.22, 0.05, 0.32), CF(0, -0.62, -0.13) * ANG(rad(-16), 0, 0), C.Accent, NEON)

	-- Muzzle flash (relative to muzzle)
	add("flash", V(0.6, 0.07, 0.02), CF(0, 0, -0.05), C.Flash, NEON, { Transparency = 1 })
	add("flash", V(0.07, 0.6, 0.02), CF(0, 0, -0.05), C.Flash, NEON, { Transparency = 1 })
	add("flash", V(0.18, 0.18, 0.5), CF(0, 0, -0.25), C.Flash, NEON, { Transparency = 1 })

	local light = Instance.new("PointLight")
	light.Color = C.Flash; light.Range = 12; light.Brightness = 0; light.Shadows = false
	light.Parent = muzzle

	local smoke = Instance.new("ParticleEmitter")
	smoke.Enabled = false
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	smoke.LightEmission = 0
	smoke.Size = NumberSequence.new(0.12, 0.6)
	smoke.Transparency = NumberSequence.new(0.75, 1)
	smoke.Lifetime = NumberRange.new(0.4, 0.7)
	smoke.Speed = NumberRange.new(1, 2.5)
	smoke.Acceleration = Vector3.new(0, 1.5, 0)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Parent = muzzle

	return {
		Model = model, Groups = groups,
		MagPivot = magPivot, LeftPivot = leftPivot, MuzzleOffset = muzzleOffset,
		EjectOffset = CF(0.18, 0.1, -0.1),
		-- calculated so the reticle sits exactly at screen center, EYE_DIST in front of the camera
		AimOffset = CF(0, -SIGHT_Y, -(EYE_DIST + RETICLE_Z)),
		Light = light, Smoke = smoke, Reticle = reticle,
	}
end

return Builder
