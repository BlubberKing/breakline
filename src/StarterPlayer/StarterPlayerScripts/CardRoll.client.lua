-- CardRoll v1.0 (LocalScript in StarterPlayer > StarterPlayerScripts) - BREAKLINE place only. NEW in v4.3 (GDD section 4.2).
-- Phase "Cards" (right after the Warp run-in, before the 3-2-1): the power-up card roll + pick, and the card on your HUD.
--   1. The screen dims. CHOOSE YOUR CARD drops in.
--   2. Reel 1 (left) pops up and spins like a slot machine. 0.5 s later reel 2 (middle) pops up and spins, 0.5 s later reel 3.
--      Each reel winds back a hair, launches, blurs, slows down card by card and clunks onto its card (small bounce).
--      Landing = flash + burst in the card's rarity colour (bigger for higher rarities, screen shake from MYTHIC up) + rarity name.
--   3. When the last reel has landed the C.CARD_PICK (10 s) timer starts. Hover = the card lifts and glows. Click / tap or keys 1-3 = pick.
--      No pick = the MIDDLE card is picked for you (the server does the same).
--   4. LOCKED IN stamp, the other two drop away. When the countdown starts the card flies to its HUD spot (above the item row).
-- The 3 cards come from YOUR 32-card deck (MatchServer puts them in the Player attribute CardOffer). The pick is sent with the
-- CardPick remote; the server's answer is the Player attribute MatchCard (card id), which the HUD card shows all match.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UI = require(RS:WaitForChild("UIKit"))
local Cards = require(RS:WaitForChild("Cards"))
local CardArt = require(RS:WaitForChild("CardArt"))
local C = require(RS:WaitForChild("MatchConfig"))
local Sfx = RS:FindFirstChild("Sfx") and require(RS.Sfx) or nil
local State = RS:WaitForChild("MatchState")
local PickR = RS:WaitForChild("MatchRemotes"):WaitForChild("CardPick")

local K, F, new, tween = UI.C, UI.F, UI.new, UI.tween
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)

-- ===== timing + layout =====
local REVEAL = C.CARD_REVEAL or 2.8
local PICK = C.CARD_PICK or 10
local APPEAR = { 0.15, 0.65, 1.15 } -- reel i pops up at this time (s after the phase started): 0.5 s apart, left first
local ROLL = 1.5                     -- each reel spins this long -> lands at 1.65 / 2.15 / 2.65 s
local WIND = 0.14                    -- the little wind-back before a reel launches
local CW, CH = 300, 420              -- card size on this screen
local GAP = 70                       -- space between reels
local STEP = CH + 26                 -- card spacing on a spinning strip
local N = 6                          -- cards per strip (holder 0 = the card it lands on, holder 1 = the one shown just before it)
local TRAVEL = 11                    -- cards that fly past while a reel spins
local OVER = 22                      -- the reel overshoots by this many pixels, then bounces back
local CY = 548                       -- reel centre (1920 x 1080 canvas)
local HUD_W = 112                    -- card width on the HUD
local HUD_X, HUD_Y = 1872 - HUD_W, 1080 - 40 - 190 - 18 - HUD_W * 1.4 -- top-left of the HUD card: right edge, above MatchHUD's item row

local SND = { tick = { "CardTick" }, land = { "CardLand", "Equip" }, rare = { "CardRare" }, pick = { "CardPick", "Notify", "Equip" }, count = { "Countdown" } }
local function sfx(kind, pitch, vol)
	if not Sfx then return end
	for _, n in SND[kind] do
		local ok, has = pcall(Sfx.Has, n)
		if ok and has then pcall(Sfx.Play, n, nil, pitch, vol) return end
	end
end

local function serverNow() return workspace:GetServerTimeNow() end
local function easeOut(u, p) return 1 - (1 - math.clamp(u, 0, 1)) ^ p end

-- ===== guis =====
local gui = new("ScreenGui", { Name = "CardRoll", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 520, Enabled = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local modal = new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Visible = false }, gui)
local hudGui = new("ScreenGui", { Name = "CardHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player.PlayerGui)

local function makeCanvas(parent)
	local cv = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1 }, parent)
	local us = new("UIScale", {}, cv)
	local function fit()
		local v = camera.ViewportSize
		us.Scale = math.max(0.3, math.min(v.X / 1920, v.Y / 1080))
	end
	fit()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	return cv
