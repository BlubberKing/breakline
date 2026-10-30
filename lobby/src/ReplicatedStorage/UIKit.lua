-- UIKit (ModuleScript in ReplicatedStorage) - BOTH games (v3.7). Keep the two copies identical (Breakline is the master).
-- Breakline: LoadingScreen (ReplicatedFirst) + MatchFlow. Lobby: LobbyLoading (ReplicatedFirst) + LobbyClient (logo).
-- Shared look (same colors + fonts as the lobby "CLEAN" UI) and a few small builders.
--   UIKit.C / UIKit.F                      colors / fonts
--   UIKit.new(class, props, parent)        make an Instance
--   UIKit.tween(inst, tweenInfo, goal)     play a tween, returns it
--   UIKit.SoulIcon(parent, size)           the faceted blue soul crystal
--   UIKit.Logo(parent, size, props, mode)  v3.7 logo: slim spaced BREAK / LINE, red slash with light flowing through it.
--                                          mode "left" (corner logos) or "center" (loading screens: intro / outro). Returns holder, api
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
	local PERIOD = 2.4 -- seconds per pass of light down the slash
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not alive or not holder.Parent then conn:Disconnect() return end
		local t = (os.clock() - t0) % PERIOD
		local u = math.clamp(t / (PERIOD * 0.62), 0, 1) -- the light runs, then a short rest
		local e = u < 0.5 and 4 * u ^ 3 or 1 - (-2 * u + 2) ^ 3 / 2 -- ease in-out
		flowGrad.Offset = Vector2.new(0, -0.62 + 1.24 * e)
		local len = slash.AbsoluteSize.Y / math.max(holder.AbsoluteSize.Y / h, 1e-3) -- current slash length in holder units
		local along = (-0.5 + e) * len
		local a = math.rad(K.LOGO_ANGLE)
		spark.Position = UDim2.new(0.5, math.sin(a) * -along, 0.5, math.cos(a) * along)
		local vis = (u > 0 and u < 1) and math.sin(u * math.pi) or 0
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
		t0 = os.clock() - PERIOD * 0.02 -- start a light pass right away
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

return K
