-- TrainingClient v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in v5.17 (GDD 5.13 TRAINING ZONE).
-- What YOU see while you stand inside the part "TrainingZone" (TrainingServer sets the Player attribute InTraining):
--   * the lobby UI is hidden (LobbyUI, shop, cosmetics, card index) and the in-round UI takes over (MatchHUD, always running, shows itself while InTraining),
--   * GunClient (the very same file as Breakline's, stored in ReplicatedStorage > TrainingClients) is cloned into your character = first person, your equipped gun / gadgets /
--     movement ability exactly like in a match; it is destroyed again when you leave (and the camera, mouse, body and HUD are put back),
--   * two buttons at the top of the screen: LEAVE THE TRAINING ZONE (teleports you to the Workspace part "EntranceTrainingZone") and CHOOSE YOUR CARD (opens a card picker with
--     EVERY card you own, not just the 32 in your deck; the card you click is tested in the zone only - it does not touch your deck or a real match).
--   * the mouse is locked in first person, so HOLD LEFT ALT to get the cursor for the buttons (the picker frees it by itself).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local UI = require(RS:WaitForChild("UIKit"))
local Cards = require(RS:WaitForChild("Cards"))
local CardArt = require(RS:WaitForChild("CardArt"))
local Settings = RS:FindFirstChild("Settings") and require(RS.Settings) or nil
local K, F, new = UI.C, UI.F, UI.new
local rgb = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local function tween(o, t, goal) TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), goal):Play() end

local remotes = RS:WaitForChild("TrainingRemotes", 30)
local LeaveR = remotes and remotes:WaitForChild("Leave", 10)
local PickR = remotes and remotes:WaitForChild("PickCard", 10)
local templates = RS:WaitForChild("TrainingClients", 30)

local LOBBY_GUIS = { "LobbyUI", "ShopGui", "CosmeticsGui", "CardIndex" } -- hidden while you are in the zone
local hidden = {} -- gui -> true (the ones WE switched off)
local gunClone

-- ======================================================================================
-- the two buttons + the card picker
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

local function bigButton(y, w, h, text, red)
	local b = new("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(960, y), Size = UDim2.fromOffset(w, h),
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
local leaveBtn = bigButton(18, 560, 58, "", true)
new("TextLabel", { BackgroundTransparency = 1, Text = "LEAVE THE TRAINING ZONE", TextSize = 30, FontFace = F.H, TextColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, leaveBtn)
local cardBtn = bigButton(86, 560, 52, "", false)
new("TextLabel", { BackgroundTransparency = 1, Text = "CHOOSE YOUR CARD", TextSize = 26, FontFace = F.H, TextColor3 = K.text, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(0, 300, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6 }, cardBtn)
local cardNow = new("TextLabel", { BackgroundTransparency = 1, Text = "NO CARD", TextSize = 16, FontFace = F.MB, TextColor3 = K.dim, Position = UDim2.new(0, 300, 0, 0), Size = UDim2.new(1, -320, 1, 0),
	TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6 }, cardBtn)
local hint = new("TextLabel", { BackgroundTransparency = 1, Text = "HOLD  LEFT ALT  FOR THE CURSOR", TextSize = 14, FontFace = F.MB, TextColor3 = K.text, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(960, 146), Size = UDim2.fromOffset(560, 20), ZIndex = 5 }, canvas)
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.3 }, hint)

-- picker
local picker = new("Frame", { Name = "Picker", Size = UDim2.fromOffset(1920, 1080), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, ZIndex = 30, Active = true }, canvas)
local pBack = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30 }, picker)
local PW, PH = 1560, 900
local pPanel = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(960, 540), Size = UDim2.fromOffset(PW, PH), BackgroundColor3 = rgb(10, 11, 14), BorderSizePixel = 0, ZIndex = 31, Active = true }, picker)
new("UIStroke", { Color = K.line2, Thickness = 1.5 }, pPanel)
new("Frame", { Size = UDim2.fromOffset(PW, 4), BackgroundColor3 = K.red, BorderSizePixel = 0, ZIndex = 32 }, pPanel)
new("TextLabel", { BackgroundTransparency = 1, Text = "CHOOSE A CARD TO TEST", TextSize = 48, FontFace = F.H, TextColor3 = K.text, Position = UDim2.fromOffset(40, 22), Size = UDim2.fromOffset(900, 58),
	TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }, pPanel)
