-- TrainingClient v1.1 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. (v1 NEW in v5.17, GDD 5.13 TRAINING ZONE)
-- v5.18 FIXES + ADDITIONS (owner Nov 9):
--   * walking OUT of the zone no longer leaves a copy of your hands + gun floating in the air: the gun script is told to clean up (attribute Stop) BEFORE it is
--     destroyed (Roblox stops a script that is being destroyed before its own Destroying handler can run), and every leftover viewmodel in the camera is removed
--   * walking out no longer leaves you stuck in FIRST PERSON with the mouse locked in the middle: the camera is pushed back out to the normal third-person
--     distance (switching LockFirstPerson -> Classic kept the zoom at ~0.5 studs, which Roblox still treats as first person = locked mouse)
--   * the card you pick is EQUIPPED: it shows on the HUD bottom right (above the item row) exactly like the card you picked in a match, and the gun gets a
--     fresh life so DEEP POCKETS / a full magazine show at once
--   * a CHANGE LOADOUT button next to CHANGE CARD: pick your movement ability, gun, 3 gadgets and 3 reserve slots right here (saved to your real loadout,
--     the same rules as the lobby loadout: no item twice in a row, a gadget is in a gadget slot OR the reserve, a gun is the primary OR in the reserve)
-- What YOU see while you stand inside the part "TrainingZone" (TrainingServer sets the Player attribute InTraining):
--   * the lobby UI is hidden (LobbyUI, shop, cosmetics, card index) and the in-round UI takes over (MatchHUD, always running, shows itself while InTraining),
--   * GunClient (the very same file as Breakline's, stored in ReplicatedStorage > TrainingClients) is cloned into your character = first person, your equipped gun / gadgets /
--     movement ability exactly like in a match; it is stopped + destroyed again when you leave (and the camera, mouse, body and HUD are put back),
--   * buttons at the top of the screen: LEAVE THE TRAINING ZONE (teleports you to the Workspace part "EntranceTrainingZone"), CHANGE CARD (every card you own,
--     tested in the zone only - it does not touch your deck or a real match) and CHANGE LOADOUT.
--   * the mouse is locked in first person, so HOLD LEFT ALT to get the cursor for the buttons (the pickers free it by themselves).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UI = require(RS:WaitForChild("UIKit"))
local Cards = require(RS:WaitForChild("Cards"))
local CardArt = require(RS:WaitForChild("CardArt"))
local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local Settings = RS:FindFirstChild("Settings") and require(RS.Settings) or nil
local GunModels = RS:FindFirstChild("GunModels") and require(RS.GunModels) or nil
local GM = RS:FindFirstChild("GadgetModels") and require(RS.GadgetModels) or nil
local K, F, new = UI.C, UI.F, UI.new
local rgb = Color3.fromRGB
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function tween(o, t, goal, style) TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal):Play() end

local remotes = RS:WaitForChild("TrainingRemotes", 30)
local LeaveR = remotes and remotes:WaitForChild("Leave", 10)
local PickR = remotes and remotes:WaitForChild("PickCard", 10)
local lobbyRemotes = RS:WaitForChild("LobbyRemotes", 30)
local SetLoadoutR = lobbyRemotes and lobbyRemotes:WaitForChild("SetLoadout", 10)
local templates = RS:WaitForChild("TrainingClients", 30)

local LOBBY_GUIS = { "LobbyUI", "ShopGui", "CosmeticsGui", "CardIndex" } -- hidden while you are in the zone
local hidden = {} -- gui -> true (the ones WE switched off)
local gunClone
local DEFAULT_MIN_ZOOM = player.CameraMinZoomDistance -- (the place's own setting, put back after the zoom-out push)
local DEFAULT_MAX_ZOOM = player.CameraMaxZoomDistance
local THIRD_PERSON_ZOOM = 12 -- v5.18: studs the camera is pushed out to when you leave the zone

-- ======================================================================================
-- the buttons
-- ======================================================================================
local gui = new("ScreenGui", { Name = "TrainingGui", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
	player:WaitForChild("PlayerGui"))
local modal = new("TextButton", { Name = "ModalCursor", Text = "", Modal = true, BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1), Visible = false }, gui)
local canvas = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1 }, gui)
local cScale = new("UIScale", {}, canvas)
local function rescale()
	local vp = camera.ViewportSize
	cScale.Scale = math.max(0.35, math.min(vp.X / 1920, vp.Y / 1080))
