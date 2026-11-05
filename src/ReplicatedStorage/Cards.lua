-- Cards (ModuleScript in ReplicatedStorage) - BOTH games (Lobby + Breakline). Keep the two copies identical (Lobby is the master).
-- v4.3: the power-up card system (GDD section 4). Data + deck rules only; CardArt draws the cards.
--   Cards.List / Cards.ById[id]          every card: { id, name, desc, rarity, art }
--   Cards.Rarities / Cards.RarityById    the 8 rarities, lowest first (v4.9: + EPIC, purple)
--   Cards.Is(id)                         true for a real card id
--   Cards.Collection(saved)              owned copies { [id] = n } (starter collection merged with the saved profile key "Cards")
--   Cards.Validate(deck, collection)     ok, reason   (exactly DECK_SIZE cards, max MAX_COPIES of a card, only copies you own)
--   Cards.Clean(deck, collection)        a copy of the deck if it is valid, otherwise nil
--   Cards.DefaultDeck(collection)        a valid 32-card deck (one of every card)
--   Cards.Counts(deck)                   { [id] = copies }
--   Cards.Sort(a, b)                     sort ids: highest rarity first, then name
-- PLACEHOLDER CARDS: names, art and text are placeholders. None of the abilities do anything yet.
local M = {}

M.DECK_SIZE = 32   -- a deck holds exactly this many cards, no more, no less
M.MAX_COPIES = 4   -- most copies of one card in a deck
M.DRAW = 3         -- cards rolled at the start of a match
M.PICK_TIME = 10   -- seconds to pick (MatchConfig.CARD_PICK is what the server uses)

local rgb = Color3.fromRGB
-- body = card background top, deep = background bottom, light = highlights / text on dark, label = rarity text colour
M.Rarities = {
	{ id = "common",    name = "COMMON",    rank = 1, body = rgb(128, 131, 136), deep = rgb(66, 68, 73),   light = rgb(206, 209, 214), label = rgb(232, 234, 238), glow = rgb(190, 194, 200) },
	{ id = "uncommon",  name = "UNCOMMON",  rank = 2, body = rgb(64, 160, 86),   deep = rgb(20, 74, 38),   light = rgb(170, 238, 170), label = rgb(214, 255, 210), glow = rgb(110, 230, 130) },
	{ id = "rare",      name = "RARE",      rank = 3, body = rgb(50, 112, 220),  deep = rgb(16, 38, 104),  light = rgb(160, 206, 255), label = rgb(214, 234, 255), glow = rgb(90, 160, 255) },
	-- v4.9: EPIC (purple) sits between Rare and Legendary
	{ id = "epic",      name = "EPIC",      rank = 4, body = rgb(140, 72, 226),  deep = rgb(44, 14, 96),   light = rgb(226, 196, 255), label = rgb(240, 226, 255), glow = rgb(178, 110, 255) },
	{ id = "legendary", name = "LEGENDARY", rank = 5, body = rgb(240, 188, 50),  deep = rgb(150, 86, 10),  light = rgb(255, 238, 160), label = rgb(66, 38, 4),     glow = rgb(255, 210, 80) },
	{ id = "mythic",    name = "MYTHIC",    rank = 6, body = rgb(212, 40, 42),   deep = rgb(84, 6, 14),    light = rgb(255, 170, 140), label = rgb(255, 222, 210), glow = rgb(255, 80, 60) },
	-- v4.9: DIVINE = watercolour rainbow (soft rose / peach / butter / mint / sky / lilac washes, not a hard full rainbow). body = the swatch colour
	{ id = "divine",    name = "DIVINE",    rank = 7, body = rgb(222, 196, 236), deep = rgb(120, 104, 168), light = rgb(255, 250, 240), label = rgb(58, 40, 86), glow = rgb(255, 200, 236),
		wash = { rgb(255, 150, 170), rgb(255, 196, 140), rgb(255, 236, 150), rgb(160, 232, 190), rgb(140, 200, 255), rgb(196, 160, 255) } },
	{ id = "signature", name = "SIGNATURE", rank = 8, body = rgb(240, 240, 238), deep = rgb(14, 14, 16),   light = rgb(255, 255, 255), label = rgb(255, 255, 255), glow = rgb(255, 255, 255) },
}
M.RarityById = {}
for _, r in M.Rarities do M.RarityById[r.id] = r end

