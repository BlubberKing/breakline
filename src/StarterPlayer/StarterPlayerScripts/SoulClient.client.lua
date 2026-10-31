-- SoulClient v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v4.1.
-- Everything you see and do about SOULS (the thing a dead teammate leaves behind), made by DeathServer:
--   LOOK     each soul is a stylised wisp: a glowing teardrop core in the dead player's TEAM colour, two turning halo rings, orbiting sparks, a flowing
--            tail, a soft light, a floor ring + beam, and a BIG NAME TAG above it ("<NAME>" + "SOUL" + the revive progress). Bobs gently while loose.
--   CARRY    hold E on it = pick it up (like a box). While carrying: LEFT CLICK = throw, Q = drop. (Guns / gadgets are put away, MatchHUD hint shows.)
--   REVIVE   hold F on it for 8 s (stand next to it, you kneel and cannot move). While you do, the REVIVED player's body is built right there out of
--            souls (RevealFX, slowly, matching the 8 s) and a progress ring + the name show on the soul. If you let go or walk away, the body vanishes.
--   PROMPTS  the E / F prompts are only shown to living teammates of the dead player (never to the owner, never to the enemy), and the F prompt
--            is hidden while the soul is carried or someone else is already reviving it.
-- Uses the soul part attributes set by DeathServer: OwnerId, OwnerName, TeamName, State, RezBy, RezStart, RezTime, Ground, Carrier.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local CS = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = require(RS:WaitForChild("MatchConfig"))
local RevealFX = require(RS:WaitForChild("RevealFX"))
local Skins = require(RS:WaitForChild("Skins"))
local Remotes = RS:WaitForChild("SoulRemotes")
local ThrowR, DropR = Remotes:WaitForChild("Throw"), Remotes:WaitForChild("Drop")
local MatchState = RS:WaitForChild("MatchState")

local rad, sin, cos, clamp = math.rad, math.sin, math.cos, math.clamp
local TEAM_COLORS = { [C.Teams[1].Name] = C.Teams[1].Color.Color, [C.Teams[2].Name] = C.Teams[2].Color.Color 
}
local ICE = Color3.fromRGB(220, 246, 255)

local fxFolder = workspace:FindFirstChild("SoulFX") or Instance.new("Folder")
if not fxFolder.Parent then fxFolder.Name = "SoulFX"; fxFolder.Parent = workspace end

local function mk(size, color, transp, shape, parent)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transp or 0
	p.Size = size
	if shape then p.Shape = shape end
	p.Parent = parent or fxFolder
	return p
end

------------------------------------------------------------------ the soul look
local looks = {} -- soul part -> look

local function teamColorOf(part)
	return TEAM_COLORS[part:GetAttribute("TeamName") or ""] or Color3.fromRGB(110, 200, 255)
end

