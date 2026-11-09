-- PoseClient v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BOTH games (Lobby + Breakline), keep the two copies identical. NEW in v5.16 (GDD 5.10).
-- POSES (emotes):
--   * T opens the POSE WHEEL (the 6 poses you put on it in the cosmetics locker, POSES tab). Move the mouse over a slot (it follows the direction of
--     the mouse from the middle) and click, or press 1 - 6. T / ESC closes it. Breakline: only while the round is Playing.
--   * Your character holds the pose (a still pose, or a looping animated one) until you MOVE in any way (walk, jump, crouch / slide), or try to pull
--     something out (1 - 4, Q, E, F, R, G, a mouse click): the pose ends and you are back to normal. Holding a pose puts away what you held
--     (GunClient / GadgetClient read the character attribute Pose).
--   * While you pose, the camera swings out to a third-person view in front of you (drag-free: just move the mouse to look around you), and back
--     into first person when the pose ends.
--   * EVERY character with the attribute Pose (set by PoseServer) is animated here from the Poses module: the joint angles are blended in over
--     0.2 s, held, and blended out over 0.2 s when the pose ends. MoveAnim / ThirdPersonClient stand down while a character poses.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Poses = require(RS:WaitForChild("Poses"))
local UI = require(RS:WaitForChild("UIKit"))
local Skins = require(RS:WaitForChild("Skins"))
local K, F, new = UI.C, UI.F, UI.new
local Remotes = RS:WaitForChild("PoseRemotes", 30)
local PlayR = Remotes and Remotes:WaitForChild("Play", 10)
local StopR = Remotes and Remotes:WaitForChild("Stop", 10)

local rgb = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function tween(o, t, goal, style) TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal):Play() end
local function serverNow() return workspace:GetServerTimeNow() end
local isBreakline = RS:FindFirstChild("MatchState") ~= nil or RS:FindFirstChild("MatchConfig") ~= nil

-- ======================================================================================
-- 1) ANIMATE every posing character (Motor6D.Transform after the Animator, like MoveAnim / AbilityPose)
-- ======================================================================================
local FADE = 0.2
local states = {} -- char -> { w, id, at, last, motors }
local function motorsOf(char)
	local m = {}
	for key, spec in Poses.MOTORS do
		local part = char:FindFirstChild(spec[1])
		local mot = part and part:FindFirstChild(spec[2])
		if mot and mot:IsA("Motor6D") then m[key] = mot end
	end
	return m
end
local function rootScale(char)
	local lt = char:FindFirstChild("LowerTorso")
	return lt and math.clamp(lt.Size.Y / 0.4, 0.5, 2.5) or 1
end
local function target(key, j, sc)
	if key == "Root" then return CFrame.new(0, (j[4] or 0) * sc, 0) * CFrame.Angles(j[1], j[2], j[3]) end
	return Poses.Angles(j)
end
local function ease(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end
local function apply(st, J, w, out)
	local e = ease(w)
	for key, mot in st.motors do
		if mot.Parent and J[key] then
			local tg = target(key, J[key], st.sc)
			if out then mot.Transform = CFrame.identity:Lerp(tg, e) else mot.Transform = mot.Transform:Lerp(tg, e) end
		end
	end
end
RunService.Stepped:Connect(function(_, dt)
	dt = math.min(dt, 0.1)
	local now = serverNow()
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char and char.Parent then
			local id = char:GetAttribute("Pose")
			local st = states[char]
			if id and Poses.Is(id) then
				if not st then
					st = { w = 0, motors = motorsOf(char), sc = rootScale(char) }
					states[char] = st
					char.AncestryChanged:Connect(function(_, parent) if not parent then states[char] = nil end end)
				end
				if st.id ~= id then st.id, st.at = id, char:GetAttribute("PoseAt") or now end
				st.out = false
				st.w = math.min(1, st.w + dt / FADE)
				local J = Poses.Sample(id, now - st.at)
				st.last = J
				apply(st, J, st.w, false)
			elseif st then
				st.w -= dt / FADE
				if st.w <= 0 or not st.last then
					for _, mot in st.motors do if mot.Parent then mot.Transform = CFrame.identity end end
					states[char] = nil
				else
					apply(st, st.last, st.w, true)
				end
			end
		end
	end
end)

-- ======================================================================================
-- 2) YOUR pose: cancel on any movement / pulling something out, third-person camera, body shown
-- ======================================================================================
local function myChar() return player.Character end
local function myPose() local c = myChar() return c and c:GetAttribute("Pose") end
local lastStop = 0
local function stopMine()
	if myPose() == nil or os.clock() - lastStop < 0.3 then return end
	lastStop = os.clock()
	if StopR then StopR:FireServer() end
