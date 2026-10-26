-- LobbyClient (LocalScript in StarterPlayer > StarterPlayerScripts) - LOBBY place only.
-- Builds the lobby UI in code: PLAY / CANCEL button, party panel (invite by name, leave, kick), invite popup, coins.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = RS:WaitForChild("LobbyRemotes")
local QueueR, InviteR, RespondR, LeaveR, KickR, NoticeR =
	remotes:WaitForChild("Queue"), remotes:WaitForChild("Invite"), remotes:WaitForChild("Respond"),
	remotes:WaitForChild("Leave"), remotes:WaitForChild("Kick"), remotes:WaitForChild("Notice")

local RED, BLUE, DARK, PANEL = Color3.fromRGB(235, 70, 70), Color3.fromRGB(70, 140, 255), Color3.fromRGB(20, 22, 30), Color3.fromRGB(32, 36, 48)

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 8) c.Parent = o end
local function label(parent, text, size, pos, sz, color, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text, l.TextSize = text, size
	l.Font = bold and Enum.Font.GothamBlack or Enum.Font.GothamMedium
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Position, l.Size = pos, sz
	l.Parent = parent
	return l
end
local function button(parent, text, pos, sz, color)
	local b = Instance.new("TextButton")
	b.Text, b.TextSize = text, 18
	b.Font = Enum.Font.GothamBlack
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Position, b.Size = pos, sz
	b.Parent = parent
	corner(b)
	return b
end

-- title + coins
label(gui, "BREAKLINE", 54, UDim2.new(0.5, -200, 0, 30), UDim2.fromOffset(400, 60), Color3.new(1, 1, 1), true)
local coins = label(gui, "", 22, UDim2.new(1, -230, 0, 16), UDim2.fromOffset(210, 30), Color3.fromRGB(255, 214, 80), true)
coins.TextXAlignment = Enum.TextXAlignment.Right
local function updCoins()
	coins.Text = ("COINS %d   W %d  L %d"):format(player:GetAttribute("Coins") or 0, player:GetAttribute("Wins") or 0, player:GetAttribute("Losses") or 0)
end
for _, k in { "Coins", "Wins", "Losses" } do player:GetAttributeChangedSignal(k):Connect(updCoins) end
updCoins()

-- play button
local play = button(gui, "PLAY  3v3", UDim2.new(0.5, -130, 1, -130), UDim2.fromOffset(260, 70), RED)
play.TextSize = 30
local status = label(gui, "", 18, UDim2.new(0.5, -200, 1, -52), UDim2.fromOffset(400, 26), Color3.fromRGB(210, 215, 230), false)

-- party panel
local panel = Instance.new("Frame")
panel.BackgroundColor3, panel.BackgroundTransparency = PANEL, 0.1
panel.Position, panel.Size = UDim2.fromOffset(20, 90), UDim2.fromOffset(260, 330)
panel.Parent = gui
corner(panel, 12)
label(panel, "PARTY", 22, UDim2.fromOffset(14, 8), UDim2.fromOffset(200, 28), Color3.new(1, 1, 1), true).TextXAlignment = Enum.TextXAlignment.Left
local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Position, list.Size = UDim2.fromOffset(10, 42), UDim2.fromOffset(240, 150)
list.Parent = panel
local lay = Instance.new("UIListLayout") lay.Padding = UDim.new(0, 4) lay.Parent = list

local box = Instance.new("TextBox")
box.PlaceholderText, box.Text, box.TextSize = "Roblox username", "", 16
box.Font = Enum.Font.GothamMedium
box.TextColor3, box.BackgroundColor3 = Color3.new(1, 1, 1), DARK
box.ClearTextOnFocus = false
box.Position, box.Size = UDim2.fromOffset(10, 204), UDim2.fromOffset(240, 34)
box.Parent = panel
corner(box, 6)
local inviteBtn = button(panel, "INVITE", UDim2.fromOffset(10, 246), UDim2.fromOffset(115, 34), BLUE)
local leaveBtn = button(panel, "LEAVE", UDim2.fromOffset(135, 246), UDim2.fromOffset(115, 34), Color3.fromRGB(90, 94, 110))
local note = label(panel, "", 14, UDim2.fromOffset(10, 288), UDim2.fromOffset(240, 36), Color3.fromRGB(255, 220, 140), false)
note.TextWrapped = true

local function members()
	local raw = player:GetAttribute("PartyMembers")
	if type(raw) ~= "string" then return {} end
	local ok, t = pcall(function() return HttpService:JSONDecode(raw) end)
	return ok and t or {}
end

local function renderParty()
	for _, c in list:GetChildren() do if c:IsA("Frame") then c:Destroy() end end
	local m, leader = members(), player:GetAttribute("PartyLeader")
	if #m == 0 then m = { { id = player.UserId, name = player.Name } } leader = player.UserId end
	for _, mem in m do
		local row = Instance.new("Frame")
		row.BackgroundColor3, row.Size = DARK, UDim2.new(1, 0, 0, 34)
		row.Parent = list
		corner(row, 6)
		local n = label(row, (mem.id == leader and "* " or "") .. mem.name, 16, UDim2.fromOffset(10, 0), UDim2.new(1, -50, 1, 0), Color3.new(1, 1, 1), false)
		n.TextXAlignment = Enum.TextXAlignment.Left
		if leader == player.UserId and mem.id ~= player.UserId then
			local k = button(row, "X", UDim2.new(1, -34, 0, 4), UDim2.fromOffset(28, 26), Color3.fromRGB(160, 60, 60))
			k.TextSize = 14
			k.MouseButton1Click:Connect(function() KickR:FireServer(mem.id) end)
		end
	end
	local isLeader = (leader == player.UserId)
	box.Visible, inviteBtn.Visible = isLeader, isLeader
	leaveBtn.Visible = #members() > 0
end
for _, k in { "PartyId", "PartyLeader", "PartyMembers" } do player:GetAttributeChangedSignal(k):Connect(renderParty) end
renderParty()

local function say(text)
	note.Text = text
	task.delay(4, function() if note.Text == text then note.Text = "" end end)
end

inviteBtn.MouseButton1Click:Connect(function()
	if #box.Text >= 3 then InviteR:FireServer(box.Text) box.Text = "" end
end)
leaveBtn.MouseButton1Click:Connect(function() LeaveR:FireServer() end)

-- queue button
local function refreshQueue()
	local q = player:GetAttribute("Queued")
	play.Text = q and "CANCEL" or "PLAY  3v3"
	play.BackgroundColor3 = q and Color3.fromRGB(90, 94, 110) or RED
	local tp = player:GetAttribute("Teleporting")
	status.Text = tp and "Joining match..." or (q and "Searching for players..." or "")
end
for _, k in { "Queued", "Teleporting" } do player:GetAttributeChangedSignal(k):Connect(refreshQueue) end
play.MouseButton1Click:Connect(function()
	if player:GetAttribute("Teleporting") then return end
	QueueR:FireServer(not player:GetAttribute("Queued"))
end)
task.spawn(function() -- search timer
	while true do
		task.wait(1)
		local q = player:GetAttribute("QueuedAt")
		if player:GetAttribute("Queued") and q and not player:GetAttribute("Teleporting") then
			status.Text = ("Searching for players...  %ds"):format(math.max(0, os.time() - q))
		end
	end
end)
refreshQueue()

-- invite popup
local pop = Instance.new("Frame")
pop.BackgroundColor3 = PANEL
pop.AnchorPoint, pop.Position, pop.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, -120), UDim2.fromOffset(340, 100)
pop.Parent = gui
corner(pop, 12)
local popText = label(pop, "", 18, UDim2.fromOffset(10, 8), UDim2.fromOffset(320, 40), Color3.new(1, 1, 1), true)
popText.TextWrapped = true
local yes = button(pop, "ACCEPT", UDim2.fromOffset(20, 56), UDim2.fromOffset(145, 34), Color3.fromRGB(60, 170, 90))
local no = button(pop, "DECLINE", UDim2.fromOffset(175, 56), UDim2.fromOffset(145, 34), Color3.fromRGB(160, 60, 60))
local current
local function showPop(on)
	TweenService:Create(pop, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, on and 20 or -120) }):Play()
end
yes.MouseButton1Click:Connect(function() if current then RespondR:FireServer(current, true) current = nil showPop(false) end end)
no.MouseButton1Click:Connect(function() if current then RespondR:FireServer(current, false) current = nil showPop(false) end end)

NoticeR.OnClientEvent:Connect(function(d)
	if type(d) ~= "table" then return end
	if d.kind == "msg" then say(tostring(d.text))
	elseif d.kind == "invite" then
		current = d.id
		popText.Text = tostring(d.fromName) .. " invited you to a party"
		showPop(true)
		task.delay(30, function() if current == d.id then current = nil showPop(false) end end)
	end
end)
