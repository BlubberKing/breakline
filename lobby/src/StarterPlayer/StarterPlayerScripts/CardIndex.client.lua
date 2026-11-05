-- CardIndex v1.3 (v4.9b: the collection grid really uses static cards now - it built fresh ANIMATED cards before, which was the lag - and baked sprite-sheet cards when CardArt.SHEETS is filled in) (was v1.2 v4.9: PERFORMANCE - only the cards on screen exist. Collection cells are filled when they scroll into view and emptied when they leave, card art comes from a shared template cache (CardArt) and the deck minis are built the same way, so hundreds of cards stay smooth even on a tablet) (was v1.1 v4.4: deck panel shows mini CARDS instead of stacked name rows; no "x1" badge on collection cards; only OWNED text, bigger; smaller +/-)
-- (was v1.0) (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in v4.3 (GDD section 4.1).
-- The CARD INDEX page: your card collection on the left, your 32-card DECK on the right.
-- Opened by the CARD INDEX buttons in LobbyClient (they set the Player attribute CardIndexOpen = true). ESC / BACK closes it.
--   Collection : every card you own, filter by rarity, sort by rarity or name. Under each card: [-]  red in-deck boxes + OWNED n  [+].
--                Click a card to inspect it big (add / remove there too, < > or arrow keys to browse).
--   Deck       : n / 32 counter, rarity mix bar, the cards in it as a grid of mini cards with an xN count (click = inspect, right click or [-] = take one out),
--                AUTO FILL / CLEAR / UNDO CHANGES.
--   (?)        : the deck rules (from Cards.RULES) and the 7 rarities.
-- Saving: the deck saves by itself the moment it is valid (exactly 32 cards). The server re-checks it (LobbyServer, SetDeck remote).
-- Leaving with an unfinished deck asks once, then throws the changes away (your last saved deck stays).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local SetDeckR = RS:WaitForChild("LobbyRemotes"):WaitForChild("SetDeck")
local Cards = require(RS:WaitForChild("Cards"))
local CardArt = require(RS:WaitForChild("CardArt"))
local UI = require(RS:WaitForChild("UIKit"))

-- ================= theme (same as LobbyClient "CLEAN") =================
local rgb = Color3.fromRGB
local C = {
	void = rgb(4, 5, 7), bg = rgb(9, 10, 13), panel = rgb(14, 15, 19), panel2 = rgb(22, 24, 29), panel3 = rgb(31, 34, 41),
	line = rgb(40, 43, 51), line2 = rgb(78, 82, 94), text = rgb(238, 239, 242), dim = rgb(148, 153, 164), mute = rgb(90, 95, 106),
	red = rgb(226, 38, 48), redHi = rgb(255, 64, 74), redDeep = rgb(116, 20, 28),
}
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local FONTS = UI.F
local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GROW = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function tween(o, info, goal) TweenService:Create(o, info, goal):Play() end
local function border(o, color, thick, transp)
	return new("UIStroke", { Color = color or C.line, Thickness = thick or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter }, o)
end
local function frame(parent, x, y, w, h, color, transp)
	return new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = color or C.panel,
		BackgroundTransparency = transp or 0, BorderSizePixel = 0 }, parent)
end
local function lbl(parent, text, size, x, y, w, h, color, font, align)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = FONTS[font or "B"], TextColor3 = color or C.text,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), TextXAlignment = align or Enum.TextXAlignment.Left }, parent)
end
local function hoverable(b, bg, bgHot, st, stCol, stHot)
	b.MouseEnter:Connect(function()
		tween(b, FAST, { BackgroundColor3 = bgHot })
		if st then tween(st, FAST, { Color = stHot }) end
	end)
	b.MouseLeave:Connect(function()
		tween(b, FAST, { BackgroundColor3 = bg })
		if st then tween(st, FAST, { Color = stCol }) end
	end)
end
local function grow(b, amt)
	if b.AnchorPoint == Vector2.zero then
		local p, sz = b.Position, b.Size
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(p.X.Scale + sz.X.Scale / 2, p.X.Offset + sz.X.Offset / 2, p.Y.Scale + sz.Y.Scale / 2, p.Y.Offset + sz.Y.Offset / 2)
	end
	local sc = new("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function() TweenService:Create(sc, GROW, { Scale = amt or 1.05 }):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(sc, GROW, { Scale = 1 }):Play() end)
	return sc
end
local function button(parent, text, x, y, w, h, kind, size)
	kind = kind or "ghost"
	local primary = kind == "primary"
	local bg, bgHot = primary and C.red or C.panel2, primary and C.redHi or C.panel3
	local b = new("TextButton", { Text = text, TextSize = size or 16, FontFace = FONTS.H, TextColor3 = (kind == "danger") and C.redHi or C.text,
		BackgroundColor3 = bg, AutoButtonColor = false, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h) }, parent)
	local st
	if not primary then st = border(b, kind == "danger" and C.redDeep or C.line, 1) end
	hoverable(b, bg, bgHot, st, kind == "danger" and C.redDeep or C.line, kind == "danger" and C.red or C.line2)
	return b
end
local function keyHint(parent, key, text, x, y)
	local kw = math.max(30, #key * 8 + 16)
	local k = frame(parent, x, y, kw, 24, C.panel2, 0)
	border(k, C.line2, 1)
	lbl(k, key, 12, 0, 0, kw, 24, C.text, "MB", Enum.TextXAlignment.Center)
	return lbl(parent, text, 16, x + kw + 8, y, 160, 24, C.dim, "HM")
end
local function diamond(parent, cx, cy, s, col)
	return new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(s, s), Rotation = 45,
		BackgroundColor3 = col, BorderSizePixel = 0 }, parent)
