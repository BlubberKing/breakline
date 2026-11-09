-- GadgetClient (v5.16: a POSE puts the held gadget away and blocks gadgets until it ends)
-- GadgetClient v2.1 (v4.9: STRONGER THROWS - fast flat throw with light in-flight gravity, released from the throwing hand, RIGHT CLICK = underhand toss;
--   new first-person hold pose + keyframed throw: cock back, whip forward (item leaves the hand at the whip), follow-through, next one rises) (was v2: LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v4.0, reworked in v4.1.
-- v4.1: gadgets are EQUIPPED (your gun is swapped for the item, like in Call of Duty / The Finals):
--   keys 2 / 3 / 4 (gamepad DPad left / up / right, mobile buttons)  equip that loadout gadget. Press it again, or 1, or Q = put it away (gun back).
--   THROW kinds (frag, smoke, flashbang): CLICK = throw. HOLD the click = a see-through line shows where it will land; release = throw. RIGHT CLICK while
--                                         holding = cancel the throw. v4.9: RIGHT CLICK when not holding = short underhand toss.
--   PLACE kinds (sentry, bubble shield, prox mine): a BLUE see-through copy follows where you look (drag it around by moving your view), it turns RED
--                                         when it cannot go there (too far, too steep, edge, something in the way). CLICK = put it down exactly there.
-- The first-person hand model, the throw line, the preview and the third-person held item are all built here from GadgetModels. The server (GadgetServer)
-- re-checks everything (it uses the same GadgetModels.Check as the preview) and plays the visuals it broadcasts:
--   "Boom" "Flash" "ShieldBreak" "Placed"
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Remotes = RS:WaitForChild("GadgetRemotes")
local UseR, FxR = Remotes:WaitForChild("Use"), Remotes:WaitForChild("FX")
local EquipR, PlaceR = Remotes:WaitForChild("Equip"), Remotes:WaitForChild("Place")
local Cfg = require(RS:WaitForChild("GadgetConfig"))
local GM = require(RS:WaitForChild("GadgetModels"))
local MatchState = RS:FindFirstChild("MatchState")
local Sfx
pcall(function() Sfx = require(RS:WaitForChild("Sfx", 3)) end)
local function sound(name, at, pitch, vol) if Sfx then pcall(Sfx.Play, name, at, pitch, vol) end end -- silent until the SoundBank has these slots

local rnd = Random.new()
local rad, clamp = math.rad, math.clamp
local BLUE, RED = Color3.fromRGB(70, 160, 255), Color3.fromRGB(255, 70, 70)

local fxFolder = workspace:FindFirstChild("ClientFX") or Instance.new("Folder")
if not fxFolder.Parent then fxFolder.Name = "ClientFX"; fxFolder.Parent = workspace end

------------------------------------------------------------------ state
local held -- nil | { slot, id, cfg, since }
local aimingThrow, aimStart = false, 0
local throwKick, throwing = 0, false
local throwUnder, throwT0 = false, -10
local THROW_WHIP, THROW_DROP = 0.1, 0.34 -- v4.9: keyframed first-person throw (overhand / underhand), started at throwT0
local lastThrowAt = 0
local ghost -- { model, id, extra = {parts}, hl }
local traj = {} -- pooled line segments
local landMark
local lastValid = false
local lastSpot, lastNormal

local function menuOpen()
	return player:GetAttribute("GunMenuOpen") == true or player:GetAttribute("LobbyMenuOpen") == true
end
local function myChar() return player.Character end
local function aliveHum()
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return (h and h.Health > 0) and h or nil, c
end
local function blockedNow()
	local hum, c = aliveHum()
	if not hum then return true end
	if menuOpen() then return true end
	if player:GetAttribute("Carrying") == true or player:GetAttribute("CarryingSoul") == true then return true end
	if c:GetAttribute("AbilityMode") == "climb" or c:GetAttribute("Revealing") == true or c:GetAttribute("Reviving") == true then return true end
	if player:GetAttribute("IsDead") == true then return true end
	if c:GetAttribute("Pose") ~= nil then return true end -- v5.16: holding a pose puts the gadget away (and none can be pulled out)
	if MatchState and MatchState:GetAttribute("Phase") ~= "Playing" then return true end
	return false
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local function refreshFilter()
	local ig = { camera, fxFolder }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ig, p.Character) end end
	local gf = workspace:FindFirstChild("GadgetFX")
	if gf then table.insert(ig, gf) end
	if ghost then table.insert(ig, ghost.model) end
	rayParams.FilterDescendantsInstances = ig
