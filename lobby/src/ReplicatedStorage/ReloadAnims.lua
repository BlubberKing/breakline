-- ReloadAnims: one hand-authored first-person reload per gun (keyed by model id).
-- Used by GunClient. ReloadAnims.Make(modelId, points, scale) -> { Pose = fn(u), Events = { ... } }
--   u = reload progress 0..1. Pose(u) returns:
--     tilt   CFrame   whole-gun offset/rotation (lifts + turns the gun toward screen center so the action is on screen)
--     mag    CFrame   offset of the "mag" group relative to Points.MagPivot
--     hand   Vector3  left hand position (gun space), grab 0..1 = how closed the hand is
--     cover  CFrame?  gun-space transform for the "cover" group (M249 feed cover)
--     cycleZ number?  gun-space Z travel of the "cycle" group (bolt / pump / slide / charging handle)
--     aux    {[id]=CFrame}? loose rounds / shells / casings / belt links (parts in the "aux" group; missing id = hidden)
--     fall   boolean  true while the mag is intentionally dropped out of view
-- To change a reload: edit the keyframes of that gun in Defs. Times are fractions of ReloadTime (WeaponConfig).
-- Each key = { t, hand, grab, mag, rx, ry, rz, cyc, cov, fall }: anything left out keeps the previous key's value.
-- v7 HOLD FLAGS (0..1, blended between keys):
--   hm = 1  the left hand is GLUED to the magazine (the hand follows the mag, so the mag is really held in the fist)
--   hf = 1  the hand position in the key is FINAL (no resting-grip drop / offset). Every key of a reload uses hf = 1 except the first + last.
-- Round-fed guns (AWP, shotgun, revolver) get opts = { n = rounds to load, T = seconds, rr = WeaponConfig RoundReload } so a 1-round reload
-- only plays 1 round (and takes less time). Mag guns always play the full mag swap.
-- Positions are unscaled gun space (the same numbers as GunModels). m(x,y,z) = offset from the mag pivot.
local ReloadAnims = {}
ReloadAnims.HAND_DROP = 0.4 -- studs (viewmodel scale): how far GunClient drops the resting left hand under the handguard (the reload poses start + end at that height)

local V, CF = Vector3.new, CFrame.new
local rad = math.rad
local function ang(x, y, z) return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0)) end
local function seg(u, a, b) return math.clamp((u - a) / (b - a), 0, 1) end
local function smooth(x) return x * x * (3 - 2 * x) end

local IDENT = CF()
local Defs = {}

local ZERO = V(0, 0, 0)
local TOSS = V(-2.6, -0.9, -0.6) -- where a thrown mag flies to (left + forward, then it is hidden)
local POUCH = V(-1.0, -0.85, 0.3) -- where the fresh mag comes from (relative to the mag pivot)
local function base(FO)
	return { t = 0, hand = FO, grab = 0, mag = ZERO, rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0, tr = 0, tp = 0, ty = 0, gp = ZERO, hm = 0, hf = 0 }
end

-- ================= M4A1: thumb the release, yank the mag (gun jerks), FLICK it away, fresh mag from the pouch, slam + tap, charge =================
function Defs.VX9(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -30, pitch = 12, yaw = 10, lift = V(-0.3, 0.55, 0.25), rise = 0.12, fall = 0.9 },
		keys = {
			base(FO),
			{ t = 0.07, tr = -6, hf = 1 },
			{ t = 0.15, hand = m(0, -0.05, 0), grab = 1, hm = 1 },
			{ t = 0.21, hand = m(0, -0.12, 0), tr = -10, gp = V(0, -0.04, 0.05) },
			{ t = 0.27, hand = m(-0.1, -0.65, 0.05), mag = V(-0.1, -0.6, 0.05), rx = 12, tr = -16, tp = 5, gp = V(0.04, -0.06, 0.12) },
			{ t = 0.33, hand = m(-0.6, -0.75, 0.2), grab = 0.4, mag = V(-0.6, -0.7, 0.2), rz = -35, tr = -8, tp = 0, gp = ZERO },
			{ t = 0.38, hand = m(-0.9, -0.8, 0.3), grab = 0, mag = TOSS, rx = 220, rz = -170, fall = true, hm = 0 },
			{ t = 0.45, hand = MP + POUCH, grab = 1, mag = POUCH, rx = 0, rz = 0, tr = -12, hm = 1 },
			{ t = 0.58, hand = m(-0.35, -0.55, 0.1), mag = V(-0.35, -0.5, 0.1), rx = 10 },
			{ t = 0.64, hand = m(0, -0.2, 0), mag = V(0, -0.18, 0), rx = 0 },
			{ t = 0.67, hand = m(0, 0, 0), mag = ZERO, tr = -6, gp = V(0, 0.06, -0.12) },
			{ t = 0.71, hand = m(0, -0.22, 0), grab = 0.5, tr = -4, gp = ZERO, hm = 0 },
			{ t = 0.77, hand = V(-0.1, 0.6, -0.1), grab = 1 },
			{ t = 0.83, hand = V(-0.1, 0.6, 0.3), cyc = 0.35, tp = 3 },
			{ t = 0.86, hand = V(-0.1, 0.6, -0.1), cyc = 0, tp = 0 },
			{ t = 0.93, hand = FO, grab = 0, tr = 0, hf = 0 },
			{ t = 1 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.25, snd = "MagOut", kick = { V(0.3, -0.4, 0.8), V(25, 0, -30) } },
			{ at = 0.67, snd = "MagIn", kick = { V(0, 1.5, 0.2), V(-45, 0, 30) } },
			{ at = 0.83, snd = "Bolt", kick = { V(0, 0, 2.5), V(0, 0, 0) } },
		},
	}
