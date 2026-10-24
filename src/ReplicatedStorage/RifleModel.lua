-- RifleModel: detailed VX-9 rifle + "Compact Reflector"-style optic.
-- Build({scale, accent, reticle = "Dot"|"Holo"|"Chevron"|"None", reticleColor, name})
local RifleModel = {}

local C = {
	Body    = Color3.fromRGB(36, 38, 44),
	Polymer = Color3.fromRGB(50, 52, 58),
	Metal   = Color3.fromRGB(70, 74, 82),
	Dark    = Color3.fromRGB(16, 16, 19),
	Lens    = Color3.fromRGB(150, 200, 255),
	Reticle = Color3.fromRGB(255, 45, 45),
}
local DEFAULT_ACCENT = Color3.fromRGB(255, 140, 30)
local rad = math.rad
local V, CF = Vector3.new, CFrame.new
local function ang(p, y, r) return CFrame.Angles(rad(p), rad(y), rad(r)) end

local function buildReticle(part, style, color, pps)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Reticle"
	gui.Face = Enum.NormalId.Back -- faces the shooter
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = 0
	gui.Brightness = 4
	gui.AlwaysOnTop = false
	gui.ClipsDescendants = true
	gui.Parent = part

	local function dot(size, transparency)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromOffset(size, size)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = transparency
		f.BorderSizePixel = 0
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
		f.Parent = gui
		return f
	end

	if style == "Holo" then
		local ring = dot(150, 1)
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 4
		stroke.Parent = ring
		dot(26, 0.85)
		dot(8, 0)
	elseif style == "Chevron" then
		for _, s in ipairs({-1, 1}) do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Size = UDim2.fromOffset(5, 26)
			bar.Position = UDim2.new(0.5, s * 7.5, 0.5, 10.6)
			bar.Rotation = -s * 35
			bar.BackgroundColor3 = color
			bar.BorderSizePixel = 0
			bar.Parent = gui
		end
	else -- "Dot"
		dot(30, 0.82) -- soft bloom
		dot(10, 0)    -- crisp dot
	end
end

