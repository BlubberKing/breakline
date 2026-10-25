-- WeaponConfig: every gun's stats live here. To add a gun:
--   1) add an entry to W.Weapons (only list what differs from W.Defaults)
--   2) add its id to W.Order (picker order)
--   3) add a model with the same id in GunModels (or set Model = "<existing model id>")
-- Health is 100. Distances are studs. Spreads/recoil are degrees.
local W = {}

W.Order = { "VX9", "KR47", "HX3", "WASP", "ANVIL", "LONGSHOT", "HALO50", "BREACHER", "V9", "MAGNUM" }
W.Default = "VX9"
W.Reticles = { "Dot", "Holo", "Chevron" } -- reticle styles for Red Dot / Holo sights

-- recoil helper: n shots, vertical climb per shot, side sway, fade = how much the climb shrinks over the spray
local function climb(up, side, n, fade)
	local t = {}
	for i = 1, n do
		local a = (i - 1) / math.max(n - 1, 1)
		t[i] = Vector2.new(up * (1 - fade * a), side * math.sin(i * 1.3) * (0.4 + a))
	end
	return t
end

W.Defaults = {
	Class = "Rifle", Inspiration = "", Model = nil,
	Sights = { "Iron" }, DefaultSight = "Iron",

	FireMode = "Auto",          -- "Auto" | "Semi" | "Burst"
	RPM = 600,                  -- Auto/Semi: max fire rate. Burst: time between bursts comes from BurstDelay
	BurstCount = 3, BurstRPM = 900, BurstDelay = 0.3,
	Pellets = 1, PelletSpread = 0, ADSPelletMult = 1,

	Damage = 18, HeadMultiplier = 1.5,
	MagSize = 30, ReloadTime = 2.0, Range = 700,
	FalloffStart = 40, FalloffEnd = 100, FalloffMin = 0.7,

	SpreadHip = 1.0, SpreadADS = 0, SpreadMove = 0.4, SpreadMoveADS = nil, SpreadAir = 2.0,
	BloomPerShot = 0.08, BloomMax = 0.8, BloomRecovery = 5,

	ADSTime = 0.14, ADSFov = 58, ADSSensitivity = 0.7, ADSRecoilMult = 0.7,

	RecoilPattern = climb(0.45, 0.1, 12, 0.5),
	RecoilJitter = 0.06, SprayResetTime = 0.3,
	RecoverDelay = 0.1, RecoverSpeed = 10, ClimbSnap = 30,

	CamPunch = 14, CamRoll = 30, FovPunch = 22,
	KickBack = 4.5, KickUp = 70, KickYaw = 25, KickRoll = 80,

	MoveSpeed = 1.0, EquipTime = 0.3,
	Cycle = nil, CycleTime = 0.4, CycleDelay = 0.05, CycleDist = 0.25, -- "Pump" | "Bolt" | "Slide"
	FirePitch = 1, FireVolume = 1,
	Shell = { Size = Vector3.new(0.035, 0.035, 0.11), Color = Color3.fromRGB(214, 168, 72) },
}

