-- LobbyNameplates v2.3 (v5.17: the TITLE above the name is much LARGER (32 px) and LONGER (a long thin tier-coloured line each side of the text, wider plate), easier to read from far away; the name row did not move)
-- LobbyNameplates v2.2 (v5.16: the equipped TITLE (Titles module, Player attribute Title) shows as a small coloured line right above the name)
-- LobbyNameplates v2.1 (v5.12: the crown sits close above the head (CROWN_Y 4.5 -> 1.45) and the nameplate moves up over it while a crown shows;
--   the xN streak text is sized in STUDS now, so it always stays outside the crown at its upper right (in pixels it slid into the crown from far away)) (v2 v5.10: WIN-STREAK CROWN - a gold crown floats (bobbing + turning) well above the nameplate of everyone who is on a winning streak, with the streak
--   (x2, x5 ...) in small text at its upper right, angled. The streak = Player attribute "Streak" (ProfileStore: +1 per win in any mode, back to 0 on a loss), so the crown
--   disappears the moment the streak is lost. Tier 1 / 2 / 3 (1-2 / 3-4 / 5+ wins) changes the gem colour; tier 3 sparkles.) (v1 LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in GDD v3.8.
-- A small nameplate above every player's head in the lobby (yours too): [LV 12] NAME. The level comes from the Player attribute
-- "Level" (ProfileStore derives it from the saved XP). Roblox's own overhead name is switched off (locally) so there is only one.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UI = require(RS:WaitForChild("UIKit"))
local K, F = UI.C, UI.F
local Crown = require(RS:WaitForChild("Crown"))
local Titles = RS:FindFirstChild("Titles") and require(RS.Titles) or nil -- v5.16: the TITLE line above the name

-- ===== v5.10: win-streak crown =====
local CROWN_Y = 1.45 -- v5.12: studs above the head's centre = just over the head / helmet (was 4.5, floating far above the nameplate)
local PLATE_Y, PLATE_Y_CROWN = 2.5, 2.95 -- nameplate height without / with a crown (it moves up so it never covers the crown)
local active = {} -- { weld, t0 }
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i = #active, 1, -1 do
		local a = active[i]
		if not a.weld.Parent then
			table.remove(active, i)
		else
			local k = t - a.t0
			a.weld.C0 = CFrame.new(0, CROWN_Y + math.sin(k * 2.2) * 0.12, 0) * CFrame.Angles(0, k * 0.9, 0)
		end
	end
end)