end
-- small +/- sign drawn from bars
local function signIcon(parent, plus, col, len)
	len = len or 12
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(len, 2), BackgroundColor3 = col, BorderSizePixel = 0 }, parent)
	if plus then new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, len), BackgroundColor3 = col, BorderSizePixel = 0 }, parent) end
end
local function rarityTint(R) -- readable rarity colour on the dark UI
	if R.id == "signature" then return WHITE end
	if R.id == "common" then return R.light end
	return R.glow
end

-- ================= data =================
local function decode(attr)
	local raw = player:GetAttribute(attr)
	if type(raw) ~= "string" then return nil end
	local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
	return ok and type(d) == "table" and d or nil
end
local collection = Cards.Collection(decode("CardsJson"))
local saved = decode("DeckJson") or Cards.DefaultDeck(collection)
local draft = table.clone(saved)
local pendingSave = false
local discardArmed = 0

local function sortedDeck(d)
	local out = table.clone(d)
	table.sort(out, Cards.Sort)
	return out
end
local function sameDeck(a, b)
	if #a ~= #b then return false end
	local ca, cb = Cards.Counts(a), Cards.Counts(b)
	for id, n in ca do if cb[id] ~= n then return false end end
	return true
end
local function maxFor(id) return math.min(Cards.MAX_COPIES, collection[id] or 0) end

-- ================= gui =================
local gui = new("ScreenGui", { Name = "CardIndex", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Enabled = false }, player:WaitForChild("PlayerGui"))
new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) }, gui)
local root = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.void, BorderSizePixel = 0 }, gui)
do -- starfield + a faint red glow low on the screen
	local rng = Random.new(42)
	for _ = 1, 110 do
		local s = rng:NextNumber() < 0.15 and 2 or 1
		new("Frame", { Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber()), Size = UDim2.fromOffset(s, s), BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.45 + rng:NextNumber() * 0.45, BorderSizePixel = 0 }, root)
	end
	local glow = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = C.redDeep, BorderSizePixel = 0 }, root)
	new("UIGradient", { Rotation = 270, Transparency = NumberSequence.new(0.72, 1) }, glow)
end
local cv = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1 }, root)
local cvScale = new("UIScale", {}, cv)
local function rescale()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	cvScale.Scale = math.max(0.3, math.min(vs.X / 1920, vs.Y / 1080))
end
rescale()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

local RIGHT = 1864
-- ----- top bar -----
-- logo  /  CARD INDEX  (?) DECK RULES   - a horizontal list, so the title always sits right after the logo whatever its width
local header = new("Frame", { Position = UDim2.fromOffset(56, 28), Size = UDim2.fromOffset(1100, 60), BackgroundTransparency = 1 }, cv)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 16) }, header)
local logo = UI.Logo(header, 36, {}, "left")
logo.LayoutOrder = 1
local function autoLbl(text, size, font, color, order)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = FONTS[font], TextColor3 = color, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 56), LayoutOrder = order }, header)
	return l
end
autoLbl("/", 34, "HM", C.mute, 2)
autoLbl("CARD INDEX", 44, "H", C.text, 3)
local helpBtn = new("TextButton", { Text = "?", TextSize = 22, FontFace = FONTS.H, TextColor3 = C.text, AutoButtonColor = false, BackgroundColor3 = C.panel2,
	BorderSizePixel = 0, Size = UDim2.fromOffset(38, 38), LayoutOrder = 4 }, header)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, helpBtn)
local helpStroke = border(helpBtn, C.line2, 1.5)
hoverable(helpBtn, C.panel2, C.red, helpStroke, C.line2, C.redHi)
autoLbl("DECK RULES", 11, "MB", C.mute, 5)
local backBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(1752, 40), Size = UDim2.fromOffset(112, 36) }, cv)
local backLbl = keyHint(backBtn, "ESC", "BACK", 0, 6)
backBtn.MouseEnter:Connect(function() tween(backLbl, FAST, { TextColor3 = C.text }) end)
backBtn.MouseLeave:Connect(function() tween(backLbl, FAST, { TextColor3 = C.dim }) end)
grow(backBtn, 1.05)
frame(cv, 56, 98, RIGHT - 56, 1, C.line, 0)

-- toast
local toast = frame(cv, 760, 112, 640, 40, C.bg, 0.02)
toast.Visible = false
toast.ZIndex = 50 -- above the inspect + rules panels
border(toast, C.line, 1)
frame(toast, 0, 0, 3, 40, C.red, 0)
local toastText = lbl(toast, "", 15, 16, 0, 612, 40, C.text, "HM", Enum.TextXAlignment.Center)
local toastToken = 0
local function say(text)
	toastToken += 1
	local my = toastToken
	toastText.Text = string.upper(text)
	toast.Visible = true
	task.delay(3.5, function() if my == toastToken then toast.Visible = false end end)
end

-- ================= deck editing =================
local refreshAll -- forward
local function canAdd(id)
	if #draft >= Cards.DECK_SIZE then return false, ("Deck is full (%d / %d). Take a card out first."):format(#draft, Cards.DECK_SIZE) end
	local have = Cards.Counts(draft)[id] or 0
	if have >= Cards.MAX_COPIES then return false, ("Max %d copies of a card."):format(Cards.MAX_COPIES) end
	if have >= (collection[id] or 0) then return false, ("You only own %d."):format(collection[id] or 0) end
	return true
end
local saveToken = 0
local lastSent = nil
local function scheduleSave()
	saveToken += 1
	local my = saveToken
	if #draft ~= Cards.DECK_SIZE or sameDeck(draft, saved) or not Cards.Validate(draft, collection) then pendingSave = false return end
	pendingSave = true
	task.delay(0.35, function()
		if my ~= saveToken then return end
		lastSent = sortedDeck(draft)
		SetDeckR:FireServer(lastSent)
	end)