end

------------------------------------------------------------------ throw line
local function simulate(id, look)
	local cfg = Cfg.Items[id]
	local hum, char = aliveHum()
	local head = char and char:FindFirstChild("Head")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not head or not root then return nil end
	-- v4.9: same maths as GadgetServer (start beside the head on the throwing side, light gravity until the first bounce)
	local T = Cfg.Throw
	local dir = (look + Vector3.new(0, T.Up, 0)).Unit
	local from = head.Position
	local right = dir:Cross(Vector3.yAxis)
	right = right.Magnitude > 0.05 and right.Unit or Vector3.xAxis
	local want = from + right * (T.Side or 0) + Vector3.new(0, -0.15, 0) + dir * (T.Start or 1.8)
	local origin = want
	local r = workspace:Raycast(from, want - from, rayParams)
	if r then origin = r.Position - (want - from).Unit * 0.4 end
	local vel = dir * cfg.speed + root.AssemblyLinearVelocity * (T.Inherit or 0.35)
	local g = Vector3.new(0, -math.min(T.Gravity or workspace.Gravity, workspace.Gravity), 0)
	local pts, pos = { origin }, origin
	local dt, t, bounces = 0.035, 0, 0
	local final
	while t < math.min(cfg.fuse or 2.5, 2.6) and #pts < 140 do
		local nxt = pos + vel * dt + g * (0.5 * dt * dt)
		local hit = workspace:Raycast(pos, nxt - pos, rayParams)
		if hit then
			table.insert(pts, hit.Position)
			final = hit
			bounces += 1
			if bounces >= 2 then break end
			vel = (vel - 2 * vel:Dot(hit.Normal) * hit.Normal) * (T.Bounce or 0.38)
			g = Vector3.new(0, -workspace.Gravity, 0) -- normal gravity after the first bounce (the server switches its lift off)
			pos = hit.Position + hit.Normal * 0.1
		else
			pos = nxt
			table.insert(pts, pos)
		end
		vel += g * dt
		t += dt
	end
	return pts, final
end

local function segPart()
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(235, 245, 255)
	p.Transparency = 0.45
	p.Size = Vector3.new(0.09, 0.09, 1)
	p.Parent = fxFolder
	return p
end

local function hideTraj()
	for _, p in traj do p.Transparency = 1 end
	if landMark then landMark.Transparency = 1 end
end