local function buildLook(part)
	local col = teamColorOf(part)
	local look = { part = part, col = col, born = os.clock(), seed = math.random() * 10, parts = {} }
	local function add(p) table.insert(look.parts, p) return p end
	local folder = Instance.new("Folder")
	folder.Name = "SoulLook_" .. part:GetAttribute("OwnerName")
	folder.Parent = fxFolder
	look.folder = folder
	-- v4.2: a TINY ghostly soul: a small pale translucent head, a wispy tail that fades out, two little dark eyes, a faint glow
	look.core = add(mk(Vector3.new(0.5, 0.56, 0.5), ICE, 0.35, Enum.PartType.Ball, folder))
	look.shell = add(mk(Vector3.new(0.72, 0.8, 0.72), col, 0.78, Enum.PartType.Ball, folder))
	look.glow = add(mk(Vector3.new(1.3, 1.45, 1.3), col, 0.93, Enum.PartType.Ball, folder))
	look.tail = {}
	for i = 1, 6 do
		table.insert(look.tail, add(mk(Vector3.one * (0.46 - i * 0.065), i % 2 == 0 and col or ICE, 0.45 + i * 0.09, Enum.PartType.Ball, folder)))
	end
	look.eyes = {}
	for i = 1, 2 do
		table.insert(look.eyes, add(mk(Vector3.new(0.09, 0.13, 0.05), Color3.fromRGB(20, 26, 40), 0.1, nil, folder)))
	end
	look.rings, look.sparks = {}, {}
	local pl = Instance.new("PointLight")
	pl.Color, pl.Range, pl.Brightness = col, 6, 0.9
	pl.Parent = look.core
	-- faint floor ring only (no beam)
	look.floorRing = add(mk(Vector3.new(0.06, 1.6, 1.6), col, 0.6, Enum.PartType.Cylinder, folder))
	look.floorDot = add(mk(Vector3.new(0.06, 0.6, 0.6), ICE, 0.7, Enum.PartType.Cylinder, folder))
	look.beam = add(mk(Vector3.new(0.1, 0.1, 0.1), col, 1, nil, folder))
	-- name tag
	local bb = Instance.new("BillboardGui")
	bb.Name = "Tag"
	bb.Adornee = look.core
	bb.Size = UDim2.fromOffset(300, 92)
	bb.StudsOffset = Vector3.new(0, 1.7, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 220
	bb.LightInfluence = 0
	bb.Parent = look.core
	local function lbl(y, h, text, size, color, bold)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position, t.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(300, h)
		t.Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamMedium
		t.TextSize = size
		t.TextColor3 = color
		t.Text = text
		t.TextStrokeColor3 = Color3.new(0, 0, 0)
		t.TextStrokeTransparency = 0.35
		t.Parent = bb
		return t
	end
	look.nameLbl = lbl(0, 34, string.upper(part:GetAttribute("OwnerName")), 30, col:Lerp(Color3.new(1, 1, 1), 0.35), true)
	look.subLbl = lbl(34, 20, "SOUL", 15, Color3.fromRGB(190, 215, 240), false)
	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 0)
	barBack.Position = UDim2.new(0.5, 0, 0, 62)
	barBack.Size = UDim2.fromOffset(190, 9)
	barBack.BackgroundColor3 = Color3.new(0, 0, 0)
	barBack.BackgroundTransparency = 0.35
	barBack.BorderSizePixel = 0
	barBack.Visible = false
	barBack.Parent = bb
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = col
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	look.barBack, look.barFill = barBack, barFill
	look.tag = bb
	looks[part] = look
	return look
end

local function destroyLook(part)
	local look = looks[part]
	if not look then return end
	looks[part] = nil
	if look.rez then
		look.rez.fx:Finish(true)
		if look.rez.ghost.Parent then look.rez.ghost:Destroy() end
	end
	look.folder:Destroy()
end

