-- LobbyNameplates v1 (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only. NEW in GDD v3.8.
-- A small nameplate above every player's head in the lobby (yours too): [LV 12] NAME. The level comes from the Player attribute
-- "Level" (ProfileStore derives it from the saved XP). Roblox's own overhead name is switched off (locally) so there is only one.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UI = require(RS:WaitForChild("UIKit"))
local K, F = UI.C, UI.F

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
	bb.Size = UDim2.fromOffset(300, 34)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Parent = char

	local row = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bb)
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
	bb.AncestryChanged:Connect(function(_, parent) if not parent then c:Disconnect() end end)
end

local function onPlayer(plr)
	plr.CharacterAdded:Connect(function(char) task.spawn(build, plr, char) end)
	if plr.Character then task.spawn(build, plr, plr.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do onPlayer(p) end
