-- MatchClient v1: Wall Push HUD + box controls.
--  * top bar: phase / countdown, box counts per team, wall progress bar (finish line to finish line)
--  * carrying a box: LEFT CLICK (or the Throw button on mobile) = throw, Q = drop. Guns are locked by GunClient/GunServer.
--  * hides pick-up prompts you can't use (your own plugged boxes, anything while you carry)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = require(RS:WaitForChild("MatchConfig"))
local State = RS:WaitForChild("MatchState")
local Remotes = RS:WaitForChild("MatchRemotes")
local ThrowRemote, DropRemote, NotifyRemote = Remotes:WaitForChild("Throw"), Remotes:WaitForChild("Drop"), Remotes:WaitForChild("Notify")

local ACCENT = Color3.fromRGB(255, 140, 30)
local COL_A, COL_B = C.Teams[1].Color.Color, C.Teams[2].Color.Color
local NAME_A, NAME_B = C.Teams[1].Name, C.Teams[2].Name

-- ================= GUI =================
local gui = Instance.new("ScreenGui")
gui.Name = "MatchHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, size, pos, text, ts, color)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size, l.Position = size, pos
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextSize = ts
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	local st = Instance.new("UIStroke")
	st.Thickness = 2; st.Transparency = 0.3
	st.Parent = l
	l.Parent = parent
	return l
end

local top = Instance.new("Frame")
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 10)
top.Size = UDim2.fromOffset(460, 76)
top.BackgroundTransparency = 1
top.Parent = gui

local scoreA = label(top, UDim2.fromOffset(110, 36), UDim2.fromOffset(60, 20), "0", 30, COL_A)
local scoreB = label(top, UDim2.fromOffset(110, 36), UDim2.fromOffset(400, 20), "0", 30, COL_B)
local timerLabel = label(top, UDim2.fromOffset(200, 36), UDim2.fromOffset(230, 20), "", 22)
local nameA = label(top, UDim2.fromOffset(110, 16), UDim2.fromOffset(60, 44), NAME_A:upper() .. " BOXES", 11, COL_A)
local nameB = label(top, UDim2.fromOffset(110, 16), UDim2.fromOffset(400, 44), NAME_B:upper() .. " BOXES", 11, COL_B)

-- wall progress: bar spans finish line (team A end, left) to finish line (team B end, right); the marker is the wall
local bar = Instance.new("Frame")
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.fromOffset(230, 58)
bar.Size = UDim2.fromOffset(440, 10)
bar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
bar.BackgroundTransparency = 0.2
bar.BorderSizePixel = 0
bar.Parent = top
local halfA = Instance.new("Frame")
halfA.Size = UDim2.fromScale(0.5, 1)
halfA.BackgroundColor3 = COL_A
halfA.BackgroundTransparency = 0.45
halfA.BorderSizePixel = 0
halfA.Parent = bar
local halfB = halfA:Clone()
halfB.Position = UDim2.fromScale(0.5, 0)
halfB.BackgroundColor3 = COL_B
halfB.Parent = bar
local marker = Instance.new("Frame")
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Size = UDim2.new(0, 6, 1, 10)
marker.Position = UDim2.fromScale(0.5, 0.5)
marker.BackgroundColor3 = Color3.new(1, 1, 1)
marker.BorderSizePixel = 0
marker.Parent = bar

