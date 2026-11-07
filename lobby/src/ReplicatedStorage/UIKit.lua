-- UIKit (ModuleScript in ReplicatedStorage) - BOTH games (v3.7). Keep the two copies identical (Breakline is the master).
-- Breakline: LoadingScreen (ReplicatedFirst) + MatchFlow. Lobby: LobbyLoading (ReplicatedFirst) + LobbyClient (logo).
-- Shared look (same colors + fonts as the lobby "CLEAN" UI) and a few small builders.
--   UIKit.C / UIKit.F                      colors / fonts
--   UIKit.new(class, props, parent)        make an Instance
--   UIKit.tween(inst, tweenInfo, goal)     play a tween, returns it
--   UIKit.SoulIcon(parent, size)           the faceted blue soul crystal
--   UIKit.Logo(parent, size, props, mode)  v3.7 logo: slim spaced BREAK / LINE, red slash with light flowing through it.
--                                          mode "left" (corner logos) or "center" (loading screens: intro / outro). Returns holder, api
--   UIKit.FitViewport(vp, cam, root, dir, opts)  v5.9: frames a model in a ViewportFrame so it fills the frame without being cropped,
--                                          centred on what you actually SEE (visible parts only) and re-fitted when the frame changes size.
--   UIKit.EssenceIcon(parent, size)        v5.9: the purple Essence glimmers (three small four-point sparkles)
--   UIKit.CloseButton(parent, text, props) v5.9: the top-right BACK / CLOSE button of every menu: framed, an X mark, the word, an ESC cap.
--                                          props = Position / AnchorPoint / ZIndex ... Returns the TextButton (connect MouseButton1Click).
local TweenService = game:GetService("TweenService")

local K = {}
local rgb = Color3.fromRGB

K.C = {
	void = rgb(4, 5, 7), panel = rgb(14, 15, 19), panel2 = rgb(22, 24, 29), panel3 = rgb(31, 34, 41),
	line = rgb(40, 43, 51), line2 = rgb(78, 82, 94),
	text = rgb(238, 239, 242), dim = rgb(148, 153, 164), mute = rgb(90, 95, 106),
	red = rgb(226, 38, 48), redHi = rgb(255, 64, 74),
	soul = rgb(112, 208, 255), soulPale = rgb(220, 246, 255),
	gold = rgb(255, 204, 84), green = rgb(120, 232, 160),
}

local function fam(name, weight)
	return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight or Enum.FontWeight.Regular)
end
K.F = {
	H = fam("Oswald", Enum.FontWeight.Bold),
	HM = fam("Oswald", Enum.FontWeight.Medium),
	B = fam("GothamSSm", Enum.FontWeight.Medium),
	BB = fam("GothamSSm", Enum.FontWeight.Bold),
	M = fam("RobotoMono", Enum.FontWeight.Medium),
	MB = fam("RobotoMono", Enum.FontWeight.Bold),
}

function K.new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props or {} do i[k] = v end
	if parent then i.Parent = parent end
	return i
end
local new = K.new

function K.tween(inst, info, goal)
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

-- ===== soul crystal =====
function K.SoulIcon(parent, size)
	local C = K.C
	local h = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local d = math.floor(size * 0.68)
	local outer = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(d, d),
		Rotation = 45, BackgroundColor3 = C.soul, BackgroundTransparency = 0.82, BorderSizePixel = 0 }, h)
	new("UIStroke", { Color = C.soul, Thickness = math.max(1.5, size * 0.07), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, outer)
	local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.floor(d * 0.46), math.floor(d * 0.46)), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, h)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.soulPale, C.soul) }, inner)
	return h
end