end
local function changed()
	discardArmed = 0
	scheduleSave()
	refreshAll()
end
local function addCard(id)
	local ok, why = canAdd(id)
	if not ok then say(why) return false end
	table.insert(draft, id)
	changed()
	return true
end
local function removeCard(id)
	for i = #draft, 1, -1 do
		if draft[i] == id then
			table.remove(draft, i)
			changed()
			return true
		end
	end
	return false
end

-- ================= left: COLLECTION =================
local LX, LY, LW, LH = 56, 120, 1180, 904
local left = frame(cv, LX, LY, LW, LH, C.bg, 0.12)
border(left, C.line, 1)
lbl(left, "COLLECTION", 24, 20, 12, 300, 32, C.text, "H")
local ownedLbl = lbl(left, "", 11, LW - 420, 22, 400, 14, C.mute, "M", Enum.TextXAlignment.Right)
frame(left, 20, 50, LW - 40, 1, C.line, 0)

local filter, sortMode = "all", "rarity"
local chips = {}
local rebuildOrder -- forward
do
	local x = 20
	local list = { { id = "all", name = "ALL" } }
	for _, R in Cards.Rarities do table.insert(list, { id = R.id, name = R.name, R = R }) end
	for _, f in list do
		local w = #f.name * 9 + (f.R and 40 or 26)
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(x, 62),
			Size = UDim2.fromOffset(w, 30) }, left)
		local st = border(b, C.line, 1)
		hoverable(b, C.panel, C.panel2, st, C.line, C.line2)
		local tx = 13
		if f.R then
			local d = diamond(b, 15, 15, 8, f.R.id == "signature" and WHITE or f.R.body)
			if f.R.id == "signature" then border(d, BLACK, 1) end
			tx = 27
		end
		local t = lbl(b, f.name, 12, tx, 0, w - tx, 30, C.dim, "MB")
		local under = frame(b, 0, 28, w, 2, C.red, 0)
		chips[f.id] = { b = b, t = t, under = under }
		b.MouseButton1Click:Connect(function()
			filter = f.id
			rebuildOrder()
		end)
		x += w + 8
	end
	local sortBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel, BorderSizePixel = 0, Position = UDim2.fromOffset(LW - 170, 62),
		Size = UDim2.fromOffset(150, 30) }, left)
	local st = border(sortBtn, C.line, 1)
	hoverable(sortBtn, C.panel, C.panel2, st, C.line, C.line2)
	local sortLbl = lbl(sortBtn, "", 12, 0, 0, 150, 30, C.dim, "MB", Enum.TextXAlignment.Center)
	local function paintSort() sortLbl.Text = "SORT  //  " .. string.upper(sortMode) end
	paintSort()
	sortBtn.MouseButton1Click:Connect(function()
		sortMode = (sortMode == "rarity") and "name" or "rarity"
		paintSort()
		rebuildOrder()
	end)
end
frame(left, 20, 104, LW - 40, 1, C.line, 0)

local CARD_W, CELL_W, CELL_H = 200, 208, 340
local grid = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 112), Size = UDim2.fromOffset(LW - 24, LH - 120), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, left)
new("UIGridLayout", { CellSize = UDim2.fromOffset(CELL_W, CELL_H), CellPadding = UDim2.fromOffset(14, 16), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center }, grid)
new("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 20) }, grid)

local cells = {} -- id -> cell record
local openInspect -- forward
local SQ = 28 -- v4.4: the +/- buttons are a little smaller (was 32)
local function smallSquare(parent, x, y, plus)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.panel2, BorderSizePixel = 0, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(SQ, SQ) }, parent)
	local st = border(b, C.line, 1)
	hoverable(b, C.panel2, plus and C.red or C.panel3, st, C.line, plus and C.redHi or C.line2)
	signIcon(b, plus, C.text, 10)
	grow(b, 1.08)
	return b
end

-- v4.9: a cell is just an empty frame until it scrolls near the screen. fillCell builds its buttons + card art, emptyCell throws them away again.
local function makeCell(c)
	local R = Cards.RarityById[c.rarity]
	local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = c.order }, grid)
	local rec = { c = c, R = R, cell = cell, alive = false }
	cells[c.id] = rec
	return rec
end

local paintCell -- forward
local updateMiniVisible -- forward (v4.9b fix: the deck list called it before it existed, so task.defer got nil and errored)
local function fillCell(rec)
	if rec.alive then return end
	rec.alive = true
	local c, cell = rec.c, rec.cell
	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, cell)
	local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset((CELL_W - CARD_W) / 2, 6),
		Size = UDim2.fromOffset(CARD_W, CARD_W * 1.4) }, content)
	grow(btn, 1.04)
	local holderSlot = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, btn)
	local y = CARD_W * 1.4 + 14
	local minus = smallSquare(content, (CELL_W - CARD_W) / 2, y, false)
	local plus = smallSquare(content, CELL_W - (CELL_W - CARD_W) / 2 - SQ, y, true)
	local pips = {}
	for i = 1, Cards.MAX_COPIES do
		local p = frame(content, CELL_W / 2 - 37 + (i - 1) * 20, y, 14, 14, C.panel, 0)
		p.Rotation = 0
		border(p, C.line2, 1)
		pips[i] = p
	end
	local own = lbl(content, "", 17, 36, y + 15, CELL_W - 72, 20, C.text, "H", Enum.TextXAlignment.Center) -- v4.4: only OWNED, bigger
	rec.content, rec.btn, rec.slot, rec.pips, rec.own, rec.minus, rec.plus = content, btn, holderSlot, pips, own, minus, plus
	btn.MouseButton1Click:Connect(function() openInspect(c.id) end)
	btn.MouseButton2Click:Connect(function() removeCard(c.id) end)
	plus.MouseButton1Click:Connect(function() addCard(c.id) end)
	minus.MouseButton1Click:Connect(function() if not removeCard(c.id) then say("That card is not in your deck.") end end)
	paintCell(rec)
	-- the art comes from CardArt's template cache (a clone, not a rebuild); the first time a card is seen it is built once
	rec.token = (rec.token or 0) + 1
	local my = rec.token
	task.spawn(function()
		-- v4.9 LAG FIX: this used to build a fresh ANIMATED card (anim defaulted to true), so the template cache was never used and every card
		-- that scrolled in drew 300-700 frames + looping tweens. Static now: a baked sprite-sheet image (CardArt.SHEETS) or a cached clone.
		local holder = CardArt.Build(holderSlot, c.id, { width = CARD_W, anim = false })
		if not rec.alive or rec.token ~= my then holder:Destroy() end
	end)