end
rescale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local function bigButton(x, y, w, h, red)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = red and rgb(30, 10, 13) or rgb(14, 15, 19), BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 5 }, canvas)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	local st = new("UIStroke", { Color = red and K.red or K.line2, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	local sc = new("UIScale", { Scale = 1 }, b)
	b.MouseEnter:Connect(function()
		tween(sc, 0.14, { Scale = 1.04 })
		tween(b, 0.14, { BackgroundColor3 = red and K.red or rgb(34, 36, 44) })
		tween(st, 0.14, { Color = red and K.redHi or K.text })
	end)
	b.MouseLeave:Connect(function()
		tween(sc, 0.14, { Scale = 1 })
		tween(b, 0.14, { BackgroundColor3 = red and rgb(30, 10, 13) or rgb(14, 15, 19) })
		tween(st, 0.14, { Color = red and K.red or K.line2 })
	end)
	return b
end
local function btnText(b, text, size, color)
	return new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, FontFace = F.H, TextColor3 = color or WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, b)
end
local ROW_W, ROW_GAP = 300, 12
local leaveBtn = bigButton(960, 18, ROW_W * 2 + ROW_GAP, 58, true)
btnText(leaveBtn, "LEAVE THE TRAINING ZONE", 30)
-- v5.18: CHANGE CARD and CHANGE LOADOUT side by side under it
local cardBtn = bigButton(960 - (ROW_W + ROW_GAP) / 2, 86, ROW_W, 50, false)
btnText(cardBtn, "CHANGE CARD", 24, K.text)
local loadBtn = bigButton(960 + (ROW_W + ROW_GAP) / 2, 86, ROW_W, 50, false)
btnText(loadBtn, "CHANGE LOADOUT", 24, K.text)
local cardNow = new("TextLabel", { BackgroundTransparency = 1, Text = "NO CARD", TextSize = 15, FontFace = F.MB, TextColor3 = K.dim, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 142), Size = UDim2.fromOffset(612, 20), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 }, canvas)
new("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.3 }, cardNow)
local hint = new("TextLabel", { BackgroundTransparency = 1, Text = "HOLD  LEFT ALT  FOR THE CURSOR", TextSize = 14, FontFace = F.MB, TextColor3 = K.text, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 164), Size = UDim2.fromOffset(612, 20), ZIndex = 5 }, canvas)
new("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.3 }, hint)

-- ======================================================================================
-- v5.18: the equipped card on the HUD (bottom right, above MatchHUD's item row - the same place + look as Breakline's CardRoll HUD card)
-- ======================================================================================
local HUD_W = 112
local HUD_X, HUD_Y = 1872 - HUD_W, 1080 - 40 - 190 - 18 - HUD_W * 1.4
local hudGui = new("ScreenGui", { Name = "TrainingCardHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
	player.PlayerGui)
local hudCanvas = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080), BackgroundTransparency = 1 }, hudGui)
local hudCS = new("UIScale", {}, hudCanvas)
local function hudFit()
	local v = camera.ViewportSize
	hudCS.Scale = math.max(0.3, math.min(v.X / 1920, v.Y / 1080))