end

-- ================= AK-47: rock the mag out forward, tear it free and throw it, hook the new one on the front lip, rock it back hard, charge =================
function Defs.KR47(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -26, pitch = 14, yaw = 12, lift = V(-0.3, 0.55, 0.2), rise = 0.12, fall = 0.9 },
		keys = {
			base(FO),
			{ t = 0.07, tr = -8, hf = 1 },
			{ t = 0.16, hand = m(0, -0.2, 0.05), grab = 1, hm = 1 },
			{ t = 0.25, hand = m(0, -0.3, -0.3), mag = V(0, -0.12, -0.22), rx = 40, tr = -14, tp = 6 },
			{ t = 0.32, hand = m(-0.5, -0.85, 0.0), mag = V(-0.6, -0.8, -0.05), rx = 60, rz = -20, tr = -18, gp = V(0.05, -0.08, 0.14) },
			{ t = 0.38, hand = m(-0.9, -0.9, 0.2), grab = 0.3, mag = V(-0.9, -0.8, 0.1), rx = 70, rz = -40, tr = -8, tp = 0, gp = ZERO },
			{ t = 0.42, hand = m(-1.0, -0.9, 0.2), grab = 0, mag = TOSS, rx = 260, rz = -200, fall = true, hm = 0 },
			{ t = 0.50, hand = MP + POUCH, grab = 1, mag = POUCH, rx = 0, rz = 0, tr = -12, hm = 1 },
			{ t = 0.60, hand = m(-0.2, -0.5, -0.25), mag = V(-0.05, -0.38, -0.3), rx = 42 },
			{ t = 0.66, hand = m(0, -0.4, -0.3), mag = V(0, -0.2, -0.28), rx = 38, tp = 4 },
			{ t = 0.71, hand = m(0, -0.2, 0.12), mag = ZERO, rx = 0, tp = 0, tr = -6, gp = V(0, 0.05, -0.14) },
			{ t = 0.75, hand = m(0, -0.3, 0.0), grab = 0.6, gp = ZERO, tr = -4, hm = 0 },
			{ t = 0.80, hand = V(0.17, 0.57, -0.6), grab = 1 },
			{ t = 0.86, hand = V(0.17, 0.57, -0.15), cyc = 0.45, ty = 3 },
			{ t = 0.90, hand = V(0.17, 0.57, -0.55), cyc = 0, ty = 0 },
			{ t = 0.95, hand = FO, grab = 0, tr = 0, hf = 0 },
			{ t = 1 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.30, snd = "MagOut", kick = { V(0.3, -0.5, 1.0), V(30, 0, -35) } },
			{ at = 0.71, snd = "MagIn", kick = { V(0, 1.4, 0.6), V(-55, 0, 35) } },
			{ at = 0.86, snd = "Bolt", kick = { V(0, 0, 2.6), V(0, 0, 0) } },
		},
	}
end

-- ================= FAMAS: bullpup, gun canted hard, mag spun out behind the grip, hammered home, cocking lever =================
function Defs.HX3(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -50, pitch = 20, yaw = 12, lift = V(-0.4, 0.7, -0.3), rise = 0.12, fall = 0.9 },
		keys = {
			base(FO),
			{ t = 0.07, tr = -5, hf = 1 },
			{ t = 0.16, hand = m(0, -0.1, 0), grab = 1, hm = 1 },
			{ t = 0.22, hand = m(0, -0.18, 0), tr = -9 },
			{ t = 0.28, hand = m(-0.15, -0.65, 0.05), mag = V(-0.15, -0.55, 0.05), rx = 8, rz = -8, tr = -15, tp = 6, gp = V(0.04, -0.06, 0.1) },
			{ t = 0.34, hand = m(-0.6, -0.7, 0.1), grab = 0.3, mag = V(-0.5, -0.65, 0.1), rx = 40, rz = -30, tp = 0, tr = -8, gp = ZERO },
			{ t = 0.38, hand = m(-0.8, -0.7, 0.15), grab = 0, mag = TOSS, rx = 300, rz = -140, fall = true, hm = 0 },
			{ t = 0.46, hand = MP + POUCH, grab = 1, mag = POUCH, rx = 0, rz = 0, tr = -12, hm = 1 },
			{ t = 0.58, hand = m(-0.4, -0.55, 0.05), mag = V(-0.35, -0.48, 0.05) },
			{ t = 0.65, hand = m(0, -0.2, 0), mag = V(0, -0.16, 0) },
			{ t = 0.68, hand = m(0, -0.05, 0), mag = ZERO, tr = -5, gp = V(0, 0.06, -0.1) },
			{ t = 0.72, hand = m(0, -0.25, 0), grab = 0.5, gp = ZERO, hm = 0 },
			{ t = 0.78, hand = V(0, 0.74, -0.3), grab = 1 },
			{ t = 0.84, hand = V(0, 0.74, 0.15), cyc = 0.45, tp = 3 },
			{ t = 0.88, hand = V(0, 0.74, -0.25), cyc = 0, tp = 0 },
			{ t = 0.95, hand = FO, grab = 0, tr = 0, hf = 0 },
			{ t = 1 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.26, snd = "MagOut", kick = { V(0.3, -0.4, 0.8), V(25, 0, -30) } },
			{ at = 0.68, snd = "MagIn", kick = { V(0, 1.3, 0.4), V(-40, 0, 28) } },
			{ at = 0.84, snd = "Bolt", kick = { V(0, 0, 2), V(0, 0, 0) } },
		},
	}
