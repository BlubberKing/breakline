-- LoadoutPicker (ModuleScript in ReplicatedStorage, named "LoadoutPicker") - BREAKLINE place only. NEW in v5.7. v5.9: bold dock captions, fitted pictures, CloseButton. v5.19: Dock spec.sq = tile size (the pre-game dock is bigger).
-- The loadout dock + item pickers that are shared by the pre-game loadout screen (MatchFlow) and the dead-screen RESERVE screen (DeathScreen).
--   LoadoutPicker.Dock(cv, spec)  -> dock     the row of tiles (MOVE, PRIMARY, 3 GADGETS, 3 RESERVE) with captions
--        spec = { y = 962, z = 8, itemAt = function(kind, idx) -> id, onClick = function(tile), enabled = function(tile) -> bool (optional) }
--        dock:Paint()  repaint every tile      dock:Select(tile | nil)  red frame on one tile      dock:Destroy()
--   LoadoutPicker.Big(cv, spec)   -> picker   LARGE menu (like the lobby): dim backdrop + panel + grid of big cards. Click a card = pick + close.
--   LoadoutPicker.Strip(cv, spec) -> picker   small horizontal scroll right above the dock (used by the RESERVE screen)
--        spec = { title, sub, items = { catalog items }, current = id, allowNone = bool, onPick = function(id), onClose = function(),
--                 z = 12, (Strip only:) x = 960, bottomY = 910 }
--        picker:Destroy()
-- cv = a 1920 x 1080 canvas Frame (MatchFlow.makeCanvas). Needs ReplicatedStorage: UIKit, LobbyCatalog, GunModels (optional), GadgetModels (optional).
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local UI = require(RS:WaitForChild("UIKit"))
local Sfx = RS:FindFirstChild("Sfx") and require(RS.Sfx) or nil
local function snd(name) if Sfx then pcall(Sfx.Play, name) end end -- SoundBank slots UIHover / UIClick (silent until filled)
local GunModels = RS:FindFirstChild("GunModels") and require(RS.GunModels) or nil
local GM = RS:FindFirstChild("GadgetModels") and require(RS.GadgetModels) or nil

local K, F, new, tween = UI.C, UI.F, UI.new, UI.tween
local rgb = Color3.fromRGB
local QUICK = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local P = {}

local function label(parent, text, size, font, color, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = font or F.H, TextColor3 = color or K.text }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end

-- ===== pictures =====
function P.GunPicture(parent, weaponId)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 158), LightColor = rgb(255, 252, 246),
		LightDirection = Vector3.new(-0.5, -1, -0.3) }, parent)
	if not GunModels then return vp end
	local ok, desc = pcall(GunModels.Describe, weaponId, "Iron")
	if not ok or not desc then return vp end
	local model = new("Model", {}, vp)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = (d.Glow and K.red) or d.Color,
				Material = d.Material or Enum.Material.SmoothPlastic, Transparency = d.Transparency or 0 }, model)
			if d.Shape then p.Shape = d.Shape end
			local half = d.Size / 2
			minV, maxV = minV:Min(d.CF.Position - half), maxV:Max(d.CF.Position + half)
		end
	end
	local cam = new("Camera", { FieldOfView = 16 }, vp)
	-- v5.9: fitted to the real silhouette and the frame's shape (long guns were cropped, short ones off centre)
	UI.FitViewport(vp, cam, model, Vector3.new(1, 0.08, 0), { pad = 0.1, fov = 16 })
	return vp
end

-- picture of any catalog item inside `parent` (a frame): gun model / gadget model / ability icon / glyph
function P.ItemPicture(parent, it, glyphSize, z)
	glyphSize = glyphSize or 30
	if it.kind == "weapon" then
		P.GunPicture(parent, it.id)
	elseif it.kind == "gadget" and GM then
		local holder = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, parent)
		GM.Picture(holder, it.id)
	elseif it.kind == "move" then
		local ic = UI.AbilityIcon(parent, it.icon or it.id, math.floor(glyphSize * 1.7), it.color)
		ic.AnchorPoint, ic.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		if z then
			ic.ZIndex = z
			for _, d in ic:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = z end end
		end
	else
		label(parent, it.glyph or "?", glyphSize, F.H, it.color or K.text, { Size = UDim2.fromScale(1, 1), ZIndex = z or 1 })
	end
end