end
hudFit()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(hudFit)
local hudHolder = new("Frame", { Position = UDim2.fromOffset(HUD_X, HUD_Y), Size = UDim2.fromOffset(HUD_W, HUD_W * 1.4), BackgroundTransparency = 1, Visible = false }, hudCanvas)
local hudScale = new("UIScale", { Scale = 1 }, hudHolder)
local hudText = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0, -14, 1, -4), Size = UDim2.fromOffset(300, 74), BackgroundTransparency = 1 }, hudHolder)
new("TextLabel", { BackgroundTransparency = 1, Text = "YOUR CARD", TextSize = 11, FontFace = F.MB, TextColor3 = K.dim, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Right }, hudText)
local hudName = new("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 24, FontFace = F.H, TextColor3 = WHITE, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Right }, hudText)
new("UIStroke", { Color = BLACK, Thickness = 2, Transparency = 0.5 }, hudName)
local hudRarity = new("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 12, FontFace = F.MB, TextColor3 = WHITE, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Right }, hudText)
new("UIStroke", { Color = BLACK, Thickness = 1.5, Transparency = 0.5 }, hudRarity)
local hudCard, hudCardId = nil, nil
local function refreshHudCard(pop)
	local id = player:GetAttribute("MatchCard")
	local show = player:GetAttribute("InTraining") == true and Cards.Is(id)
	hudGui.Enabled = show
	if Cards.Is(id) and id ~= hudCardId then
		if hudCard then hudCard:Destroy() hudCard = nil end
		local ok, built = pcall(CardArt.Build, hudHolder, id, { width = HUD_W })
		hudCard = ok and built or nil
		hudCardId = id
		local c, R = Cards.ById[id], Cards.Rarity(id)
		hudName.Text = string.upper(c.name)
		hudRarity.Text = R and R.name or ""
		if R then hudRarity.TextColor3 = R.id == "legendary" and R.glow or (R.id == "signature" and WHITE or R.light) end
	elseif not Cards.Is(id) then
		if hudCard then hudCard:Destroy() hudCard = nil end
		hudCardId = nil
	end
	if show and pop then
		hudScale.Scale = 0.6
		tween(hudScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	hudHolder.Visible = show
end
player:GetAttributeChangedSignal("MatchCard"):Connect(function() refreshHudCard(true) end)

-- ======================================================================================
-- shared picker shell (card picker + loadout picker)
-- ======================================================================================
local PW, PH = 1560, 900
local function pickerShell(name, title, sub)
	local root = new("Frame", { Name = name, Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, ZIndex = 30, Active = true }, canvas)
	local back = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 }, root)
	local panel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 540), Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = rgb(10, 11, 14), BorderSizePixel = 0, ZIndex = 31, Active = true }, root)
	new("UIStroke", { Color = K.line2, Thickness = 1.5 }, panel)
	new("Frame", { Size = UDim2.fromOffset(PW, 4), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 32 }, panel)
	new("TextLabel", { BackgroundTransparency = 1, Text = title, TextSize = 48, FontFace = F.H, TextColor3 = K.text, Position = UDim2.fromOffset(40, 22), Size = UDim2.fromOffset(900, 58),
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }, panel)
	new("TextLabel", { BackgroundTransparency = 1, Text = sub, TextSize = 13, FontFace = F.M, TextColor3 = K.dim,
		Position = UDim2.fromOffset(42, 80), Size = UDim2.fromOffset(1100, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }, panel)
	local close = UI.CloseButton(panel, "CLOSE", { Position = UDim2.fromOffset(PW - 152 - 30, 28), ZIndex = 40 })
	return root, panel, back, close
end

-- ======================================================================================
-- the card picker
-- ======================================================================================
local picker, pPanel, pBack, closeBtn = pickerShell("Picker", "CHOOSE A CARD TO TEST", "EVERY CARD YOU OWN  //  IT IS EQUIPPED FOR THE TRAINING ZONE (HUD BOTTOM RIGHT)  //  YOUR MATCH DECK IS NOT CHANGED")
local noneBtn = new("TextButton", { Text = "NO CARD", AutoButtonColor = false, Position = UDim2.fromOffset(PW - 152 - 30 - 170, 28), Size = UDim2.fromOffset(150, 42), BackgroundColor3 = K.panel2, BorderSizePixel = 0,
	TextSize = 19, FontFace = F.H, TextColor3 = K.text, ZIndex = 40 }, pPanel)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, noneBtn)
new("UIStroke", { Color = K.line2, Thickness = 1.5 }, noneBtn)
local scroll = new("ScrollingFrame", { Position = UDim2.fromOffset(30, 118), Size = UDim2.fromOffset(PW - 60, PH - 140), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
	ScrollBarImageColor3 = K.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 32 }, pPanel)
new("UIGridLayout", { CellSize = UDim2.fromOffset(220, 360), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 16) }, scroll)

local cells = {} -- card id -> { frame, mark, tag }
local function currentCard() return player:GetAttribute("TrainingCard") end
local function paintCells()
	local cur = currentCard()
	for id, c in cells do
		local on = id == cur
		c.stroke.Color = on and K.redHi or K.line
		c.stroke.Thickness = on and 4 or 1
		c.mark.Visible = on
	end
	local card = cur and Cards.ById[cur]
	cardNow.Text = card and ("CARD EQUIPPED:  " .. string.upper(card.name)) or "NO CARD EQUIPPED"
	cardNow.TextColor3 = card and K.redHi or K.dim