local function drawTraj(id)
	local pts, final = simulate(id, camera.CFrame.LookVector)
	if not pts then hideTraj() return end
	local used = 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		if len > 0.05 then
			used += 1
			local p = traj[used]
			if not p then p = segPart(); traj[used] = p end
			p.Size = Vector3.new(0.09, 0.09, len)
			p.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2)
			-- fades toward the end so it reads as a guide, not a laser
			p.Transparency = 0.35 + 0.5 * (i / #pts)
		end
	end
	for i = used + 1, #traj do traj[i].Transparency = 1 end
	if not landMark then
		landMark = Instance.new("Part")
		landMark.Shape = Enum.PartType.Cylinder
		landMark.Anchored, landMark.CanCollide, landMark.CanQuery, landMark.CanTouch, landMark.CastShadow = true, false, false, false, false
		landMark.Material = Enum.Material.Neon
		landMark.Color = Color3.fromRGB(235, 245, 255)
		landMark.Parent = fxFolder
	end
	local end0 = pts[#pts]
	local n = final and final.Normal or Vector3.yAxis
	local rr = Cfg.Items[id].radius or 3
	local size = clamp(rr * 0.32, 1.6, 5)
	landMark.Size = Vector3.new(0.08, size * 2, size * 2)
	landMark.CFrame = CFrame.lookAt(end0 + n * 0.08, end0 + n * 2) * CFrame.Angles(0, rad(90), 0)
	landMark.Transparency = 0.6
end

------------------------------------------------------------------ placement preview (blue = fine, red = cannot go here)
local function destroyGhost()
	if ghost then ghost.model:Destroy() ghost = nil end
end

local function buildGhost(id)
	destroyGhost()
	local model = GM.Build(id, nil, { ghost = BLUE })
	if not model then return end
	local extras = {}
	if id == "SHIELD" then
		local R = Cfg.Items.SHIELD.radius
		local dome = Instance.new("Part")
		dome.Name = "DomeGhost"
		dome.Shape = Enum.PartType.Ball
		dome.Size = Vector3.one * R * 2
		dome.Position = Vector3.new(0, R * 0.45, 0)
		dome.Anchored, dome.CanCollide, dome.CanQuery, dome.CanTouch, dome.CastShadow = true, false, false, false, false
		dome.Material = Enum.Material.SmoothPlastic
		dome.Color, dome.Transparency = BLUE, 0.88
		dome.Parent = model
		table.insert(extras, dome)
	elseif id == "MINE" then
		local R = Cfg.Items.MINE.trigger
		local disc = Instance.new("Part")
		disc.Name = "RangeGhost"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.08, R * 2, R * 2)
		disc.CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, rad(90))
		disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
		disc.Material = Enum.Material.SmoothPlastic
		disc.Color, disc.Transparency = BLUE, 0.9
		disc.Parent = model
		table.insert(extras, disc)
	elseif id == "SENTRY" then
		local R = Cfg.Items.SENTRY.range
		local disc = Instance.new("Part")
		disc.Name = "RangeGhost"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.08, R * 2, R * 2)
		disc.CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, rad(90))
		disc.Anchored, disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = true, false, false, false, false
		disc.Material = Enum.Material.SmoothPlastic
		disc.Color, disc.Transparency = BLUE, 0.94
		disc.Parent = model
		table.insert(extras, disc)
	end
	local hl = Instance.new("Highlight")
	hl.FillColor, hl.OutlineColor = BLUE, BLUE
	hl.FillTransparency, hl.OutlineTransparency = 0.78, 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Adornee = model
	hl.Parent = model
	model.Parent = fxFolder
	ghost = { model = model, id = id, hl = hl, extras = extras, valid = true }
	refreshFilter()
end

local function paintGhost(valid)
	if not ghost or ghost.valid == valid then return end
	ghost.valid = valid
	local col = valid and BLUE or RED
	ghost.hl.FillColor, ghost.hl.OutlineColor = col, col
	for _, d in ghost.model:GetChildren() do
		if d:IsA("BasePart") then d.Color = col end
	end
end

local lastFacing = Vector3.new(0, 0, -1)
local function updateGhost(dt)
	if not ghost or not held then return end
	local pl = GM.Place[ghost.id]
	local hum, char = aliveHum()
	local head = char and char:FindFirstChild("Head")
	if not head then ghost.model.Parent = nil return end
	local cf = camera.CFrame
	local hit = workspace:Raycast(cf.Position, cf.LookVector * (pl.range + 6), rayParams)
	local pos, normal, valid
	if hit then
		pos, normal = hit.Position, hit.Normal
		valid = (pos - head.Position).Magnitude <= pl.range
	else
		-- nothing in reach: hang the copy at the end of your range, red
		local far = cf.Position + cf.LookVector * pl.range
		local down = workspace:Raycast(far, Vector3.new(0, -12, 0), rayParams)
		pos = down and down.Position or far
		normal = down and down.Normal or Vector3.yAxis
		valid = false
	end
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if flatLook.Magnitude > 0.1 then lastFacing = flatLook.Unit end
	if valid then
		local ok = GM.Check(ghost.id, pos, normal, { char, camera, fxFolder, ghost.model, workspace:FindFirstChild("GadgetFX") })
		valid = ok
	end
	if ghost.model.Parent ~= fxFolder then ghost.model.Parent = fxFolder end
	local target = GM.CFOnSurface(pos, normal, lastFacing)
	-- the copy glides to the spot instead of snapping
	if ghost.cf then target = ghost.cf:Lerp(target, 1 - math.exp(-dt * 24)) end
	ghost.cf = target
	ghost.model:PivotTo(target)
	paintGhost(valid)
	lastValid, lastSpot, lastNormal = valid, pos, normal
end

------------------------------------------------------------------ first-person hand model (gadget in your hand)
local vm -- { folder, model, glove, sleeve, id, t0 }
local SLEEVE, GLOVE = Color3.fromRGB(58, 70, 98), Color3.fromRGB(30, 33, 40)
local function destroyVM()
	if vm then vm.folder:Destroy() vm = nil end
