-- CardShop v1 (ModuleScript in ReplicatedStorage) - LOBBY place only. NEW in v5.14 (GDD 5.9).
-- Everything the CARDS tab of the shop sells, in one place. The server (CardShopServer) and the shop screen (CardShopUI) both read it,
-- so the odds the player sees are exactly the odds the server rolls.
--   CardShop.Packs / CardShop.PackById[id]   every card pack: { id, name, tag, desc, price, onSale, look = {...}, entries = { 12 x { id, rarity, weight } } }
--   CardShop.Odds(packId)                    { { id, rarity, weight, chance (0..1) }, ... } in pack order (chance = weight / total weight)
--   CardShop.RollPack(packId, rng)           index, entry   (rng = a Random; the server uses its own)
--   CardShop.Day(t) / CardShop.DayEnds(day)  the daily shop day number (UTC, changes at 00:00 UTC) and when that day ends (unix seconds)
--   CardShop.DailyPool()                     every distinct { id, rarity } in the packs that are ON SALE (the daily shop only ever shows these)
--   CardShop.DailyOffer(day)                 the 3 daily cards for that day: { { key, id, rarity, price }, x3 } - the same on every server
--   CardShop.DailyPrice[rarity] / DailyWeight[rarity]
-- PRICES ARE SOULS. Nothing in the card shop costs Essence.
-- PLACEHOLDERS: until the real pack cards exist, every pack slot is the PLACEHOLDER card shown in that slot's rarity. To put a real card in a
-- slot, replace id = "placeholder" with the card id from Cards.List and remove the rarity (a real card always uses its own rarity).
local Cards = require(script.Parent:WaitForChild("Cards"))

local M = {}
M.DAY_SECONDS = 86400
M.DAILY_SLOTS = 3

-- the daily shop: how likely each rarity is to be picked for a slot (bigger = more often) and what one copy costs in souls
M.DailyWeight = { common = 40, uncommon = 26, rare = 16, epic = 9, legendary = 5, mythic = 2.5, divine = 1, signature = 0.5 }
M.DailyPrice  = { common = 150, uncommon = 300, rare = 600, epic = 1000, legendary = 1800, mythic = 3000, divine = 4500, signature = 6000 }

local rgb = Color3.fromRGB
local function slot(rarity, weight, id) return { id = id or "placeholder", rarity = rarity, weight = weight } end

-- 12 cards per pack. Weights are percentages here (each pack adds up to 100) but any numbers work: chance = weight / total.
M.Packs = {
	{
		id = "first_steps", name = "FIRST STEPS", tag = "BEGINNER PACK", price = 300, onSale = true,
		desc = "Made for new players. Mostly common and uncommon cards, with a small chance at a rare or an epic.",
		look = { top = rgb(96, 196, 150), bottom = rgb(20, 74, 64), accent = rgb(214, 255, 226), ink = rgb(10, 36, 30), emblem = "steps" },
		entries = {
			slot("common", 12), slot("common", 12), slot("common", 12), slot("common", 12), slot("common", 12),
			slot("uncommon", 6.5), slot("uncommon", 6.5), slot("uncommon", 6.5), slot("uncommon", 6.5),
			slot("rare", 5), slot("rare", 5),
			slot("epic", 4),
		},
	},
	{
		id = "soul_pack", name = "SOUL PACK", tag = "STANDARD PACK", price = 750, onSale = true,
		desc = "The standard pack. Every rarity is inside, from common all the way up to signature.",
		look = { top = rgb(112, 208, 255), bottom = rgb(18, 40, 96), accent = rgb(220, 246, 255), ink = rgb(8, 18, 44), emblem = "soul" },
		entries = {
			slot("common", 14), slot("common", 14), slot("common", 14),
			slot("uncommon", 11), slot("uncommon", 11),
			slot("rare", 8), slot("rare", 8),
			slot("epic", 9),
			slot("legendary", 6),
			slot("mythic", 3),
			slot("divine", 1.5),
			slot("signature", 0.5),
		},
	},
	{
		id = "level_up", name = "LEVEL UP", tag = "ADVANCED PACK", price = 1500, onSale = true,
		desc = "For players who want the big cards. No commons or uncommons: rare and up, with the best odds for legendary and above.",
		look = { top = rgb(255, 204, 84), bottom = rgb(120, 40, 10), accent = rgb(255, 240, 190), ink = rgb(48, 18, 4), emblem = "levelup" },
		entries = {
			slot("rare", 14), slot("rare", 14),
			slot("epic", 10), slot("epic", 10), slot("epic", 10),
			slot("legendary", 7), slot("legendary", 7), slot("legendary", 7),
			slot("mythic", 6), slot("mythic", 6),
			slot("divine", 6),
			slot("signature", 3),
		},
	},
}
M.PackById = {}
for i, p in M.Packs do
	p.order = i
	M.PackById[p.id] = p
	for _, e in p.entries do
		local c = Cards.ById[e.id]
		if not c then warn("[CardShop] pack", p.id, "has an unknown card id", e.id) end
		if c and not c.placeholder then e.rarity = c.rarity end -- a real card always uses its own rarity
		e.rarity = e.rarity or (c and c.rarity) or "common"
	end