end

-- ================= SMG: YANK the mag so the whole gun lurches, whip it away, jam the new one in, pull the charging knob =================
function Defs.WASP(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	local pouch = V(-0.9, -0.75, 0.3)
	return {
		tilt = { roll = -34, pitch = 8, yaw = 14, lift = V(-0.35, 0.5, 0.2), rise = 0.1, fall = 0.9 },
		keys = {
			base(FO),
			{ t = 0.05, tr = -6, hf = 1 },
			{ t = 0.12, hand = m(0, -0.1, 0), grab = 1, hm = 1 },
			{ t = 0.18, hand = m(-0.3, -0.55, 0.05), mag = V(-0.3, -0.5, 0.05), rz = -25, tr = -24, tp = 9, gp = V(0.06, -0.1, 0.16) },
			{ t = 0.23, hand = m(-0.7, -0.65, 0.1), grab = 0.2, mag = V(-0.7, -0.6, 0.1), rz = -60, tr = -10, tp = 0, gp = ZERO },
			{ t = 0.26, hand = m(-0.8, -0.7, 0.15), grab = 0, mag = TOSS, rx = 150, rz = -300, fall = true, hm = 0 },
			{ t = 0.34, hand = m(-0.9, -0.75, 0.3), grab = 1, mag = V(-0.9, -0.75, 0.3), rx = 0, rz = 0, tr = -12, hm = 1 },
			{ t = 0.42, hand = m(-0.2, -0.4, 0.05), mag = V(-0.2, -0.38, 0.05) },
			{ t = 0.47, hand = m(0, -0.1, 0), mag = ZERO, tr = -5, gp = V(0, 0.08, -0.14) },
			{ t = 0.51, hand = m(0, -0.2, 0), grab = 0.5, gp = ZERO, hm = 0 },
			{ t = 0.59, hand = V(0.15, 0.56, -0.1), grab = 1 },
			{ t = 0.67, hand = V(0.15, 0.56, 0.3), cyc = 0.4 },
			{ t = 0.72, hand = V(0.15, 0.56, -0.05), cyc = 0 },
			{ t = 0.80, hand = FO, grab = 0, tr = 0, hf = 0 },
			{ t = 1 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.17, snd = "MagOut", kick = { V(0.5, -0.6, 1.4), V(40, 0, -45) } },
			{ at = 0.47, snd = "MagIn", kick = { V(0, 1.6, 0.2), V(-45, 0, 30) } },
			{ at = 0.67, snd = "Bolt", kick = { V(0, 0, 1.8), V(0, 0, 0) } },
		},
	}
end

-- ================= M249: pop the feed cover, haul the old box out and heave it, swing the fresh box up, slam it, lay the belt, slam the cover =================
function Defs.ANVIL(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	local tray = function(i) return V(0, 0.56, -0.45 + i * 0.12) end
	return {
		tilt = { roll = -10, pitch = 12, yaw = 20, lift = V(-0.35, 0.45, 0.0), rise = 0.12, fall = 0.9 },
		hinge = V(0.12, 0.6, -0.25), hingeRoll = true,
		keys = {
			base(FO),
			{ t = 0.07, tr = -3, hf = 1 },
			{ t = 0.15, hand = V(0.2, 0.7, -0.1), grab = 1 },
			{ t = 0.24, hand = V(0.3, 0.85, -0.25), cov = -150, tp = 4, gp = V(0, -0.04, 0.08) },
			{ t = 0.30, tp = 0, gp = ZERO },
			{ t = 0.36, hand = m(-0.03, -0.25, 0), grab = 1, hm = 1 },
			{ t = 0.44, hand = m(-0.5, -0.55, 0.1), mag = V(-0.5, -0.45, 0.1), rz = -12, tr = -10, tp = 6, gp = V(0.05, -0.12, 0.16) },
			{ t = 0.50, hand = m(-0.7, -0.8, 0.2), grab = 0.3, mag = V(-0.8, -0.8, 0.2), rz = -40, tr = -4, tp = 0, gp = ZERO },
			{ t = 0.54, hand = m(-0.8, -0.85, 0.2), grab = 0, mag = TOSS, rx = 200, rz = -120, fall = true, hm = 0 },
			{ t = 0.62, hand = MP + POUCH, grab = 1, mag = POUCH, rx = 0, rz = 0, hm = 1 },
			{ t = 0.70, hand = m(-0.3, -0.5, 0.05), mag = V(-0.3, -0.4, 0.05) },
			{ t = 0.75, hand = m(-0.03, -0.25, 0), mag = ZERO, gp = V(0, 0.05, -0.16) },
			{ t = 0.78, hand = m(-0.03, 0.05, 0), grab = 0.6, gp = ZERO, hm = 0 },
			{ t = 0.86, hand = V(0.3, 0.8, -0.25) },
			{ t = 0.88, hand = V(0.3, 0.85, -0.25), grab = 1 },
			{ t = 0.93, hand = V(0.15, 0.72, -0.2), cov = 0 },
			{ t = 0.96, hand = V(0.05, 0.66, -0.2) },
			{ t = 1, hand = FO, grab = 0, tr = 0, hf = 0 },
		},
		aux = function(u, c)
			local out = {}
			if u >= 0.78 and u < 0.93 then
				for i = 0, 3 do
					local x = smooth(seg(u, 0.78 + i * 0.015, 0.87 + i * 0.015))
					out[i + 1] = CF(c.MP + V(-0.03, 0.12, 0.0)):Lerp(CF(tray(i)), x)
				end
			end
			return out
		end,
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.22, snd = "CoverOpen", kick = { V(0, 0.4, 0.8), V(10, 0, 10) } },
			{ at = 0.42, snd = "MagOut", kick = { V(0.3, -0.8, 1.2), V(35, 0, -25) } },
			{ at = 0.75, snd = "MagIn", kick = { V(0, 1.8, 0), V(-35, 0, 22) } },
			{ at = 0.84, snd = "BeltIn" },
			{ at = 0.92, snd = "CoverClose", kick = { V(0, -0.5, 2.5), V(-20, 0, 0) } },
		},
	}