end
-- v4.2: held gadget size (1 = the old, huge size). Lower = smaller on screen.
local VM_SCALE_THROW, VM_SCALE_PLACE = 0.38, 0.24
local function buildVM(id)
	destroyVM()
	local folder = Instance.new("Model")
	folder.Name = "GadgetVM"
	local isPlace = Cfg.Items[id] and Cfg.Items[id].kind == "place"
	local vmScale = isPlace and VM_SCALE_PLACE or VM_SCALE_THROW -- v4.2: much smaller in your hand
	local model = GM.Build(id, nil, { anchored = true, scale = vmScale })
	if not model then return end
	model.Parent = folder
	-- v4.8: a real gloved hand (fingers curl round the item, thumb on the side) built by GadgetModels, and a round sleeve
	local glove = GM.BuildHand(folder)
	local sleeve = Instance.new("Part")
	sleeve.Name = "Sleeve"
	sleeve.Shape = Enum.PartType.Cylinder
	sleeve.Color, sleeve.Material = SLEEVE, Enum.Material.SmoothPlastic
	for _, pt in { sleeve } do
		pt.Anchored = true
		pt.CanCollide, pt.CanQuery, pt.CanTouch, pt.CastShadow = false, false, false, false
		pt.TopSurface, pt.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		pt.Parent = folder
	end
	folder.Parent = camera
	vm = { folder = folder, model = model, glove = glove, sleeve = sleeve, id = id, t0 = os.clock(), bob = 0, scale = vmScale }
end

local function easeOut(a) return 1 - (1 - clamp(a, 0, 1)) ^ 3 end
local function easeInOut(a) a = clamp(a, 0, 1) return a * a * (3 - 2 * a) end
local function lerp3(a, b, t) return a + (b - a) * t end

-- v4.9 first-person throw, in 3 beats (times after the release click):
--   0 .. Windup            cock: hand pulls up + back beside your head, item tilts back (underhand: hand drops low + back)
--   Windup .. +WHIP        whip: hand snaps forward and across, the item LEAVES the hand at Windup (same moment the server launches it)
--   .. +THROW_DROP         follow-through: the empty hand carries on down and out of view; then the next one rises (equip raise)

local OVER = {
	cock = { pos = Vector3.new(0.32, 0.42, 0.5), rot = Vector3.new(38, 6, -14) },
	whip = { pos = Vector3.new(-0.28, -0.05, -1.05), rot = Vector3.new(-30, 14, 8) },
	drop = { pos = Vector3.new(-0.55, -1.5, -0.4), rot = Vector3.new(-60, 20, 20) },
}
local UNDER = {
	cock = { pos = Vector3.new(0.12, -0.55, 0.45), rot = Vector3.new(-30, 0, -6) },
	whip = { pos = Vector3.new(-0.05, 0.05, -1.0), rot = Vector3.new(30, 6, 0) },
	drop = { pos = Vector3.new(-0.1, -1.3, -0.5), rot = Vector3.new(10, 10, 6) },
}
-- returns position offset, rotation (degrees), whether the item is still in the hand, and whether the throw anim is running
local function throwPose(now)
	local W = Cfg.Throw.Windup
	local tp = now - throwT0
	if tp < 0 or tp > W + THROW_DROP then return Vector3.zero, Vector3.zero, true, false end
	local K = throwUnder and UNDER or OVER
	if tp < W then
		local a = easeOut(tp / W)
		return K.cock.pos * a, K.cock.rot * a, true, true
	elseif tp < W + THROW_WHIP then
		local a = easeInOut((tp - W) / THROW_WHIP)
		return lerp3(K.cock.pos, K.whip.pos, a), lerp3(K.cock.rot, K.whip.rot, a), false, true
	else
		local a = easeInOut((tp - W - THROW_WHIP) / (THROW_DROP - THROW_WHIP))
		return lerp3(K.whip.pos, K.drop.pos, a), lerp3(K.whip.rot, K.drop.rot, a), false, true
	end
end