end

local function emptyCell(rec)
	if not rec.alive then return end
	rec.alive = false
	rec.token = (rec.token or 0) + 1
	if rec.content then rec.content:Destroy() end
	rec.content, rec.btn, rec.slot, rec.pips, rec.own, rec.minus, rec.plus = nil, nil, nil, nil, nil, nil, nil
end

function paintCell(rec)
	if not rec.alive then return end
	local id = rec.c.id
	local inDeck = Cards.Counts(draft)[id] or 0
	local owned = collection[id] or 0
	local cap = maxFor(id)
	for i, p in rec.pips do
		p.Visible = i <= cap
		local on = i <= inDeck
		p.BackgroundColor3 = on and C.red or C.panel
		p:FindFirstChildOfClass("UIStroke").Color = on and C.redHi or C.line2
	end
	rec.own.Text = ("OWNED %d"):format(owned)
	local full = #draft >= Cards.DECK_SIZE
	rec.plus.AutoButtonColor = false
	rec.plus.BackgroundTransparency = (full or inDeck >= cap) and 0.6 or 0
	rec.minus.BackgroundTransparency = (inDeck == 0) and 0.6 or 0
end

function rebuildOrder()
	for id, ch in chips do
		local on = (id == filter)
		ch.under.Visible = on
		ch.t.TextColor3 = on and C.text or C.dim
		ch.b.BackgroundColor3 = on and C.panel2 or C.panel
	end
	local list = {}
	for _, c in Cards.List do table.insert(list, c) end
	if sortMode == "name" then
		table.sort(list, function(a, b) return a.name < b.name end)
	else
		table.sort(list, function(a, b) return Cards.Sort(a.id, b.id) end)
	end
	for i, c in list do
		local rec = cells[c.id]
		if rec then
			rec.cell.LayoutOrder = i
			rec.cell.Visible = (filter == "all" or c.rarity == filter) and (collection[c.id] or 0) > 0
		end
	end
	grid.CanvasPosition = Vector2.zero
end

-- ================= right: DECK =================
local DX, DY, DW, DH = 1260, 120, RIGHT - 1260, 904
local deckP = frame(cv, DX, DY, DW, DH, C.bg, 0.12)
border(deckP, C.line, 1)
frame(deckP, 0, 0, DW, 3, C.red, 0)
lbl(deckP, "DECK", 24, 20, 12, 200, 32, C.text, "H")
lbl(deckP, "YOUR CARD POOL  //  3 ROLL OUT AT THE START OF EVERY MATCH", 11, 20, 46, DW - 40, 14, C.dim, "M")
local countBig = lbl(deckP, "32", 72, 18, 66, 110, 80, C.text, "H")
local countOf = lbl(deckP, "/ 32", 30, 120, 96, 90, 40, C.mute, "HM")
local status = frame(deckP, DW - 230, 88, 210, 34, C.panel2, 0)
local statusStroke = border(status, C.line2, 1)
local statusT = lbl(status, "", 14, 0, 0, 210, 34, C.text, "H", Enum.TextXAlignment.Center)
local barTrack = frame(deckP, 20, 152, DW - 40, 6, C.panel3, 0)
local barFill = frame(barTrack, 0, 0, DW - 40, 6, WHITE, 0)
lbl(deckP, "RARITY MIX", 10, 20, 172, 200, 13, C.mute, "MB")
local mixBar = frame(deckP, 20, 190, DW - 40, 14, C.panel, 0)
border(mixBar, C.line, 1)
local mixLegend = new("Frame", { Position = UDim2.fromOffset(20, 210), Size = UDim2.fromOffset(DW - 40, 16), BackgroundTransparency = 1 }, deckP)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }, mixLegend)
frame(deckP, 20, 238, DW - 40, 1, C.line, 0)

-- v4.4: the deck is shown as a grid of mini CARDS (one per distinct card, with an xN count) instead of stacked name rows
local MINI_W = 104
local MINI_H = math.floor(MINI_W * 1.4)
local list = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 246), Size = UDim2.fromOffset(DW - 24, DH - 246 - 86), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, deckP)
new("UIGridLayout", { CellSize = UDim2.fromOffset(MINI_W, MINI_H), CellPadding = UDim2.fromOffset(9, 12), SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center }, list)
new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 12) }, list)
lbl(deckP, "CLICK A CARD TO INSPECT   //   RIGHT CLICK OR [-] TO TAKE ONE OUT", 11, 20, DH - 80, DW - 40, 14, C.mute, "M")
local emptyHint = lbl(deckP, "YOUR DECK IS EMPTY\nADD CARDS FROM YOUR COLLECTION", 16, 0, 420, DW, 60, C.mute, "HM", Enum.TextXAlignment.Center)