end

-- ================= M14: rock the mag out, stuff it in the pouch, pull a fresh one, hook it on the lip, heavy rock-in, pull the op-rod =================
function Defs.LONGSHOT(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -26, pitch = 14, yaw = 16, lift = V(-0.35, 0.6, 0.15), rise = 0.12, fall = 0.9 },
		keys = {
			base(FO),
			{ t = 0.07, tr = -6, hf = 1 },
			{ t = 0.15, hand = m(0, -0.1, 0), grab = 1, hm = 1 },
			{ t = 0.23, hand = m(0, -0.3, -0.25), mag = V(0, -0.12, -0.2), rx = 35, tr = -12, tp = 4 },
			{ t = 0.31, hand = m(-0.4, -0.7, 0.0), mag = V(-0.45, -0.65, 0.0), rx = 30, rz = -15, tr = -16, tp = 0, gp = V(0.04, -0.08, 0.12) },
			{ t = 0.40, hand = m(-0.95, -0.85, 0.3), mag = V(-0.95, -0.75, 0.3), rx = 0, rz = -25, tr = -8, gp = ZERO },
			{ t = 0.44, hand = m(-1.05, -0.95, 0.3), mag = V(-1.1, -1.0, 0.35), fall = true, hm = 0 },
			{ t = 0.52, hand = MP + POUCH, grab = 1, mag = POUCH, rx = 0, rz = 0, tr = -12, hm = 1 },
			{ t = 0.60, hand = m(-0.3, -0.5, 0.0), mag = V(-0.3, -0.45, 0.0), rx = 25 },
			{ t = 0.68, hand = m(0, -0.3, -0.25), mag = V(0, -0.2, -0.22), rx = 30, tp = 3 },
			{ t = 0.75, hand = m(0, -0.1, 0.08), mag = ZERO, rx = 0, tp = 0, tr = -6, gp = V(0, 0.07, -0.18) },
			{ t = 0.80, hand = m(0, -0.2, 0), grab = 0.5, gp = ZERO, tr = -4, hm = 0 },
			{ t = 0.86, hand = V(0.17, 0.5, -0.3), grab = 1 },
			{ t = 0.92, hand = V(0.17, 0.5, 0.2), cyc = 0.5, ty = 3 },
			{ t = 0.97, hand = V(0.17, 0.5, -0.25), cyc = 0, ty = 0 },
			{ t = 1, hand = FO, grab = 0, tr = 0, hf = 0 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.30, snd = "MagOut", pitch = 0.9, kick = { V(0.3, -0.6, 1.0), V(30, 0, -30) } },
			{ at = 0.75, snd = "MagIn", pitch = 0.85, vol = 1.2, kick = { V(0, 1.8, 0.4), V(-50, 0, 32) } },
			{ at = 0.92, snd = "Bolt", pitch = 0.85, kick = { V(0, 0, 2.8), V(0, 0, 0) } },
		},
	}
end

-- ================= ROUND-FED GUNS: only the rounds that are missing get loaded, one at a time =================
-- a.n = rounds to load, a.rr = { Open, Per, Close } seconds (WeaponConfig RoundReload), a.T = total seconds (= Open + n * Per + Close).
-- Every round is carried IN the left hand (hand key positions are final, hf = 1), pushed into the gun, and vanishes into the receiver.
local HOLD = V(0, 0.1, 0) -- a carried round / shell sits just above the fist, pinched between the fingers