local function updateVM(dt, now)
	if not held then destroyVM() return end
	if not vm or vm.id ~= held.id then buildVM(held.id) end
	if not vm then return end
	local cfg = held.cfg
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local speed = root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude or 0
	vm.bob += dt * clamp(speed, 0, 30) * 0.45
	local amp = clamp(speed / 16, 0, 1.4)
	throwKick = math.max(0, throwKick - dt * 4.5)
	local place = cfg.kind == "place"
	local tPos, tRot, inHand, throwingAnim = Vector3.zero, Vector3.zero, true, false
	if not place then tPos, tRot, inHand, throwingAnim = throwPose(now) end
	local raise = throwingAnim and 1 or easeOut((now - held.since) / Cfg.Throw.EquipTime)
	-- the thrown item is gone from the hand until the next one is raised
	local showItem = inHand and (now - throwT0 > Cfg.Throw.Windup + THROW_DROP or now - throwT0 < Cfg.Throw.Windup or place)
	if vm.shown ~= showItem then
		vm.shown = showItem
		vm.model.Parent = showItem and vm.folder or nil
	end
	-- aiming (holding the click): the arm cocks back beside your head, ready to throw - v4.9 a real ready-to-throw pose
	local hold = (aimingThrow and not place) and clamp((now - aimStart) / 0.22, 0, 1) or 0
	vm.hold = (vm.hold or 0) + (hold - (vm.hold or 0)) * (1 - math.exp(-dt * 16))
	local h = easeInOut(vm.hold) * (throwingAnim and 0 or 1)
	-- resting hold: grenade low in the right hand, palm up, fingers round it, a little inward (it no longer floats in the middle of the screen)
	local base = place and Vector3.new(0.7, -0.62, -1.9) or Vector3.new(0.62, -0.58, -1.55)
	local breathe = math.sin(now * 1.7) * 0.007
	local pos = base
		+ Vector3.new(math.sin(vm.bob) * 0.04 * amp, -math.abs(math.cos(vm.bob)) * 0.05 * amp + breathe, 0)
		+ Vector3.new(0.05, -1.3 * (1 - raise), 0.5 * (1 - raise))
		+ OVER.cock.pos * 0.8 * h
		+ tPos
	local rx = (place and 0 or 8) + OVER.cock.rot.X * 0.8 * h + tRot.X
	local ry = -12 + OVER.cock.rot.Y * h + tRot.Y
	local rz = -8 + 16 * (1 - raise) + OVER.cock.rot.Z * h + tRot.Z
	local rot = CFrame.Angles(rad(rx), rad(ry), rad(rz))
	local cf = camera.CFrame * CFrame.new(pos) * rot
	vm.model:PivotTo(cf * CFrame.new(0, place and 0.2 * vm.scale or 0, 0))
	local gloveCF = cf * CFrame.new(-0.03, place and -0.1 or -0.2, 0.01)
	vm.glove:PivotTo(gloveCF)
	local a = gloveCF.Position
	local b = camera.CFrame * CFrame.new(1.5, -2.4, 0.9).Position
	local len = (b - a).Magnitude
	vm.sleeve.Size = Vector3.new(len, 0.3, 0.3)
	vm.sleeve.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2) * CFrame.Angles(0, math.pi / 2, 0)
end

------------------------------------------------------------------ equip / use
local function slotId(slot) return player:GetAttribute("GadId" .. slot) end
local function slotCount(slot) return player:GetAttribute("GadCount" .. slot) or 0 end

local onPrimaryDown, onPrimaryUp
local function unequip(silent)
	if not held then return end
	held = nil
	aimingThrow, throwing = false, false
	hideTraj()
	destroyGhost()
	CAS:UnbindAction("GadgetFire")
	if not silent then EquipR:FireServer(0) end
	if not silent then sound("GadPutAway") end -- v5.7: sound hook
end

local function equip(slot)
	if blockedNow() then return end
	local id = slotId(slot)
	local cfg = id and id ~= "" and Cfg.Items[id]
	if not cfg or slotCount(slot) <= 0 then return end
	if held and held.slot == slot then unequip() return end -- same key again = put it away
	held = { slot = slot, id = id, cfg = cfg, since = os.clock() }
	aimingThrow, throwing = false, false
	hideTraj()
	destroyGhost()
	if cfg.kind == "place" then buildGhost(id) end
	EquipR:FireServer(slot)
	sound("GadEquip_" .. id) -- v5.7: sound hook (falls back to GadEquip)
	if UIS.TouchEnabled then
		CAS:BindAction("GadgetFire", function(_, state)
			if state == Enum.UserInputState.Begin then onPrimaryDown() elseif state == Enum.UserInputState.End then onPrimaryUp() end
			return Enum.ContextActionResult.Sink
		end, true)
		CAS:SetTitle("GadgetFire", cfg.kind == "place" and "Place" or "Throw")
		CAS:SetPosition("GadgetFire", UDim2.new(1, -95, 1, -330))
	end