local function updateCrown(plr, char, head)
	if not char.Parent or not head.Parent then return end
	local streak = math.floor(tonumber(plr:GetAttribute("Streak")) or 0)
	local old = char:FindFirstChild("StreakCrown")
	local plate = char:FindFirstChild("Nameplate")
	if plate then plate.StudsOffsetWorldSpace = Vector3.new(0, streak >= 1 and PLATE_Y_CROWN or PLATE_Y, 0) end
	if streak < 1 then
		if old then old:Destroy() end
		return
	end
	local tier = Crown.TierFor(streak)
	if old and old:GetAttribute("Tier") == tier then
		local l = old:FindFirstChild("StreakLabel", true)
		if l then l.Text = streak >= 2 and ("x" .. streak) or "" end
		return
	end
	if old then old:Destroy() end
	local m = Crown.Build(char, { tier = tier, anchored = false, scale = 1.15 })
	m.Name = "StreakCrown"
	m:SetAttribute("Tier", tier)
	local w = Instance.new("Weld")
	w.Part0, w.Part1 = head, m.PrimaryPart
	w.C0 = CFrame.new(0, CROWN_Y, 0)
	w.Parent = m.PrimaryPart
	table.insert(active, { weld = w, t0 = os.clock() })
	-- the streak number: small, gold, at the crown's upper right on screen and tilted (a billboard offset is in camera space)
	local bb = Instance.new("BillboardGui")
	bb.Name = "StreakBillboard"
	bb.Adornee = m.PrimaryPart
	-- v5.12: sized in studs (scale), so it keeps its place next to the crown at every distance. Left edge = 0.85 studs right of the centre
	-- (the crown is ~0.7 wide each side), a little above the band = upper right of the crown, outside it
	bb.Size = UDim2.fromScale(1.6, 0.75)
	bb.StudsOffset = Vector3.new(1.65, 0.62, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = m.PrimaryPart
	local l = UI.new("TextLabel", { Name = "StreakLabel", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Rotation = -14, Text = streak >= 2 and ("x" .. streak) or "",
		TextScaled = true, FontFace = F.H, TextColor3 = Color3.fromRGB(255, 214, 96), TextXAlignment = Enum.TextXAlignment.Left }, bb)
	UI.new("UIStroke", { Color = Color3.fromRGB(70, 40, 6), Thickness = 2, Transparency = 0.15 }, l)
end

local function build(plr, char)
	local hum = char:WaitForChild("Humanoid", 10)
	local head = char:WaitForChild("Head", 10)
	if not hum or not head or not char.Parent then return end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local old = char:FindFirstChild("Nameplate")
	if old then old:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = "Nameplate"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(560, 130) -- v5.17: wider + taller (the name row stays exactly in the middle, the big TITLE sits above it)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = char

	local row = UI.new("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 }, bb)
	-- v5.16 TITLE (the one the player equipped in the cosmetics locker), small and coloured by its tier, right above the name
	local titleBox = UI.new("Frame", { Name = "TitleBox", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 42), Visible = false }, bb)
	local titleL = UI.new("TextLabel", { Name = "Title", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextSize = 32, FontFace = F.H, TextColor3 = K.text }, titleBox)
	UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2.5, Transparency = 0.15 }, titleL)
	-- v5.17: a long thin line each side of the title, in the title's colour, fading outward (makes the title read as a banner and longer)
	local lineL = UI.new("Frame", { Name = "LineL", AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = K.text, BorderSizePixel = 0, Size = UDim2.fromOffset(110, 3) }, titleBox)
	UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, lineL)
	local lineR = UI.new("Frame", { Name = "LineR", AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = K.text, BorderSizePixel = 0, Size = UDim2.fromOffset(110, 3) }, titleBox)
	UI.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, lineR)
	local function placeLines()
		local half = titleL.AbsoluteSize.X / 2
		lineL.Position = UDim2.new(0.5, -half - 12, 0.5, 0)
		lineR.Position = UDim2.new(0.5, half + 12, 0.5, 0)
	end
	titleL:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeLines)
	local function updTitle()
		local t = Titles and Titles.ById[plr:GetAttribute("Title")] or nil
		titleBox.Visible = t ~= nil
		if t then
			titleL.Text, titleL.TextColor3 = t.text, t.color
			lineL.BackgroundColor3, lineR.BackgroundColor3 = t.color, t.color
			placeLines()
		end
	end
	updTitle()
	local c3 = plr:GetAttributeChangedSignal("Title"):Connect(updTitle)
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, row)

	local chip = UI.new("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), BackgroundColor3 = K.void,
		BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = 1 }, row)
	UI.new("UIStroke", { Color = K.red, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, chip)
	local lv = UI.new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), Text = "LV 1",
		TextSize = 15, FontFace = F.MB, TextColor3 = K.text }, chip)

	local name = UI.new("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28),
		Text = string.upper(plr.DisplayName), TextSize = 24, FontFace = F.HM, TextColor3 = K.text, LayoutOrder = 2 }, row)
	UI.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Transparency = 0.4 }, name)

	local function upd() lv.Text = "LV " .. tostring(plr:GetAttribute("Level") or 1) end
	upd()
	local c = plr:GetAttributeChangedSignal("Level"):Connect(upd)
	local c2 = plr:GetAttributeChangedSignal("Streak"):Connect(function() updateCrown(plr, char, head) end)
	bb.AncestryChanged:Connect(function(_, parent) if not parent then c:Disconnect() c2:Disconnect() c3:Disconnect() end end)
	updateCrown(plr, char, head)
	-- the profile can load a moment after the character: look again until the streak is known
	task.spawn(function()
		local t0 = os.clock()
		while char.Parent and plr:GetAttribute("ProfileLoaded") ~= true and os.clock() - t0 < 12 do task.wait(0.25) end
		updateCrown(plr, char, head)
	end)
end

local function onPlayer(plr)
	plr.CharacterAdded:Connect(function(char) task.spawn(build, plr, char) end)
	if plr.Character then task.spawn(build, plr, plr.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