end
local CANCEL_KEYS = {
	[Enum.KeyCode.One] = true, [Enum.KeyCode.Two] = true, [Enum.KeyCode.Three] = true, [Enum.KeyCode.Four] = true, [Enum.KeyCode.Q] = true,
	[Enum.KeyCode.E] = true, [Enum.KeyCode.F] = true, [Enum.KeyCode.R] = true, [Enum.KeyCode.G] = true, [Enum.KeyCode.Space] = true,
	[Enum.KeyCode.C] = true, [Enum.KeyCode.LeftControl] = true, [Enum.KeyCode.ButtonA] = true, [Enum.KeyCode.ButtonX] = true, [Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.DPadLeft] = true, [Enum.KeyCode.DPadUp] = true, [Enum.KeyCode.DPadRight] = true,
}
local wheelOpen = false

local camOn, camYaw, camPitch, savedSubject = false, 0, 0.18, nil
local CAM_DIST, CAM_UP = 10, 1.3
local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude
local function showBody(char)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
	end
end
local function camStart(char)
	camOn = true
	local root = char:FindFirstChild("HumanoidRootPart")
	local lv = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	camYaw = math.atan2(lv.X, lv.Z) -- the camera sits IN FRONT of you, looking back at you
	camPitch = 0.18
	savedSubject = camera.CameraSubject
	camera.CameraType = Enum.CameraType.Scriptable
end
local function camStop()
	if not camOn then return end
	camOn = false
	camera.CameraType = Enum.CameraType.Custom
	local hum = myChar() and myChar():FindFirstChildOfClass("Humanoid")
	camera.CameraSubject = hum or savedSubject
end
RunService:BindToRenderStep("BreaklinePoseCam", Enum.RenderPriority.Camera.Value + 60, function(dt)
	local char = myChar()
	local id = char and char:GetAttribute("Pose")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (id and hum and root and hum.Health > 0) then camStop() return end
	if not camOn then camStart(char) end
	-- cancel on movement (after a short grace so the start never cancels itself)
	local started = char:GetAttribute("PoseAt") or serverNow()
	if serverNow() - started > 0.25 and (hum.MoveDirection.Magnitude > 0.1 or hum.Jump or char:GetAttribute("Sliding") == true
		or char:GetAttribute("Crouching") == true or char:GetAttribute("AbilityMode") ~= nil) then
		stopMine()
	end
	-- look around with the mouse (no button needed)
	if not wheelOpen then
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		local d = UIS:GetMouseDelta()
		camYaw -= d.X * 0.006
		camPitch = math.clamp(camPitch + d.Y * 0.005, -0.35, 1.1)
	end
	local focus = root.Position + Vector3.new(0, CAM_UP, 0)
	local dir = Vector3.new(math.sin(camYaw) * math.cos(camPitch), math.sin(camPitch), math.cos(camYaw) * math.cos(camPitch))
	rayP.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(focus, dir * CAM_DIST, rayP)
	local dist = hit and math.max(2.5, hit.Distance - 0.6) or CAM_DIST
	camera.CFrame = CFrame.lookAt(focus + dir * dist, focus)
	showBody(char)
end)

-- ======================================================================================
-- 3) THE POSE WHEEL (T)
-- ======================================================================================
local gui = new("ScreenGui", { Name = "PoseWheel", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 80, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local modal = new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) }, gui)
local _ = modal
local canvas = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1 }, gui)
local cScale = new("UIScale", {}, canvas)
local function rescale()
	local vp = camera.ViewportSize
	cScale.Scale = math.max(0.35, math.min(vp.X / 1920, vp.Y / 1080))
end
rescale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local CX, CY = 960, 540
local R_SLOT, SLOT_D = 205, 168
local dimBg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
dimBg.ZIndex = 0
local wheel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(620, 620), BackgroundTransparency = 1 }, canvas)
local wScale = new("UIScale", { Scale = 1 }, wheel)
local disc = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 620), BackgroundColor3 = rgb(8, 9, 12),
	BackgroundTransparency = 0.25, BorderSizePixel = 0 }, wheel)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, disc)