local fillBtn = button(deckP, "AUTO FILL", 20, DH - 58, 176, 42, "ghost", 16)
local undoBtn = button(deckP, "UNDO CHANGES", 20 + 188, DH - 58, 176, 42, "ghost", 16)
local clearBtn = button(deckP, "CLEAR", 20 + 376, DH - 58, DW - 40 - 376, 42, "danger", 16)
for _, b in { fillBtn, undoBtn, clearBtn } do grow(b, 1.04) end

local miniCells = {} -- card id -> { id, cell, slot, pill, pillT, artOn, holder }
local function miniCell(id)
	local m = miniCells[id]
	if m then return m end
	local cell = new("Frame", { BackgroundTransparency = 1 }, list)
	local slot = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, cell)
	local btn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3 }, cell)
	local pill = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), Size = UDim2.fromOffset(40, 24), BackgroundColor3 = C.red, BorderSizePixel = 0, ZIndex = 4 }, cell)
	border(pill, BLACK, 1.5)
	local pillT = lbl(pill, "", 16, 0, 0, 40, 24, WHITE, "H", Enum.TextXAlignment.Center)
	pillT.ZIndex = 5
	local mb = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 6 }, cell)
	local mst = border(mb, C.line2, 1)
	hoverable(mb, C.bg, C.red, mst, C.line2, C.redHi)
	signIcon(mb, false, C.text, 10)
	for _, ch in mb:GetChildren() do if ch:IsA("Frame") then ch.ZIndex = 7 end end
	local cellScale = new("UIScale", { Scale = 1 }, cell)
	btn.MouseEnter:Connect(function() tween(cellScale, GROW, { Scale = 1.05 }) end)
	btn.MouseLeave:Connect(function() tween(cellScale, GROW, { Scale = 1 }) end)
	btn.MouseButton1Click:Connect(function() openInspect(id) end)
	btn.MouseButton2Click:Connect(function() removeCard(id) end)
	mb.MouseButton1Click:Connect(function() removeCard(id) end)
	m = { id = id, cell = cell, slot = slot, pill = pill, pillT = pillT, artOn = false }
	miniCells[id] = m
	return m
end

local function paintDeckCards()
	local counts = Cards.Counts(draft)
	local distinct, seen = {}, {}
	for _, id in sortedDeck(draft) do if not seen[id] then seen[id] = true table.insert(distinct, id) end end
	emptyHint.Visible = #distinct == 0
	for i, id in distinct do
		local m = miniCell(id)
		m.cell.Visible = true
		m.cell.LayoutOrder = i
		m.pillT.Text = "x" .. counts[id]
	end
	task.defer(updateMiniVisible) -- v4.9: the art of the minis is built / dropped by updateMiniVisible (only the ones on screen)
	for id, m in miniCells do
		if not seen[id] then m.cell.Visible = false end
	end
end

local function paintDeck()
	local n = #draft
	countBig.Text = tostring(n)
	countBig.TextColor3 = (n == Cards.DECK_SIZE) and C.text or C.redHi
	countOf.Text = "/ " .. Cards.DECK_SIZE
	barFill.Size = UDim2.new(math.clamp(n / Cards.DECK_SIZE, 0, 1), 0, 1, 0)
	barFill.BackgroundColor3 = (n == Cards.DECK_SIZE) and WHITE or C.red
	if n < Cards.DECK_SIZE then
		local need = Cards.DECK_SIZE - n
		statusT.Text = ("ADD %d MORE CARD%s"):format(need, need == 1 and "" or "S")
		statusT.TextColor3, statusStroke.Color, status.BackgroundColor3 = C.redHi, C.red, C.panel2
	elseif n > Cards.DECK_SIZE then
		statusT.Text = ("REMOVE %d CARDS"):format(n - Cards.DECK_SIZE)
		statusT.TextColor3, statusStroke.Color, status.BackgroundColor3 = C.redHi, C.red, C.panel2
	elseif pendingSave or not sameDeck(draft, saved) then
		statusT.Text = "SAVING..."
		statusT.TextColor3, statusStroke.Color, status.BackgroundColor3 = C.dim, C.line2, C.panel2
	else
		statusT.Text = "SAVED  //  READY"
		statusT.TextColor3, statusStroke.Color, status.BackgroundColor3 = C.void, C.text, C.text
	end
	-- rarity mix
	for _, ch in mixBar:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
	for _, ch in mixLegend:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
	local counts = {}
	for _, id in draft do local r = Cards.ById[id].rarity counts[r] = (counts[r] or 0) + 1 end
	local x = 0
	local W = DW - 40
	for i, R in Cards.Rarities do
		local k = counts[R.id] or 0
		if k > 0 then
			local w = W * k / Cards.DECK_SIZE
			local seg = frame(mixBar, x, 0, math.max(1, w - 1), 14, R.id == "signature" and WHITE or R.body, 0)
			if R.id == "signature" then
				new("UIGradient", { Rotation = 0, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.5, WHITE),
					ColorSequenceKeypoint.new(0.51, BLACK), ColorSequenceKeypoint.new(1, BLACK) }) }, seg)
			elseif R.wash then
				seg.BackgroundColor3 = WHITE
				local kp = {}
				for k, cl in R.wash do table.insert(kp, ColorSequenceKeypoint.new((k - 1) / (#R.wash - 1), cl)) end
				new("UIGradient", { Color = ColorSequence.new(kp) }, seg)
			end
			x += w
			local item = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i }, mixLegend)
			diamond(item, 5, 8, 7, R.id == "signature" and WHITE or R.body)
			local t = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
				Text = string.sub(R.name, 1, 3) .. " " .. k, TextSize = 10, FontFace = FONTS.MB, TextColor3 = C.dim }, item)
			t.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	paintDeckCards()