-- ===== dock =====
local DEFS = {
	{ kind = "move", idx = 1, tag = "MOVE", group = 1 },
	{ kind = "weapon", idx = 1, tag = "PRIMARY", group = 2 },
	{ kind = "gadget", idx = 1, tag = "2", group = 3 }, { kind = "gadget", idx = 2, tag = "3", group = 3 }, { kind = "gadget", idx = 3, tag = "4", group = 3 },
	{ kind = "reserve", idx = 1, tag = "R1", group = 4 }, { kind = "reserve", idx = 2, tag = "R2", group = 4 }, { kind = "reserve", idx = 3, tag = "R3", group = 4 },
}
local CAPTIONS = { "MOVEMENT", "WEAPON", "GADGETS", "RESERVE" }

function P.Dock(cv, spec)
	local Catalog = require(RS:WaitForChild("LobbyCatalog"))
	-- v5.19: spec.sq = tile size (default 92; the Breakline pre-game screen uses 118). Gaps, icons and text grow with it.
	local SQ = spec.sq or 92
	local U = SQ / 92
	local GAP, GGAP = math.floor(12 * U + 0.5), math.floor(40 * U + 0.5)
	local y = spec.y or 962
	local z = spec.z or 8
	local holder = new("Frame", { Name = "LoadoutDock", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z, Active = false }, cv)
	local dock = { tiles = {}, holder = holder }
	local selected

	local totalW = 0
	for i, d in DEFS do
		if i > 1 then totalW += (d.group == DEFS[i - 1].group) and GAP or GGAP end
		totalW += SQ
	end
	local x = 960 - totalW / 2

	local function enabled(t) return not spec.enabled or spec.enabled(t) end

	local function paintTile(t)
		for _, c in t.content:GetChildren() do c:Destroy() end
		local id = spec.itemAt(t.kind, t.idx)
		local it = (id and id ~= "") and Catalog.ById[id] or nil
		if it and it.kind == "weapon" then
			P.GunPicture(t.content, it.id)
		elseif it and it.kind == "move" then
			local ic = UI.AbilityIcon(t.content, it.icon or it.id, math.floor(44 * U + 0.5), it.color)
			ic.AnchorPoint, ic.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		elseif it and it.kind == "gadget" and GM then
			local h = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, t.content) -- v5.9: the whole picture area (was the top 72 %: off centre)
			GM.Picture(h, it.id)
		elseif it then
			label(t.content, it.glyph or "?", math.floor(30 * U), F.H, it.color, { Size = UDim2.fromScale(1, 1) })
		else
			label(t.content, "+", math.floor(34 * U), F.H, K.mute, { Size = UDim2.fromScale(1, 1) })
		end
		t.name.Text = it and string.upper(it.name) or "EMPTY"
		t.name.TextColor3 = it and K.text or K.mute
		local on = enabled(t)
		t.btn.BackgroundTransparency = on and 0.05 or 0.35
		t.btn.Active = on
	end
	function dock:Paint()
		for _, t in self.tiles do
			paintTile(t)
			t.stroke.Color = (selected == t) and K.red or K.line2
			t.stroke.Thickness = (selected == t) and 2 or 1
		end
	end
	function dock:Select(t) selected = t; self:Paint() end
	function dock:Destroy() holder:Destroy() end

	local groupX = {}
	for i, d in DEFS do
		if i > 1 then x += (d.group == DEFS[i - 1].group) and GAP or GGAP end
		local btn = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(SQ, SQ),
			BackgroundColor3 = K.panel, BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = z }, holder)
		local stroke = new("UIStroke", { Color = K.line2, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
		local content = new("Frame", { Position = UDim2.fromOffset(6, math.floor(16 * U)), Size = UDim2.new(1, -12, 1, -math.floor(38 * U)), BackgroundTransparency = 1, ZIndex = z + 1 }, btn) -- v5.9: below the tag, above the name
		local nameL = label(btn, "", math.floor(12 * U + 0.5), F.M, K.text, { Position = UDim2.new(0, 2, 1, -math.floor(20 * U)), Size = UDim2.new(1, -4, 0, math.floor(18 * U)), ZIndex = z + 1 })
		label(btn, d.tag, math.floor(12 * U + 0.5), F.MB, K.dim, { Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(math.floor(40 * U), math.floor(14 * U)), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 2 })
		local t = { kind = d.kind, idx = d.idx, btn = btn, stroke = stroke, content = content, name = nameL }
		table.insert(dock.tiles, t)
		btn.MouseEnter:Connect(function() if enabled(t) then tween(btn, QUICK, { BackgroundColor3 = K.panel3 }) end end)
		btn.MouseLeave:Connect(function() tween(btn, QUICK, { BackgroundColor3 = K.panel }) end)
		btn.MouseButton1Click:Connect(function() if enabled(t) and spec.onClick then snd("UIClick") spec.onClick(t) end end)
		groupX[d.group] = groupX[d.group] or { x, x }
		groupX[d.group][2] = x + SQ
		x += SQ
	end
	for g, r in groupX do
		-- v5.9: bold + bright (was 13 px grey mono and hard to read)
		local cap = label(holder, CAPTIONS[g], math.floor(18 * U + 0.5), F.H, K.text, { Position = UDim2.fromOffset(r[1], y - math.floor(30 * U)), Size = UDim2.fromOffset(r[2] - r[1], math.floor(24 * U)), ZIndex = z })
		new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.45 }, cap)
	end
	dock:Paint()
	return dock