function RifleModel.Build(opts)
	opts = opts or {}
	local s = opts.scale or 1
	local accent = opts.accent or DEFAULT_ACCENT
	local reticleStyle = opts.reticle or "Dot"

	local model = Instance.new("Model")
	model.Name = opts.name or "Rifle"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V(0.1, 0.1, 0.1) * s
	root.Transparency = 1
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless = false, false, false, true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local function add(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		if shape then p.Shape = shape end
		p.Size = size * s
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CastShadow = size.Magnitude * s > 0.3
		local lcf = CF(cf.Position * s) * cf.Rotation
		p.CFrame = root.CFrame * lcf
		local w = Instance.new("Weld")
		w.Part0, w.Part1, w.C0 = root, p, lcf
		w.Parent = p
		p.Parent = model
		return p
	end
	local function glow(name, size, cf)
		local p = add(name, size, cf, accent, Enum.Material.Neon)
		p:SetAttribute("TeamAccent", true)
		p.CastShadow = false
		return p
	end
	local function cylZ(name, length, dia, cf, color, material) -- cylinder along the barrel axis
		return add(name, V(length, dia, dia), cf * ang(0, 90, 0), color, material, Enum.PartType.Cylinder)
	end
	local function cylX(name, length, dia, cf, color, material) -- cylinder sideways
		return add(name, V(length, dia, dia), cf, color, material, Enum.PartType.Cylinder)
	end
	local function att(parent, name, cf)
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = CF(cf.Position * s) * cf.Rotation
		a.Parent = parent
		return a
	end
	local function octRing(name, center, innerR, thick, depth, color)
		local R = innerR + thick / 2
		local len = 2 * R * math.tan(math.pi / 8) + 0.01
		for i = 0, 7 do
			add(name, V(len, thick, depth), center * CFrame.Angles(0, 0, i * math.pi / 4) * CF(0, R, 0), color)
		end
	end

	-- Grip + trigger
	local grip = add("Grip", V(0.2, 0.52, 0.32), CF(0, -0.02, 0.04) * ang(-16, 0, 0), C.Polymer)
	add("GripPanel", V(0.215, 0.3, 0.2), CF(0, -0.06, 0.06) * ang(-16, 0, 0), C.Dark)
	add("TriggerGuard", V(0.04, 0.035, 0.36), CF(0, 0.08, -0.22), C.Dark)
	add("GuardPost", V(0.04, 0.16, 0.04), CF(0, 0.15, -0.39), C.Dark)
	add("Trigger", V(0.035, 0.12, 0.045), CF(0, 0.14, -0.16) * ang(-12, 0, 0), C.Metal)

	-- Receiver
	add("LowerReceiver", V(0.27, 0.3, 1.0), CF(0, 0.33, -0.25), C.Body)
	add("Magwell", V(0.25, 0.2, 0.38), CF(0, 0.12, -0.62), C.Body)
	add("UpperReceiver", V(0.3, 0.26, 1.35), CF(0, 0.6, -0.32), C.Body)
	add("TopCover", V(0.24, 0.06, 1.2), CF(0, 0.755, -0.32), C.Metal)
	add("Rail", V(0.18, 0.05, 1.15), CF(0, 0.81, -0.35), C.Dark)
	for i = 0, 8 do add("RailTooth", V(0.2, 0.025, 0.05), CF(0, 0.845, -0.85 + i * 0.125), C.Dark) end
	add("EjectionPort", V(0.02, 0.12, 0.34), CF(0.152, 0.6, -0.2), C.Dark)
	add("ChargingHandle", V(0.14, 0.06, 0.14), CF(0, 0.75, 0.4), C.Dark)
	glow("SideStripeR", V(0.02, 0.035, 0.8), CF(0.155, 0.5, -0.45))
	glow("SideStripeL", V(0.02, 0.035, 0.8), CF(-0.155, 0.5, -0.45))

	-- Handguard + foregrip
	add("Handguard", V(0.32, 0.32, 1.05), CF(0, 0.56, -1.5), C.Polymer)
	add("HandguardRail", V(0.16, 0.04, 0.9), CF(0, 0.74, -1.5), C.Dark)
	for _, sx in ipairs({-1, 1}) do
		for i = 0, 2 do add("Vent", V(0.02, 0.09, 0.2), CF(sx * 0.162, 0.6, -1.2 - i * 0.3), C.Dark) end
	end
	glow("HandguardStripe", V(0.12, 0.02, 0.6), CF(0, 0.395, -1.62))
	local fore = add("Foregrip", V(0.13, 0.32, 0.15), CF(0, 0.25, -1.2) * ang(-8, 0, 0), C.Dark)

	-- Barrel + muzzle
	add("GasBlock", V(0.16, 0.15, 0.1), CF(0, 0.6, -2.08), C.Dark)
	cylZ("Barrel", 0.75, 0.12, CF(0, 0.58, -2.4), C.Metal)
	local muzzle = cylZ("Muzzle", 0.28, 0.2, CF(0, 0.58, -2.85), C.Dark)
	for _, sx in ipairs({-1, 1}) do add("MuzzlePort", V(0.03, 0.07, 0.07), CF(sx * 0.1, 0.58, -2.83), C.Metal) end

	-- Mag
	local magCF = CF(0, -0.15, -0.68) * ang(12, 0, 0)
	local mag = add("Mag", V(0.19, 0.6, 0.34), magCF, C.Polymer)
	local magBase = glow("MagBase", V(0.21, 0.05, 0.37), magCF * CF(0, -0.3, 0))

	-- Stock
	cylZ("BufferTube", 0.55, 0.13, CF(0, 0.58, 0.6), C.Dark)
	add("Stock", V(0.22, 0.36, 0.6), CF(0, 0.47, 0.95), C.Polymer)
	add("CheekRest", V(0.2, 0.08, 0.42), CF(0, 0.68, 0.92), C.Body)
	add("ButtPad", V(0.24, 0.48, 0.1), CF(0, 0.43, 1.3), C.Dark)
	glow("StockStripeR", V(0.01, 0.03, 0.4), CF(0.115, 0.5, 0.95))
	glow("StockStripeL", V(0.01, 0.03, 0.4), CF(-0.115, 0.5, 0.95))

	-- Optic: compact reflector
	local O = CF(0, 0.835, -0.45)
	add("OpticBase", V(0.24, 0.09, 0.42), O * CF(0, 0.045, 0.02), C.Body)
	add("OpticClamp", V(0.04, 0.12, 0.3), O * CF(0.13, 0.03, 0.02), C.Dark)
	cylX("OpticKnob", 0.06, 0.1, O * CF(0.17, 0.04, 0.02), C.Metal)
	local hc = O * CF(0, 0.3, -0.04) -- hood center = reticle line
	octRing("OpticHood", hc, 0.15, 0.04, 0.26, C.Body)
	octRing("OpticLip", hc * CF(0, 0, -0.135), 0.155, 0.03, 0.03, C.Metal)
	add("OpticBridge", V(0.16, 0.06, 0.24), hc * CF(0, -0.2, 0), C.Body)
	glow("OpticStripe", V(0.05, 0.012, 0.18), hc * CF(0, 0.196, 0))
	cylX("OpticBattery", 0.07, 0.12, hc * CF(-0.215, -0.06, 0.05), C.Metal)
	local ring = cylX("OpticBatteryRing", 0.02, 0.125, hc * CF(-0.255, -0.06, 0.05), accent, Enum.Material.Neon)
	ring:SetAttribute("TeamAccent", true)
	local lens = cylZ("OpticLens", 0.012, 0.31, hc * CF(0, 0, -0.07), C.Lens, Enum.Material.Glass)
	lens.Transparency = 0.75
	lens.Reflectance = 0.08
	lens.CastShadow = false
	if reticleStyle ~= "None" then
		local rp = add("OpticReticle", V(0.3, 0.3, 0.002), hc * CF(0, 0, -0.05), C.Dark)
		rp.Transparency = 1
		buildReticle(rp, reticleStyle, opts.reticleColor or C.Reticle, 1000 / s)
	end

	-- Attachments (hands, muzzle, ADS aim point)
	att(grip, "RightGrip", CF(0.2, 0.05, 0))
	att(fore, "LeftForegrip", CF(-0.2, 0.02, 0))
	att(mag, "LeftMagwell", CF(-0.25, 0.08, 0))
	att(root, "MuzzlePoint", CF(0, 0.58, -3.0))
	att(root, "AimPoint", hc * CF(0, 0, -0.05)) -- reticle center, -Z = downrange

	-- Muzzle flash
	local flash = add("Flash", V(0.4, 0.4, 0.7), CF(0, 0.58, -3.3), Color3.fromRGB(255, 200, 90), Enum.Material.Neon)
	flash.Transparency = 1
	flash.CastShadow = false
	local light = Instance.new("PointLight")
	light.Name = "FlashLight"
	light.Color = Color3.fromRGB(255, 190, 90)
	light.Range = 12
	light.Brightness = 5
	light.Enabled = false
	light.Parent = muzzle

	model:SetAttribute("Scale", s)
	mag:SetAttribute("IsMag", true)
	magBase:SetAttribute("IsMag", true)
	return model
end

function RifleModel.SetAccent(model, color)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("TeamAccent") then d.Color = color end
	end
end

return RifleModel