end

-- ================= inspect (big card) =================
local insp = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.25, Visible = false, ZIndex = 30 }, cv)
insp.Size = UDim2.fromOffset(1920, 1080)
local ip = frame(insp, 330, 170, 1260, 700, C.bg, 0)
border(ip, C.line2, 1)
frame(ip, 0, 0, 1260, 3, C.red, 0)
local ipCardSlot = new("Frame", { Position = UDim2.fromOffset(60, 52), Size = UDim2.fromOffset(426, 596), BackgroundTransparency = 1 }, ip)
local ipRar = lbl(ip, "", 14, 560, 70, 600, 18, C.text, "MB")
local ipName = lbl(ip, "", 64, 556, 92, 660, 80, C.text, "H")
ipName.TextScaled = true
new("UITextSizeConstraint", { MaxTextSize = 64 }, ipName)
local ipDesc = lbl(ip, "", 20, 560, 190, 620, 90, C.text, "B")
ipDesc.TextWrapped = true
ipDesc.TextYAlignment = Enum.TextYAlignment.Top
lbl(ip, "PLACEHOLDER CARD  //  THE ABILITY DOES NOTHING YET", 11, 560, 290, 620, 14, C.mute, "MB")
frame(ip, 560, 320, 640, 1, C.line, 0)
local ipStats = lbl(ip, "", 18, 560, 338, 640, 26, C.text, "HM")
local ipPips = new("Frame", { Position = UDim2.fromOffset(560, 376), Size = UDim2.fromOffset(300, 22), BackgroundTransparency = 1 }, ip)
local ipAdd = button(ip, "ADD TO DECK", 560, 430, 300, 58, "primary", 22)
local ipRem = button(ip, "TAKE ONE OUT", 876, 430, 300, 58, "ghost", 22)
grow(ipAdd, 1.04) grow(ipRem, 1.04)
lbl(ip, "RIGHT CLICK A CARD IN THE COLLECTION TO TAKE ONE OUT QUICKLY", 11, 560, 504, 640, 14, C.mute, "M")
local ipPrev = button(ip, "<", 560, 600, 58, 48, "ghost", 26)
local ipNext = button(ip, ">", 630, 600, 58, 48, "ghost", 26)
lbl(ip, "BROWSE", 11, 700, 617, 200, 14, C.mute, "MB")
local ipClose = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(1110, 24), Size = UDim2.fromOffset(130, 30) }, ip)
keyHint(ipClose, "ESC", "CLOSE", 0, 3)
local ipCard, ipId, ipToken = nil, nil, 0
local ipBlock = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, ip) -- clicks on the panel do not close it

local function paintInspect()
	if not ipId then return end
	local c = Cards.ById[ipId]
	local R = Cards.RarityById[c.rarity]
	local inDeck = Cards.Counts(draft)[ipId] or 0
	local cap = maxFor(ipId)
	ipRar.Text = R.name .. "  //  CARD " .. string.format("%02d", c.order) .. " OF " .. #Cards.List
	ipRar.TextColor3 = rarityTint(R)
	ipName.Text = string.upper(c.name)
	ipDesc.Text = c.desc
	ipStats.Text = ("IN DECK  %d / %d          OWNED  %d"):format(inDeck, cap, collection[ipId] or 0)
	for _, ch in ipPips:GetChildren() do ch:Destroy() end
	for i = 1, Cards.MAX_COPIES do
		local p = frame(ipPips, (i - 1) * 30, 0, 22, 22, i <= inDeck and C.red or C.panel, i <= cap and 0 or 0.8)
		border(p, i <= inDeck and C.redHi or C.line2, 1, i <= cap and 0 or 0.7)
	end
	local okAdd = canAdd(ipId)
	ipAdd.BackgroundTransparency = okAdd and 0 or 0.55
	ipRem.TextTransparency = inDeck > 0 and 0 or 0.6
end
local function visibleOrder()
	local out = {}
	for id, rec in cells do if rec.cell.Visible then table.insert(out, { id = id, o = rec.cell.LayoutOrder }) end end
	table.sort(out, function(a, b) return a.o < b.o end)
	return out
