-- AvatarService: every player spawns as a custom blocky "operator"
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

StarterPlayer.LoadCharacterAppearance = false

local LOOK = {
	Suit   = Color3.fromRGB(40, 42, 48),
	Under  = Color3.fromRGB(26, 27, 31),
	Armor  = Color3.fromRGB(78, 82, 90),
	Trim   = Color3.fromRGB(18, 18, 21),
	Accent = Color3.fromRGB(255, 140, 30), -- used when there are no teams
}

local BODY_COLORS = {
	Head = LOOK.Under, Torso = LOOK.Suit, UpperTorso = LOOK.Suit, LowerTorso = LOOK.Under,
	LeftUpperArm = LOOK.Suit, RightUpperArm = LOOK.Suit, LeftLowerArm = LOOK.Suit, RightLowerArm = LOOK.Suit,
	LeftHand = LOOK.Trim, RightHand = LOOK.Trim, ["Left Arm"] = LOOK.Suit, ["Right Arm"] = LOOK.Suit,
	LeftUpperLeg = LOOK.Under, RightUpperLeg = LOOK.Under, LeftLowerLeg = LOOK.Under, RightLowerLeg = LOOK.Under,
	LeftFoot = LOOK.Trim, RightFoot = LOOK.Trim, ["Left Leg"] = LOOK.Under, ["Right Leg"] = LOOK.Under,
}

local function accentFor(player)
	if player.Team and not player.Neutral then return player.TeamColor.Color end
	return LOOK.Accent
end

local function addPart(parent, base, name, size, offset, color, material, isAccent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CFrame = base.CFrame * offset
	if isAccent then
		p:SetAttribute("TeamAccent", true)
		p.CastShadow = false
	end
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = base, p, offset
	w.Parent = p
	p.Parent = parent
	return p
end

local function visualHeadSize(head)
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		local s = math.min(head.Size.Y, head.Size.Z) * (mesh.Scale.Y / 1.25) * 1.2
		return Vector3.new(s, s, s)
	end
	return head.Size
end

local function dress(player, char)
	local head = char:WaitForChild("Head", 10)
	local torso = char:FindFirstChild("UpperTorso") or char:WaitForChild("UpperTorso", 3) or char:FindFirstChild("Torso")
	if not head or not torso or not char.Parent then return end

	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then bc:Destroy() end
	for _, d in ipairs(char:GetChildren()) do
		if d:IsA("BasePart") and BODY_COLORS[d.Name] then d.Color = BODY_COLORS[d.Name] end
		if d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") or d:IsA("Accessory") then d:Destroy() end
	end
	local face = head:FindFirstChild("face")
	if face then face:Destroy() end

	local old = char:FindFirstChild("Gear")
	if old then old:Destroy() end
	local gear = Instance.new("Model")
	gear.Name = "Gear"
	gear.Parent = char

	local A = accentFor(player)
	local Neon = Enum.Material.Neon

	-- Helmet + visor
	local h = visualHeadSize(head)
	addPart(gear, head, "Helmet", Vector3.new(h.X*1.14, h.Y*0.5, h.Z*1.14), CFrame.new(0, h.Y*0.3, 0.02), LOOK.Armor)
	addPart(gear, head, "HelmetRidge", Vector3.new(h.X*0.22, h.Y*0.12, h.Z*1.18), CFrame.new(0, h.Y*0.58, 0), LOOK.Trim)
	addPart(gear, head, "VisorFrame", Vector3.new(h.X*1.1, h.Y*0.28, 0.12), CFrame.new(0, h.Y*0.02, -h.Z*0.5 - 0.04), LOOK.Trim)
	addPart(gear, head, "Visor", Vector3.new(h.X*0.94, h.Y*0.13, 0.06), CFrame.new(0, h.Y*0.02, -h.Z*0.5 - 0.11), A, Neon, true)
	for _, s in ipairs({-1, 1}) do
		addPart(gear, head, "EarCup", Vector3.new(0.16, h.Y*0.4, h.Z*0.5), CFrame.new(s*(h.X*0.5 + 0.06), -h.Y*0.02, 0.05), LOOK.Trim)
	end
	addPart(gear, head, "Antenna", Vector3.new(0.05, h.Y*0.7, 0.05), CFrame.new(-(h.X*0.5 + 0.1), h.Y*0.45, 0.15), LOOK.Trim)
	addPart(gear, head, "AntennaTip", Vector3.new(0.09, 0.09, 0.09), CFrame.new(-(h.X*0.5 + 0.1), h.Y*0.82, 0.15), A, Neon, true)

	-- Chest rig + back power cell
	local t = torso.Size
	addPart(gear, torso, "ChestPlate", Vector3.new(t.X*0.86, t.Y*0.62, 0.22), CFrame.new(0, t.Y*0.12, -t.Z*0.5 - 0.1), LOOK.Armor)
	addPart(gear, torso, "ChestStripe", Vector3.new(t.X*0.5, 0.08, 0.05), CFrame.new(0, t.Y*0.28, -t.Z*0.5 - 0.23), A, Neon, true)
	for _, s in ipairs({-1, 1}) do
		addPart(gear, torso, "Pouch", Vector3.new(t.X*0.24, t.Y*0.22, 0.2), CFrame.new(s*t.X*0.22, -t.Y*0.22, -t.Z*0.5 - 0.2), LOOK.Trim)
	end
	addPart(gear, torso, "PowerCell", Vector3.new(t.X*0.56, t.Y*0.66, 0.42), CFrame.new(0, t.Y*0.05, t.Z*0.5 + 0.2), LOOK.Trim)
	addPart(gear, torso, "CellCore", Vector3.new(t.X*0.14, t.Y*0.46, 0.06), CFrame.new(0, t.Y*0.05, t.Z*0.5 + 0.43), A, Neon, true)

	local lt = char:FindFirstChild("LowerTorso")
	if lt then
		local l = lt.Size
		addPart(gear, lt, "Belt", Vector3.new(l.X*1.05, l.Y*0.35, l.Z*1.1), CFrame.new(0, l.Y*0.15, 0), LOOK.Trim)
	end

	-- Shoulder + knee pads
	for _, side in ipairs({"Left", "Right"}) do
		local arm = char:FindFirstChild(side .. "UpperArm") or char:FindFirstChild(side .. " Arm")
		if arm then
			local a, upper = arm.Size, arm.Name:find("Upper") ~= nil
			addPart(gear, arm, side .. "Pad", Vector3.new(a.X*1.18, a.Y*(upper and 0.32 or 0.18), a.Z*1.18),
				CFrame.new(0, a.Y*(upper and 0.3 or 0.38), 0), LOOK.Armor)
		end
		local leg = char:FindFirstChild(side .. "LowerLeg") or char:FindFirstChild(side .. " Leg")
		if leg then
			local l = leg.Size
			local y = leg.Name:find("Lower") and l.Y*0.3 or -l.Y*0.05
			addPart(gear, leg, side .. "Knee", Vector3.new(l.X*0.8, math.min(l.Y*0.3, 0.55), 0.16), CFrame.new(0, y, -l.Z*0.5 - 0.06), LOOK.Armor)
		end
	end
end

local function recolor(player)
	local char = player.Character
	if not char then return end
	local A = accentFor(player)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("TeamAccent") then d.Color = A end
	end
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) dress(player, char) end)
	player:GetPropertyChangedSignal("Team"):Connect(function() recolor(player) end)
	player:GetPropertyChangedSignal("TeamColor"):Connect(function() recolor(player) end)
	if player.Character then task.spawn(dress, player, player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