new("UIStroke", { Color = K.line2, Thickness = 1.5, Transparency = 0.2 }, disc)
local hole = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(196, 196), BackgroundColor3 = rgb(14, 15, 20),
	BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 3 }, wheel)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, hole)
new("UIStroke", { Color = K.line2, Thickness = 1, Transparency = 0.3 }, hole)
local pointer = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(150, 4), BackgroundColor3 = K.red,
	BorderSizePixel = 0, ZIndex = 2, Visible = false }, wheel)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(1, 0) }) }, pointer)
local centerName = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(180, 50),
	Text = "POSES", TextScaled = true, FontFace = F.H, TextColor3 = K.text, ZIndex = 4 }, wheel)
new("UITextSizeConstraint", { MaxTextSize = 34 }, centerName)
new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(180, 20),
	Text = "CLICK  //  1 - 6", TextSize = 13, FontFace = F.MB, TextColor3 = K.dim, ZIndex = 4 }, wheel)

local slots = {}
local tplCache = {} -- "skin|pose" -> ViewportFrame template
local function poseThumb(parent, poseId)
	local skin = player:GetAttribute("Skin")
	if not Skins.Is(skin) then skin = Skins.Default end
	local key = tostring(skin) .. "|" .. poseId
	local tpl = tplCache[key]
	if not tpl then
		tpl = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 160), LightColor = rgb(255, 250, 244),
			LightDirection = Vector3.new(-0.5, -0.9, -0.4) })
		new("Camera", { FieldOfView = 22 }, tpl)
		local model = new("Model", {}, tpl)
		local p = Poses.ById[poseId]
		local ok, fig = pcall(Skins.NewFigure, model, skin, { static = true, pose = poseId, poseT = p and p.still or 0 })
		if ok and fig then pcall(fig.Update, fig, 0, 0) end
		tplCache[key] = tpl
	end
	local vp = tpl:Clone()
	vp.Parent = parent
	local cam = vp:FindFirstChildOfClass("Camera")
	vp.CurrentCamera = cam
	pcall(UI.FitViewport, vp, cam, vp:FindFirstChildOfClass("Model"), Vector3.new(0.28, 0.1, 1), { pad = 0.08, fov = 22 })
	return vp
end
for i = 1, Poses.WHEEL do
	local ang = math.rad(-90 + (i - 1) * 60)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(310 + math.cos(ang) * R_SLOT, 310 + math.sin(ang) * R_SLOT), Size = UDim2.fromOffset(SLOT_D, SLOT_D),
		BackgroundColor3 = rgb(20, 22, 28), BorderSizePixel = 0, ZIndex = 5 }, wheel)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, b)
	local st = new("UIStroke", { Color = K.line, Thickness = 1.5 }, b)
	local sc = new("UIScale", { Scale = 1 }, b)
	local well = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(110, 104), BackgroundTransparency = 1,
		ZIndex = 6, ClipsDescendants = true }, b)
	local nm = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 118), Size = UDim2.fromOffset(136, 22),
		Text = "", TextScaled = true, FontFace = F.H, TextColor3 = K.text, ZIndex = 7 }, b)
	new("UITextSizeConstraint", { MaxTextSize = 19 }, nm)
	local num = new("TextLabel", { BackgroundColor3 = K.panel3, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(ang) * 74, 0.5, math.sin(ang) * 74), Size = UDim2.fromOffset(26, 26), Text = tostring(i), TextSize = 15, FontFace = F.H,
		TextColor3 = K.text, ZIndex = 8 }, b)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, num)
	slots[i] = { b = b, st = st, sc = sc, well = well, nm = nm, num = num, ang = ang, id = "" }
	-- (clicks are handled in InputBegan: one path for the mouse direction, clicks and the 1 - 6 keys)
end