end

local built = false
local function buildCells()
	if built then return end
	built = true
	local raw = player:GetAttribute("CardsJson")
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	local owned = ok and type(t) == "table" and Cards.Owned(t) or {}
	local ids = {}
	for id, n in owned do if Cards.Is(id) and (tonumber(n) or 0) > 0 then table.insert(ids, id) end end
	table.sort(ids, function(a, b) return Cards.Sort(a, b) end)
	for i, id in ids do
		local c = Cards.ById[id]
		local cell = new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 33 }, scroll)
		local slot = new("Frame", { Position = UDim2.fromOffset(15, 6), Size = UDim2.fromOffset(190, 266), BackgroundTransparency = 1, ZIndex = 34 }, cell)
		local hit = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Position = UDim2.fromOffset(15, 6), Size = UDim2.fromOffset(190, 266), ZIndex = 38 }, cell)
		local frame = new("Frame", { Position = UDim2.fromOffset(9, 0), Size = UDim2.fromOffset(202, 278), BackgroundTransparency = 1, ZIndex = 33 }, cell)
		new("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
		local stroke = new("UIStroke", { Color = K.line, Thickness = 1 }, frame)
		local mark = new("TextLabel", { BackgroundColor3 = K.red, Text = "EQUIPPED", TextSize = 15, FontFace = F.H, TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(110, 24), Visible = false, ZIndex = 40, BorderSizePixel = 0 }, cell)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, mark)
		new("TextLabel", { BackgroundTransparency = 1, Text = (c.works and "" or "NO EFFECT YET  //  ") .. "OWNED x" .. tostring(owned[id]), TextSize = 13, FontFace = F.MB, TextColor3 = c.works and K.green or K.mute,
			Position = UDim2.fromOffset(0, 286), Size = UDim2.fromOffset(220, 18), ZIndex = 34 }, cell)
		cells[id] = { frame = frame, stroke = stroke, mark = mark }
		hit.MouseButton1Click:Connect(function()
			if PickR then PickR:FireServer(currentCard() == id and "" or id) end
		end)
		task.spawn(function() -- (CardArt.Build can yield; a few cards per frame, no hitch)
			task.wait(math.floor((i - 1) / 6) * 0.03)
			if slot.Parent then pcall(CardArt.Build, slot, id, { width = 190, anim = false }) end
		end)
	end
	paintCells()
end

-- ======================================================================================
-- v5.18: the loadout picker (CHANGE LOADOUT) - the same loadout as the lobby's, saved through LobbyRemotes.SetLoadout (the server cleans it with LoadoutRules)
-- ======================================================================================
local loadPicker, lPanel, lBack, lClose = pickerShell("LoadoutPicker", "CHANGE YOUR LOADOUT",
	"CLICK A SLOT, THEN WHAT GOES IN IT  //  SAVED TO YOUR REAL LOADOUT  //  A GADGET IS IN A GADGET SLOT OR THE RESERVE, A GUN IS THE PRIMARY OR IN THE RESERVE")
local SLOTS = {
	{ kind = "move", idx = 1, label = "MOVE" },
	{ kind = "weapon", idx = 1, label = "PRIMARY" },
	{ kind = "gadget", idx = 1, label = "GADGET 1" }, { kind = "gadget", idx = 2, label = "GADGET 2" }, { kind = "gadget", idx = 3, label = "GADGET 3" },
	{ kind = "reserve", idx = 1, label = "RESERVE 1" }, { kind = "reserve", idx = 2, label = "RESERVE 2" }, { kind = "reserve", idx = 3, label = "RESERVE 3" },
}
local lo = { Weapon = Catalog.DefaultWeapon, Move = "", Gadgets = { "", "", "" }, Reserve = { "", "", "" } }
local function readLoadout()
	local raw = player:GetAttribute("LoadoutJson")
	local ok, t = pcall(function() return HttpService:JSONDecode(raw or "") end)
	if not ok or type(t) ~= "table" then return end
	lo.Weapon = type(t.Weapon) == "string" and t.Weapon or lo.Weapon
	lo.Move = type(t.Move) == "string" and t.Move or ""
	for i = 1, 3 do
		lo.Gadgets[i] = type(t.Gadgets) == "table" and type(t.Gadgets[i]) == "string" and t.Gadgets[i] or ""
		lo.Reserve[i] = type(t.Reserve) == "table" and type(t.Reserve[i]) == "string" and t.Reserve[i] or ""
	end