end
function openInspect(id)
	if not Cards.Is(id) then return end
	if id ~= ipId then
		if ipCard then ipCard:Destroy() ipCard = nil end
		ipId = id
		ipToken += 1
		local my = ipToken
		task.spawn(function() -- (CardArt.Build can yield while it measures the description text)
			local holder = CardArt.Build(ipCardSlot, id, { width = 426 })
			if my ~= ipToken then holder:Destroy() return end
			ipCard = holder
			local sc = new("UIScale", { Scale = 0.92 }, holder)
			tween(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end)
	end
	insp.Visible = true
	paintInspect()
end
local function closeInspect() insp.Visible = false end
local function browse(dir)
	local order = visibleOrder()
	for i, e in order do
		if e.id == ipId then
			local n = order[((i - 1 + dir) % #order) + 1]
			if n then openInspect(n.id) end
			return
		end
	end
end
ipAdd.MouseButton1Click:Connect(function() addCard(ipId) end)
ipRem.MouseButton1Click:Connect(function() if not removeCard(ipId) then say("That card is not in your deck.") end end)
ipPrev.MouseButton1Click:Connect(function() browse(-1) end)
ipNext.MouseButton1Click:Connect(function() browse(1) end)
ipClose.MouseButton1Click:Connect(closeInspect)
insp.MouseButton1Click:Connect(closeInspect)
ipBlock.MouseButton1Click:Connect(function() end)

-- ================= rules (?) =================
local rules = new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = BLACK, BackgroundTransparency = 0.3, Visible = false, ZIndex = 40 }, cv)
local rp = frame(rules, 500, 170, 920, 700, C.bg, 0)
border(rp, C.line2, 1)
frame(rp, 0, 0, 920, 3, C.red, 0)
new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, rp)
lbl(rp, "DECK RULES", 40, 36, 24, 500, 50, C.text, "H")
lbl(rp, "HOW THE CARD SYSTEM WORKS", 11, 38, 76, 500, 14, C.dim, "M")
local rClose = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(770, 30), Size = UDim2.fromOffset(130, 30) }, rp)
keyHint(rClose, "ESC", "CLOSE", 0, 3)
frame(rp, 36, 104, 848, 1, C.line, 0)
for i, text in Cards.RULES do
	local y = 124 + (i - 1) * 54
	local n = frame(rp, 36, y, 34, 34, C.panel2, 0)
	border(n, C.line2, 1)
	lbl(n, tostring(i), 18, 0, 0, 34, 34, C.redHi, "H", Enum.TextXAlignment.Center)
	local t = lbl(rp, text, 17, 86, y - 4, 800, 44, C.text, "B")
	t.TextWrapped = true
	t.TextYAlignment = Enum.TextYAlignment.Center
end
lbl(rp, "RARITIES  //  LOWEST TO HIGHEST", 11, 38, 460, 500, 14, C.dim, "MB")
local RS_W = math.floor((848 - (#Cards.Rarities - 1) * 10) / #Cards.Rarities) -- v4.9: 8 rarities (Epic added)
for i, R in Cards.Rarities do
	local x = 36 + (i - 1) * (RS_W + 10)
	local sw = frame(rp, x, 484, RS_W, 120, R.body, 0)
	border(sw, BLACK, 1.5)
	if R.id == "signature" then
		sw.BackgroundColor3 = BLACK
		local clip = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true }, sw)
		for k = 0, 12 do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(k * 14 - 20, 60), Size = UDim2.fromOffset(5, 240), Rotation = 32,
				BackgroundColor3 = WHITE, BorderSizePixel = 0 }, clip)
		end
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(200, 5), Rotation = -58, BackgroundColor3 = C.red, BorderSizePixel = 0 }, clip)
	elseif R.wash then -- v4.9 DIVINE: watercolour rainbow swatch
		sw.BackgroundColor3 = WHITE
		local kp = {}
		for k, cl in R.wash do table.insert(kp, ColorSequenceKeypoint.new((k - 1) / (#R.wash - 1), cl:Lerp(WHITE, 0.35))) end
		new("UIGradient", { Rotation = 62, Color = ColorSequence.new(kp) }, sw)
	else
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(R.body:Lerp(R.light, 0.2), R.deep) }, sw)
	end
	local tag = frame(rp, x, 610, RS_W, 26, C.panel, 0)
	lbl(tag, R.name, 11, 0, 0, RS_W, 26, rarityTint(R), "MB", Enum.TextXAlignment.Center)
	lbl(rp, ("%d"):format(i), 12, x, 640, RS_W, 16, C.mute, "M", Enum.TextXAlignment.Center)
end
local function openRules() rules.Visible = true end
local function closeRules() rules.Visible = false end
helpBtn.MouseButton1Click:Connect(openRules)
rules.MouseButton1Click:Connect(closeRules)
rClose.MouseButton1Click:Connect(closeRules)

-- ================= deck buttons =================
fillBtn.MouseButton1Click:Connect(function()
	if #draft >= Cards.DECK_SIZE then say("Your deck is already full.") return end
	-- fill with the rarest cards you still have room for (one copy each pass, so the deck stays varied)
	local order = {}
	for _, c in Cards.List do table.insert(order, c.id) end
	table.sort(order, Cards.Sort)
	local added = true
	while #draft < Cards.DECK_SIZE and added do
		added = false
		local counts = Cards.Counts(draft)
		local pass = {}
		for _, id in order do
			if #draft + #pass < Cards.DECK_SIZE and (counts[id] or 0) < maxFor(id) then table.insert(pass, id) end
		end
		for _, id in pass do table.insert(draft, id) added = true end
	end
	changed()
	say("Deck filled.")
end)
clearBtn.MouseButton1Click:Connect(function()
	if #draft == 0 then return end
	table.clear(draft)
	changed()
	say("Deck cleared. Add 32 cards to save it.")
end)
undoBtn.MouseButton1Click:Connect(function()
	draft = table.clone(saved)
	changed()
	say("Back to your saved deck.")
end)

-- ================= refresh / build =================
function refreshAll()
	for _, rec in cells do paintCell(rec) end
	paintDeck()
	paintInspect()
	local total = 0
	for _, n in collection do total += n end
	ownedLbl.Text = ("%d CARDS  //  %d COPIES OWNED"):format(#Cards.List, total)
end

local built = false

-- v4.9: decide which collection cells are near the screen. Cells inside the window (plus one row of margin) are filled, the rest are emptied.
local FILL_PER_TICK = 6 -- v4.9b: static / baked cards are cheap now
local function updateVisible()
	if not built then return end
	local gy, gh = grid.AbsolutePosition.Y, grid.AbsoluteSize.Y
	local filled = 0
	for _, rec in cells do
		local cell = rec.cell
		local want, keep = false, false
		if cell.Visible then
			local ch = cell.AbsoluteSize.Y
			local top = cell.AbsolutePosition.Y
			-- (a cell with no size yet = the layout has not run: wait for the next tick)
			want = ch > 1 and top + ch > gy - ch * 1.2 and top < gy + gh + ch * 1.2
			-- v4.9b: a filled cell is only emptied once it is 3 rows away, so scrolling up and down does not rebuild the same cards over and over
			keep = ch > 1 and top + ch > gy - ch * 3 and top < gy + gh + ch * 3
		end
		if want then
			if not rec.alive and filled < FILL_PER_TICK then
				fillCell(rec)
				filled += 1
			end
		elseif rec.alive and not keep then
			emptyCell(rec)
		end
	end
	return filled
end

-- the deck list does the same for its mini cards
function updateMiniVisible()
	if not built or not list then return end
	local gy, gh = list.AbsolutePosition.Y, list.AbsoluteSize.Y
	for _, m in miniCells do
		if m.cell.Visible then
			local ch = math.max(m.cell.AbsoluteSize.Y, 1)
			local top = m.cell.AbsolutePosition.Y
			local want = top + ch > gy - ch and top < gy + gh + ch
			if want and not m.artOn then
				m.artOn = true
				m.token = (m.token or 0) + 1
				local my = m.token
				task.spawn(function()
					local holder = CardArt.Build(m.slot, m.id, { width = MINI_W, anim = false })
					if not m.artOn or m.token ~= my then holder:Destroy() else m.holder = holder end
				end)
			elseif not want and m.artOn then
				m.artOn = false
				m.token = (m.token or 0) + 1
				if m.holder then m.holder:Destroy() m.holder = nil end
			end
		elseif m.artOn then
			m.artOn = false
			m.token = (m.token or 0) + 1
			if m.holder then m.holder:Destroy() m.holder = nil end
		end
	end
end

local function buildGrid()
	if built then return end
	built = true
	for _, c in Cards.List do makeCell(c) end
	rebuildOrder()
	refreshAll()
	updateVisible()
	updateMiniVisible()
end

-- ================= open / close =================
local menuWasOpen = nil
local isOpen = false
-- v4.9: ten times a second, fill the cells that scrolled into view and empty the ones that left (cheap: a few hundred position reads)
do
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if not isOpen then return end
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		updateVisible()
		updateMiniVisible()
	end)
end
local function open()
	if isOpen then return end
	isOpen = true
	collection = Cards.Collection(decode("CardsJson"))
	saved = decode("DeckJson") or saved
	draft = table.clone(saved)
	discardArmed = 0
	menuWasOpen = player:GetAttribute("LobbyMenuOpen")
	player:SetAttribute("LobbyMenuOpen", true)
	gui.Enabled = true
	root.BackgroundTransparency = 0
	cv.Position = UDim2.new(0.5, 0, 0.5, 18)
	tween(cv, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) })
	buildGrid()
	closeInspect()
	closeRules()
	refreshAll()