W.Weapons = {
	VX9 = {
		Name = "VX-9 RIFLE", Class = "Assault Rifle",
		Inspiration = "Real: M4 / AR-15 · Finals: FCAR / ARN-220 · Rivals: Assault Rifle",
		Sights = { "Iron", "RedDot", "Holo", "Ranger3x" }, DefaultSight = "RedDot",
		Damage = 18, HeadMultiplier = 1.6, RPM = 650, MagSize = 30, ReloadTime = 1.9, Range = 700,
		FalloffStart = 40, FalloffEnd = 100, FalloffMin = 0.7,
		SpreadHip = 1.0, SpreadMove = 0.4, SpreadAir = 2.0, BloomPerShot = 0.08, BloomMax = 0.8,
		RecoilPattern = {
			Vector2.new(0.50, 0), Vector2.new(0.48, 0.03), Vector2.new(0.45, 0.05),
			Vector2.new(0.42, -0.04), Vector2.new(0.38, -0.08), Vector2.new(0.34, -0.12),
			Vector2.new(0.30, -0.14), Vector2.new(0.28, -0.08), Vector2.new(0.26, 0.06),
			Vector2.new(0.24, 0.14), Vector2.new(0.22, 0.16), Vector2.new(0.20, 0.10),
		},
	},

	KR47 = {
		Name = "KR-47 BRUISER", Class = "Assault Rifle",
		Inspiration = "Real: AKM · Finals: AKM · Rivals: Assault Rifle (heavier)",
		Sights = { "Iron", "RedDot", "Holo" }, DefaultSight = "Iron",
		Damage = 22, HeadMultiplier = 1.5, RPM = 540, MagSize = 30, ReloadTime = 2.3, Range = 650,
		FalloffStart = 35, FalloffEnd = 90, FalloffMin = 0.62,
		SpreadHip = 1.3, SpreadMove = 0.5, BloomPerShot = 0.1, BloomMax = 1.0,
		ADSTime = 0.17,
		RecoilPattern = climb(0.62, 0.14, 12, 0.35), RecoilJitter = 0.09,
		CamPunch = 17, KickBack = 5.2, KickUp = 85,
		MoveSpeed = 0.97, FirePitch = 0.88, FireVolume = 1.1,
	},

	HX3 = {
		Name = "HX-3 BURST", Class = "Burst Rifle",
		Inspiration = "Real: FAMAS (bullpup) · Finals: FAMAS · Rivals: Burst Rifle",
		Sights = { "Iron", "RedDot", "Holo", "Ranger3x" }, DefaultSight = "RedDot",
		FireMode = "Burst", BurstCount = 3, BurstRPM = 900, BurstDelay = 0.3,
		Damage = 22, HeadMultiplier = 1.55, MagSize = 24, ReloadTime = 2.0, Range = 750,
		FalloffStart = 60, FalloffEnd = 140, FalloffMin = 0.75,
		SpreadHip = 1.1, BloomPerShot = 0.05, BloomMax = 0.6, ADSFov = 55,
		RecoilPattern = climb(0.4, 0.05, 6, 0.2), SprayResetTime = 0.45,
		CamPunch = 13, KickUp = 65, FirePitch = 1.05,
	},

	WASP = {
		Name = "WASP SMG", Class = "SMG",
		Inspiration = "Real: MP7 / Vector · Finals: XP-54 / M11 · Rivals: Uzi",
		Sights = { "Iron", "RedDot", "Holo" }, DefaultSight = "RedDot",
		Damage = 14, HeadMultiplier = 1.4, RPM = 900, MagSize = 40, ReloadTime = 1.8, Range = 400,
		FalloffStart = 22, FalloffEnd = 55, FalloffMin = 0.55,
		SpreadHip = 0.9, SpreadMove = 0.2, SpreadAir = 1.2, BloomPerShot = 0.05, BloomMax = 0.6,
		ADSTime = 0.11, ADSFov = 62,
		RecoilPattern = climb(0.28, 0.14, 14, 0.3), RecoilJitter = 0.1,
		CamPunch = 9, KickBack = 3, KickUp = 45,
		MoveSpeed = 1.06, EquipTime = 0.25, FirePitch = 1.18, FireVolume = 0.8,
	},

	ANVIL = {
		Name = "ANVIL LMG", Class = "LMG",
		Inspiration = "Real: M249 / M60 · Finals: M60 / Lewis Gun · Rivals: Minigun (role)",
		Sights = { "Iron", "RedDot", "Holo", "Ranger3x" }, DefaultSight = "Holo",
		Damage = 17, HeadMultiplier = 1.4, RPM = 620, MagSize = 80, ReloadTime = 3.8, Range = 700,
		FalloffStart = 45, FalloffEnd = 110, FalloffMin = 0.7,
		SpreadHip = 1.8, SpreadMove = 0.8, BloomPerShot = 0.06, BloomMax = 1.2,
		ADSTime = 0.24, ADSFov = 56, ADSRecoilMult = 0.6,
		RecoilPattern = climb(0.45, 0.18, 16, 0.5),
		CamPunch = 13, KickUp = 60, KickBack = 4,
		MoveSpeed = 0.9, EquipTime = 0.6, FirePitch = 0.82, FireVolume = 1.15,
	},

	LONGSHOT = {
		Name = "LONGSHOT DMR", Class = "Marksman",
		Inspiration = "Real: M14 EBR · Finals: LH1 · Rivals: (none — fills the gap)",
		Sights = { "Iron", "RedDot", "Ranger3x" }, DefaultSight = "Ranger3x",
		FireMode = "Semi", RPM = 260,
		Damage = 38, HeadMultiplier = 1.75, MagSize = 15, ReloadTime = 2.4, Range = 900,
		FalloffStart = 90, FalloffEnd = 200, FalloffMin = 0.75,
		SpreadHip = 1.6, SpreadMove = 0.6, BloomPerShot = 0.35, BloomMax = 1.2, BloomRecovery = 4,
		ADSTime = 0.2, ADSFov = 52, ADSSensitivity = 0.65,
		RecoilPattern = climb(1.1, 0.15, 6, 0), RecoverSpeed = 9,
		CamPunch = 22, KickBack = 6, KickUp = 110,
		MoveSpeed = 0.96, FirePitch = 0.8, FireVolume = 1.2,
	},

	HALO50 = {
		Name = "HALO-50 SNIPER", Class = "Sniper",
		Inspiration = "Real: AWM · Finals: SR-84 · Rivals: Sniper",
		Sights = { "Sniper8x", "Ranger3x", "Iron" }, DefaultSight = "Sniper8x",
		FireMode = "Semi", RPM = 48,
		Damage = 85, HeadMultiplier = 2.0, MagSize = 5, ReloadTime = 3.0, Range = 1500,
		FalloffStart = 2000, FalloffEnd = 2001, FalloffMin = 1,
		SpreadHip = 5, SpreadADS = 0, SpreadMove = 3, SpreadMoveADS = 0, SpreadAir = 6,
		BloomPerShot = 0, BloomMax = 0,
		ADSTime = 0.3, ADSFov = 64, ADSSensitivity = 0.6,
		RecoilPattern = { Vector2.new(2.5, 0) }, RecoverSpeed = 6,
		CamPunch = 30, FovPunch = 10, KickBack = 8, KickUp = 150,
		MoveSpeed = 0.9, EquipTime = 0.7,
		Cycle = "Bolt", CycleTime = 0.8, CycleDelay = 0.2, CycleDist = 0.32,
		FirePitch = 0.62, FireVolume = 1.4,
		Shell = { Size = Vector3.new(0.05, 0.05, 0.18), Color = Color3.fromRGB(214, 168, 72) },
	},

	BREACHER = {
		Name = "BREACHER PUMP", Class = "Shotgun",
		Inspiration = "Real: Remington 870 · Finals: M26 Matter / SA1216 · Rivals: Shotgun",
		Sights = { "Iron", "RedDot" }, DefaultSight = "Iron",
		FireMode = "Semi", RPM = 80, Pellets = 10, PelletSpread = 4.5, ADSPelletMult = 0.85,
		Damage = 9, HeadMultiplier = 1.25, MagSize = 6, ReloadTime = 2.6, Range = 300,
		FalloffStart = 15, FalloffEnd = 40, FalloffMin = 0.35,
		SpreadHip = 0, SpreadMove = 0, SpreadAir = 0.5, BloomPerShot = 0, BloomMax = 0,
		ADSTime = 0.16, ADSFov = 64,
		RecoilPattern = { Vector2.new(1.8, 0) }, RecoverSpeed = 7,
		CamPunch = 26, FovPunch = 30, KickBack = 9, KickUp = 120,
		Cycle = "Pump", CycleTime = 0.5, CycleDelay = 0.08, CycleDist = 0.28,
		FirePitch = 0.6, FireVolume = 1.4,
		Shell = { Size = Vector3.new(0.08, 0.08, 0.17), Color = Color3.fromRGB(200, 40, 40) },
	},

	V9 = {
		Name = "V9 SIDEARM", Class = "Pistol",
		Inspiration = "Real: Glock 17 · Finals: V9S · Rivals: Handgun",
		Model = "V9",
		Sights = { "Iron", "RedDot" }, DefaultSight = "Iron",
		FireMode = "Semi", RPM = 420,
		Damage = 24, HeadMultiplier = 1.6, MagSize = 15, ReloadTime = 1.3, Range = 500,
		FalloffStart = 25, FalloffEnd = 60, FalloffMin = 0.6,
		SpreadHip = 0.8, SpreadMove = 0.3, BloomPerShot = 0.2, BloomMax = 0.9,
		ADSTime = 0.1, ADSFov = 64,
		RecoilPattern = climb(0.7, 0.1, 6, 0),
		CamPunch = 12, KickBack = 3.5, KickUp = 70,
		MoveSpeed = 1.08, EquipTime = 0.25,
		Cycle = "Slide", CycleTime = 0.08, CycleDelay = 0, CycleDist = 0.14,
		FirePitch = 1.12, FireVolume = 0.8,
		Shell = { Size = Vector3.new(0.03, 0.03, 0.07), Color = Color3.fromRGB(214, 168, 72) },
	},

	MAGNUM = {
		Name = "MAGNUM .44", Class = "Revolver",
		Inspiration = "Real: S&W Model 29 · Finals: R.357 · Rivals: Revolver",
		Sights = { "Iron", "RedDot" }, DefaultSight = "Iron",
		FireMode = "Semi", RPM = 140,
		Damage = 45, HeadMultiplier = 1.6, MagSize = 6, ReloadTime = 2.4, Range = 700,
		FalloffStart = 50, FalloffEnd = 120, FalloffMin = 0.7,
		SpreadHip = 1.0, BloomPerShot = 0.4, BloomMax = 1.2, BloomRecovery = 4,
		ADSTime = 0.15, ADSFov = 60,
		RecoilPattern = { Vector2.new(2.0, 0.2) }, RecoverSpeed = 7,
		CamPunch = 26, KickBack = 5, KickUp = 140,
		MoveSpeed = 1.04, FirePitch = 0.72, FireVolume = 1.3,
		Shell = false, -- revolvers keep their brass
	},
}