-- art = which drawing CardArt uses (see PAINT in CardArt)
M.List = {
	-- COMMON (grey)
	{ id = "steady_hands",  rarity = "common",    art = "hand",      name = "Steady Hands",   desc = "Your recoil settles a little faster after every burst." },
	{ id = "light_feet",    rarity = "common",    art = "feather",   name = "Light Feet",     desc = "Sprint speed +4%. You land from big drops without a stumble." },
	{ id = "thick_skin",    rarity = "common",    art = "shield",    name = "Thick Skin",     desc = "+10 max health for the whole match." },
	{ id = "deep_pockets",  rarity = "common",    art = "bullets",   name = "Deep Pockets",   desc = "Spawn with one extra magazine for your primary." },
	{ id = "long_breath",   rarity = "common",    art = "wind",      name = "Long Breath",    desc = "Slides carry you 15% further before they fade out." },
	{ id = "box_hugger",    rarity = "common",    art = "crate",     name = "Box Hugger",     desc = "Pick up loose boxes a quarter of a second faster." },
	{ id = "ember_heart",   rarity = "common",    art = "heart",     name = "Ember Heart",    desc = "Health starts coming back one second sooner." },
	{ id = "scrap_plating", rarity = "common",    art = "gear",      name = "Scrap Plating",  desc = "Boxes you plug start with 5% more health." },
	{ id = "lucky_coin",    rarity = "common",    art = "coin",      name = "Lucky Coin",     desc = "Earn 5% more souls from this match. Heads, you win." },
	-- UNCOMMON (green)
	{ id = "ghost_step",    rarity = "uncommon",  art = "footprints",name = "Ghost Step",     desc = "Your footsteps are quieter while you crouch or walk." },
	{ id = "menders_thread",rarity = "uncommon",  art = "needle",    name = "Mender's Thread",desc = "Revive teammates 1.5 seconds faster." },
	{ id = "hot_barrel",    rarity = "uncommon",  art = "flame",     name = "Hot Barrel",     desc = "Fire rate +10% for 4 seconds after a kill." },
	{ id = "magnet_palms",  rarity = "uncommon",  art = "magnet",    name = "Magnet Palms",   desc = "Catch thrown boxes from twice as far away." },
	{ id = "grave_candle",  rarity = "uncommon",  art = "candle",    name = "Grave Candle",   desc = "See fallen teammates' souls through walls." },
	{ id = "scouts_eye",    rarity = "uncommon",  art = "eye",       name = "Scout's Eye",    desc = "Enemies you hit stay outlined for 2 seconds." },
	{ id = "skeleton_key",  rarity = "uncommon",  art = "key",       name = "Skeleton Key",   desc = "Pull enemy boxes out of their holes 30% faster." },
	{ id = "paper_crane",   rarity = "uncommon",  art = "crane",     name = "Paper Crane",    desc = "Thrown boxes fly further and fall slower." },
	-- RARE (blue)
	{ id = "tidebreaker",   rarity = "rare",      art = "wave",      name = "Tidebreaker",    desc = "While your team pushes, the wall moves 10% faster." },
	{ id = "moonlit_reload",rarity = "rare",      art = "moon",      name = "Moonlit Reload", desc = "Reload 20% faster while under half health." },
	{ id = "hollow_point",  rarity = "rare",      art = "target",    name = "Hollow Point",   desc = "Headshots deal 12% more damage." },
	-- EPIC (purple, v4.9)
	{ id = "stormcaller",   rarity = "epic",      art = "storm",     name = "Stormcaller",    desc = "Your frag grenade arcs lightning to one nearby enemy." },
	{ id = "lantern_keeper",rarity = "epic",      art = "lantern",   name = "Lantern Keeper", desc = "Carrying a soul no longer slows you down." },
	{ id = "glass_cannon",  rarity = "epic",      art = "crystal",   name = "Glass Cannon",   desc = "Deal 15% more damage. Take 15% more damage." },
	-- LEGENDARY (yellow)
	{ id = "crown_of_line", rarity = "legendary", art = "crown",     name = "Crown of the Line", desc = "Every box your team plugs heals you to full." },
	{ id = "sun_eater",     rarity = "legendary", art = "sun",       name = "Sun Eater",      desc = "Flashbangs cannot blind you. Yours burn twice as bright." },
	{ id = "golden_hour",   rarity = "legendary", art = "hourglass", name = "Golden Hour",    desc = "Once per life, drop to 1 HP instead of dying and slow time for 2s." },
	{ id = "oathblade",     rarity = "legendary", art = "sword",     name = "Oathblade",      desc = "The last player alive on your team deals 25% more damage." },
	-- MYTHIC (red)
	{ id = "red_serpent",   rarity = "mythic",    art = "serpent",   name = "The Red Serpent",desc = "Kills restore 30 health. Every 3rd kill refills your magazine." },
	{ id = "bloodmoon_pact",rarity = "mythic",    art = "bloodmoon", name = "Bloodmoon Pact", desc = "Respawn 5 seconds faster. Your soul cannot be revived." },
	-- DIVINE (watercolour rainbow)
	{ id = "halo_of_ash",   rarity = "divine",    art = "halo",      name = "Halo of Ash",    desc = "When you die, your whole team is shielded for 3 seconds." },
	{ id = "seraphs_eye",   rarity = "divine",    art = "seraph",    name = "Seraph's Eye",   desc = "Every 20 seconds, see every enemy through walls for 1 second." },
	-- SIGNATURE (white / black)
	{ id = "the_breakline", rarity = "signature", art = "breakline", name = "The Breakline",  desc = "Once per match, shove the wall a full box-length toward the enemy." },
}
M.ById = {}
for i, c in M.List do c.order = i M.ById[c.id] = c end