end

-- ===== one item card (shared by Big + Strip) =====
local function itemCard(parent, it, spec, size, pos, z, big)
	local cur = spec.current
	local equipped = (it and it.id == cur) or (not it and (cur == nil or cur == ""))
	local b = new("TextButton", { Text = "", AutoButtonColor = false, Position = pos, Size = size, BackgroundColor3 = K.panel2, BorderSizePixel = 0, ZIndex = z }, parent)
	local st = new("UIStroke", { Color = equipped and K.red or K.line, Thickness = equipped and 2 or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	local artH = big and 140 or 78
	local art = new("Frame", { Position = UDim2.fromOffset(big and 14 or 6, big and 12 or 6), Size = UDim2.new(1, big and -28 or -12, 0, artH), BackgroundTransparency = 1, ZIndex = z + 1 }, b)
	if it then
		P.ItemPicture(art, it, big and 26 or 30, z + 1)
	else
		label(art, "NONE", big and 26 or 22, F.H, K.mute, { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
	end
	local nameY = big and 156 or 92
	label(b, it and string.upper(it.name) or "EMPTY", big and 22 or 16, F.H, K.text, { Position = UDim2.fromOffset(big and 16 or 4, nameY), Size = UDim2.new(1, big and -32 or -8, 0, big and 30 or 22), ZIndex = z + 1,
		TextXAlignment = big and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center })
	label(b, it and string.upper(it.sub or "") or "CLEAR SLOT", big and 11 or 12, F.M, K.dim, { Position = UDim2.fromOffset(big and 17 or 4, nameY + (big and 30 or 22)), Size = UDim2.new(1, big and -32 or -8, 0, 18), ZIndex = z + 1,
		TextXAlignment = big and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center })
	if equipped and big then
		local tag = new("Frame", { Size = UDim2.fromOffset(86, 20), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = z + 3 }, b)
		label(tag, "EQUIPPED", 11, F.MB, K.text, { Size = UDim2.fromScale(1, 1), ZIndex = z + 4 })
	end
	b.MouseEnter:Connect(function()
		snd("UIHover")
		tween(b, QUICK, { BackgroundColor3 = K.panel3 })
		if not equipped then tween(st, QUICK, { Color = K.line2 }) end
	end)
	b.MouseLeave:Connect(function()
		tween(b, QUICK, { BackgroundColor3 = K.panel2 })
		if not equipped then tween(st, QUICK, { Color = K.line }) end
	end)
	return b
end

local function listWithNone(spec)
	local list = {}
	if spec.allowNone then table.insert(list, false) end
	for _, it in spec.items do table.insert(list, it) end
	return list
end

-- ===== BIG picker (lobby style) =====
function P.Big(cv, spec)
	local z = spec.z or 20
	local picker = {}
	local root = new("Frame", { Name = "BigPicker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z }, cv)
	-- dim backdrop: a click outside the panel closes it
	local back = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = z }, root)
	local PW, PH = 1560, 690
	local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 550), Size = UDim2.fromOffset(PW, PH),
		BackgroundColor3 = K.panel, BackgroundTransparency = 0.02, BorderSizePixel = 0, ZIndex = z + 1, Active = true }, root)
	new("UIStroke", { Color = K.line2, Thickness = 1 }, panel)
	new("Frame", { Size = UDim2.fromOffset(4, PH), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = z + 2 }, panel)
	label(panel, spec.title or "", 40, F.H, K.text, { Position = UDim2.fromOffset(32, 16), Size = UDim2.fromOffset(900, 50), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 2 })
	if spec.sub and spec.sub ~= "" then
		label(panel, spec.sub, 12, F.M, K.dim, { Position = UDim2.fromOffset(34, 68), Size = UDim2.fromOffset(1000, 16), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 2 })
	end
	local closeBtn = UI.CloseButton(panel, "CLOSE", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(PW - 28, 24), ZIndex = z + 3 }) -- v5.9: clear close button
	new("Frame", { Position = UDim2.fromOffset(32, 98), Size = UDim2.fromOffset(PW - 64, 1), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = z + 2 }, panel)

	local wide = false
	for _, it in spec.items do if it.kind == "weapon" then wide = true end end
	local CW, CH = wide and 312 or 246, 208
	local sf = new("ScrollingFrame", { Position = UDim2.fromOffset(24, 110), Size = UDim2.fromOffset(PW - 48, PH - 126), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = K.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = z + 2 }, panel)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(CW, CH), CellPadding = UDim2.fromOffset(16, 16), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingBottom = UDim.new(0, 16) }, sf)

	local function pickId(id)
		snd("UIClick")
		if spec.onPick then spec.onPick(id) end
		picker:Destroy()
	end
	for i, it in listWithNone(spec) do
		local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, ZIndex = z + 2 }, sf)
		local b = itemCard(cell, it or nil, spec, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), z + 3, true)
		b.MouseButton1Click:Connect(function() pickId(it and it.id or "") end)
	end
	if #spec.items == 0 then
		label(panel, "NOTHING TO CHOOSE FROM", 22, F.H, K.mute, { Position = UDim2.fromOffset(0, 300), Size = UDim2.fromOffset(PW, 40), ZIndex = z + 2 })
	end

	local closing = false
	local conn
	function picker:Destroy()
		if closing then return end
		closing = true
		if conn then conn:Disconnect() end
		root:Destroy()
		if spec.onClose then spec.onClose() end
	end
	back.MouseButton1Click:Connect(function() picker:Destroy() end)
	closeBtn.MouseButton1Click:Connect(function() picker:Destroy() end)
	conn = UIS.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then picker:Destroy() end
	end)
	picker.root = root
	-- small pop-in
	local us = new("UIScale", { Scale = 0.96 }, panel)
	tween(us, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 })
	return picker
