-- OverheadBars v2 (v4.7: shield removed - one white health bar, and it now stays visible for 10 s after the last hit) (v1: LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v4.4.
-- A slim health + shield bar floating above OTHER players' heads. It replaces Roblox's own overhead health bar (switched off here and in Vitals).
--   * Hidden until that player is damaged. It fades in on the hit, stays about 3.5 s, then fades out. Never shown for yourself or dead players.
--   * Top (thin, blue) = SHIELD, bottom = HEALTH (white, red when low). Three small notches mark the quarters.
--   * Damage effect: the bar pops a little, flashes white, and a pale "ghost" of what was just lost drains slowly behind the real value.
-- Reads: the Humanoid health + the character attributes Shield / MaxShield (Vitals, server).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local WHITE = Color3.fromRGB(246, 246, 244)
local RED = Color3.fromRGB(235, 60, 60)
local BLUE = Color3.fromRGB(86, 176, 255)
local BLACK = Color3.new(0, 0, 0)

local SHOW_FOR = 10    -- seconds the bar stays after the last hit (was 3.5)
local FADE = 0.6       -- fade out time
local W, SH_H, HP_H = 112, 0, 10

local recs = {} -- character -> rec

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

local function barParts(parent, y, h, color)
	local back = new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(W, h), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, parent)
	new("UICorner", { CornerRadius = UDim.new(0, math.ceil(h / 2)) }, back)
	local ghost = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.45, BorderSizePixel = 0 }, back)
	new("UICorner", { CornerRadius = UDim.new(0, math.ceil(h / 2)) }, ghost)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, back)
	new("UICorner", { CornerRadius = UDim.new(0, math.ceil(h / 2)) }, fill)
	return { back = back, ghost = ghost, fill = fill, h = h, ghostFrac = 1, frac = 1, flash = 0, color = color }
end

local function build(char, plr, hum, head)
	local gui = new("BillboardGui", { Name = "OverheadBar", Adornee = head, Size = UDim2.fromOffset(W + 8, 30), StudsOffsetWorldSpace = Vector3.new(0, 1.9, 0),
		AlwaysOnTop = false, MaxDistance = 140, LightInfluence = 0, ResetOnSpawn = false, Active = false }, head)
	local cg = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1 }, gui)
	local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, HP_H), BackgroundTransparency = 1 }, cg)
	local pop = new("UIScale", { Scale = 1 }, holder)
	local health = barParts(holder, 0, HP_H, WHITE)
	-- quarter notches over the health bar (a little style, nothing loud)
	for i = 1, 3 do
		new("Frame", { Position = UDim2.fromOffset(math.floor(W * i / 4), 0), Size = UDim2.fromOffset(1, HP_H), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 5 }, health.back)
	end
	-- thin team-coloured underline
	local tc = (plr.Team and not plr.Neutral) and plr.TeamColor.Color or WHITE
	local under = new("Frame", { Position = UDim2.fromOffset(6, HP_H + 3), Size = UDim2.fromOffset(W - 12, 2), BackgroundColor3 = tc, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, under)

	local rec = { char = char, plr = plr, hum = hum, gui = gui, cg = cg, pop = pop, health = health, under = under,
		lastHp = hum.Health, shownAt = -100, alpha = 0 }
	return rec
end

local function paintBar(b, frac, color, dt)
	frac = math.clamp(frac, 0, 1)
	if frac > b.ghostFrac then b.ghostFrac = frac end
	if b.ghostFrac > frac then b.ghostFrac = math.max(frac, b.ghostFrac - dt * 0.4) end
	b.frac = frac
	b.flash = math.max(0, b.flash - dt * 4)
	b.fill.Size = UDim2.fromScale(frac, 1)
	b.fill.BackgroundColor3 = color:Lerp(WHITE, b.flash * 0.85)
	b.ghost.Size = UDim2.fromScale(b.ghostFrac, 1)
end

local function attach(plr)
	if plr == player then return end
	local char = plr.Character
	if not char or recs[char] then return end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
	if not hum or not head or recs[char] then return end
	pcall(function()
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end)
	local old = head:FindFirstChild("OverheadBar")
	if old then old:Destroy() end
	local rec = build(char, plr, hum, head)
	recs[char] = rec
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			recs[char] = nil
			if rec.gui.Parent then rec.gui:Destroy() end
		end
	end)
end

local function onPlayer(plr)
	if plr == player then return end
	plr.CharacterAdded:Connect(function() task.defer(attach, plr) end)
	if plr.Character then task.spawn(attach, plr) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for char, r in recs do
		local hum = r.hum
		if not char.Parent or not hum.Parent then continue end
		local max = math.max(hum.MaxHealth, 1)
		local hp = math.max(hum.Health, 0)
		-- a drop in health = a hit
		if hp < r.lastHp - 0.01 and hp > 0 then
			r.shownAt = now
			r.pop.Scale = 1.18
			r.health.flash = 1
		end
		r.lastHp = hp
		r.pop.Scale += (1 - r.pop.Scale) * math.min(1, dt * 12)

		local dead = hp <= 0 or (r.plr:GetAttribute("IsDead") == true)
		local want = 0
		if not dead then
			local age = now - r.shownAt
			if age < SHOW_FOR then want = 1 elseif age < SHOW_FOR + FADE then want = 1 - (age - SHOW_FOR) / FADE end
		end
		r.alpha += (want - r.alpha) * math.min(1, dt * (want > r.alpha and 22 or 10))
		r.cg.GroupTransparency = 1 - r.alpha
		r.gui.Enabled = r.alpha > 0.01
		if r.gui.Enabled then
			paintBar(r.health, hp / max, (hp / max <= 0.3) and RED or WHITE, dt)
			local team = r.plr.Team
			r.under.BackgroundColor3 = (team and not r.plr.Neutral) and r.plr.TeamColor.Color or WHITE
		end
	end
end)