for id, w in pairs(W.Weapons) do
	w.Id = id
	w.Model = w.Model or id
	setmetatable(w, { __index = W.Defaults })
end

function W.Get(id)
	return W.Weapons[id] or W.Weapons[W.Default]
end

function W.HasSight(cfg, sight)
	return table.find(cfg.Sights, sight) ~= nil
end

-- time (s) at which shot number k (1-based) leaves the barrel when holding/spamming the trigger
function W.ShotTime(cfg, k)
	if cfg.FireMode == "Burst" then
		local bi = 60 / cfg.BurstRPM
		local bursts = math.floor((k - 1) / cfg.BurstCount)
		local within = (k - 1) % cfg.BurstCount
		return bursts * ((cfg.BurstCount - 1) * bi + cfg.BurstDelay) + within * bi
	end
	return (k - 1) * 60 / cfg.RPM
end

-- average seconds per shot over a long spray (used by the server rate limit)
function W.AvgInterval(cfg)
	if cfg.FireMode == "Burst" then
		return ((cfg.BurstCount - 1) * 60 / cfg.BurstRPM + cfg.BurstDelay) / cfg.BurstCount
	end
	return 60 / cfg.RPM
end

-- time to kill a 100 HP target at full damage (all pellets hit for shotguns)
function W.TTK(cfg, headshots)
	local per = cfg.Damage * cfg.Pellets * (headshots and cfg.HeadMultiplier or 1)
	local stk = math.ceil(100 / per - 1e-6)
	return W.ShotTime(cfg, stk), stk
end

return W