-- ===== v5.9: fit a model into a ViewportFrame =====
-- vp = ViewportFrame, cam = its Camera, root = Model / Folder / part holding the parts to show (parts with Transparency >= 1 are ignored),
-- dir = direction FROM the model TO the camera (world space), opts = { pad = 0.1 (share of the frame left empty around the model), fov = 16 }.
-- The camera keeps `dir`, is shifted sideways so the visible silhouette is centred, and is pulled back just far enough that the whole
-- silhouette fits both the width and the height of the frame (real perspective, every corner of every part is checked).
function K.FitViewport(vp, cam, root, dir, opts)
	opts = opts or {}
	local pad = opts.pad or 0.1
	cam.FieldOfView = opts.fov or cam.FieldOfView
	local pts = {}
	local parts = root:IsA("BasePart") and { root } or {}
	for _, d in root:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d) end end
	for _, p in parts do
		if p.Transparency < 1 then
			local h, cf = p.Size / 2, p.CFrame
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				table.insert(pts, cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)))
			end end end
		end
	end
	if #pts == 0 then return end
	local center = Vector3.zero
	for _, q in pts do center += q end
	center /= #pts
	dir = (dir.Magnitude > 0.001) and dir.Unit or Vector3.new(1, 0, 0)
	local upHint = math.abs(dir.Y) > 0.98 and Vector3.zAxis or Vector3.yAxis
	local rot = CFrame.lookAt(Vector3.zero, -dir, upHint) -- camera rotation (looks along -dir)
	local loc = {}
	for i, q in pts do loc[i] = rot:PointToObjectSpace(q - center) end -- x right, y up, z toward the camera
	local function fit()
		local sz = vp.AbsoluteSize
		local aspect = (sz.X > 1 and sz.Y > 1) and sz.X / sz.Y or (opts.aspect or 1)
		local tv = math.tan(math.rad(cam.FieldOfView / 2)) * (1 - pad)
		local th = tv * aspect
		local ox, oy, dist = 0, 0, 1
		for _ = 1, 3 do
			-- distance that fits every corner, for the current sideways offset
			dist = 0
			for _, q in loc do
				local need = math.max(math.abs(q.X - ox) / th, math.abs(q.Y - oy) / tv) + q.Z
				if need > dist then dist = need end
			end
			dist += 0.05
			-- re-centre on the projected silhouette
			local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
			for _, q in loc do
				local d = dist - q.Z
				local sx, sy = (q.X - ox) / d, (q.Y - oy) / d
				minX, maxX, minY, maxY = math.min(minX, sx), math.max(maxX, sx), math.min(minY, sy), math.max(maxY, sy)
			end
			ox += (minX + maxX) / 2 * dist
			oy += (minY + maxY) / 2 * dist
		end
		cam.CFrame = CFrame.new(center) * rot * CFrame.new(ox, oy, dist)
	end
	fit()
	vp.CurrentCamera = cam
	vp:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end

-- ===== v5.9: Essence icon (premium currency): three purple four-point glimmers, one big + two small =====
K.C.essence = rgb(176, 108, 255)
K.C.essencePale = rgb(232, 210, 255)
function K.EssenceIcon(parent, size)
	local C = K.C
	local h = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	-- one glimmer = two thin rounded arms crossing (vertical + horizontal), bright in the middle and fading to the tips, with a pale core
	local function glimmer(cx, cy, s)
		local kp = ColorSequenceKeypoint.new
		local tp = NumberSequenceKeypoint.new
		for _, rot in { 0, 90 } do
			local arm = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromOffset(math.max(2, math.floor(s * 0.2)), math.floor(s)),
				Rotation = rot, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, h)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, arm)
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ kp(0, C.essence), kp(0.5, C.essencePale), kp(1, C.essence) }),
				Transparency = NumberSequence.new({ tp(0, 0.75), tp(0.3, 0.15), tp(0.5, 0), tp(0.7, 0.15), tp(1, 0.75) }) }, arm)
		end
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(cx, cy), Size = UDim2.fromOffset(math.max(2, math.floor(s * 0.26)), math.max(2, math.floor(s * 0.26))),
			Rotation = 45, BackgroundColor3 = C.essencePale, BorderSizePixel = 0 }, h)
	end
	glimmer(0.42, 0.56, size * 0.78)
	glimmer(0.8, 0.24, size * 0.4)
	glimmer(0.16, 0.18, size * 0.3)
	return h
end