end
local function label(parent, text, size, font, color, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font, TextColor3 = color or WHITE }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end

-- ======================================================================================
-- HUD card (bottom right, above the item row) - visible all match once you have a card
-- ======================================================================================
local hudCanvas = makeCanvas(hudGui)
local hudHolder = new("Frame", { Position = UDim2.fromOffset(HUD_X, HUD_Y), Size = UDim2.fromOffset(HUD_W, HUD_W * 1.4), BackgroundTransparency = 1, Visible = false }, hudCanvas)
local hudScale = new("UIScale", { Scale = 1 }, hudHolder)
local hudText = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0, -14, 1, -4), Size = UDim2.fromOffset(300, 74), BackgroundTransparency = 1 }, hudHolder)
label(hudText, "YOUR CARD", 11, F.MB, K.dim, { Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Right })
local hudName = label(hudText, "", 24, F.H, WHITE, { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Right })
new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.5 }, hudName)
local hudRarity = label(hudText, "", 12, F.MB, WHITE, { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right })
new("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.5 }, hudRarity)
local hudCard, hudCardId = nil, nil
local rollActive = false

local function refreshHud(pop)
	local id = player:GetAttribute("MatchCard")
	local ph = State:GetAttribute("Phase")
	local show = Cards.Is(id) and (ph == "Countdown" or ph == "Playing" or ph == "SlowMo") and not rollActive
	if Cards.Is(id) and id ~= hudCardId then
		if hudCard then hudCard:Destroy() end
		hudCard = CardArt.Build(hudHolder, id, { width = HUD_W })
		hudCardId = id
		local c, R = Cards.ById[id], Cards.Rarity(id)
		hudName.Text = string.upper(c.name)
		hudRarity.Text = R.name
		hudRarity.TextColor3 = R.id == "legendary" and R.glow or (R.id == "signature" and WHITE or R.light)
	end
	if show and not hudHolder.Visible and pop then
		hudScale.Scale = 0.6
		tween(hudScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	end
	hudHolder.Visible = show
end
player:GetAttributeChangedSignal("MatchCard"):Connect(function() refreshHud(true) end)

-- ======================================================================================
-- the roll screen
-- ======================================================================================
local token = 0
local screen -- current roll screen state (table) or nil

local function burst(parent, x, y, R, rank)
	-- rotating rays
	local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1 }, parent)
	local n = 6 + rank * 2
	for i = 0, n - 1 do
		local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 900, 0, 10 + rank * 3),
			Rotation = i * 180 / n, BackgroundColor3 = R.glow, BackgroundTransparency = 0.55, BorderSizePixel = 0 }, rays)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 1),
			NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.65, 1), NumberSequenceKeypoint.new(1, 1) }) }, r)
	end
	local sc = new("UIScale", { Scale = 0.3 }, rays)
	tween(sc, TweenInfo.new(0.6 + rank * 0.08, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 0.55 + rank * 0.12 })
	tween(rays, TweenInfo.new(2.4, Enum.EasingStyle.Linear), { Rotation = 40 })
	task.delay(0.35, function()
		for _, r in rays:GetChildren() do if r:IsA("Frame") then tween(r, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }) end end
	end)
	task.delay(2.1, function() rays:Destroy() end)
	-- shock ring (rare and up)
	if rank >= 3 then
		local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CW, CW), BackgroundTransparency = 1 }, parent)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		local st = new("UIStroke", { Color = R.glow, Thickness = 6, Transparency = 0.1 }, ring)
		tween(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(CW * (1.8 + rank * 0.2), CW * (1.8 + rank * 0.2)) })
		tween(st, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Transparency = 1, Thickness = 1 })
		task.delay(0.75, function() ring:Destroy() end)
	end
	-- sparks
	local rng = Random.new()
	for _ = 1, 8 + rank * 4 do
		local a = rng:NextNumber() * math.pi * 2
		local dist = 160 + rng:NextNumber() * (120 + rank * 40)
		local s = 3 + rng:NextInteger(0, 3)
		local sp = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(s, s), Rotation = 45,
			BackgroundColor3 = (rng:NextNumber() < 0.4) and WHITE or R.glow, BorderSizePixel = 0 }, parent)
		tween(sp, TweenInfo.new(0.55 + rng:NextNumber() * 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(x + math.cos(a) * dist, y + math.sin(a) * dist * 0.8), BackgroundTransparency = 1, Rotation = 225 })
		task.delay(1, function() sp:Destroy() end)
	end
