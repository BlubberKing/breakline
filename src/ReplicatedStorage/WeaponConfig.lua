return {
	AR = {
		Name = "VX-9 RIFLE",
		Damage = 18, HeadMultiplier = 1.6,
		RPM = 650, MagSize = 30, ReloadTime = 1.9, Range = 700,
		FalloffStart = 40, FalloffEnd = 100, FalloffMin = 0.7,

		-- Accuracy (degrees). Arcade style: accurate hipfire, light movement penalty.
		SpreadHip = 1.0, SpreadADS = 0, SpreadMove = 0.4, SpreadAir = 2.0,
		BloomPerShot = 0.08, BloomMax = 0.8, BloomRecovery = 5,

		ADSTime = 0.14, ADSFov = 58, ADSSensitivity = 0.7, ADSRecoilMult = 0.7,

		-- REAL aim climb (moves your crosshair). Kept small and readable.
		RecoilPattern = {
			Vector2.new(0.50, 0), Vector2.new(0.48, 0.03), Vector2.new(0.45, 0.05),
			Vector2.new(0.42, -0.04), Vector2.new(0.38, -0.08), Vector2.new(0.34, -0.12),
			Vector2.new(0.30, -0.14), Vector2.new(0.28, -0.08), Vector2.new(0.26, 0.06),
			Vector2.new(0.24, 0.14), Vector2.new(0.22, 0.16), Vector2.new(0.20, 0.10),
		},
		RecoilJitter = 0.06, SprayResetTime = 0.3,
		RecoverDelay = 0.1, RecoverSpeed = 10, ClimbSnap = 30,

		-- VISUAL kick only (does not move your aim). This is where the "punch" lives.
		CamPunch = 14, CamRoll = 30, FovPunch = 22,
		KickBack = 4.5, KickUp = 70, KickYaw = 25, KickRoll = 80,
	},
}