-- starter collection: everyone owns every placeholder card (no shop yet). Lower rarities come with more copies.
local STARTER_COPIES = { common = 4, uncommon = 3, rare = 2, epic = 2, legendary = 2, mythic = 1, divine = 1, signature = 1 }

M.RULES = {
	"Your deck holds exactly 32 cards. No more, no less. It only saves when it is full.",
	"You can put at most 4 copies of the same card in your deck.",
	"You can only add copies you own. Your collection shows how many you have.",
	"At the start of every match, after the run-in, 3 cards roll out of your DECK (not your whole collection).",
	"You have 10 seconds to pick one. If you do not pick, the middle card is picked for you.",
	"The card you pick lasts the whole match and sits on your HUD.",
}

function M.Is(id) return type(id) == "string" and M.ById[id] ~= nil end
function M.Rarity(id) local c = M.ById[id] return c and M.RarityById[c.rarity] or M.Rarities[1] end

function M.Collection(saved)
	local out = {}
	for _, c in M.List do out[c.id] = STARTER_COPIES[c.rarity] or 1 end
	if type(saved) == "table" then
		for id, n in saved do
			if M.Is(id) and type(n) == "number" then out[id] = math.max(out[id], math.floor(n)) end
		end
	end
	return out
end

function M.Counts(deck)
	local n = {}
	if type(deck) == "table" then
		for _, id in deck do if type(id) == "string" then n[id] = (n[id] or 0) + 1 end end
	end
	return n
end

function M.Validate(deck, collection)
	if type(deck) ~= "table" then return false, "no deck" end
	collection = collection or M.Collection(nil)
	local size = 0
	for k in deck do
		if type(k) ~= "number" then return false, "bad deck" end
		size += 1
	end
	if size ~= M.DECK_SIZE or #deck ~= M.DECK_SIZE then return false, ("deck needs exactly %d cards"):format(M.DECK_SIZE) end
	local counts = {}
	for _, id in deck do
		if not M.Is(id) then return false, "unknown card" end
		counts[id] = (counts[id] or 0) + 1
		if counts[id] > M.MAX_COPIES then return false, ("max %d copies of a card"):format(M.MAX_COPIES) end
		if counts[id] > (collection[id] or 0) then return false, "you do not own enough copies" end
	end
	return true
end

function M.Clean(deck, collection)
	if not M.Validate(deck, collection) then return nil end
	local out = table.create(M.DECK_SIZE)
	for i = 1, M.DECK_SIZE do out[i] = deck[i] end
	return out
end

function M.DefaultDeck(collection)
	collection = collection or M.Collection(nil)
	local out, counts = {}, {}
	-- one of every card first, then top up with extra copies of the lowest rarities
	for _, c in M.List do
		if #out < M.DECK_SIZE and (collection[c.id] or 0) >= 1 then
			table.insert(out, c.id)
			counts[c.id] = 1
		end
	end
	local copies = 1
	while #out < M.DECK_SIZE and copies < M.MAX_COPIES do
		copies += 1
		for _, c in M.List do
			if #out < M.DECK_SIZE and (collection[c.id] or 0) >= copies and (counts[c.id] or 0) < copies then
				table.insert(out, c.id)
				counts[c.id] = copies
			end
		end
	end
	return out
end

function M.Sort(a, b)
	local ca, cb = M.ById[a], M.ById[b]
	if not ca or not cb then return tostring(a) < tostring(b) end
	local ra, rb = M.RarityById[ca.rarity].rank, M.RarityById[cb.rarity].rank
	if ra ~= rb then return ra > rb end
	return ca.order < cb.order
end

return M