-- ================= AWP: work the bolt, roll the rifle, drop each missing round into the side port with the left hand, close the bolt =================
function Defs.HALO50(a)
	local FO, T, n, rr = a.FO, a.T, a.n, a.rr
	local O, Pr, Cl = rr.Open, rr.Per, rr.Close
	local function f(s) return s / T end
	local pouch, above, into = V(0.85, -0.55, 0.05), V(0.42, 0.66, -0.18), V(0.06, 0.37, -0.18)
	local bolt, boltBack = V(0.25, 0.4, 0.1), V(0.25, 0.4, 0.42)
	local keys = {
		{ t = 0, hand = FO, grab = 0, mag = ZERO, rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0, tr = 0, tp = 0, ty = 0, gp = ZERO, hm = 0, hf = 0 },
		{ t = f(0.10), tr = 12, hf = 1 },
		{ t = f(0.30), hand = bolt, grab = 1 },
		{ t = f(0.50), hand = boltBack, cyc = 0.47, ty = 3, tr = -10 },
		{ t = f(O - 0.05), tr = -32, ty = 0, grab = 0.6 },
	}
	local events = { { at = f(0.02), snd = "ReloadStart" }, { at = f(0.5), snd = "BoltOpen", kick = { V(0, 0, 1.6), V(-12, 0, 8) } } }
	for i = 0, n - 1 do
		local s0 = O + i * Pr
		table.insert(keys, { t = f(s0), hand = pouch, grab = 1, tr = -32 })
		table.insert(keys, { t = f(s0 + 0.45 * Pr), hand = above, grab = 1 })
		table.insert(keys, { t = f(s0 + 0.78 * Pr), hand = into, grab = 0.5 })
		table.insert(events, { at = f(s0 + 0.78 * Pr), snd = "RoundIn", kick = { V(0, 0.1, 0.3), V(-5, 0, 3) } })
	end
	local C0 = O + n * Pr
	table.insert(keys, { t = f(C0 + 0.12), hand = boltBack, grab = 1, cyc = 0.47, tr = 12 })
	table.insert(keys, { t = f(C0 + 0.34), hand = bolt, cyc = 0, tr = 12 })
	table.insert(keys, { t = f(C0 + Cl * 0.82), tr = 0, grab = 1 })
	table.insert(keys, { t = 1, hand = FO, grab = 0, hf = 0, tr = 0 })
	table.insert(events, { at = f(C0 + 0.34), snd = "BoltClose", kick = { V(0, 0, 3.4), V(-18, 0, 0) } })
	return {
		tilt = { roll = 0, pitch = 14, yaw = 14, lift = V(-0.3, 0.6, 0.15), rise = 0.08, fall = 0.94 },
		keys = keys, noWarp = true,
		aux = function(u, c)
			local out = {}
			for i = 0, n - 1 do
				local s0 = O + i * Pr
				if u >= f(s0) and u < f(s0 + 0.8 * Pr) then
					out[i + 1] = CF(c.hand(u) + HOLD) -- rides in the hand until it sinks into the receiver
				end
			end
			return out
		end,
		events = events,
	}
end

-- ================= Remington 870: roll the gun, thumb each MISSING shell up into the loading port (each one jolts the gun), rack the pump =================
function Defs.BREACHER(a)
	local FO, T, n, rr = a.FO, a.T, a.n, a.rr
	local O, Pr, Cl = rr.Open, rr.Per, rr.Close
	local function f(s) return s / T end
	local pouch, below, up = V(-0.9, -0.6, -0.1), V(0, -0.12, -0.45), V(0, 0.2, -0.45)
	local pumpFwd, pumpBack = V(0, 0.2, -1.2), V(0, 0.2, -0.7)
	local keys = {
		{ t = 0, hand = FO, grab = 0, mag = ZERO, rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0, tr = 0, tp = 0, ty = 0, gp = ZERO, hm = 0, hf = 0 },
		{ t = f(O * 0.6), tr = 0, hf = 1, grab = 0.6 },
	}
	local events = { { at = f(0.02), snd = "ReloadStart" } }
	for i = 0, n - 1 do
		local s0 = O + i * Pr
		table.insert(keys, { t = f(s0), hand = pouch, grab = 1 })
		table.insert(keys, { t = f(s0 + 0.4 * Pr), hand = below, grab = 1 })
		table.insert(keys, { t = f(s0 + 0.76 * Pr), hand = up, grab = 0.6 })
		table.insert(events, { at = f(s0 + 0.76 * Pr), snd = "ShellIn", kick = { V(0, 0.15, 0.5), V(-8, 0, 4) } })
	end
	local C0 = O + n * Pr
	table.insert(keys, { t = f(C0 + 0.12), hand = pumpFwd, grab = 1 })
	table.insert(keys, { t = f(C0 + 0.36), hand = pumpBack, cyc = 0.5 })
	table.insert(keys, { t = f(C0 + 0.6), hand = pumpFwd, cyc = 0 })
	table.insert(keys, { t = 1, hand = FO, grab = 0, hf = 0 })
	table.insert(events, { at = f(C0 + 0.36), snd = "PumpBack", kick = { V(0, 0, 2.8), V(0, 0, 0) } })
	table.insert(events, { at = f(C0 + 0.6), snd = "PumpForward", kick = { V(0, 0, -2.4), V(-10, 0, 0) } })
	return {
		tilt = { roll = -55, pitch = 18, yaw = 10, lift = V(-0.35, 0.55, 0.15), rise = 0.08, fall = 0.94 },
		keys = keys, noWarp = true,
		aux = function(u, c)
			local out = {}
			for i = 0, n - 1 do
				local s0 = O + i * Pr
				if u >= f(s0) and u < f(s0 + 0.8 * Pr) then
					out[i + 1] = CF(c.hand(u) + HOLD)
				end
			end
			return out
		end,
		events = events,
	}
