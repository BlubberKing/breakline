-- CardShopServer v1 (Script in ServerScriptService) - LOBBY place only. NEW in v5.14 (GDD 5.9).
-- The CARDS tab of the shop: card packs + the daily card shop. Everything costs SOULS (never Essence). The client only asks; every
-- purchase is checked and rolled here, the result is saved at once (Profiles.Save), and the new collection is published as CardsJson
-- (+ DeckJson) exactly like LobbyServer does.
--   Remotes (folder ReplicatedStorage.CardShopRemotes, made here):
--     GetState  (RemoteFunction)          -> { day, endsAt, now, daily = { { slot, key, id, rarity, price, bought }, x3 } }
--     BuyDaily  (RemoteFunction: slot)    -> ok, message, cardId, rarity      (one copy, each daily slot can be bought once per day)
--     BuyPack   (RemoteFunction: packId)  -> ok, message, { index, id, rarity } (one card per pack, rolled with CardShop.RollPack)
--   Saved data: profile key "Cards" = EXTRA copies { [cardId] = n } added on top of Cards.STARTER (see Cards.Collection);
--               profile key "CardShopDaily" = { day = <day number>, bought = { slot numbers bought that day } }.
-- The daily shop changes at 00:00 UTC (CardShop.Day) and is the same on every lobby server (seeded by the day number).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Cards = require(RS:WaitForChild("Cards"))
local CardShop = require(RS:WaitForChild("CardShop"))
local Profiles = require(script.Parent:WaitForChild("ProfileStore"))

local folder = RS:FindFirstChild("CardShopRemotes") or Instance.new("Folder")
folder.Name = "CardShopRemotes"
folder.Parent = RS
local function remote(class, name)
	local r = folder:FindFirstChild(name) or Instance.new(class)
	r.Name = name
	r.Parent = folder
	return r
end
local GetStateR, BuyDailyR, BuyPackR = remote("RemoteFunction", "GetState"), remote("RemoteFunction", "BuyDaily"), remote("RemoteFunction", "BuyPack")

local busy, lastAsk = {}, {}
local rng = Random.new()

local function loaded(p) return Profiles.Get(p, "Loadout") ~= nil end

-- same as LobbyServer.publishCards: the full collection + a valid deck for the client
local function publishCards(p)
	local col = Cards.Collection(Profiles.Get(p, "Cards"))
	local deck = Cards.Clean(Profiles.Get(p, "Deck"), col) or Cards.DefaultDeck(col)
	p:SetAttribute("CardsJson", HttpService:JSONEncode(col))
	p:SetAttribute("DeckJson", HttpService:JSONEncode(deck))
end

local function grant(p, id)
	local extra = Profiles.Get(p, "Cards")
	extra = type(extra) == "table" and table.clone(extra) or {}
	extra[id] = math.floor(tonumber(extra[id]) or 0) + 1
	Profiles.Set(p, "Cards", extra)
	publishCards(p)
end

local function dailyRecord(p, day)
	local r = Profiles.Get(p, "CardShopDaily")
	if type(r) ~= "table" or r.day ~= day or type(r.bought) ~= "table" then r = { day = day, bought = {} } end
	return r
end

local function state(p)
	local now = os.time()
	local day = CardShop.Day(now)
	local rec = dailyRecord(p, day)
	local daily = {}
	for i, o in CardShop.DailyOffer(day) do
		daily[i] = { slot = o.slot, key = o.key, id = o.id, rarity = o.rarity, price = o.price, bought = table.find(rec.bought, o.slot) ~= nil }
	end
	return { day = day, endsAt = CardShop.DayEnds(day), now = now, daily = daily }
end

local function gate(p)
	if os.clock() - (lastAsk[p] or 0) < 0.35 then return "Slow down." end
	lastAsk[p] = os.clock()
	if busy[p] then return "Still working on your last purchase." end
	if not loaded(p) then return "Your data is still loading." end
	return nil
end

local function pay(p, price)
	local souls = Profiles.Get(p, "Souls")
	if type(souls) ~= "number" or souls < price then return false end
	Profiles.Increment(p, "Souls", -price)
	return true
end

GetStateR.OnServerInvoke = function(p)
	if not loaded(p) then Profiles.WaitFor(p) end
	return state(p)
end

BuyDailyR.OnServerInvoke = function(p, slotNum)
	local why = gate(p)
	if why then return false, why end
	slotNum = tonumber(slotNum)
	if not slotNum or slotNum % 1 ~= 0 or slotNum < 1 or slotNum > CardShop.DAILY_SLOTS then return false, "Unknown card." end
	busy[p] = true
	local ok, a, b, c, d = pcall(function()
		local day = CardShop.Day()
		local offer = CardShop.DailyOffer(day)[slotNum]
		if not offer then return false, "That card is not in today's shop." end
		local rec = dailyRecord(p, day)
		if table.find(rec.bought, slotNum) then return false, "You already bought this card today." end
		if not pay(p, offer.price) then return false, "Not enough souls." end
		rec = { day = day, bought = table.clone(rec.bought) }
		table.insert(rec.bought, slotNum)
		Profiles.Set(p, "CardShopDaily", rec)
		grant(p, offer.id)
		task.spawn(Profiles.Save, p) -- written right away, so a crash or a teleport can never lose a purchase
		local card = Cards.ById[offer.id]
		return true, "Bought " .. (card and card.name or offer.id) .. ".", offer.id, offer.rarity
	end)
	busy[p] = nil
	if not ok then warn("[CardShopServer] daily buy failed:", a) return false, "Something went wrong. Try again in a moment." end
	return a, b, c, d
end

BuyPackR.OnServerInvoke = function(p, packId)
	local why = gate(p)
	if why then return false, why end
	local pack = type(packId) == "string" and CardShop.PackById[packId]
	if not pack or not pack.onSale or type(pack.price) ~= "number" then return false, "That pack is not for sale." end
	busy[p] = true
	local ok, a, b, c = pcall(function()
		if not pay(p, pack.price) then return false, "Not enough souls." end
		local index, entry = CardShop.RollPack(pack.id, rng)
		grant(p, entry.id)
		task.spawn(Profiles.Save, p)
		return true, "Opened " .. pack.name .. ".", { index = index, id = entry.id, rarity = CardShop.RarityOf(entry) }
	end)
	busy[p] = nil
	if not ok then warn("[CardShopServer] pack buy failed:", a) return false, "Something went wrong. Try again in a moment." end
	return a, b, c
end

Players.PlayerRemoving:Connect(function(p) busy[p] = nil lastAsk[p] = nil end)
