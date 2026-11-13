-- ShopServer v1.1 (Script in ServerScriptService) - LOBBY place only. NEW in v4.7. v5.19: +3,000 souls with the starter pick (STARTER_SOULS).
-- 1) BUYING. The shop (ShopClient) sells every gun / gadget / movement ability in LobbyCatalog.Price for SOULS. The client only asks
--    ("Buy", id); everything is checked here: real item, has a price, not owned yet, enough souls, starter pick done. Souls are taken and the
--    item is added to the saved collection (profile key "Owned", mirrored as the attribute OwnedJson). Saved right away.
-- 2) STARTER PICK. A new player (profile StarterDone = false) picks 1 weapon (M4A1 / V9 / AK-47) and 1 movement ability (Double Jump / Wall Climb /
--    Dash). They get those two + Frag Grenade + Flashbang + Sentry (not selectable, LobbyCatalog.Starter.Gadgets), and the loadout is filled with them.
-- 3) SHOP NPC. Put a Model in the workspace and either NAME it "ShopNPC" or give it the CollectionService tag "ShopNPC". This script adds a
--    ProximityPrompt ("Open Shop") to it (on its HumanoidRootPart / PrimaryPart / first part) and opens the shop for whoever uses it.
--    The prompt is created here, so you only place the model. (To use your own prompt instead, add a ProximityPrompt named "ShopPrompt" to
--    the model: this script will use it as it is.) Models added later while the game runs are picked up too.
-- Remotes (created here, folder ReplicatedStorage.ShopRemotes): Buy (RemoteFunction: id -> ok, message), Starter (RemoteFunction: weapon, move -> ok, message),
--    Open (RemoteEvent, server -> client: open the shop).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")

local Catalog = require(RS:WaitForChild("LobbyCatalog"))
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))
local Rules = require(script.Parent:WaitForChild("LoadoutRules"))
-- v5.19 (owner): a NEW player gets 3,000 souls to start with, the moment they make the starter pick (weapon + movement)
local STARTER_SOULS = 3000

local folder = RS:FindFirstChild("ShopRemotes") or Instance.new("Folder")
folder.Name = "ShopRemotes"
folder.Parent = RS
local function remote(class, name)
	local r = folder:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = folder
	return r
end
local BuyR, StarterR, OpenR = remote("RemoteFunction", "Buy"), remote("RemoteFunction", "Starter"), remote("RemoteEvent", "Open")

local lastBuy = {}

local function loaded(player) return Profiles.Get(player, "Loadout") ~= nil end

BuyR.OnServerInvoke = function(player, id)
	if os.clock() - (lastBuy[player] or 0) < 0.4 then return false, "Slow down." end
	lastBuy[player] = os.clock()
	if type(id) ~= "string" then return false, "Unknown item." end
	local item, price = Catalog.ById[id], Catalog.Price[id]
	if not item or type(price) ~= "number" then return false, "That item is not for sale." end
	if not loaded(player) then return false, "Your data is still loading." end
	if Profiles.Get(player, "StarterDone") ~= true then return false, "Pick your starting gear first." end
	if Rules.Owns(player, id) then return false, "You already own this." end
	local souls = Profiles.Get(player, "Souls")
	if type(souls) ~= "number" or souls < price then return false, "Not enough souls." end
	Profiles.Increment(player, "Souls", -price)
	Rules.Give(player, { id })
	task.spawn(Profiles.Save, player) -- written right away, so a crash or a teleport can never lose a purchase
	return true, "Bought " .. item.name .. "."
end

StarterR.OnServerInvoke = function(player, weapon, move)
	if not loaded(player) then return false, "Your data is still loading." end
	if Profiles.Get(player, "StarterDone") == true then return false, "You already picked." end
	local S = Catalog.Starter
	if type(weapon) ~= "string" or type(move) ~= "string" or not table.find(S.Weapons, weapon) or not table.find(S.Moves, move) then
		return false, "Pick one weapon and one movement ability."
	end
	local ids = { weapon, move }
	for _, g in S.Gadgets do table.insert(ids, g) end
	Rules.Give(player, ids)
	Profiles.Set(player, "StarterDone", true)
	local l = { Weapon = weapon, Move = move, Gadgets = table.clone(S.Gadgets), Reserve = { "", "", "" } }
	Profiles.Set(player, "Loadout", l)
	Profiles.Set(player, "Weapon", weapon)
	Rules.Publish(player, l)
	Profiles.Increment(player, "Souls", STARTER_SOULS) -- v5.19: starting souls (only here, so it can never be given twice: StarterDone is set above)
	task.spawn(Profiles.Save, player)
	return true, "Welcome to Breakline. +3,000 souls to start."
end

Players.PlayerRemoving:Connect(function(p) lastBuy[p] = nil end)

-- ===== shop NPC =====
local lastOpen = {}
local function openFor(player)
	if os.clock() - (lastOpen[player] or 0) < 0.5 then return end
	lastOpen[player] = os.clock()
	OpenR:FireClient(player)
end

local function anchorPart(model)
	if model:IsA("BasePart") then return model end
	if model:IsA("Model") then
		return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local done = setmetatable({}, { __mode = "k" })
local function setupNpc(model)
	if done[model] then return end
	local part = anchorPart(model)
	if not part then return end
	done[model] = true
	local prompt = model:FindFirstChild("ShopPrompt", true)
	if not (prompt and prompt:IsA("ProximityPrompt")) then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.ActionText = "Open Shop"
		prompt.ObjectText = "Shop"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = part
	end
	prompt.Triggered:Connect(openFor)
end

local function consider(inst)
	if inst:IsA("Model") and (inst.Name == "ShopNPC" or CS:HasTag(inst, "ShopNPC")) then task.defer(setupNpc, inst) end
end
for _, d in workspace:GetDescendants() do consider(d) end
workspace.DescendantAdded:Connect(consider)
CS:GetInstanceAddedSignal("ShopNPC"):Connect(function(inst) task.defer(setupNpc, inst) end)
for _, inst in CS:GetTagged("ShopNPC") do task.defer(setupNpc, inst) end