end

local function shake(cv, amount, time)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = (os.clock() - t0) / time
		if u >= 1 or not cv.Parent then
			conn:Disconnect()
			if cv.Parent then cv.Position = UDim2.fromScale(0.5, 0.5) end
			return
		end
		local a = amount * (1 - u)
		cv.Position = UDim2.new(0.5, math.random(-100, 100) / 100 * a, 0.5, math.random(-100, 100) / 100 * a)
	end)
end

local function edgePulse(parent, col)
	for _, cfg in { { 0, 90 }, { 1, 270 } } do -- { top or bottom, gradient rotation }
		local f = new("Frame", { AnchorPoint = Vector2.new(0, cfg[1]), Position = UDim2.fromScale(0, cfg[1]), Size = UDim2.new(1, 0, 0, 160),
			BackgroundColor3 = col, BackgroundTransparency = 0.35, BorderSizePixel = 0 }, parent)
		new("UIGradient", { Rotation = cfg[2], Transparency = NumberSequence.new(0, 1) }, f)
		tween(f, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		task.delay(1, function() f:Destroy() end)
	end
end

local function keyCap(parent, key, x, y)
	local k = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(30, 26), BackgroundColor3 = K.panel2, BorderSizePixel = 0 }, parent)
	new("UIStroke", { Color = K.line2, Thickness = 1 }, k)
	label(k, key, 13, F.MB, K.text, { Size = UDim2.fromScale(1, 1) })
	return k
end

local function cleanupScreen(s)
	if not s then return end
	for _, c in s.conns do c:Disconnect() end
	if s.root and s.root.Parent then s.root:Destroy() end
end