local hovered = nil
local function paintSlots()
	for i, s in slots do
		local on = hovered == i and s.id ~= ""
		s.st.Color = on and K.red or (s.id ~= "" and K.line2 or K.line)
		s.st.Thickness = on and 3 or 1.5
		s.b.BackgroundColor3 = on and rgb(36, 20, 24) or rgb(20, 22, 28)
		tween(s.sc, 0.14, { Scale = on and 1.1 or 1 })
		s.num.BackgroundColor3 = on and K.red or K.panel3
	end
	local s = hovered and slots[hovered]
	if s and s.id ~= "" then
		centerName.Text = Poses.ById[s.id].name
		pointer.Visible = true
		pointer.Rotation = math.deg(s.ang)
	else
		centerName.Text = (s and s.id == "") and "EMPTY" or "POSES"
		pointer.Visible = s ~= nil
		if s then pointer.Rotation = math.deg(s.ang) end
	end
end
local function fillSlots()
	local w = Poses.Wheel(player)
	for i, s in slots do
		s.id = w[i] or ""
		for _, c in s.well:GetChildren() do c:Destroy() end
		if s.id ~= "" then
			s.nm.Text = Poses.ById[s.id].name
			s.nm.TextColor3 = K.text
			pcall(poseThumb, s.well, s.id)
		else
			s.nm.Text = "EMPTY"
			s.nm.TextColor3 = K.mute
		end
	end
end

local function canOpen()
	local char = myChar()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if UIS:GetFocusedTextBox() then return false end
	if player:GetAttribute("LobbyMenuOpen") == true or player:GetAttribute("CosmeticsShown") == true or player:GetAttribute("CardIndexOpen") == true then return false end
	if player:GetAttribute("GunMenuOpen") == true and not wheelOpen then return false end
	local ms = RS:FindFirstChild("MatchState")
	if ms and ms:GetAttribute("Phase") ~= "Playing" then return false end
	if player:GetAttribute("IsDead") == true then return false end
	return true
end
local function closeWheel()
	if not wheelOpen then return end
	wheelOpen = false
	hovered = nil
	if isBreakline then player:SetAttribute("GunMenuOpen", nil) end
	player:SetAttribute("PoseWheelOpen", nil)
	tween(wScale, 0.12, { Scale = 0.9 })
	tween(dimBg, 0.12, { BackgroundTransparency = 1 })
	task.delay(0.12, function() if not wheelOpen then gui.Enabled = false end end)
end
local function openWheel()
	if wheelOpen or not canOpen() then return end
	wheelOpen = true
	if isBreakline then player:SetAttribute("GunMenuOpen", true) end -- GunClient + GadgetClient ignore clicks / keys meanwhile
	player:SetAttribute("PoseWheelOpen", true)
	fillSlots()
	hovered = nil
	paintSlots()
	gui.Enabled = true
	wScale.Scale = 0.85
	tween(wScale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(dimBg, 0.2, { BackgroundTransparency = 0.55 })
end
local function playSlot(i)
	local s = slots[i]
	if not s or s.id == "" then return end
	closeWheel()
	if PlayR then PlayR:FireServer(i) end
end

-- the slot under the mouse: the DIRECTION of the mouse from the wheel's middle picks the slot (anything outside the centre hole)
RunService.RenderStepped:Connect(function()
	if not wheelOpen then return end
	if not canOpen() then closeWheel() return end
	local m = UIS:GetMouseLocation()
	local c = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
	local d = m - c
	local k = wheel.AbsoluteSize.X / 620
	local pick = nil
	if d.Magnitude > 92 * k then
		local a = math.deg(math.atan2(d.Y, d.X)) + 90 -- 0 = straight up, clockwise
		pick = (math.floor(((a + 30) % 360) / 60)) + 1
	end
	if pick ~= hovered then hovered = pick paintSlots() end
end)

local NUM = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6 }
UIS.InputBegan:Connect(function(input, gpe)
	if UIS:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.T and not gpe then
		if wheelOpen then closeWheel() else openWheel() end
		return
	end
	if wheelOpen then
		if input.KeyCode == Enum.KeyCode.Escape then closeWheel() return end
		if NUM[input.KeyCode] then playSlot(NUM[input.KeyCode]) return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if hovered then playSlot(hovered) else closeWheel() end
		end
		return
	end
	-- posing: pulling anything out (or pressing a move key) ends the pose
	if myPose() ~= nil and not gpe then
		if CANCEL_KEYS[input.KeyCode] or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
			stopMine()
		end
	end
end)

player.CharacterAdded:Connect(function()
	closeWheel()
	camStop()
end)