end

local function doThrow(under)
	if not held or held.cfg.kind ~= "throw" or throwing then return end
	if blockedNow() then return end
	local now = os.clock()
	if now - held.since < Cfg.Throw.EquipTime or now - lastThrowAt < 0.3 then return end
	local slot = held.slot
	if slotCount(slot) <= 0 then return end
	if workspace:GetServerTimeNow() < (player:GetAttribute("GadReady" .. slot) or 0) then return end
	lastThrowAt = now
	throwing = true
	throwKick = 1
	throwUnder = under == true
	throwT0 = now
	held.since = now + Cfg.Throw.Windup + THROW_DROP -- the next grenade comes up from below once the arm has followed through
	-- v4.9: sent right away; the server starts everybody's throwing arm and releases the item after Cfg.Throw.Windup (when the arm whips forward)
	UseR:FireServer(slot, camera.CFrame.LookVector, throwUnder)
	sound("GadThrow_" .. held.id, nil, throwUnder and 0.85 or 1) -- v5.7: sound hook (falls back to GadThrow)
	task.delay(Cfg.Throw.Windup + 0.05, function() throwing = false end)
end

local function doPlace()
	if not held or held.cfg.kind ~= "place" or not ghost then return end
	if blockedNow() then return end
	local now = os.clock()
	if now - held.since < Cfg.Throw.EquipTime or now - lastThrowAt < 0.35 then return end
	if not lastValid or not lastSpot then return end
	local slot = held.slot
	if slotCount(slot) <= 0 then return end
	if workspace:GetServerTimeNow() < (player:GetAttribute("GadReady" .. slot) or 0) then return end
	lastThrowAt = now
	throwKick = 0.6
	PlaceR:FireServer(slot, lastSpot, lastFacing)
	sound("GadPlaceTry") -- v5.7: sound hook (the click when you press place; the placed sound itself plays from the object)
end

onPrimaryDown = function()
	if not held or blockedNow() then return end
	if held.cfg.kind == "throw" then
		aimingThrow, aimStart = true, os.clock()
	else
		doPlace()
	end
end
onPrimaryUp = function()
	if held and held.cfg.kind == "throw" and aimingThrow then
		aimingThrow = false
		hideTraj()
		doThrow()
	end
end

local KEYS = { Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local PAD = { Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadRight }
for slot = 1, 3 do
	local name = "Gadget" .. slot
	CAS:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then equip(slot) end
		return Enum.ContextActionResult.Pass
	end, UIS.TouchEnabled, KEYS[slot], PAD[slot])
	CAS:SetTitle(name, "G" .. slot)
	CAS:SetPosition(name, UDim2.new(1, -95 - (slot - 1) * 70, 1, -255))
end

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then onPrimaryDown()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		if aimingThrow then
			aimingThrow = false hideTraj() -- right click cancels a throw you are charging
		elseif held and held.cfg.kind == "throw" then
			doThrow(true) -- v4.9: right click (not charging) = short underhand toss
		end
	elseif input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.ButtonR1 then unequip()
	elseif input.KeyCode == Enum.KeyCode.Q and held and player:GetAttribute("Carrying") ~= true and player:GetAttribute("CarryingSoul") ~= true then unequip() end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then onPrimaryUp() end
end)

------------------------------------------------------------------ what others see: the item in their hand (third person)
local others = {} -- char -> { id, model }
local function dropOther(char)
	local o = others[char]
	if o then if o.model then o.model:Destroy() end others[char] = nil end
end
local function syncOthers()
	for _, plr in Players:GetPlayers() do
		if plr ~= player then
			local char = plr.Character
			local id = char and char:GetAttribute("HeldGadget")
			local hand = char and char:FindFirstChild("RightHand")
			local cur = char and others[char]
			if char and id and hand and Cfg.Items[id] then
				if not cur or cur.id ~= id or not cur.model.Parent then
					dropOther(char)
					-- v4.9: smaller and sitting IN the palm (it used to hang off the front of the hand); placeables a bit bigger, held in front
					local isThrow = Cfg.Items[id].kind == "throw"
					local model = GM.Build(id, nil, { anchored = false, scale = isThrow and 0.55 or 0.6 })
					if model then
						model:PivotTo(hand.CFrame * (isThrow and CFrame.new(-0.1, -0.3, -0.04) or CFrame.new(-0.25, -0.35, -0.2)))
						local anchorPart = hand
						for _, d in model:GetChildren() do
							if d:IsA("BasePart") then
								local w = Instance.new("WeldConstraint")
								w.Part0, w.Part1 = anchorPart, d
								w.Parent = d
							end
						end
						model.Parent = char
						others[char] = { id = id, model = model }
					end
				end
			elseif char and cur then
				dropOther(char)
			end
		end
	end
	for char in others do if not char.Parent then dropOther(char) end end