end

-- ===== STRIP picker (small horizontal scroll above the dock) =====
function P.Strip(cv, spec)
	local z = spec.z or 12
	local picker = {}
	local items = listWithNone(spec)
	local CW, CH = 118, 142
	local count = #items
	local w = math.clamp(count * (CW + 10) + 40, 330, 1500)
	local px = math.clamp(spec.x or 960, w / 2 + 20, 1900 - w / 2) -- keep the strip on the screen
	local frame = new("Frame", { Name = "StripPicker", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(px, spec.bottomY or 910), Size = UDim2.fromOffset(w, CH + 74),
		BackgroundColor3 = K.panel, BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = z }, cv)
	new("UIStroke", { Color = K.line2, Thickness = 1 }, frame)
	new("Frame", { Size = UDim2.fromOffset(3, CH + 74), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = z + 1 }, frame)
	label(frame, spec.title or "", 22, F.H, K.text, { Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(500, 28), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 1 })
	local sf = new("ScrollingFrame", { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, CH + 16), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(count * (CW + 10), 0), ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.X, ZIndex = z + 1 }, frame)
	if count == 0 then
		label(frame, spec.emptyText or "NOTHING IN YOUR RESERVE FOR THIS SLOT", 16, F.H, K.mute, { Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 30), ZIndex = z + 1 })
	end
	local closing = false
	function picker:Destroy()
		if closing then return end
		closing = true
		frame:Destroy()
		if spec.onClose then spec.onClose() end
	end
	for i, it in items do
		local b = itemCard(sf, it or nil, spec, UDim2.fromOffset(CW, CH), UDim2.fromOffset((i - 1) * (CW + 10), 0), z + 2, false)
		b.MouseButton1Click:Connect(function()
			if spec.onPick then spec.onPick(it and it.id or "") end
			picker:Destroy()
		end)
	end
	picker.root = frame
	return picker
end

return P