------------------------------------------------------------------ revive animation (the revived player's body is built right where the reviver kneels)
local function ownerCharacter(part)
	local p = Players:GetPlayerByUserId(part:GetAttribute("OwnerId") or 0)
	return p
end

local function startRezFx(look)
	local part = look.part
	local owner = ownerCharacter(part)
	local g = part:GetAttribute("Ground") or (part.Position.Y - 1.5)
	-- a posed copy of the revived player's body (their dead body is in pieces): their skin, standing beside the soul, facing the reviver
	local by = Players:GetPlayerByUserId(part:GetAttribute("RezBy") or 0)
	local byRoot = by and by.Character and by.Character:FindFirstChild("HumanoidRootPart")
	local pos = Vector3.new(part.Position.X, g, part.Position.Z)
	local face = byRoot and (Vector3.new(byRoot.Position.X, g, byRoot.Position.Z) - pos) or Vector3.new(0, 0, 1)
	if face.Magnitude < 0.1 then face = Vector3.new(0, 0, 1) end
	face = face.Unit
	-- the body stands 3.4 studs to the side of the soul so the reviver (who kneels at the soul) is not inside it
	local side = face:Cross(Vector3.yAxis)
	pos += side * 3.2
	local skinId = (owner and owner:GetAttribute("Skin")) or Skins.Default
	local weapon = (owner and owner:GetAttribute("Weapon")) or nil
	local fig = Skins.NewFigure(fxFolder, skinId, { weapon = weapon, still = true })
	fig:SetRoot(CFrame.lookAt(pos, pos - face)) -- figures face their local +Z (same as MatchFlow.faceDir)
	fig:Update(0, 0)
	local ghost = fig.Model
	local cf, size = ghost:GetBoundingBox()
	local height = math.max(size.Y, 4)
	local feet = cf.Position.Y - size.Y / 2
	local start = part:GetAttribute("RezStart") or workspace:GetServerTimeNow()
	local total = part:GetAttribute("RezTime") or C.REZ_TIME
	local function parts()
		local list = {}
		for _, d in ghost:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then table.insert(list, d) end
		end
		return list
	end
	local fx = RevealFX.New({
		parts = parts,
		x = pos.X, z = pos.Z, feet = feet, height = height, duration = total,
		progress = function() return (workspace:GetServerTimeNow() - start) / total end,
		highlightAdornee = ghost,
	})
	look.rez = { fx = fx, ghost = ghost, fig = fig, start = start, total = total, by = part:GetAttribute("RezBy") }
	for _, d in parts() do d.LocalTransparencyModifier = 1 end
end

local function stopRezFx(look)
	local r = look.rez
	if not r then return end
	look.rez = nil
	r.fx:Finish(true) -- cancelled: it just fades away
	local ghost = r.ghost
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0
			TweenService:Create(d, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
	end
	task.delay(0.4, function() if ghost.Parent then ghost:Destroy() end end)
end

------------------------------------------------------------------ per-frame
local function smooth(x) x = clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function myAliveTeam()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 or player:GetAttribute("IsDead") == true then return nil end
	return player.Team and player.Team.Name or nil
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	-- create / destroy looks
	for _, part in CS:GetTagged("Soul") do
		if part:IsA("BasePart") and part.Parent and not looks[part] then buildLook(part) end
	end
	for part, look in looks do
		if not part.Parent then destroyLook(part) continue end
		local t = now - look.born + look.seed
		local state = part:GetAttribute("State")
		local rezBy = part:GetAttribute("RezBy")
		local pos = part.Position
		local g = part:GetAttribute("Ground") or (pos.Y - 1.5)
		-- bobbing while loose, steadier while carried, flickering when thrown
		local bob = (state == "Loose") and sin(t * 2.1) * 0.22 or 0
		local c = pos + Vector3.new(0, bob, 0)
		local tilt = (state == "Thrown") and (t * 8) or 0
		look.core.CFrame = CFrame.new(c) * CFrame.Angles(0, t * 0.8, tilt * 0.2)
		local pulse = 1 + 0.06 * sin(t * 4)
		look.core.Size = Vector3.new(0.5, 0.56, 0.5) * pulse
		look.shell.CFrame = look.core.CFrame
		look.shell.Size = Vector3.new(0.72, 0.8, 0.72) * (1 + 0.08 * sin(t * 3 + 1))
		look.glow.CFrame = look.core.CFrame
		look.glow.Size = Vector3.new(1.3, 1.45, 1.3) * (1 + 0.1 * sin(t * 2.4 + 2))
		-- the wispy tail trails below and sways like smoke
		for i, tp in look.tail do
			local sway = Vector3.new(sin(t * 3 + i * 0.8) * 0.07 * i, -0.3 - i * 0.2, cos(t * 2.6 + i * 0.8) * 0.07 * i)
			tp.CFrame = CFrame.new(c + sway)
		end
		-- two tiny eyes, on the side of the head that faces the camera
		local toCam = camera.CFrame.Position - c
		local faceCF = CFrame.lookAt(c, Vector3.new(camera.CFrame.Position.X, c.Y, camera.CFrame.Position.Z))
		for i, e in look.eyes do
			e.CFrame = faceCF * CFrame.new((i == 1 and -0.1 or 0.1), 0.05, -0.23)
		end
		-- floor marker (small + faint)
		local onFloor = state ~= "Thrown"
		look.floorRing.Transparency = onFloor and (0.6 + 0.2 * sin(t * 3)) or 1
		look.floorDot.Transparency = onFloor and 0.7 or 1
		local fpos = Vector3.new(c.X, g + 0.1, c.Z)
		look.floorRing.CFrame = CFrame.new(fpos) * CFrame.Angles(0, 0, math.rad(90))
		look.floorRing.Size = Vector3.new(0.06, 1.5 + 0.2 * sin(t * 3), 1.5 + 0.2 * sin(t * 3))
		look.floorDot.CFrame = CFrame.new(fpos) * CFrame.Angles(0, 0, math.rad(90))
		look.beam.CFrame = CFrame.new(c.X, g + 1, c.Z)

		-- is it a soul I can use? (living teammate of the dead player)
		local mine = (part:GetAttribute("OwnerId") == player.UserId)
		local myTeam = myAliveTeam()
		local team = part:GetAttribute("TeamName")
		local isMate = myTeam ~= nil and myTeam == team and not mine
		local mineAlive = part:FindFirstChild("PickPrompt")
		local pick, rez = part:FindFirstChild("PickPrompt"), part:FindFirstChild("RezPrompt")
		local busy = rezBy ~= nil
		local carryingSomething = player:GetAttribute("Carrying") == true or player:GetAttribute("CarryingSoul") == true
		if pick then pick.Enabled = isMate and state == "Loose" and not busy and not carryingSomething end
		if rez then
			rez.Enabled = isMate and state == "Loose" and (not busy or rezBy == player.UserId) and not carryingSomething
		end
		-- name tag + progress
		look.subLbl.Text = mine and "YOUR SOUL" or (isMate and "HOLD  F  REVIVE    E  CARRY" or "SOUL")
		look.tag.Enabled = true
		local scale = clamp((camera.CFrame.Position - c).Magnitude / 45, 0.6, 1.2)
		look.tag.Size = UDim2.fromOffset(300 * scale, 92 * scale)
		if rezBy then
			local start = part:GetAttribute("RezStart") or 0
			local total = part:GetAttribute("RezTime") or C.REZ_TIME
			local f = clamp((workspace:GetServerTimeNow() - start) / total, 0, 1)
			look.barBack.Visible = true
			look.barFill.Size = UDim2.fromScale(f, 1)
			look.subLbl.Text = ("REVIVING  %d%%"):format(math.floor(f * 100))
			if not look.rez then startRezFx(look) end
		else
			look.barBack.Visible = false
			if look.rez then stopRezFx(look) end
		end
		if look.rez then
			local rzz = look.rez
			rzz.fig:Update(now, dt)
			rzz.fx:Step(dt)
			if workspace:GetServerTimeNow() - rzz.start > rzz.total + 0.2 then
				-- the server will respawn the player any moment now: hold the finished pose
			end
		end
	end
end)

------------------------------------------------------------------ carrying a soul: click = throw, Q = drop
local THROW = "SoulThrow"
local carrying = false
local function setCarrying(on)
	if on == carrying then return end
	carrying = on
	if on then
		CAS:BindActionAtPriority(THROW, function(_, state)
			if state == Enum.UserInputState.Begin then ThrowR:FireServer(camera.CFrame.LookVector) end
			return Enum.ContextActionResult.Sink
		end, true, Enum.ContextActionPriority.High.Value + 1, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		CAS:SetTitle(THROW, "Throw")
		CAS:SetPosition(THROW, UDim2.new(1, -95, 1, -245))
	else
		CAS:UnbindAction(THROW)
	end
end
player:GetAttributeChangedSignal("CarryingSoul"):Connect(function() setCarrying(player:GetAttribute("CarryingSoul") == true) end)
setCarrying(player:GetAttribute("CarryingSoul") == true)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if (input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1) and player:GetAttribute("CarryingSoul") == true then
		DropR:FireServer()
	end
end)

-- hint under the crosshair while carrying a soul / reviving
local gui = Instance.new("ScreenGui")
gui.Name = "SoulHint"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 7
gui.Parent = player:WaitForChild("PlayerGui")
local hint = Instance.new("TextLabel")
hint.AnchorPoint = Vector2.new(0.5, 0.5)
hint.Position = UDim2.new(0.5, 0, 0.78, 0)
hint.Size = UDim2.fromOffset(640, 30)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamBold
hint.TextSize = 19
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextStrokeTransparency = 0.4
hint.Visible = false
hint.Parent = gui
RunService.Heartbeat:Connect(function()
	local c = player.Character
	local reviving = c and c:GetAttribute("Reviving") == true
	local soul = player:GetAttribute("CarryingSoul") == true
	hint.Visible = reviving or soul
	if reviving then hint.Text = "REVIVING  -  KEEP HOLDING  F  (do not move away)"
	elseif soul then hint.Text = "LEFT CLICK  throw      Q  drop" end
end)