end
local function itemAt(kind, idx)
	if kind == "weapon" then return lo.Weapon end
	if kind == "move" then return lo.Move end
	return ((kind == "gadget") and lo.Gadgets or lo.Reserve)[idx] or ""
end
-- the same rules as LobbyClient.setSlot (the server re-checks with LoadoutRules.Clean)
local function setSlot(kind, idx, id)
	if kind == "weapon" then
		if id == "" then return end
		lo.Weapon = id
		for j = 1, 3 do if lo.Reserve[j] == id then lo.Reserve[j] = "" end end
	elseif kind == "move" then
		lo.Move = id
	else
		if kind == "reserve" and id ~= "" and id == lo.Weapon then return end
		local arr = (kind == "gadget") and lo.Gadgets or lo.Reserve
		if id ~= "" then
			for j = 1, 3 do if j ~= idx and arr[j] == id then arr[j] = arr[idx] break end end
		end
		arr[idx] = id
		if id ~= "" then
			local other = (kind == "gadget") and lo.Reserve or lo.Gadgets
			for j = 1, 3 do if other[j] == id then other[j] = "" end end
		end
	end
	if SetLoadoutR then
		SetLoadoutR:FireServer({ Weapon = lo.Weapon, Move = lo.Move, Gadgets = table.clone(lo.Gadgets), Reserve = table.clone(lo.Reserve) })
	end
end

local function gunPicture(parent, weaponId)
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = rgb(150, 152, 158),
		LightColor = rgb(255, 252, 246), LightDirection = Vector3.new(-0.5, -1, -0.3), ZIndex = parent.ZIndex + 1 }, parent)
	if not GunModels then return vp end
	local ok, desc = pcall(GunModels.Describe, weaponId, "Iron")
	if not ok or not desc then return vp end
	local model = new("Model", {}, vp)
	for _, d in desc.Parts do
		if not d.Reticle and d.Group ~= "aux" and (d.Transparency or 0) < 1 then
			local p = new("Part", { Anchored = true, Size = d.Size, CFrame = d.CF, Color = (d.Glow and K.red) or d.Color,
				Material = d.Material or Enum.Material.SmoothPlastic, Transparency = d.Transparency or 0 }, model)
			if d.Shape then p.Shape = d.Shape end
		end
	end
	local cam = new("Camera", { FieldOfView = 16 }, vp)
	pcall(UI.FitViewport, vp, cam, model, Vector3.new(1, 0.08, 0), { pad = 0.1, fov = 16 })
	return vp
end
local function itemPicture(parent, item)
	if not item then return end
	if item.kind == "weapon" then gunPicture(parent, item.id) return end
	if item.kind == "gadget" and GM then
		local ok, vp = pcall(GM.Picture, parent, item.id)
		if ok and vp then vp.ZIndex = parent.ZIndex + 1 end
		return
	end
	if item.kind == "move" and item.icon then
		local ok, ic = pcall(UI.AbilityIcon, parent, item.icon, 84, item.color)
		if ok and ic then ic.AnchorPoint, ic.Position, ic.ZIndex = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), parent.ZIndex + 1 end
	end
end