local function runRoll(my)
	-- wait for this round's offer
	local offer
	local w0 = os.clock()
	while my == token and os.clock() - w0 < 4 do
		local raw = player:GetAttribute("CardOffer")
		if type(raw) == "string" then
			local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
			local phaseStart = (State:GetAttribute("PhaseEnds") or 0) - REVEAL - PICK
			if ok and type(d) == "table" and type(d.cards) == "table" and #d.cards == 3 and type(d.t) == "number" and math.abs(d.t - phaseStart) < 3 then offer = d break end
		end
		task.wait()
	end
	if not offer or my ~= token then return end
	for i = 1, 3 do if not Cards.Is(offer.cards[i]) then return end end
	local deck = type(offer.deck) == "table" and offer.deck or offer.cards
	local startT = offer.t
	local function T() return serverNow() - startT end

	rollActive = true
	refreshHud(false)
	local s = { conns = {}, reels = {}, picked = nil, hover = nil, done = false }
	screen = s
	modal.Visible = true

	local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)
	s.root = root
	tween(root, TweenInfo.new(0.35), { BackgroundTransparency = 0.38 })
	local vign = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0, BorderSizePixel = 0 }, root)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0.2) }) }, vign)
	local cv = makeCanvas(root)
	s.cv = cv

	-- title
	local title = label(cv, "CHOOSE YOUR CARD", 60, F.H, WHITE, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 90), Size = UDim2.fromOffset(1000, 70), TextTransparency = 1 })
	new("UIStroke", { Color = BLACK, Thickness = 3, Transparency = 0.4 }, title)
	local sub = label(cv, "3 CARDS FROM YOUR DECK   //   ONE CARD FOR THE WHOLE MATCH", 14, F.MB, K.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 164),
		Size = UDim2.fromOffset(1000, 18), TextTransparency = 1 })
	local rule = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, 194), Size = UDim2.fromOffset(0, 2), BackgroundColor3 = K.red, BorderSizePixel = 0 }, cv)
	title.Position = UDim2.fromOffset(960, 70)
	tween(title, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(960, 90), TextTransparency = 0 })
	tween(sub, TweenInfo.new(0.5), { TextTransparency = 0 })
	tween(rule, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(260, 2) })

	-- reels
	local rng = Random.new()
	local function randomDeckCard(avoid)
		for _ = 1, 8 do
			local id = deck[rng:NextInteger(1, #deck)]
			if Cards.Is(id) and id ~= avoid then return id end
		end
		return Cards.List[rng:NextInteger(1, #Cards.List)].id
	end
	local function teaseCard(final)
		-- the card shown right before the final one: the rarest card in your deck that is not the final card (a near miss)
		local best
		for _, id in deck do
			if Cards.Is(id) and id ~= final and (not best or Cards.Sort(id, best)) then best = id end
		end
		return best or randomDeckCard(final)
	end

	local function buildReel(i)
		local cx = 960 + (i - 2) * (CW + GAP)
		local r = { i = i, cx = cx, id = offer.cards[i], R = Cards.Rarity(offer.cards[i]), landed = false, started = false, lastTick = 0 }
		local housing = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, CY), Size = UDim2.fromOffset(CW + 28, CH + 28),
			BackgroundColor3 = K.panel, BorderSizePixel = 0, Visible = false }, cv)
		new("UIStroke", { Color = K.line2, Thickness = 1 }, housing)
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(60, 3), BackgroundColor3 = K.red, BorderSizePixel = 0 }, housing)
		for _, side in { 0, 1 } do -- pay-line notches
			local n = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(side, 0, 0.5, 0), Size = UDim2.fromOffset(12, 12), Rotation = 45,
				BackgroundColor3 = K.red, BorderSizePixel = 0 }, housing)
			r["notch" .. side] = n
		end
		r.housing = housing
		r.hscale = new("UIScale", { Scale = 0.7 }, housing)
		local win = new("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(CW, CH), BackgroundColor3 = K.void, BorderSizePixel = 0,
			ClipsDescendants = true }, housing)
		r.win = win
		r.holders = {}
		for k = 0, N - 1 do
			local id = (k == 0) and r.id or (k == 1 and teaseCard(r.id) or randomDeckCard(r.id))
			local h = CardArt.Build(win, id, { width = CW, anim = false })
			r.holders[k] = h
		end
		-- depth: dark at the top + bottom of the window, and speed streaks
		for _, cfg in { { 0, 90 }, { 1, 270 } } do
			local g = new("Frame", { AnchorPoint = Vector2.new(0, cfg[1]), Position = UDim2.fromScale(0, cfg[1]), Size = UDim2.new(1, 0, 0, 90), BackgroundColor3 = BLACK, BorderSizePixel = 0 }, win)
			new("UIGradient", { Rotation = cfg[2], Transparency = NumberSequence.new(0.1, 1) }, g)
		end
		local streaks = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, win)
		for _ = 1, 16 do
			new("Frame", { Position = UDim2.fromOffset(rng:NextNumber() * CW, 0), Size = UDim2.new(0, rng:NextInteger(1, 3), 1, 0), BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.6 + rng:NextNumber() * 0.3, BorderSizePixel = 0 }, streaks)
		end
		streaks.Visible = false
		r.streaks = streaks
		r.payline = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = K.red,
			BackgroundTransparency = 0.25, BorderSizePixel = 0 }, win)
		r.flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0 }, win)
		-- strip position: pos grows = cards move down. Holder 0 rests at y = 0 when pos = posEnd.
		local L = N * STEP
		r.posEnd = STEP + L * 4
		r.posStart = r.posEnd - TRAVEL * STEP
		r.pos = r.posStart
		r.key = keyCap(cv, tostring(i), cx, CY + CH / 2 + 30)
		r.key.Visible = false
		r.rarityLbl = label(cv, r.R.name, 26, F.H, r.R.id == "signature" and WHITE or r.R.glow, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(cx, CY - CH / 2 - 58),
			Size = UDim2.fromOffset(CW, 32), TextTransparency = 1 })
		new("UIStroke", { Color = BLACK, Thickness = 2.5, Transparency = 0.3 }, r.rarityLbl)
		s.reels[i] = r
		return r
	end

	local function placeStrip(r)
		local L = N * STEP
		for k = 0, N - 1 do
			local y = ((k * STEP + r.pos) % L) - STEP
			r.holders[k].Position = UDim2.fromOffset(0, y)
			r.holders[k].Visible = y > -CH and y < CH
		end
	end

	local function popReel(r)
		r.housing.Visible = true
		tween(r.hscale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		r.flash.BackgroundTransparency = 0.2
		tween(r.flash, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
		placeStrip(r)
	end

	local function interactive(r)
		-- swap the spinning strip for one live card that can be hovered / clicked
		local slot = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(r.cx, CY),
			Size = UDim2.fromOffset(CW, CH), BackgroundTransparency = 1 }, cv)
		r.slot = slot
		r.sscale = new("UIScale", { Scale = 1 }, slot)
		local holder, api = CardArt.Build(slot, r.id, { width = CW })
		r.api = api
		r.cardHolder = holder
		r.dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, BorderSizePixel = 0 }, slot)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, r.dim)
		slot.Activated:Connect(function()
			if not s.picked and T() >= REVEAL - 0.5 and s.lockIn then s.lockIn(r.i, false) end
		end)
		r.win.Visible = false
		r.payline.Visible = false
		r.notch0.BackgroundColor3, r.notch1.BackgroundColor3 = r.R.glow, r.R.glow
	end

	local function land(r)
		r.landed = true
		r.pos = r.posEnd + OVER
		placeStrip(r)
		-- bounce back from the overshoot
		local b0 = os.clock()
		local bc
		bc = RunService.RenderStepped:Connect(function()
			local u = math.clamp((os.clock() - b0) / 0.26, 0, 1)
			local back = 1 + 2.2 * (u - 1) ^ 3 + 1.2 * (u - 1) ^ 2 -- easeOutBack-ish
			r.pos = r.posEnd + OVER * (1 - back)
			placeStrip(r)
			if u >= 1 then bc:Disconnect() end
		end)
		table.insert(s.conns, bc)
		local rank = r.R.rank
		r.flash.BackgroundTransparency = 0.05
		tween(r.flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		r.hscale.Scale = 1.07
		tween(r.hscale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		r.streaks.Visible = false
		burst(cv, r.cx, CY, r.R, rank)
		sfx("land", 0.9 + rank * 0.05, 1)
		if rank >= 4 then sfx("rare", 1, 1) end
		if rank >= 5 then
			shake(cv, 6 + (rank - 5) * 4, 0.35)
			edgePulse(root, r.R.glow)
		end
		local rl = r.rarityLbl
		local us = new("UIScale", { Scale = 1.8 }, rl)
		tween(us, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		tween(rl, TweenInfo.new(0.15), { TextTransparency = 0 })
		task.delay(0.28, function() if s.root.Parent then interactive(r) end end)
	end

	-- ===== pick =====
	local timerNum, timerBar, timerLbl, autoTag
	local function buildTimer()
		timerLbl = label(cv, "PICK A CARD", 13, F.MB, K.dim, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, CY + CH / 2 + 78), Size = UDim2.fromOffset(600, 16) })
		local track = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, CY + CH / 2 + 100), Size = UDim2.fromOffset(3 * CW + 2 * GAP, 4),
			BackgroundColor3 = K.line, BorderSizePixel = 0 }, cv)
		timerBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, track)
		timerNum = label(cv, tostring(PICK), 44, F.H, WHITE, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, CY + CH / 2 + 110), Size = UDim2.fromOffset(200, 50) })
		local mid = s.reels[2]
		autoTag = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(mid.cx, CY - CH / 2 - 62), Size = UDim2.fromOffset(150, 20), BackgroundColor3 = K.red, BorderSizePixel = 0 }, cv)
		label(autoTag, "AUTO PICK", 11, F.MB, WHITE, { Size = UDim2.fromScale(1, 1) })
		for _, r in s.reels do r.key.Visible = true end
	end

	local function setHover(i)
		if s.picked or s.hover == i then return end
		s.hover = i
		for j, r in s.reels do
			if r.slot then
				local on = (j == i)
				tween(r.sscale, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = on and 1.06 or 1 })
				tween(r.slot, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(r.cx, CY - (on and 16 or 0)) })
				tween(r.dim, TweenInfo.new(0.2), { BackgroundTransparency = (i and not on) and 0.45 or 1 })
				r.api.setGlow(on)
			end
		end
	end

	local function lockIn(i, auto)
		if s.picked == i then return end
		local first = s.picked == nil
		s.picked = i
		s.hover = nil
		if first and not auto then PickR:FireServer(i) end
		if first then sfx("pick", 1, 1) end
		for j, r in s.reels do
			if r.slot then
				local on = (j == i)
				r.api.setGlow(on)
				r.slot.Active = false
				tween(r.sscale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = on and 1.1 or 0.9 })
				tween(r.slot, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(r.cx, CY + (on and -10 or 60)) })
				tween(r.dim, TweenInfo.new(0.3), { BackgroundTransparency = on and 1 or 0.35 })
				tween(r.housing, TweenInfo.new(0.3), { BackgroundTransparency = on and 0 or 0.6 })
				r.key.Visible = false
				r.rarityLbl.TextTransparency = on and 0 or 0.6
			end
		end
		if autoTag then autoTag.Visible = false end
		local r = s.reels[i]
		if s.stamp then s.stamp:Destroy() end
		local stamp = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(250, 66), Rotation = -9,
			BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, BorderSizePixel = 0 }, r.slot)
		new("UIStroke", { Color = K.red, Thickness = 4 }, stamp)
		label(stamp, auto and "AUTO PICKED" or "LOCKED IN", 40, F.H, K.redHi, { Size = UDim2.fromScale(1, 1) })
		local ss = new("UIScale", { Scale = 2.2 }, stamp)
		tween(ss, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		s.stamp = stamp
		if timerLbl then
			timerLbl.Text = "WAITING FOR THE OTHER PLAYERS"
			timerNum.Visible = false
			timerBar.Parent.Visible = false
		end
		burst(cv, r.cx, CY, r.R, math.max(2, r.R.rank - 1))
	end
	s.lockIn = lockIn

	-- input
	table.insert(s.conns, UIS.InputBegan:Connect(function(input, gpe)
		if gpe or s.picked or T() < REVEAL - 0.5 then return end
		local map = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3 }
		local i = map[input.KeyCode]
		if i and s.reels[i] and s.reels[i].slot then lockIn(i, false) end
	end))
	table.insert(s.conns, player:GetAttributeChangedSignal("CardPick"):Connect(function()
		local i = player:GetAttribute("CardPick")
		if type(i) == "number" and s.reels[i] and s.reels[i].slot and s.picked ~= i then lockIn(i, s.picked == nil) end
	end))

	-- ===== main loop =====
	local timerBuilt, lastSec = false, nil
	table.insert(s.conns, RunService.RenderStepped:Connect(function(dt)
		if s.done then return end
		local t = T()
		player:SetAttribute("GunMenuOpen", true) -- MatchFlow clears it on every phase change: keep the cursor free while picking
		for i = 1, 3 do
			local r = s.reels[i]
			if r and not r.landed then
				local a = APPEAR[i]
				if t >= a and not r.started then
					r.started = true
					popReel(r)
				end
				if r.started then
					local rt = t - a
					local prevPos = r.pos
					if rt >= ROLL then
						land(r)
					else
						if rt < WIND then
							r.pos = r.posStart - 40 * (rt / WIND) ^ 2
						else
							local u = (rt - WIND) / (ROLL - WIND)
							r.pos = (r.posStart - 40) + (TRAVEL * STEP + 40 + OVER) * easeOut(u, 2.7)
						end
						placeStrip(r)
						local speed = math.abs(r.pos - prevPos) / math.max(dt, 1 / 240)
						r.streaks.Visible = speed > 2600 -- motion streaks only while the reel is a blur
						local idx = math.floor(r.pos / STEP)
						if idx ~= r.lastIdx then
							r.lastIdx = idx
							if os.clock() - r.lastTick > 0.045 then
								r.lastTick = os.clock()
								sfx("tick", 0.9 + rt * 0.15, 0.5)
								r.notch0.BackgroundColor3, r.notch1.BackgroundColor3 = WHITE, WHITE
								task.delay(0.04, function() if r.notch0.Parent and not r.landed then r.notch0.BackgroundColor3, r.notch1.BackgroundColor3 = K.red, K.red end end)
							end
						end
					end
				end
			end
		end
		-- pick timer
		if t >= REVEAL then
			if not timerBuilt then
				timerBuilt = true
				buildTimer()
			end
			local left = math.max(0, REVEAL + PICK - t)
			if not s.picked then
				timerBar.Size = UDim2.fromScale(left / PICK, 1)
				timerBar.BackgroundColor3 = left <= 3 and K.redHi or WHITE
				local sec = math.ceil(left)
				timerNum.Text = tostring(sec)
				timerNum.TextColor3 = left <= 3 and K.redHi or WHITE
				if sec ~= lastSec then
					lastSec = sec
					if sec <= 3 and sec >= 1 then sfx("count", 1.2, 0.6) end
				end
				-- hover from the mouse position (works under the UIScale of the canvas)
				local m = UIS:GetMouseLocation()
				local hit
				for i, r in s.reels do
					if r.slot then
						local p, sz = r.slot.AbsolutePosition, r.slot.AbsoluteSize
						local my = m.Y - game:GetService("GuiService"):GetGuiInset().Y
						if m.X >= p.X and m.X <= p.X + sz.X and my >= p.Y and my <= p.Y + sz.Y then hit = i end
					end
				end
				setHover(hit)
				if left <= 0 then lockIn(2, true) end
			end
		end
	end))
	for i = 1, 3 do -- one reel per frame (each is 6 cards of art), so the screen never hitches
		if my ~= token or not root.Parent then return end
		local r = buildReel(i)
		r.housing.Visible = false
		task.wait()
	end
