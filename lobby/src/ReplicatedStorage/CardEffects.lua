-- CardEffects v1 (ModuleScript in ReplicatedStorage) - BREAKLINE place only. NEW in v5.14 (GDD 4.4).
-- What the 8 starter power-up cards really do in a match, and every number for them in one place. The card a player picked at the start of
-- the match is the Player attribute "MatchCard" (MatchServer sets it after the card roll, clears it after the match).
-- Who uses it:
--   Vitals (server)          EMBER HEART (regen delay), THICK SKIN (max health), GLASS CANNON (damage taken)
--   GunServer (server)       DEEP POCKETS (extra magazine), HOT BARREL (fire rate after a kill), HOLLOW POINT (headshots), GLASS CANNON (damage dealt)
--   GadgetServer (server)    GLASS CANNON (grenade / mine / sentry damage dealt)
--   GunClient (client)       DEEP POCKETS + HOT BARREL (so the client's ammo / fire rate match the server)
--   CardEffectsClient        GRAVE CANDLE (teammate souls through walls), SCOUT'S EYE (outline enemies you hit)
local Players = game:GetService("Players")

local E = {}

E.EMBER_HEART_REGEN_SOONER = 1     -- seconds: health starts coming back this much sooner (Vitals.REGEN_DELAY 12 -> 11)
E.THICK_SKIN_HEALTH = 10           -- extra max health (250 -> 260)
E.DEEP_POCKETS_MAGS = 1            -- extra magazines loaded on top of the normal one at the start of every life
E.HOT_BARREL_RATE = 1.10           -- fire rate multiplier ...
E.HOT_BARREL_TIME = 4              -- ... for this many seconds after a kill (each kill restarts it)
E.HOLLOW_POINT_HEAD = 1.12         -- headshot damage multiplier
E.GLASS_CANNON_DEAL = 1.15         -- damage you deal (guns + gadgets)
E.GLASS_CANNON_TAKE = 1.15         -- damage you take (everything that goes through Vitals.Damage)
E.SCOUTS_EYE_TIME = 2              -- seconds an enemy stays outlined after you hit them
E.GRAVE_CANDLE_COLOR = Color3.fromRGB(255, 196, 110)
E.SCOUTS_EYE_COLOR = Color3.fromRGB(255, 70, 60)

-- true when this player's match card is cardId
function E.Has(player, cardId)
	return typeof(player) == "Instance" and player:IsA("Player") and player:GetAttribute("MatchCard") == cardId
end

-- the player who owns a character / humanoid (nil for bots, sentries, boxes)
function E.PlayerOf(inst)
	if typeof(inst) ~= "Instance" then return nil end
	local model = inst:IsA("Humanoid") and inst.Parent or inst
	return model and Players:GetPlayerFromCharacter(model) or nil
end

-- HOT BARREL: the attribute "HotBarrelUntil" (server time) is set by GunServer on a kill
function E.HotBarrelActive(player)
	if not E.Has(player, "hot_barrel") then return false end
	local t = player:GetAttribute("HotBarrelUntil")
	return type(t) == "number" and workspace:GetServerTimeNow() < t
end

-- multiplier for the time between shots (smaller = faster)
function E.FireIntervalMult(player)
	return E.HotBarrelActive(player) and (1 / E.HOT_BARREL_RATE) or 1
end

return E