local banner = label(gui, UDim2.fromOffset(700, 60), UDim2.new(0.5, 0, 0.22, 0), "", 40)
banner.TextTransparency = 1
local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
bannerStroke.Transparency = 1
local bannerToken = 0
local function showBanner(text, color, hold)
	bannerToken += 1
	local t = bannerToken
	banner.Text = text
	banner.TextColor3 = color
	banner.TextTransparency, bannerStroke.Transparency = 0, 0.3
	task.delay(hold or 1.8, function()
		if bannerToken ~= t then return end
		TweenService:Create(banner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		TweenService:Create(bannerStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	end)
end

local hint = label(gui, UDim2.fromOffset(600, 30), UDim2.new(0.5, 0, 0.78, 0), "", 18)
hint.Visible = false

-- ================= HUD update =================
local lastPhase
local function teamColor()
	return player.Team and player.Team.TeamColor.Color or ACCENT
end

local function refresh()
	local phase = State:GetAttribute("Phase")
	local ends = State:GetAttribute("PhaseEnds") or 0
	scoreA.Text = tostring(State:GetAttribute("BoxesA") or 0)
	scoreB.Text = tostring(State:GetAttribute("BoxesB") or 0)
	marker.Position = UDim2.fromScale(0.5 + 0.5 * (State:GetAttribute("WallFrac") or 0), 0.5)

	if phase == "Waiting" then
		timerLabel.Text = "WAITING FOR PLAYERS"
	elseif phase == "Intermission" then
		timerLabel.Text = ("STARTING IN %d"):format(math.max(0, math.ceil(ends - workspace:GetServerTimeNow())))
	elseif phase == "Playing" then
		local t = player.Team and player.Team.Name
		timerLabel.Text = t and t:upper() or "SPECTATING"
		timerLabel.TextColor3 = t and teamColor() or Color3.new(1, 1, 1)
	elseif phase == "Result" then
		local w = State:GetAttribute("Winner")
		timerLabel.Text = (w and w ~= "") and (w:upper() .. " WINS") or "ROUND OVER"
		timerLabel.TextColor3 = (w == NAME_A and COL_A) or (w == NAME_B and COL_B) or Color3.new(1, 1, 1)
	end
	if phase ~= "Playing" and phase ~= "Result" then timerLabel.TextColor3 = Color3.new(1, 1, 1) end

	if phase ~= lastPhase then
		lastPhase = phase
		if phase == "Playing" then
			local t = player.Team
			showBanner(t and ("YOU ARE " .. t.Name:upper()) or "ROUND STARTED", t and t.TeamColor.Color or ACCENT, 2.5)
		end
	end
end

-- ================= box controls =================
local carrying = false
local function throw()
	if not carrying then return end
	ThrowRemote:FireServer(camera.CFrame.LookVector)
end
local function drop()
	if carrying then DropRemote:FireServer() end
end

local THROW_ACTION = "WPThrow"
local function setCarrying(on)
	if on == carrying then return end
	carrying = on
	hint.Visible = on
	hint.Text = "LEFT CLICK  throw      Q  drop      walk into a hole on your side to plug it"
	if on then
		-- sink the click so Roblox/other scripts do not also use it
		CAS:BindActionAtPriority(THROW_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then throw() end
			return Enum.ContextActionResult.Sink
		end, true, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
		CAS:SetTitle(THROW_ACTION, "Throw")
		CAS:SetPosition(THROW_ACTION, UDim2.new(1, -95, 1, -245))
	else
		CAS:UnbindAction(THROW_ACTION)
	end
end
player:GetAttributeChangedSignal("Carrying"):Connect(function() setCarrying(player:GetAttribute("Carrying") == true) end)
setCarrying(player:GetAttribute("Carrying") == true)

UIS.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonL1 then drop() end
end)

NotifyRemote.OnClientEvent:Connect(function(text, color)
	showBanner(text, color or Color3.new(1, 1, 1), 1.6)
end)

-- ================= prompt filtering + box outlines =================
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	refresh()
	acc += dt
	if acc < 0.15 then return end
	acc = 0
	local myTeam = player.Team and player.Team.Name
	for _, pr in CollectionService:GetTagged("WPPrompt") do
		local box = pr.Parent
		if box then
			local st = box:GetAttribute("State")
			local usable
			if carrying or not myTeam then
				usable = false
			elseif st == "Plugged" then
				usable = box:GetAttribute("PlugTeam") ~= myTeam -- extract ENEMY boxes only
			else
				usable = st == "Loose"
			end
			if pr.Enabled ~= usable then pr.Enabled = usable end
		end
	end
end)