end

-- the countdown started: the picked card flies to the HUD, the screen fades
local function outro(s)
	if not s or s.done then return end
	s.done = true
	local id = player:GetAttribute("MatchCard")
	local pick = player:GetAttribute("CardPick")
	if type(pick) == "number" and s.reels[pick] and s.reels[pick].slot and s.picked ~= pick then s.lockIn(pick, s.picked == nil) end
	local r = pick and s.reels[pick] or (s.picked and s.reels[s.picked])
	if s.stamp then tween(s.stamp, TweenInfo.new(0.15), { BackgroundTransparency = 1 }) s.stamp.Visible = false end
	for _, other in s.reels do
		if other ~= r then
			if other.slot then tween(other.slot, TweenInfo.new(0.3), { Position = UDim2.fromOffset(other.cx, CY + 200) }) end
			other.housing.Visible = false
			other.rarityLbl.Visible = false
		end
	end
	tween(s.root, TweenInfo.new(0.45), { BackgroundTransparency = 1 })
	for _, d in s.cv:GetChildren() do
		if d:IsA("TextLabel") then tween(d, TweenInfo.new(0.25), { TextTransparency = 1 }) end
		if d:IsA("Frame") and (not r or d ~= r.housing) then d.Visible = false end
	end
	if r and r.slot then
		r.housing.Visible = false
		r.rarityLbl.Visible = false
		local target = UDim2.fromOffset(HUD_X + HUD_W / 2, HUD_Y + HUD_W * 0.7)
		tween(r.slot, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Position = target })
		tween(r.sscale, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Scale = HUD_W / CW })
	end
	task.delay(0.6, function()
		modal.Visible = false
		if player:GetAttribute("GunMenuOpen") then player:SetAttribute("GunMenuOpen", nil) end
		rollActive = false
		refreshHud(false)
		cleanupScreen(s)
		if screen == s then screen = nil end
	end)
	if not Cards.Is(id) then return end
end

local function onPhase()
	local ph = State:GetAttribute("Phase")
	if ph == "Cards" then
		if screen then cleanupScreen(screen) screen = nil end
		token += 1
		task.spawn(runRoll, token)
	else
		token += 1
		if screen then
			if ph == "Countdown" or ph == "Playing" then
				outro(screen)
			else
				cleanupScreen(screen)
				screen = nil
				modal.Visible = false
				rollActive = false
				if ph ~= "Pregame" and ph ~= "Summary" and player:GetAttribute("GunMenuOpen") then player:SetAttribute("GunMenuOpen", nil) end
			end
		end
		if ph ~= "Countdown" and ph ~= "Playing" and ph ~= "SlowMo" then rollActive = false end
	end
	refreshHud(ph == "Countdown" or ph == "Playing")
end
State:GetAttributeChangedSignal("Phase"):Connect(onPhase)
onPhase()