end

-- the rarity a card shows / is priced at in the shop (the placeholder takes the slot's rarity)
function M.RarityOf(entry)
	local c = Cards.ById[entry.id]
	if c and not c.placeholder then return c.rarity end
	return entry.rarity or (c and c.rarity) or "common"
end

function M.Odds(packId)
	local p = M.PackById[packId]
	if not p then return {} end
	local total = 0
	for _, e in p.entries do total += math.max(0, e.weight or 0) end
	local out = {}
	for i, e in p.entries do
		out[i] = { index = i, id = e.id, rarity = M.RarityOf(e), weight = e.weight, chance = total > 0 and math.max(0, e.weight or 0) / total or 0 }
	end
	return out
end

function M.RollPack(packId, rng)
	local p = M.PackById[packId]
	if not p then return nil end
	rng = rng or Random.new()
	local total = 0
	for _, e in p.entries do total += math.max(0, e.weight or 0) end
	local x = rng:NextNumber() * total
	for i, e in p.entries do
		x -= math.max(0, e.weight or 0)
		if x <= 0 then return i, e end
	end
	return #p.entries, p.entries[#p.entries]
end

function M.Day(t) return math.floor((t or os.time()) / M.DAY_SECONDS) end
function M.DayEnds(day) return (day + 1) * M.DAY_SECONDS end

function M.DailyPool()
	local seen, out = {}, {}
	for _, p in M.Packs do
		if p.onSale then
			for _, e in p.entries do
				local r = M.RarityOf(e)
				local key = e.id .. "@" .. r
				if not seen[key] and Cards.ById[e.id] then
					seen[key] = true
					table.insert(out, { key = key, id = e.id, rarity = r })
				end
			end
		end
	end
	return out
end

-- 3 different cards (if the pool has 3), picked by rarity weight, seeded by the day number so every lobby server shows the same shop
function M.DailyOffer(day)
	local pool = M.DailyPool()
	local rng = Random.new(day * 7919 + 1013)
	local out, used = {}, {}
	for s = 1, M.DAILY_SLOTS do
		local total = 0
		for i, e in pool do
			if not used[i] or #pool < M.DAILY_SLOTS then total += M.DailyWeight[e.rarity] or 1 end
		end
		if total <= 0 then break end
		local x = rng:NextNumber() * total
		local pick, last = nil, nil
		for i, e in pool do
			if not used[i] or #pool < M.DAILY_SLOTS then
				last = i
				x -= M.DailyWeight[e.rarity] or 1
				if x <= 0 then pick = i break end
			end
		end
		pick = pick or last
		used[pick] = true
		local e = pool[pick]
		out[s] = { slot = s, key = e.key, id = e.id, rarity = e.rarity, price = M.DailyPrice[e.rarity] or 500 }
	end
	return out
end

return M