end

-- ================= Glock: press the release (mag drops free), fresh mag off the belt, slam it, slingshot the slide =================
function Defs.V9(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -28, pitch = 12, yaw = 10, lift = V(-0.35, 0.5, 0.1), rise = 0.12, fall = 0.9 },
		keys = {
			base(FO),
			{ t = 0.06, tr = -5, hf = 1 },
			{ t = 0.14, hand = m(0, -0.05, 0.05), grab = 0.8, hm = 0 },
			{ t = 0.20, hand = m(0, -0.12, 0.05), tr = -9, tp = 4 },
			{ t = 0.25, hand = m(-0.25, -0.3, 0.1), grab = 0.3, mag = V(0, -1.0, 0.1), rx = 10, tr = -14, tp = 7, gp = V(0.02, -0.05, 0.1) },
			{ t = 0.30, hand = m(-0.35, -0.45, 0.15), mag = V(-0.2, -3.0, 0.2), rx = 40, fall = true, tp = 0, gp = ZERO },
			{ t = 0.42, hand = m(-0.5, -0.65, 0.25), grab = 1, mag = V(-0.5, -0.55, 0.25), rx = 0, tr = -10, hm = 1 },
			{ t = 0.52, hand = m(-0.25, -0.45, 0.08), mag = V(-0.25, -0.4, 0.08) },
			{ t = 0.58, hand = m(0, -0.3, 0), mag = V(0, -0.28, 0) },
			{ t = 0.62, hand = m(0, 0, 0), mag = ZERO, tr = -4, gp = V(0, 0.06, -0.1) },
			{ t = 0.67, hand = m(0, -0.15, 0), grab = 0.5, gp = ZERO, hm = 0 },
			{ t = 0.74, hand = V(0, 0.46, 0.1), grab = 1 },
			{ t = 0.82, hand = V(0, 0.46, 0.52), cyc = 0.42, tp = 5 },
			{ t = 0.86, hand = V(0, 0.46, 0.1), cyc = 0, tp = 0 },
			{ t = 0.93, hand = FO, grab = 0, tr = 0, hf = 0 },
			{ t = 1 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.24, snd = "MagOut", kick = { V(0.2, 0.6, 0.6), V(30, 0, -20) } },
			{ at = 0.62, snd = "MagIn", kick = { V(0, 1.4, 0), V(-35, 0, 22) } },
			{ at = 0.82, snd = "Bolt", pitch = 1.1, kick = { V(0, 0, 2.2), V(0, 0, 0) } },
		},
	}
end

-- ================= .44 Magnum: flick the cylinder OUT on its crane, punch the spent casings out, thumb the MISSING rounds in ONE BY ONE, flick it SHUT =================
function Defs.MAGNUM(a)
	local MP, FO, T, n, rr = a.MP, a.FO, a.T, a.n, a.rr
	local O, Pr, Cl = rr.Open, rr.Per, rr.Close
	local function f(s) return s / T end
	-- the cylinder swings about its crane (0.1 left + 0.1 below its centre): offset of the cylinder centre after turning th degrees
	local function sw(th)
		local c, s = math.cos(math.rad(th)), math.sin(math.rad(th))
		return V(0.1 * (c - s) - 0.1, 0.1 * (s + c) - 0.1, 0)
	end
	local OPEN = 120 -- multiple of 60: the chambers line up with the closed cylinder
	local function cylHand(th, dz) return MP + sw(th) + V(-0.15, 0, dz or 0.05) end
	local cylOpenCF = a.MPcf * CF(sw(OPEN)) * ang(0, 0, OPEN)
	local function chamberPos(j) return (cylOpenCF * ang(0, 0, 60 * j) * CF(0.14, 0, 0)).Position end
	local pouch = MP + V(-1.0, -0.8, 0.3)
	local keys = {
		base(FO),
		{ t = f(0.08), tr = -6, hf = 1 },
		{ t = f(0.2), hand = cylHand(0), grab = 1 },
		{ t = f(0.36), hand = cylHand(60), mag = sw(60), rz = 60, tr = -12 },
		{ t = f(0.52), hand = cylHand(OPEN), mag = sw(OPEN), rz = OPEN, tr = -18, gp = V(0.04, -0.04, 0.1) },
		{ t = f(0.58), grab = 0.5, gp = ZERO },
		{ t = f(0.66), hand = V(0, 0.55, -0.95), grab = 1, tp = 6 },
		{ t = f(0.78), hand = V(0, 0.55, -0.7), tp = 30, tr = -10 },
		{ t = f(0.88), tp = 30 },
	}
	local events = {
		{ at = f(0.02), snd = "ReloadStart" },
		{ at = f(0.36), snd = "CylinderOpen", kick = { V(0.2, 0, 0.4), V(0, 0, -22) } },
		{ at = f(0.78), snd = "CasingOut", kick = { V(0, 0.6, 0.4), V(20, 0, 0) } },
	}
	-- one round at a time: pouch -> behind its chamber -> pushed in -> next
	for j = 0, n - 1 do
		local s0 = O + j * Pr
		local ch = chamberPos(j) - HOLD
		table.insert(keys, { t = f(s0 + 0.0), hand = pouch, grab = 1, tp = 0, tr = -16 })
		table.insert(keys, { t = f(s0 + 0.45 * Pr), hand = ch + V(0, 0, 0.55), grab = 1 })
		table.insert(keys, { t = f(s0 + 0.78 * Pr), hand = ch, grab = 0.5, gp = V(0, 0, -0.05) })
		table.insert(events, { at = f(s0 + 0.78 * Pr), snd = "RoundIn", kick = { V(0, 0.2, 0.6), V(-10, 0, 6) } })
	end
	local C0 = O + n * Pr
	table.insert(keys, { t = f(C0 + 0.04), hand = cylHand(OPEN), grab = 1, gp = ZERO })
	table.insert(keys, { t = f(C0 + 0.3), hand = cylHand(0), mag = ZERO, rz = 0, tr = 12, tp = -8 })
	table.insert(keys, { t = f(C0 + 0.4), tr = 0, tp = 0 })
	table.insert(keys, { t = 1, hand = FO, grab = 0, hf = 0 })
	table.insert(events, { at = f(C0 + 0.3), snd = "CylinderClose", kick = { V(0, 1.4, 0), V(-35, 0, 30) } })
	local EJ0, EJ1 = f(0.78), f(0.98) -- casings punched out
	return {
		tilt = { roll = -22, pitch = 22, yaw = 12, lift = V(-0.3, 0.45, 0.2), rise = 0.08, fall = 0.94 },
		keys = keys, noWarp = true,
		aux = function(u, c)
			local out = {}
			local cyl = c.MPcf * c.magRel(u)
			-- spent casings (only as many as you fired): sit in the open cylinder, get punched out and fall
			if u > f(0.3) and u < EJ1 + 0.03 then
				for k = 0, n - 1 do
					local x = seg(u, EJ0 + k * 0.004, EJ1)
					local off = V((k % 2 == 0 and 1 or -1) * 0.5 * x, 0.3 * x - 3.2 * x * x, 0.25 * x)
					out[k + 1] = CF(off) * cyl * ang(0, 0, k * 60) * CF(0.14, 0, 0)
				end
			end
			-- fresh rounds: carried in the hand one at a time, then they sit in their chamber until the cylinder shuts
			for j = 0, n - 1 do
				local s0 = O + j * Pr
				if u >= f(s0) and u < f(C0 + 0.3) then
					if u < f(s0 + 0.78 * Pr) then
						out[7 + j] = CF(c.hand(u) + HOLD)
					else
						out[7 + j] = cyl * ang(0, 0, 60 * j) * CF(0.14, 0, 0)
					end
				end
			end
			return out
		end,
		events = events,
	}
