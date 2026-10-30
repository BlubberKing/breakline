-- Levels (ModuleScript in ReplicatedStorage) - BOTH games (v3.8). Keep the two copies identical.
-- Player level from total XP. XP is saved in the shared profile as "XP" (ProfileStore mirrors it to the Player attribute "XP"
-- and the derived level to the Player attribute "Level"). XP is earned at the end of a Breakline match (MatchServer.buildReward).
--   Levels.Need(level)   -> XP needed to go from `level` to `level + 1`
--   Levels.FromXp(xp)    -> level, xpIntoThisLevel, xpNeededForThisLevel   (at MAX: the bar is simply full)
local L = {}
L.MAX = 100

function L.Need(level)
	return 100 + 40 * (level - 1)
end

function L.FromXp(xp)
	xp = math.max(0, math.floor(tonumber(xp) or 0))
	local level = 1
	while level < L.MAX do
		local need = L.Need(level)
		if xp < need then return level, xp, need end
		xp -= need
		level += 1
	end
	return L.MAX, L.Need(L.MAX), L.Need(L.MAX)
end

return L