new("TextLabel", { BackgroundTransparency = 1, Text = "EVERY CARD YOU OWN  //  ONLY FOR THE TRAINING ZONE  //  YOUR MATCH DECK IS NOT CHANGED", TextSize = 13, FontFace = F.M, TextColor3 = K.dim,
	Position = UDim2.fromOffset(42, 80), Size = UDim2.fromOffset(1000, 20), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 32 }, pPanel)
local closeBtn = UI.CloseButton(pPanel, "CLOSE", { Position = UDim2.fromOffset(PW - 152 - 30, 28), ZIndex = 40 })
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
	cardNow.Text = card and ("TESTING:  " .. string.upper(card.name)) or "NO CARD"
	cardNow.TextColor3 = card and K.redHi or K.dim
end

local built = false
local function buildCells()
	if built then return end
	built = true
	local raw = player:GetAttribute("CardsJson")
	local ok, t = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
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
		local mark = new("TextLabel", { BackgroundColor3 = K.red, Text = "TESTING", TextSize = 15, FontFace = F.H, TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(100, 24), Visible = false, ZIndex = 40, BorderSizePixel = 0 }, cell)
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
player:GetAttributeChangedSignal("TrainingCard"):Connect(paintCells)

-- ======================================================================================
-- cursor: HOLD LEFT ALT (or the picker is open) = a free cursor, guns / gadgets ignore clicks meanwhile
-- ======================================================================================
local altDown, pickerOpen = false, false
local function inTraining() return player:GetAttribute("InTraining") == true end
local function cursorMode()
	local want = inTraining() and (altDown or pickerOpen)
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
	if on then buildCells() paintCells() end
	picker.Visible = on
	cursorMode()
end
UIS.InputBegan:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.LeftAlt then
		altDown = true
		cursorMode()
	elseif input.KeyCode == Enum.KeyCode.Escape and pickerOpen then
		setPicker(false)
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
leaveBtn.MouseButton1Click:Connect(function()
	setPicker(false)
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
local function startGun()
	local ch = myChar()
	if not ch or not templates then return end
	local old = ch:FindFirstChild("GunClient")
	if old then old:Destroy() end
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
	task.spawn(startGun)
end
local function leave()
	setPicker(false)
	altDown = false
	cursorMode()
	if gunClone then gunClone:Destroy() gunClone = nil end
	local ch = myChar()
	local old = ch and ch:FindFirstChild("GunClient")
	if old then old:Destroy() end
	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		for _, n in { "GunHUD", "GadgetFX" } do
			local g = pg:FindFirstChild(n)
			if g then g:Destroy() end
		end
	end
	for _, c in camera:GetChildren() do if c.Name == "GadgetVM" then c:Destroy() end end
	gui.Enabled = false
	player.CameraMode = Enum.CameraMode.Classic
	UIS.MouseIconEnabled = true
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	local s = Settings and Settings.Get(player).Sens
	UIS.MouseDeltaSensitivity = type(s) == "number" and s or 1
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
		hum.AutoRotate = true
	end
	if ch then
		for _, d in ch:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end
		end
	end
	for g in hidden do if g.Parent then g.Enabled = true end end
	table.clear(hidden)
	player:SetAttribute("GunMenuOpen", nil)
end
player:GetAttributeChangedSignal("InTraining"):Connect(function()
	if inTraining() then enter() else leave() end
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