end

------------------------------------------------------------------ frame loop
local acc, sync = 0, 0
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	acc += dt
	if acc > 0.5 then acc = 0 refreshFilter() end
	sync += dt
	if sync > 0.2 then sync = 0 syncOthers() end
	if held then
		local hum, char = aliveHum()
		-- the server owns the truth: dead / no longer holding / out of charges = put it away
		if not hum or blockedNow() or (char and char:GetAttribute("HeldGadget") == nil and now - held.since > 0.6) then
			unequip(not hum)
		elseif slotCount(held.slot) <= 0 and not throwing and now - lastThrowAt > Cfg.Throw.Windup + THROW_DROP then
			unequip()
		end
	end
	if held then
		if held.cfg.kind == "throw" and aimingThrow and now - aimStart > 0.12 then drawTraj(held.id) end
		if held.cfg.kind == "place" then updateGhost(dt) end
	end
	updateVM(dt, now)
end)

------------------------------------------------------------------ visuals
local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	for k, v in props do p[k] = v end
	p.Parent = fxFolder
	return p
end

local shake = 0
local function boom(pos, radius)
	local fire = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = pos, Color = Color3.fromRGB(255, 170, 60), Transparency = 0.1 })
	TweenService:Create(fire, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 1.25, Transparency = 1 }):Play()
	local core = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Position = pos, Color = Color3.fromRGB(255, 250, 230), Transparency = 0 })
	TweenService:Create(core, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * radius * 0.55, Transparency = 1 }):Play()
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 210, 140), Transparency = 0.3 })
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, radius * 2.2, radius * 2.2), Transparency = 1 }):Play()
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 190, 110), radius * 1.8, 8
	light.Parent = core
	TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	-- sparks
	local att = fxPart({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 110, 40))
	pe.Lifetime = NumberRange.new(0.3, 0.8)
	pe.Speed = NumberRange.new(radius * 1.2, radius * 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.LightEmission = 1
	pe.Drag = 4
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(40)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 66, 62))
	smoke.Lifetime = NumberRange.new(1.0, 1.8)
	smoke.Speed = NumberRange.new(2, 7)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, radius * 0.25), NumberSequenceKeypoint.new(1, radius * 0.6) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Rate = 0
	smoke.Parent = att
	smoke:Emit(14)
	Debris:AddItem(fire, 0.5); Debris:AddItem(core, 0.5); Debris:AddItem(ring, 0.5); Debris:AddItem(att, 2.2)
	sound("Explosion", pos, 1, 1.2)
	local d = (camera.CFrame.Position - pos).Magnitude
	shake = math.max(shake, math.clamp(1 - d / (radius * 5), 0, 1) * 1.1)
end

-- flashbang blind screen
local gui = Instance.new("ScreenGui")
gui.Name = "GadgetFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 200
gui.Parent = player:WaitForChild("PlayerGui")
local white = Instance.new("Frame")
white.Size = UDim2.fromScale(1, 1)
white.BackgroundColor3 = Color3.new(1, 1, 1)
white.BackgroundTransparency = 1
white.BorderSizePixel = 0
white.Parent = gui
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = 0
cc.Parent = Lighting
local blind, blindMax = 0, 1 -- seconds left, seconds at the start
local peak = 0