end
local function close(force)
	if not isOpen then return end
	if not force and #draft ~= Cards.DECK_SIZE and not sameDeck(draft, saved) then
		if os.clock() - discardArmed > 4 then
			discardArmed = os.clock()
			say(("Deck has %d / %d cards and is not saved. Press BACK again to discard changes."):format(#draft, Cards.DECK_SIZE))
			return
		end
		draft = table.clone(saved)
	end
	isOpen = false
	gui.Enabled = false
	-- v4.9: nothing stays built while the page is closed (the template cache makes opening it again cheap)
	for _, rec in cells do emptyCell(rec) end
	for _, m in miniCells do
		m.artOn = false
		m.token = (m.token or 0) + 1
		if m.holder then m.holder:Destroy() m.holder = nil end
	end
	player:SetAttribute("LobbyMenuOpen", menuWasOpen)
	-- cleared a moment later, so the same ESC press is not also handled by LobbyClient (it ignores keys while CardIndexOpen is set)
	task.delay(0.1, function()
		if not isOpen and player:GetAttribute("CardIndexOpen") then player:SetAttribute("CardIndexOpen", nil) end
	end)
end
backBtn.MouseButton1Click:Connect(function() close(false) end)

player:GetAttributeChangedSignal("CardIndexOpen"):Connect(function()
	if player:GetAttribute("CardIndexOpen") then open() else close(true) end
end)
player:GetAttributeChangedSignal("DeckJson"):Connect(function()
	local d = decode("DeckJson")
	if not d then return end
	saved = d
	pendingSave = false
	if not isOpen then
		draft = table.clone(saved)
	elseif lastSent and sameDeck(draft, lastSent) and not sameDeck(saved, lastSent) then
		draft = table.clone(saved) -- the server refused that deck: show what is really saved
	elseif #draft == Cards.DECK_SIZE and not sameDeck(draft, saved) then
		scheduleSave() -- you changed it again while the last save was on its way: send the newest one
	end
	if lastSent and sameDeck(saved, lastSent) then lastSent = nil end
	if isOpen then refreshAll() end
end)
player:GetAttributeChangedSignal("CardsJson"):Connect(function()
	collection = Cards.Collection(decode("CardsJson"))
	if isOpen then rebuildOrder() refreshAll() end
end)

UIS.InputBegan:Connect(function(input, gpe)
	if not isOpen or gpe or UIS:GetFocusedTextBox() then return end
	local k = input.KeyCode
	if k == Enum.KeyCode.Escape then
		if rules.Visible then closeRules()
		elseif insp.Visible then closeInspect()
		else close(false) end
	elseif insp.Visible and (k == Enum.KeyCode.Left or k == Enum.KeyCode.A) then browse(-1)
	elseif insp.Visible and (k == Enum.KeyCode.Right or k == Enum.KeyCode.D) then browse(1)
	end
end)