local TILE, TILE_GAP = 160, 14
local tiles = {} -- i -> { btn, stroke, pic, name }
local selected = 2 -- PRIMARY open by default
local tileRow = new("Frame", { Position = UDim2.fromOffset(0, 118), Size = UDim2.fromOffset(PW, TILE + 40), BackgroundTransparency = 1, ZIndex = 32 }, lPanel)
do
	local total = #SLOTS * TILE + (#SLOTS - 1) * TILE_GAP + 2 * 26 -- (+ two wider gaps: after MOVE / PRIMARY and before the reserve)
	local x = (PW - total) / 2
	for i, sl in SLOTS do
		if i == 3 or i == 6 then x += 26 end
		local b = new("TextButton", { Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(TILE, TILE), BackgroundColor3 = K.panel, BorderSizePixel = 0, ZIndex = 33 }, tileRow)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
		local st = new("UIStroke", { Color = K.line, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local pic = new("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(TILE - 20, TILE - 44), BackgroundTransparency = 1, ZIndex = 34 }, b)
		local nm = new("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = 15, FontFace = F.H, TextColor3 = K.text, Position = UDim2.fromOffset(6, TILE - 32), Size = UDim2.fromOffset(TILE - 12, 26),
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 35 }, b)
		new("TextLabel", { BackgroundTransparency = 1, Text = sl.label, TextSize = 12, FontFace = F.MB, TextColor3 = K.dim, Position = UDim2.fromOffset(x, TILE + 6), Size = UDim2.fromOffset(TILE, 16), ZIndex = 33 }, tileRow)
		tiles[i] = { btn = b, stroke = st, pic = pic, name = nm, shown = nil }
		x += TILE + TILE_GAP
	end
end
local gridScroll = new("ScrollingFrame", { Position = UDim2.fromOffset(30, 118 + TILE + 52), Size = UDim2.fromOffset(PW - 60, PH - (118 + TILE + 52) - 24), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 6, ScrollBarImageColor3 = K.line2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 32 }, lPanel)
new("UIGridLayout", { CellSize = UDim2.fromOffset(250, 190), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, gridScroll)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 16) }, gridScroll)
new("Frame", { Position = UDim2.fromOffset(40, 118 + TILE + 36), Size = UDim2.fromOffset(PW - 80, 1), BackgroundColor3 = K.line, BorderSizePixel = 0, ZIndex = 32 }, lPanel)

local buildGrid -- forward
local function paintTiles()
	for i, sl in SLOTS do
		local t = tiles[i]
		local id = itemAt(sl.kind, sl.idx)
		local on = i == selected
		t.stroke.Color = on and K.redHi or K.line
		t.stroke.Thickness = on and 3 or 1.5
		t.btn.BackgroundColor3 = on and rgb(30, 14, 17) or K.panel
		if t.shown ~= id then
			t.shown = id
			for _, c in t.pic:GetChildren() do c:Destroy() end
			local item = Catalog.ById[id]
			itemPicture(t.pic, item)
			t.name.Text = item and string.upper(item.name) or "EMPTY"
			t.name.TextColor3 = item and K.text or K.mute
		end
	end
end
for i, t in tiles do
	t.btn.MouseButton1Click:Connect(function()
		selected = i
		paintTiles()
		buildGrid()
	end)
end
local function ownedItems(kind)
	local out = {}
	local function add(list) for _, it in list do if Catalog.Owns(player, it.id) then table.insert(out, it) end end end
	if kind == "weapon" then add(Catalog.Weapons)
	elseif kind == "move" then add(Catalog.Moves)
	elseif kind == "gadget" then add(Catalog.Gadgets)
	else
		add(Catalog.Gadgets)
		add(Catalog.Weapons)
		for i = #out, 1, -1 do if out[i].id == lo.Weapon then table.remove(out, i) end end -- the primary gun can not also go in the reserve
	end
	return out
