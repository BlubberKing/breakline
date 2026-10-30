-- MatchConfig: every tuning number for the Wall Push mode (GDD 2.1) in one place.
-- Items marked PROPOSAL are not owner-approved yet - change them freely while playtesting.
local C = {}

-- ===== match flow =====
C.MIN_PLAYERS  = 1   -- players needed to start a round (raise to 2-6 for live games; 1 lets you test alone)
-- Flow: Waiting (loading screen) -> Pregame -> Warp (cutscene) -> Countdown -> Playing -> SlowMo -> Result (winner cutscene) -> Summary (souls screen)
C.READY_TIMEOUT  = 40  -- seconds to wait for slow clients to finish loading before starting without them
C.PREGAME_TIME   = 20  -- pre-game screen (loadout + clock)
C.WARP_TIME      = 9   -- soul flight + run-in cutscene (MatchFlow is timed to this: do not shorten below ~8)
C.COUNTDOWN_TIME = 3   -- 3-2-1 on the map, everybody frozen
C.SLOWMO_TIME    = 2.6 -- the moment the round is decided everything slows down (movement, shooting, falling) for this long, then the winner cutscene
C.SLOWMO_SCALE   = 0.1 -- how slow it gets (0.1 = ten times slower)
C.SLOWMO_RAMP    = 0.5 -- seconds to ease from normal speed down to SLOWMO_SCALE
C.RESULT_TIME    = 5   -- winner cutscene (winners sit on thrones) before the souls screen
C.SUMMARY_MAX    = 60  -- the server never waits longer than this for players to press CONTINUE
C.SUMMARY_AUTO   = 15  -- the client presses CONTINUE for you this many seconds after the soul count finished

-- ===== souls earned per match (multipliers stack on the base) =====
C.REWARD = {
	Base = 50,
	Win = 1.5, Loss = 0.75, Draw = 1.0,   -- set multiplier for how the match ended
	PerKill = 0.10,                       -- + this per kill
	PerPlugged = 0.05,                    -- + this per box you plugged into a hole
	PerDestroyed = 0.08,                  -- + this per enemy box you destroyed
	PerThousandDamage = 0.02,             -- + this per 1000 damage dealt to players (tiny)
}
-- v3.8: player XP earned per match (one number on the summary screen, the bar fills while the stat rows are revealed).
-- XP = Base + outcome + kills + boxes plugged + boxes destroyed + damage. Level curve lives in ReplicatedStorage.Levels.
C.XP = {
	Base = 40,
	Win = 60, Draw = 30, Loss = 20,
	PerKill = 12, PerPlugged = 8, PerDestroyed = 10,
	PerHundredDamage = 2,
}
C.RESPAWN_TIME = 5   -- PROPOSAL (GDD: 5-7s)
C.REVEAL_TIME = 1.4  -- v3.8: after a respawn your body is revealed bottom-up by souls; you cannot move / shoot / be hurt until it is done

-- Team 1 (Red) defends one end of the map, team 2 (Blue) the other. See MAP.SwapEnds.
C.Teams = {
	{ Name = "Red",  Color = BrickColor.new("Bright red") },
	{ Name = "Blue", Color = BrickColor.new("Bright blue") },
}

-- ===== map fitting =====
-- The map size comes from YOUR part named "MapBounds" in Workspace (anchored, fully transparent, as big as the playable area).
--   * MapBounds X size = map width, Z size = map length, Y size = map height. Its BOTTOM is the ground level.
--   * Red's end is the Front (-Z) end of MapBounds, Blue's end is the Back (+Z) end. Rotate MapBounds, or set SwapEnds, to change it.
-- MatchServer builds only: invisible boundary walls + ceiling, the 2 finish lines, the 6 invisible team spawns, the wall, and the boxes.
C.MAP = {
	FinishInset     = 12,                -- studs the finish lines + spawns sit in from each end of MapBounds
	WallThickness   = 6,
	WallHeightMax   = 60,                -- the wall is as tall as MapBounds, but never taller than this
	HoleXFrac       = { -0.28, 0, 0.28 }, -- 3 holes per side; positions as a fraction of MapBounds width (0 = center)
	HoleY           = 3,                 -- height of a plugged box's center above the ground
	SpawnXFrac      = { -0.14, 0, 0.14 }, -- 3 spawns per team; fraction of MapBounds width
	GroundOffset    = 0,                 -- raise (+) or lower (-) the ground level if your floor is not at the bottom of MapBounds
	SwapEnds        = false,             -- true = Red at the Back (+Z) end instead
	ShowFinishLines = true,              -- thin glowing line in each team's color (false = invisible)
}

-- ===== wall =====
-- studs/second by how many MORE plugged boxes the pushing team has: [1] = one box ahead, [2] = two ahead, [3] = three ahead.
-- (Slowed down Oct 25: was 1.5 / 3.0 / 4.5.) Tie = wall stands still.
C.WALL_SPEED = { 0.8, 1.5, 2.1 }

-- ===== boxes =====
C.BOX = {
	Size            = 2.8,
	Health          = 5000, -- plugged-box health (owner)
	DamageMult      = 1,    -- gun damage multiplier against boxes
	PushDrainPerSec = 10,   -- owner: boxes of the team that is currently PUSHING the wall take this much damage every second
	SpawnInterval   = 60,   -- every minute, one new box on EACH side of the wall (owner)
	StartPerSide    = 1,    -- boxes on each side when a round starts (owner)
}

C.PICKUP_TIME   = 0.25 -- hold time (s) to pick up a loose box
C.EXTRACT_TIME  = 1.5  -- hold time (s) to extract an ENEMY plugged box
C.PLUG_RADIUS   = 7    -- a box this close to an empty hole of its team's side floats in by itself
C.PLUG_ANIM     = 0.45 -- seconds the box floats into the hole
C.CATCH_RADIUS  = 6    -- teammates auto-catch a thrown box this close to them
C.THROW_SPEED   = 120  -- studs/second (roughly 40-70 studs of range depending on angle)
C.THROW_UP      = 0.3  -- extra upward angle added to your aim
C.CARRY_SPEED_MULT = 0.85 -- PROPOSAL: carrier is a little slower (used by GunClient)

-- first-person carry model (MatchClient). Smaller BoxSize / lower Y = less of your screen taken up.
C.CARRY_VM = {
	BoxSize   = 0.95,
	Pos       = Vector3.new(0, -0.8, -2.1), -- camera space
	RaiseTime = 0.3,
}

return C
