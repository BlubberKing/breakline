-- MatchConfig: every tuning number for the Wall Push mode (GDD 2.1) in one place.
-- Items marked PROPOSAL are not owner-approved yet - change them freely while playtesting.
local C = {}

-- ===== match flow =====
C.MIN_PLAYERS  = 1   -- players needed to start a round (raise to 2-6 for live games; 1 lets you test alone)
C.INTERMISSION = 8   -- seconds before each round
C.RESULT_TIME  = 7   -- seconds the winner is shown
C.RESPAWN_TIME = 5   -- PROPOSAL (GDD: 5-7s)

-- Team 1 defends the -Z end, team 2 defends the +Z end.
C.Teams = {
	{ Name = "Red",  Color = BrickColor.new("Bright red") },
	{ Name = "Blue", Color = BrickColor.new("Bright blue") },
}

-- ===== gray-box map (built by MatchServer) =====
C.MAP = {
	Width         = 140,  -- X
	Length        = 260,  -- Z (team ends are at +-Length/2)
	FinishInset   = 14,   -- finish line + spawn pads sit this far in from the map end
	WallThickness = 6,
	WallHeight    = 40,
	HoleX         = { -40, 0, 40 }, -- 3 holes per side
	HoleY         = 3,              -- height of a plugged box's center
}

-- ===== wall =====
C.WALL_SPEED_PER_BOX = 1.5 -- PROPOSAL: studs/second per box of difference (tie = wall stands still)

-- ===== boxes =====
C.BOX = {
	Size          = 3,
	Health        = 400,  -- plugged-box health (VX-9 does ~195 dmg/s, so ~2s of sustained fire)
	DamageMult    = 1,    -- gun damage multiplier against boxes
	Lifetime      = 120,  -- a plugged box is destroyed after this many seconds (owner: 2 minutes)
	SpawnInterval = 60,   -- every minute, one new box on EACH side of the wall (owner)
	StartPerSide  = 2,    -- boxes on each side when a round starts (assumption, not specified)
}

C.PICKUP_TIME   = 0.25 -- hold time (s) to pick up a loose box
C.EXTRACT_TIME  = 1.5  -- hold time (s) to extract an ENEMY plugged box
C.PLUG_RADIUS   = 7    -- a box this close to an empty hole of its team's side goes in by itself
C.CATCH_RADIUS  = 6    -- teammates auto-catch a thrown box this close to them
C.THROW_SPEED   = 120  -- studs/second (roughly 40-70 studs of range depending on angle)
C.THROW_UP      = 0.3  -- extra upward angle added to your aim
C.CARRY_SPEED_MULT = 0.85 -- PROPOSAL: carrier is a little slower (used by GunClient)

return C
