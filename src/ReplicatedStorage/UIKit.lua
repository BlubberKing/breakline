-- UIKit (ModuleScript in ReplicatedStorage) - BREAKLINE place only. Used by LoadingScreen (ReplicatedFirst) and MatchFlow (StarterPlayerScripts).
-- Shared look (same colors + fonts as the lobby "CLEAN" UI) and a few small builders.
--   UIKit.C / UIKit.F                      colors / fonts
--   UIKit.new(class, props, parent)        make an Instance
--   UIKit.tween(inst, tweenInfo, goal)     play a tween, returns it
--   UIKit.SoulIcon(parent, size)           the faceted blue soul crystal
--   UIKit.Logo(parent, size, fxLayer)      BREAK / LINE logo whose red slash has an explosion at both ends.
--                                          fxLayer = a full-screen Frame (the sparks are drawn there). Returns holder, stopFn
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

-- ===== logo with an exploding slash =====
function K.Logo(parent, size, fxLayer, props)
	local C = K.C
	local rng = Random.new()
	local h = math.floor(size * 1.15)
	local holder = new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h) }, parent)
	for k, v in props or {} do holder[k] = v end
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, math.floor(size * 0.05)) }, holder)
	local function word(text, order)
		return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = K.F.H, TextColor3 = C.text,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h), LayoutOrder = order }, holder)
	end
	word("BREAK", 1)
	local gap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(math.floor(size * 0.34), h), LayoutOrder = 2 }, holder)
	local ANG = 20
	local slash = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(math.max(3, math.floor(size * 0.1)), math.floor(size * 0.98)), Rotation = ANG, BackgroundColor3 = C.red, BorderSizePixel = 0 }, gap)
	word("LINE", 3)

	local alive = true
	local function stop() alive = false end

	-- the two tips of the slash, in fxLayer pixels
	local function tips()
		local c = slash.AbsolutePosition + slash.AbsoluteSize / 2 - fxLayer.AbsolutePosition
		local half = slash.AbsoluteSize.Y / 2
		local d = Vector2.new(math.sin(math.rad(ANG)), -math.cos(math.rad(ANG)))
		return c + d * half, c - d * half
	end

	local SPARK_COLORS = { Color3.new(1, 1, 1), C.redHi, rgb(255, 170, 60), rgb(255, 220, 140) }
	local function circle(pos, d, color, transp)
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(d, d),
			BackgroundColor3 = color, BackgroundTransparency = transp, BorderSizePixel = 0, ZIndex = 5 }, fxLayer)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		return f
	end
	local function burst(pos, k)
		-- core flash
		local core = circle(pos, 26 * k, Color3.new(1, 1, 1), 0)
		K.tween(core, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(70 * k, 70 * k), BackgroundTransparency = 1 })
		task.delay(0.32, function() core:Destroy() end)
		-- shockwave ring
		local ring = circle(pos, 14, C.red, 1)
		local st = new("UIStroke", { Color = C.redHi, Thickness = 3 * k, Transparency = 0 }, ring)
		K.tween(ring, TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(190 * k, 190 * k) })
		K.tween(st, TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1, Thickness = 0.5 })
		task.delay(0.7, function() ring:Destroy() end)
		-- sparks
		for _ = 1, math.floor(16 * k) do
			local a = rng:NextNumber(0, math.pi * 2)
			local speed = rng:NextNumber(60, 210) * k
			local life = rng:NextNumber(0.4, 0.95)
			local len = rng:NextNumber(8, 22) * k
			local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(pos.X, pos.Y), Size = UDim2.fromOffset(len, 3),
				Rotation = math.deg(a), BackgroundColor3 = SPARK_COLORS[rng:NextInteger(1, #SPARK_COLORS)], BorderSizePixel = 0, ZIndex = 6 }, fxLayer)
			local to = pos + Vector2.new(math.cos(a), math.sin(a)) * speed * life
			K.tween(s, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(len * 0.2, 2), BackgroundTransparency = 1 })
			task.delay(life + 0.05, function() s:Destroy() end)
		end
	end

	-- glowing end caps that breathe between bursts
	local capA, capB
	task.spawn(function()
		task.wait(0.2); task.wait(0.2) -- let the layout settle
		if not alive or not holder.Parent then return end
		local a0, b0 = tips()
		capA = circle(a0, 14, C.redHi, 0.35)
		capB = circle(b0, 11, C.redHi, 0.45)
		local n = 0
		while alive and holder.Parent do
			local a, b = tips()
			capA.Position, capB.Position = UDim2.fromOffset(a.X, a.Y), UDim2.fromOffset(b.X, b.Y)
			n += 1
			local pulse = 0.5 + 0.5 * math.sin(os.clock() * 7)
			capA.Size = UDim2.fromOffset(10 + 8 * pulse, 10 + 8 * pulse)
			capB.Size = UDim2.fromOffset(8 + 6 * pulse, 8 + 6 * pulse)
			if n % 52 == 1 then burst(a, 1) end        -- top tip: big explosion
			if n % 52 == 27 then burst(b, 0.65) end    -- bottom tip: smaller one, half a cycle later
			task.wait()
		end
		if capA then capA:Destroy() end
		if capB then capB:Destroy() end
	end)
	return holder, stop
end

return K