end

-- ================= engine =================
-- v6: keys may also set tp / ty (extra pitch / yaw of the whole gun, degrees) and gp (extra gun shove, Vector3) - used for gun jerks on mag yanks
local function prepare(keys)
	table.sort(keys, function(x, y) return x.t < y.t end)
	local prev
	for _, k in ipairs(keys) do
		if prev then
			for f, v in pairs(prev) do
				if k[f] == nil and f ~= "fall" then k[f] = v end
			end
		end
		prev = k
	end
end

local function sample(keys, u)
	local n = #keys
	if u <= keys[1].t then return keys[1], keys[1], 0 end
	if u >= keys[n].t then return keys[n], keys[n], 0 end
	for i = 1, n - 1 do
		local k0, k1 = keys[i], keys[i + 1]
		if u < k1.t then
			return k0, k1, smooth((u - k0.t) / math.max(k1.t - k0.t, 1e-4))
		end
	end
	return keys[n], keys[n], 0
end

local function num(a, b, x) return a + (b - a) * x end

-- opts (all optional): n = rounds to load, T = reload seconds, rr = { Open, Per, Close } (round-fed guns), magCenter = centre of the mag
-- parts relative to the mag pivot (gun units; where the fist closes on the mag)
function ReloadAnims.Make(modelId, P, s, opts)
	opts = opts or {}
	local def = Defs[modelId] or Defs.VX9
	local MPcf = CF(P.MagPivot.Position / s) * P.MagPivot.Rotation
	local rr = opts.rr or { Open = 0.9, Per = 0.5, Close = 0.7 }
	local n = opts.n or 5
	local T = opts.T or (rr.Open + n * rr.Per + rr.Close)
	local magCenter = opts.magCenter or ZERO
	local spec = def({ MP = MPcf.Position, MPcf = MPcf, FO = P.Fore.Position / s, n = n, T = T, rr = rr })
	prepare(spec.keys)
	-- the resting left hand hangs HAND_DROP under the handguard (GunClient). Reload keys are FINAL positions, so the first/last key (the resting
	-- hand) is lowered by the same amount here and the hand never jumps when a reload starts or ends.
	local FOv = P.Fore.Position / s
	local FOD = FOv - V(0, ReloadAnims.HAND_DROP / s, 0)
	for _, k in ipairs(spec.keys) do
		k.hf = 1
		if k.hand == FOv then k.hand = FOD end
	end
	-- charging handle / slide rack: shorter pull and the left hand never goes back toward the camera
	local ZMAX = 0.18
	for _, k in ipairs(spec.keys) do
		if k.cyc and k.cyc > 0 and k.hand.Z > -0.35 then
			local shift = math.min(math.max(k.cyc * 0.5, k.hand.Z - ZMAX), k.cyc * 0.9) -- hand and handle move back by the same amount
			k.cyc -= shift
			k.hand = V(k.hand.X, k.hand.Y, k.hand.Z - shift)
		end
	end
	-- the last part of every reload (charge / rack / pump) plays a bit slower: authored time A.. maps to real time A2..
	local WA, WA2 = 0.76, 0.68
	local function toAuthored(u) if u <= WA2 then return u * WA / WA2 end return WA + (u - WA2) * (1 - WA) / (1 - WA2) end
	local function toReal(t) if t <= WA then return t * WA2 / WA end return WA2 + (t - WA) * (1 - WA2) / (1 - WA) end
	if spec.noWarp then -- round-fed guns are authored in real seconds already
		toAuthored, toReal = function(u) return u end, function(t) return t end
	end
	for _, e in ipairs(spec.events) do e.at = toReal(e.at) end
	local keys, tl = spec.keys, spec.tilt
	-- keep the action on screen: the mag swap is authored low (real reload height); squash anything that dips below
	-- the magwell so the hand/mag stay inside the camera frame. The intentional mag "drop" (< -1.2) stays offscreen.
	local y0, DIP = MPcf.Position.Y, 0.8 -- v5.6: 0.55 -> 0.8 (hands + mag travel further, easier to see)
	local function sq(v, rel)
		if v == FOD then return v end
		local d = rel and v.Y or (v.Y - y0)
		if d < 0 and d > -1.2 then d *= DIP; return V(v.X, (rel and 0 or y0) + d, v.Z) end
		return v
	end
	-- v5.6: a bit more prominent (0.15 -> 0.45): the gun tips toward the center so the mag swap reads clearly, but it stays near the hip hold
	local TILT = 0.45
	tl.roll, tl.pitch, tl.yaw, tl.lift = tl.roll * TILT, tl.pitch * TILT, tl.yaw * TILT, tl.lift * TILT
	local neutral = { tilt = IDENT, mag = IDENT, hand = P.Fore.Position, grab = 0, fall = false }

	local function handAt(u)
		local k0, k1, x = sample(keys, u)
		return sq(k0.hand:Lerp(k1.hand, x), false)
	end
	local function magRelAt(u)
		local k0, k1, x = sample(keys, u)
		return CF(sq(k0.mag:Lerp(k1.mag, x), true)) * ang(num(k0.rx, k1.rx, x), num(k0.ry, k1.ry, x), num(k0.rz, k1.rz, x))
	end
	local ctx = { MP = MPcf.Position, MPcf = MPcf, hand = handAt, magRel = magRelAt }
	local hinge = spec.hinge

	local function Pose(u)
		if u <= 0 or u >= 1 then return neutral end
		u = toAuthored(u)
		local k0, k1, x = sample(keys, u)
		local e = smooth(seg(u, 0, tl.rise)) * (1 - smooth(seg(u, tl.fall, 1)))
		local pose = {}
		local tr = num(k0.tr or 0, k1.tr or 0, x)
		local tp, ty = num(k0.tp or 0, k1.tp or 0, x), num(k0.ty or 0, k1.ty or 0, x)
		local gp = (k0.gp or ZERO):Lerp(k1.gp or ZERO, x) -- extra whole-gun shove (studs): the gun jerks when a mag is yanked / slammed
		pose.tilt = CF((tl.lift + gp) * e) * ang((tl.pitch + tp) * e, (tl.yaw + ty) * e, (tl.roll + tr) * e)
		pose.grab = num(k0.grab, k1.grab, x)
		local mp = sq(k0.mag:Lerp(k1.mag, x), true)
		local magRot = ang(num(k0.rx, k1.rx, x), num(k0.ry, k1.ry, x), num(k0.rz, k1.rz, x))
		pose.mag = CF(mp * s) * magRot
		-- v7: hm = the hand is glued to the mag (fist centred on the mag), hf = hand key is final (no resting-grip drop / offset)
		local hm, hf = num(k0.hm or 0, k1.hm or 0, x), num(k0.hf or 0, k1.hf or 0, x)
		local handPos = sq(k0.hand:Lerp(k1.hand, x), false)
		if hm > 0 then
			local magCtr = (MPcf * CF(mp) * magRot * CF(magCenter)).Position
			handPos = handPos:Lerp(magCtr, hm)
		end
		local hold = math.max(hm, hf)
		pose.hold = hold -- GunClient skips the resting-grip drop by this much
		pose.hand = (handPos + V(-0.13, 0.08, 0.1) * pose.grab * (1 - hold)) * s
		pose.fall = k0.fall == true
		local cyc = num(k0.cyc, k1.cyc, x)
		if cyc ~= 0 or k0.cyc ~= 0 or k1.cyc ~= 0 then pose.cycleZ = cyc * s end
		if hinge then
			local cov = num(k0.cov, k1.cov, x)
			pose.cover = CF(hinge * s) * (spec.hingeRoll and ang(0, 0, cov) or ang(cov, 0, 0)) * CF(-hinge * s)
		end
		if spec.aux then
			local raw, out = spec.aux(u, ctx), {}
			for id, cf in pairs(raw) do out[id] = CF(cf.Position * s) * cf.Rotation end
			pose.aux = out
		end
		return pose
	end

	return { Pose = Pose, Events = spec.events }
end

ReloadAnims.Defs = Defs
return ReloadAnims