end
function buildGrid()
	for _, c in gridScroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local sl = SLOTS[selected]
	local current = itemAt(sl.kind, sl.idx)
	local function card(item, order)
		local eq = (item and item.id == current) or (not item and current == "")
		local b = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = K.panel, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 33 }, gridScroll)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
		local st = new("UIStroke", { Color = eq and K.red or K.line, Thickness = eq and 2.5 or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		local pic = new("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(226, 116), BackgroundTransparency = 1, ZIndex = 34 }, b)
		if item then itemPicture(pic, item) end
		new("TextLabel", { BackgroundTransparency = 1, Text = item and string.upper(item.name) or "NONE", TextSize = 20, FontFace = F.H, TextColor3 = item and K.text or K.dim,
			Position = UDim2.fromOffset(14, 130), Size = UDim2.fromOffset(222, 28), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 35 }, b)
		new("TextLabel", { BackgroundTransparency = 1, Text = item and string.upper(item.sub or "") or "LEAVE THIS SLOT EMPTY", TextSize = 11, FontFace = F.M, TextColor3 = K.dim,
			Position = UDim2.fromOffset(15, 160), Size = UDim2.fromOffset(222, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 35 }, b)
		if eq then
			local tag = new("TextLabel", { BackgroundColor3 = K.red, Text = "EQUIPPED", TextSize = 11, FontFace = F.MB, TextColor3 = WHITE, Size = UDim2.fromOffset(86, 20), BorderSizePixel = 0, ZIndex = 36 }, b)
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, tag)
		end
		b.MouseEnter:Connect(function() if not eq then st.Color = K.line2 end b.BackgroundColor3 = K.panel2 end)
		b.MouseLeave:Connect(function() if not eq then st.Color = K.line end b.BackgroundColor3 = K.panel end)
		b.MouseButton1Click:Connect(function()
			setSlot(sl.kind, sl.idx, item and item.id or "")
			paintTiles()
			buildGrid()
		end)
	end
	if sl.kind ~= "weapon" then card(nil, 0) end
	for i, item in ownedItems(sl.kind) do card(item, i) end
end
player:GetAttributeChangedSignal("LoadoutJson"):Connect(function()
	readLoadout()
	if loadPicker.Visible then paintTiles() end
end)

-- ======================================================================================
-- cursor: HOLD LEFT ALT (or a picker is open) = a free cursor, guns / gadgets ignore clicks meanwhile
-- ======================================================================================
local altDown, pickerOpen, loadOpen = false, false, false
local function inTraining() return player:GetAttribute("InTraining") == true end
local function cursorMode()
	local want = inTraining() and (altDown or pickerOpen or loadOpen)
	modal.Visible = want
	if want then
		player:SetAttribute("TrainingMenu", true)
		player:SetAttribute("GunMenuOpen", true)
	else
		if player:GetAttribute("TrainingMenu") then
			player:SetAttribute("TrainingMenu", nil)
			if player:GetAttribute("SettingsOpen") ~= true and player:GetAttribute("PoseWheelOpen") ~= true then player:SetAttribute("GunMenuOpen", nil) end
		end
	end
end
local function setPicker(on)
	pickerOpen = on
	if on then
		loadOpen = false
		loadPicker.Visible = false
		buildCells()
		paintCells()
	end
	picker.Visible = on
	cursorMode()
end
local function setLoadout(on)
	loadOpen = on
	if on then
		pickerOpen = false
		picker.Visible = false
		readLoadout()
		paintTiles()
		buildGrid()
	end
	loadPicker.Visible = on
	cursorMode()
end
UIS.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftAlt then
		altDown = true
		cursorMode()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if pickerOpen then setPicker(false) end
		if loadOpen then setLoadout(false) end
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftAlt then
		altDown = false
		cursorMode()
	end
end)
cardBtn.MouseButton1Click:Connect(function() setPicker(not pickerOpen) end)
closeBtn.MouseButton1Click:Connect(function() setPicker(false) end)
pBack.MouseButton1Click:Connect(function() setPicker(false) end)
noneBtn.MouseButton1Click:Connect(function() if PickR then PickR:FireServer("") end end)
loadBtn.MouseButton1Click:Connect(function() setLoadout(not loadOpen) end)
lClose.MouseButton1Click:Connect(function() setLoadout(false) end)
lBack.MouseButton1Click:Connect(function() setLoadout(false) end)
leaveBtn.MouseButton1Click:Connect(function()
	setPicker(false)
	setLoadout(false)
	if LeaveR then LeaveR:FireServer() end
end)

-- ======================================================================================
-- enter / leave
-- ======================================================================================
local function myChar() return player.Character end
local function hideLobbyGuis()
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	for _, n in LOBBY_GUIS do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			hidden[g] = true
		end
	end
end
-- v5.18: stop the gun script the safe way: flag it (GunClient cleans up on the attribute Stop), give it a frame, then destroy it; then sweep the camera for any
-- viewmodel that is still there (a gun viewmodel carries an ObjectValue "Owner", the gadget hand is "GadgetVM")
local function stopGun()
	local ch = myChar()
	local list = {}
	if gunClone then table.insert(list, gunClone) end
	if ch then
		for _, c in ch:GetChildren() do
			if c.Name == "GunClient" and c:IsA("LocalScript") and not table.find(list, c) then table.insert(list, c) end
		end
	end
	gunClone = nil
	for _, sc in list do pcall(function() sc:SetAttribute("Stop", true) end) end
	if #list > 0 then RunService.RenderStepped:Wait() end
	for _, sc in list do pcall(function() sc:Destroy() end) end
	for _, c in camera:GetChildren() do
		if c:IsA("Model") and (c.Name == "Viewmodel" or c.Name == "GadgetVM" or c:FindFirstChild("Owner")) then c:Destroy() end
	end
end
local function startGun()
	local ch = myChar()
	if not ch or not templates then return end
	stopGun()
	if not inTraining() then return end
	local tpl = templates:FindFirstChild("GunClient")
	if not tpl then warn("[TrainingClient] ReplicatedStorage > TrainingClients > GunClient is missing") return end
	gunClone = tpl:Clone()
	gunClone.Name = "GunClient"
	gunClone.Enabled = true
	gunClone.Parent = ch
end
local function enter()
	player:SetAttribute("CardIndexOpen", nil)
	hideLobbyGuis()
	gui.Enabled = true
	readLoadout()
	paintCells()
	refreshHudCard(false)
	task.spawn(startGun)
end
-- v5.18: back to the normal lobby camera: third person, free mouse, zoomed OUT (Classic with a ~0.5 stud zoom is still first person + a locked mouse)
local function restoreCamera()
	player.CameraMode = Enum.CameraMode.Classic
	UIS.MouseIconEnabled = true
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
	local ch = myChar()
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
		hum.AutoRotate = true
	end
	local push = math.clamp(THIRD_PERSON_ZOOM, DEFAULT_MIN_ZOOM, math.max(DEFAULT_MAX_ZOOM, THIRD_PERSON_ZOOM))
	player.CameraMaxZoomDistance = math.max(DEFAULT_MAX_ZOOM, push)
	player.CameraMinZoomDistance = push -- forces the camera out to the push distance ...
	task.delay(0.25, function()
		if inTraining() then return end
		player.CameraMinZoomDistance = DEFAULT_MIN_ZOOM -- ... then lets you zoom freely again
		player.CameraMaxZoomDistance = DEFAULT_MAX_ZOOM
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end)
end
local function leave()
	setPicker(false)
	setLoadout(false)
	altDown = false
	cursorMode()
	stopGun()
	local ch = myChar()
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, n in { "GunHUD", "GadgetFX" } do
			local g = pg:FindFirstChild(n)
			if g then g:Destroy() end
		end
	end
	gui.Enabled = false
	refreshHudCard(false)
	local s = Settings and Settings.Get(player).Sens
	UIS.MouseDeltaSensitivity = type(s) == "number" and s or 1
	restoreCamera()
	if ch then
		for _, d in ch:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
		end
	end
	for g in hidden do if g.Parent then g.Enabled = true end end
	table.clear(hidden)
	player:SetAttribute("GunMenuOpen", nil)
	-- one more pass a moment later: the gun script's very last frame (or a stray render step) may have touched the camera / mouse / body again
	task.delay(0.1, function()
		if inTraining() then return end
		for _, c in camera:GetChildren() do
			if c:IsA("Model") and (c.Name == "Viewmodel" or c.Name == "GadgetVM" or c:FindFirstChild("Owner")) then c:Destroy() end
		end
		if player.CameraMode ~= Enum.CameraMode.Classic then player.CameraMode = Enum.CameraMode.Classic end
		UIS.MouseIconEnabled = true
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		local c2 = myChar()
		if c2 then
			for _, d in c2:GetDescendants() do
				if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
			end
		end
	end)
end
player:GetAttributeChangedSignal("InTraining"):Connect(function()
	if inTraining() then enter() else leave() end
end)
-- v5.18: a newly picked card = a fresh gun life (full magazine, DEEP POCKETS loads its extra magazine) - the server does the same (GunServer)
player:GetAttributeChangedSignal("TrainingCard"):Connect(function()
	paintCells()
	if inTraining() then
		task.delay(0.1, function() if inTraining() then startGun() end end)
	end
end)
player.CharacterAdded:Connect(function()
	gunClone = nil
	if inTraining() then
		task.wait(0.5)
		if inTraining() then startGun() end
	end
end)
-- the lobby UI can switch itself back on (menus, loading): keep it hidden while you are in the zone
RunService.Heartbeat:Connect(function()
	if not inTraining() then return end
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return end
	for _, n in LOBBY_GUIS do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			hidden[g] = true
		end
	end
end)
if inTraining() then enter() end