-- ===== v5.9: BACK / CLOSE button (top-right corner of the menus) =====
-- 152 x 42: dark plate with a light frame, a white X, the word in bold, a small ESC key cap on the right. Hover = red plate.
function K.CloseButton(parent, text, props)
	local C, F = K.C, K.F
	local W, H = 152, 42
	local b = new("TextButton", { Name = "CloseButton", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(W, H), BackgroundColor3 = C.panel2,
		BackgroundTransparency = 0.02, BorderSizePixel = 0 }, parent)
	for k, v in props or {} do b[k] = v end
	local z = b.ZIndex
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	local st = new("UIStroke", { Color = C.line2, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	local x = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(24, H / 2), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ZIndex = z + 1 }, b)
	for _, r in { 45, -45 } do
		local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(21, 3), Rotation = r,
			BackgroundColor3 = C.text, BorderSizePixel = 0, ZIndex = z + 1 }, x)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
	end
	new("TextLabel", { BackgroundTransparency = 1, Text = text or "CLOSE", TextSize = 19, FontFace = F.H, TextColor3 = C.text, Position = UDim2.fromOffset(42, 0),
		Size = UDim2.fromOffset(W - 42 - 46, H), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 1 }, b)
	local cap = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(36, 22), BackgroundColor3 = C.panel3,
		BorderSizePixel = 0, ZIndex = z + 1 }, b)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, cap)
	local capSt = new("UIStroke", { Color = C.line2, Thickness = 1 }, cap)
	new("TextLabel", { BackgroundTransparency = 1, Text = "ESC", TextSize = 11, FontFace = F.MB, TextColor3 = C.dim, Size = UDim2.fromScale(1, 1), ZIndex = z + 2 }, cap)
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	b.MouseEnter:Connect(function()
		K.tween(b, info, { BackgroundColor3 = C.red })
		K.tween(st, info, { Color = C.redHi })
		K.tween(cap, info, { BackgroundColor3 = C.redHi })
		capSt.Color = C.redHi
	end)
	b.MouseLeave:Connect(function()
		K.tween(b, info, { BackgroundColor3 = C.panel2 })
		K.tween(st, info, { Color = C.line2 })
		K.tween(cap, info, { BackgroundColor3 = C.panel3 })
		capSt.Color = C.line2
	end)
	return b
end