local function flashbang(pos, range, maxTime)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end
	-- light + pop for everyone
	local pop = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = pos, Color = Color3.new(1, 1, 1), Transparency = 0 })
	TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.one * 16, Transparency = 1 }):Play()
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.new(1, 1, 1), 40, 12
	light.Parent = pop
	TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
	Debris:AddItem(pop, 0.6)
	sound("FlashBang", pos, 1, 1)
	-- line of sight + distance + how much you look at it
	local eye = camera.CFrame.Position
	local to = pos - eye
	local dist = to.Magnitude
	if dist > range then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, camera, fxFolder }
	params.RespectCanCollide = true
	if workspace:Raycast(eye, to, params) then return end
	local look = camera.CFrame.LookVector
	local facing = math.clamp(look:Dot(to.Unit), -1, 1) -- 1 = staring at it
	local view = 0.35 + 0.65 * math.clamp((facing + 0.2) / 1.2, 0, 1) -- behind you still blinds a little
	local near = 1 - math.clamp(dist / range, 0, 1) * 0.7
	local t = maxTime * view * near
	if t < 0.25 then return end
	blind = math.max(blind, t)
	blindMax = math.max(blindMax, blind)
	peak = math.max(peak, math.clamp(0.55 + 0.45 * view, 0, 1))
end

local function shieldBreak(pos, radius, color)
	local att = fxPart({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos + Vector3.new(0, radius * 0.4, 0) })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color or Color3.fromRGB(100, 220, 230))
	pe.LightEmission = 0.9
	pe.Lifetime = NumberRange.new(0.5, 1.1)
	pe.Speed = NumberRange.new(radius * 1.5, radius * 3.2)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 0) })
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-200, 200)
	pe.Drag = 2
	pe.Acceleration = Vector3.new(0, -20, 0)
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(60)
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, radius * 1.6, radius * 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = color or Color3.fromRGB(100, 220, 230), Transparency = 0.2 })
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, radius * 2.6, radius * 2.6), Transparency = 1 }):Play()
	Debris:AddItem(att, 1.6); Debris:AddItem(ring, 0.5)
	sound("ShieldBreak", pos, 1, 1)
end

local function placedFx(pos, normal)
	local up = normal or Vector3.yAxis
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.5, 1.5), Color = Color3.fromRGB(110, 200, 255), Transparency = 0.25,
		CFrame = CFrame.lookAt(pos + up * 0.1, pos + up * 2) * CFrame.Angles(0, math.rad(90), 0) })
	TweenService:Create(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.1, 7, 7), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.55)
	local att = fxPart({ Transparency = 1, Size = Vector3.one * 0.2, Position = pos + up * 0.3 })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(190, 215, 240))
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Speed = NumberRange.new(3, 8)
	pe.SpreadAngle = Vector2.new(70, 70)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(14)
	Debris:AddItem(att, 1)
end

FxR.OnClientEvent:Connect(function(kind, a, b, c)
	if kind == "Placed" then placedFx(a, b); sound(c and ("GadPlace_" .. c) or "GadPlace", a)
	elseif kind == "SmokePop" then sound("SmokePop", a)
	elseif kind == "SentryDeploy" then sound("SentryDeploy", a)
	elseif kind == "SentryShot" then sound("SentryShot", a)
	elseif kind == "MineArm" then sound("MineArm", a)
	elseif kind == "MineBeep" then sound("MineBeep", a)
	elseif kind == "MineTrigger" then sound("MineTrigger", a)
	elseif kind == "Boom" then boom(a, b or 12)
	elseif kind == "Flash" then flashbang(a, b or 70, c or 3.5)
	elseif kind == "ShieldBreak" then shieldBreak(a, b or 9, c) end
end)

RunService.RenderStepped:Connect(function(dt)
	-- blind: hold at full white for the first 35%, then fade
	if blind > 0 then
		blind = math.max(blind - dt, 0)
		local u = blind / blindMax
		local a = u > 0.65 and peak or peak * (u / 0.65) ^ 1.4
		white.BackgroundTransparency = 1 - a
		blur.Size = 28 * a
		cc.Saturation = -0.85 * a
		if blind <= 0 then peak, blindMax = 0, 1 end
	elseif white.BackgroundTransparency < 1 then
		white.BackgroundTransparency, blur.Size, cc.Saturation = 1, 0, 0
	end
	-- camera shake from nearby explosions
	if shake > 0.01 then
		shake = shake * math.exp(-dt * 6)
		local s = shake * 0.012
		camera.CFrame = camera.CFrame * CFrame.Angles(rnd:NextNumber(-s, s), rnd:NextNumber(-s, s), rnd:NextNumber(-s, s) * 2)
	end
end)

player.CharacterAdded:Connect(function()
	blind, peak, shake = 0, 0, 0
	white.BackgroundTransparency, blur.Size, cc.Saturation = 1, 0, 0
end)