-- ===== logo: slim, serious BREAK / LINE with a red slash that has light flowing through it (v3.7) =====
-- K.Logo(parent, size, props, mode) -> holder, api
--   size  = letter height in px. props = extra holder properties (Position, AnchorPoint, ZIndex...).
--   mode  = "left" (default): holder grows to the right from its Position (top bars, HUD corners)
--           "center": holder is centred on its Position and the words can fly in / out (loading screens)
--   api.stop()            stop the flowing light (call before destroying, optional)
--   api.intro(dur)        "center" only: BREAK flies in from the left, LINE from the right, they meet and the slash draws in (yields dur)
--   api.outro(dur)        "center" only: the slash flares and stretches, the words fly apart and fade (yields dur)
--   api.slash / api.glow  the slash Frame / its glow (rotation K.LOGO_ANGLE degrees, clockwise)
--   api.setTransparency(a) fade the whole logo (0 = visible, 1 = gone)
K.LOGO_ANGLE = 20
function K.Logo(parent, size, props, mode)
	local C = K.C
	local RunService = game:GetService("RunService")
	mode = mode or "left"
	local h = math.floor(size * 1.2)
	local track = math.max(1, math.floor(size * 0.13)) -- letter spacing: slim + spaced = serious
	local gapW = math.floor(size * 0.5)
	local slashW = math.max(2, math.floor(size * 0.045 + 0.5))
	local slashH = math.floor(size * 1.12)
	local FONT = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Light)

	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, h) }, parent)
	if mode == "center" then
		holder.Size = UDim2.fromOffset(size * 7, h)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
	else
		holder.AutomaticSize = Enum.AutomaticSize.X
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) }, holder)
	end
	for k, v in props or {} do holder[k] = v end

	local letters = {}
	local function word(text, order)
		local w = new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), LayoutOrder = order }, holder)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, track) }, w)
		for i = 1, #text do
			local l = new("TextLabel", { BackgroundTransparency = 1, Text = text:sub(i, i), TextSize = size, FontFace = FONT, TextColor3 = C.text,
				AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), LayoutOrder = i }, w)
			table.insert(letters, l)
		end
		return w
	end
	local left = word("BREAK", 1)
	local gap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(gapW, h), LayoutOrder = 2, ClipsDescendants = false }, holder)
	local right = word("LINE", 3)
	if mode == "center" then
		left.AnchorPoint, left.Position = Vector2.new(1, 0.5), UDim2.new(0.5, -gapW / 2, 0.5, 0)
		right.AnchorPoint, right.Position = Vector2.new(0, 0.5), UDim2.new(0.5, gapW / 2, 0.5, 0)
		gap.AnchorPoint, gap.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	end

	-- soft glow behind the slash (transparent at its sides), the slash itself, and a light that runs down it
	local glow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(slashW * 7, slashH),
		Rotation = K.LOGO_ANGLE, BackgroundColor3 = C.red, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 1 }, gap)
	local glowGrad = new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.78), NumberSequenceKeypoint.new(1, 1) }) }, glow)
	local slash = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(slashW, slashH),
		Rotation = K.LOGO_ANGLE, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, gap)
	local DEEP, RED, HOT = rgb(120, 14, 22), C.red, rgb(255, 150, 150)
	local flowGrad = new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, DEEP), ColorSequenceKeypoint.new(0.34, RED), ColorSequenceKeypoint.new(0.47, C.redHi),
		ColorSequenceKeypoint.new(0.5, HOT), ColorSequenceKeypoint.new(0.53, C.redHi), ColorSequenceKeypoint.new(0.66, RED),
		ColorSequenceKeypoint.new(1, DEEP) }) }, slash)
	-- the travelling spark: a short bright streak that rides the slash with the flow
	local spark = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(slashW * 2.2, math.floor(slashH * 0.16)),
		Rotation = K.LOGO_ANGLE, BackgroundColor3 = rgb(255, 205, 205), BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 3 }, gap)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, spark)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, spark)

	local api = { slash = slash, glow = glow, holder = holder, left = left, right = right }
	local alive, fadeA, flare = true, 0, 0
	-- v3.8: the light goes DOWN the slash, then comes back UP the same way (smooth both ways), then rests for a moment at the top.
	-- (It used to run down, stall at the bottom and jump back to the top, which looked choppy.)
	local TRAVEL, REST = 1.05, 0.9
	local PERIOD = TRAVEL * 2 + REST
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not alive or not holder.Parent then conn:Disconnect() return end
		local t = (os.clock() - t0) % PERIOD
		local function ease(x) return x < 0.5 and 2 * x * x or 1 - (-2 * x + 2) ^ 2 / 2 end -- smooth in-out
		local e, vis = 0, 0 -- e: 0 = top of the slash, 1 = bottom
		if t < TRAVEL then
			local u = t / TRAVEL
			e, vis = ease(u), math.sin(u * math.pi)
		elseif t < TRAVEL * 2 then
			local u = (t - TRAVEL) / TRAVEL
			e, vis = 1 - ease(u), math.sin(u * math.pi)
		end
		flowGrad.Offset = Vector2.new(0, -0.62 + 1.24 * e)
		local len = slash.AbsoluteSize.Y / math.max(holder.AbsoluteSize.Y / h, 1e-3) -- current slash length in holder units
		local along = (-0.5 + e) * len
		local a = math.rad(K.LOGO_ANGLE)
		spark.Position = UDim2.new(0.5, math.sin(a) * -along, 0.5, math.cos(a) * along)
		spark.BackgroundTransparency = math.clamp(1 - (1 - fadeA) * 0.85 * vis * (len > 2 and 1 or 0), 0, 1)
		glow.BackgroundTransparency = math.clamp(fadeA + (0.25 - 0.25 * vis) - flare * 0.6, 0, 1)
	end)
	function api.stop() alive = false end
	function api.setTransparency(a)
		fadeA = a
		for _, l in letters do l.TextTransparency = a end
		slash.BackgroundTransparency = a
	end

	local function tw(inst, dur, goal, style, dir)
		return K.tween(inst, TweenInfo.new(dur, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), goal)
	end
	function api.intro(dur)
		dur = dur or 1.1
		if mode ~= "center" then return end
		local far = (parent:IsA("GuiObject") and parent.AbsoluteSize.X or 1920) / math.max(holder.AbsoluteSize.Y / h, 1e-3) * 0.6 + size * 4
		left.Position = UDim2.new(0.5, -gapW / 2 - far, 0.5, 0)
		right.Position = UDim2.new(0.5, gapW / 2 + far, 0.5, 0)
		for _, l in letters do l.TextTransparency = 1 end
		slash.Size = UDim2.fromOffset(slashW, 0)
		glow.Size = UDim2.fromOffset(slashW * 7, 0)
		local inT = dur * 0.6
		tw(left, inT, { Position = UDim2.new(0.5, -gapW / 2, 0.5, 0) })
		tw(right, inT, { Position = UDim2.new(0.5, gapW / 2, 0.5, 0) })
		for _, l in letters do tw(l, inT * 0.7, { TextTransparency = 0 }, Enum.EasingStyle.Quad) end
		task.wait(inT * 0.8)
		-- they meet: the slash draws in with a short flare
		flare = 1
		tw(slash, dur * 0.35, { Size = UDim2.fromOffset(slashW, slashH) })
		tw(glow, dur * 0.35, { Size = UDim2.fromOffset(slashW * 7, slashH) })
		t0 = os.clock() - 0.02 -- start a light pass right away
		task.spawn(function()
			local s = os.clock()
			while os.clock() - s < 0.6 do flare = 1 - (os.clock() - s) / 0.6 task.wait() end
			flare = 0
		end)
		task.wait(dur - inT * 0.8)
	end
	function api.outro(dur, stretchTo)
		dur = dur or 0.7
		if mode ~= "center" then api.setTransparency(1) return end
		flare = 1
		local far = (parent:IsA("GuiObject") and parent.AbsoluteSize.X or 1920) / math.max(holder.AbsoluteSize.Y / h, 1e-3) * 0.7 + size * 4
		tw(slash, dur * 0.5, { Size = UDim2.fromOffset(slashW * 1.6, stretchTo or slashH * 1.6), BackgroundColor3 = Color3.new(1, 1, 1) })
		tw(glow, dur * 0.5, { Size = UDim2.fromOffset(slashW * 10, stretchTo or slashH * 1.6) })
		tw(left, dur, { Position = UDim2.new(0.5, -gapW / 2 - far, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw(right, dur, { Position = UDim2.new(0.5, gapW / 2 + far, 0.5, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		for _, l in letters do tw(l, dur * 0.9, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
		task.wait(dur)
	end
	return holder, api
end

-- ===== ability icons (v3.8): small drawn graphics for the 4 movement abilities =====
-- K.AbilityIcon(parent, id, size, color) -> Frame (size x size). id = "DASH" | "DJUMP" | "MJUMP" | "WRUN" | "WCLIMB".
-- Built from thin rotated bars so they stay crisp at any size. Color defaults to white.
local function ibar(parent, size, x1, y1, x2, y2, th, col)
	local dx, dy = (x2 - x1) * size, (y2 - y1) * size
	local len = math.sqrt(dx * dx + dy * dy)
	return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2 * size, (y1 + y2) / 2 * size),
		Size = UDim2.fromOffset(len + th * 0.6, th), Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = col, BorderSizePixel = 0 }, parent)
end
function K.AbilityIcon(parent, id, size, color)
	color = color or Color3.new(1, 1, 1)
	local h = new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, parent)
	local th = math.max(2, math.floor(size * 0.09))
	local function B(x1, y1, x2, y2, c, t) return ibar(h, size, x1, y1, x2, y2, t or th, c or color) end
	local function chevronUp(cx, cy, w, c) B(cx - w, cy + w * 0.7, cx, cy, c); B(cx + w, cy + w * 0.7, cx, cy, c) end
	if id == "DASH" then -- speed lines trailing a bold arrow
		B(0.1, 0.3, 0.46, 0.3, color:Lerp(Color3.new(0, 0, 0), 0.45), math.max(1, th - 1))
		B(0.04, 0.5, 0.58, 0.5)
		B(0.16, 0.7, 0.46, 0.7, color:Lerp(Color3.new(0, 0, 0), 0.45), math.max(1, th - 1))
		B(0.62, 0.5, 0.9, 0.5)
		B(0.9, 0.5, 0.72, 0.28); B(0.9, 0.5, 0.72, 0.72)
	elseif id == "DJUMP" then -- two stacked chevrons
		chevronUp(0.5, 0.32, 0.26)
		chevronUp(0.5, 0.64, 0.26, color:Lerp(Color3.new(0, 0, 0), 0.35))
	elseif id == "MJUMP" then -- big arrow over a coiled base
		B(0.5, 0.78, 0.5, 0.2)
		chevronUp(0.5, 0.2, 0.24)
		B(0.26, 0.9, 0.74, 0.9)
		B(0.32, 0.8, 0.68, 0.8, color:Lerp(Color3.new(0, 0, 0), 0.4), math.max(1, th - 1))
	elseif id == "WRUN" then -- wall on the left, runner dashes along it
		B(0.18, 0.1, 0.18, 0.9, color:Lerp(Color3.new(0, 0, 0), 0.25), th + 1)
		B(0.38, 0.3, 0.86, 0.3)
		B(0.3, 0.52, 0.86, 0.52)
		B(0.38, 0.74, 0.86, 0.74)
		B(0.86, 0.52, 0.7, 0.4); B(0.86, 0.52, 0.7, 0.64)
	elseif id == "WCLIMB" then -- wall + ceiling corner, arrow climbing
		B(0.14, 0.12, 0.14, 0.9, color:Lerp(Color3.new(0, 0, 0), 0.25), th + 1)
		B(0.14, 0.12, 0.9, 0.12, color:Lerp(Color3.new(0, 0, 0), 0.25), th + 1)
		B(0.5, 0.82, 0.5, 0.36)
		chevronUp(0.5, 0.36, 0.2)
	end
	return h
end

return K
