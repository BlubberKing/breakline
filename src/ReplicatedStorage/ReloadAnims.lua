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
-- Positions are unscaled gun space (the same numbers as GunModels). m(x,y,z) = offset from the mag pivot.
local ReloadAnims = {}

local V, CF = Vector3.new, CFrame.new
local rad = math.rad
local function ang(x, y, z) return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0)) end
local function seg(u, a, b) return math.clamp((u - a) / (b - a), 0, 1) end
local function smooth(x) return x * x * (3 - 2 * x) end

local IDENT = CF()
local Defs = {}

-- ================= M4A1: drop the mag, fresh mag from the pouch, slap, charge =================
function Defs.VX9(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -30, pitch = 12, yaw = 10, lift = V(-0.3, 0.55, 0.25), rise = 0.14, fall = 0.86 },
		keys = {
			{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
			{ t = 0.10 },
			{ t = 0.19, hand = m(0, 0, 0), grab = 1 },
			{ t = 0.27 },
			{ t = 0.37, hand = m(-0.45, -0.5, 0.1), mag = V(-0.45, -0.5, 0.1), rx = 15, rz = -10 },
			{ t = 0.46, hand = m(-0.8, -0.8, 0.35), grab = 0.3, mag = V(-1.1, -3.5, 0.4), rx = 50, rz = -30, fall = true },
			{ t = 0.47, mag = V(-0.9, -3.0, 0.4), rx = 0, rz = 0, fall = true },
			{ t = 0.53, hand = m(-0.9, -0.8, 0.35), grab = 1, mag = V(-0.9, -0.8, 0.35), fall = false },
			{ t = 0.67, hand = m(-0.3, -0.5, 0.05), mag = V(-0.3, -0.5, 0.05) },
			{ t = 0.75, hand = m(0, -0.14, 0), mag = V(0, -0.14, 0) },
			{ t = 0.80, hand = m(0, 0, 0), mag = V(0, 0, 0) },
			{ t = 0.83 },
			{ t = 0.88, hand = V(-0.1, 0.6, -0.1) },
			{ t = 0.93, hand = V(-0.1, 0.6, 0.3), cyc = 0.35 },
			{ t = 0.97, hand = V(-0.1, 0.6, -0.1), cyc = 0 },
			{ t = 1, hand = FO, grab = 0 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.27, snd = "MagOut" },
			{ at = 0.75, snd = "MagIn", kick = { V(0, 1.5, 0), V(-40, 0, 30) } },
			{ at = 0.93, snd = "Bolt", kick = { V(0, 0, 2.5), V(0, 0, 0) } },
		},
	}
end

-- ================= AK-47: rock the mag out forward, hook the new one in front and rock it back, charge from the side =================
function Defs.KR47(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -26, pitch = 14, yaw = 12, lift = V(-0.3, 0.55, 0.2), rise = 0.14, fall = 0.86 },
		keys = {
			{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
			{ t = 0.10 },
			{ t = 0.18, hand = m(0, -0.22, 0.05), grab = 1 },
			{ t = 0.26 },
			{ t = 0.36, hand = m(0, -0.35, -0.3), mag = V(0, -0.12, -0.22), rx = 40 },
			{ t = 0.45, hand = m(-0.6, -0.9, 0.05), mag = V(-0.7, -0.8, -0.05), rx = 50, rz = -20 },
			{ t = 0.50, hand = m(-0.8, -0.9, 0.2), grab = 0.3, mag = V(-0.9, -3.4, 0.0), rx = 70, rz = -40, fall = true },
			{ t = 0.52, mag = V(-0.9, -3.0, 0.2), rx = 0, rz = 0, fall = true },
			{ t = 0.58, hand = m(-0.95, -0.95, 0.3), grab = 1, mag = V(-0.9, -0.75, 0.3), fall = false },
			{ t = 0.69, hand = m(-0.1, -0.55, -0.2), mag = V(-0.05, -0.38, -0.3), rx = 40 },
			{ t = 0.76, hand = m(0, -0.38, -0.3), mag = V(0, -0.2, -0.28), rx = 38 },
			{ t = 0.82, hand = m(0, -0.22, 0.12), mag = V(0, 0, 0), rx = 0 },
			{ t = 0.85 },
			{ t = 0.89, hand = V(0.17, 0.57, -0.6) },
			{ t = 0.94, hand = V(0.17, 0.57, -0.15), cyc = 0.45 },
			{ t = 0.97, hand = V(0.17, 0.57, -0.55), cyc = 0 },
			{ t = 1, hand = FO, grab = 0 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.26, snd = "MagOut" },
			{ at = 0.78, snd = "MagIn", kick = { V(0, 1.2, 0.6), V(-50, 0, 30) } },
			{ at = 0.94, snd = "Bolt", kick = { V(0, 0, 2.5), V(0, 0, 0) } },
		},
	}
end

-- ================= FAMAS: bullpup, gun turned hard toward the center, mag swap behind the grip, cocking lever on top =================
function Defs.HX3(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -50, pitch = 20, yaw = 12, lift = V(-0.4, 0.7, -0.3), rise = 0.14, fall = 0.86 },
		keys = {
			{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
			{ t = 0.10 },
			{ t = 0.20, hand = m(0, -0.1, 0), grab = 1 },
			{ t = 0.27 },
			{ t = 0.38, hand = m(-0.15, -0.65, 0.05), mag = V(-0.15, -0.55, 0.05), rx = 8, rz = -8 },
			{ t = 0.46, hand = m(-0.6, -0.7, 0.1), grab = 0.3, mag = V(-0.3, -2.8, 0.1), rx = 40, rz = -30, fall = true },
			{ t = 0.47, mag = V(-0.5, -2.6, 0.1), rx = 0, rz = 0, fall = true },
			{ t = 0.54, hand = m(-0.8, -0.55, 0.05), grab = 1, mag = V(-0.8, -0.45, 0.05), fall = false },
			{ t = 0.68, hand = m(-0.2, -0.5, 0.05), mag = V(-0.2, -0.4, 0.05) },
			{ t = 0.76, hand = m(0, -0.2, 0), mag = V(0, -0.12, 0) },
			{ t = 0.80, hand = m(0, -0.1, 0), mag = V(0, 0, 0) },
			{ t = 0.83 },
			{ t = 0.88, hand = V(0, 0.74, -0.3) },
			{ t = 0.93, hand = V(0, 0.74, 0.15), cyc = 0.45 },
			{ t = 0.97, hand = V(0, 0.74, -0.25), cyc = 0 },
			{ t = 1, hand = FO, grab = 0 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.27, snd = "MagOut" },
			{ at = 0.77, snd = "MagIn", kick = { V(0, 1.2, 0.4), V(-35, 0, 25) } },
			{ at = 0.93, snd = "Bolt", kick = { V(0, 0, 2), V(0, 0, 0) } },
		},
	}
end

-- ================= MP7: very fast mag flip, then pull the charging knob =================
function Defs.WASP(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -34, pitch = 8, yaw = 14, lift = V(-0.35, 0.5, 0.2), rise = 0.1, fall = 0.9 },
		keys = {
			{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
			{ t = 0.07 },
			{ t = 0.15, hand = m(0, -0.1, 0), grab = 1 },
			{ t = 0.20 },
			{ t = 0.29, hand = m(-0.7, -0.6, 0.1), mag = V(-0.7, -0.5, 0.1), rz = -35 },
			{ t = 0.35, hand = m(-0.8, -0.7, 0.2), grab = 0.3, mag = V(-1.2, -3.2, 0.2), rz = -80, fall = true },
			{ t = 0.36, mag = V(-1.0, -3.0, 0.3), rz = 0, fall = true },
			{ t = 0.42, hand = m(-0.9, -0.75, 0.3), grab = 1, mag = V(-0.9, -0.7, 0.3), fall = false },
			{ t = 0.57, hand = m(-0.2, -0.45, 0.05), mag = V(-0.2, -0.4, 0.05) },
			{ t = 0.64, hand = m(0, -0.14, 0), mag = V(0, -0.12, 0) },
			{ t = 0.68, hand = m(0, 0, 0), mag = V(0, 0, 0) },
			{ t = 0.76, hand = V(0.15, 0.56, -0.1) },
			{ t = 0.84, hand = V(0.15, 0.56, 0.3), cyc = 0.4 },
			{ t = 0.90, hand = V(0.15, 0.56, -0.05), cyc = 0 },
			{ t = 1, hand = FO, grab = 0 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.20, snd = "MagOut" },
			{ at = 0.65, snd = "MagIn", kick = { V(0, 1.2, 0), V(-30, 0, 20) } },
			{ at = 0.84, snd = "Bolt", kick = { V(0, 0, 1.8), V(0, 0, 0) } },
		},
	}
end

-- ================= M249: pop the feed cover, swap the box, lay the belt, slam the cover =================
function Defs.ANVIL(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	local tray = function(i) return V(0, 0.56, -0.45 + i * 0.12) end
	return {
		tilt = { roll = -10, pitch = 12, yaw = 20, lift = V(-0.35, 0.45, 0.0), rise = 0.12, fall = 0.9 },
		hinge = V(0.13, 0.6, -0.25), hingeRoll = true,
		keys = {
			{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
			{ t = 0.07 },
			{ t = 0.15, hand = V(0.2, 0.7, -0.1), grab = 1 },
			{ t = 0.24, hand = V(0.3, 0.85, -0.25), cov = -125 },
			{ t = 0.30 },
			{ t = 0.36, hand = m(-0.03, -0.25, 0), grab = 1 },
			{ t = 0.40 },
			{ t = 0.48, hand = m(-0.5, -0.55, 0.1), mag = V(-0.5, -0.45, 0.1), rz = -12 },
			{ t = 0.54, hand = m(-0.7, -0.8, 0.2), grab = 0.3, mag = V(-0.8, -3.2, 0.2), rz = -40, fall = true },
			{ t = 0.55, mag = V(-0.9, -3.0, 0.3), rz = 0, fall = true },
			{ t = 0.62, hand = m(-0.9, -0.85, 0.3), grab = 1, mag = V(-0.9, -0.75, 0.3), fall = false },
			{ t = 0.70, hand = m(-0.3, -0.5, 0.05), mag = V(-0.3, -0.4, 0.05) },
			{ t = 0.75, hand = m(-0.03, -0.25, 0), mag = V(0, 0, 0) },
			{ t = 0.78, hand = m(-0.03, 0.05, 0), grab = 0.6 },
			{ t = 0.86, hand = V(0.3, 0.8, -0.25) },
			{ t = 0.88, hand = V(0.3, 0.85, -0.25), grab = 1 },
			{ t = 0.93, hand = V(0.15, 0.72, -0.2), cov = 0 },
			{ t = 0.96, hand = V(0.05, 0.66, -0.2) },
			{ t = 1, hand = FO, grab = 0 },
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
			{ at = 0.22, snd = "Bolt", pitch = 0.75, vol = 0.8 },
			{ at = 0.40, snd = "MagOut" },
			{ at = 0.75, snd = "MagIn", kick = { V(0, 1.5, 0), V(-30, 0, 20) } },
			{ at = 0.84, snd = "MagIn", pitch = 1.8, vol = 0.4 },
			{ at = 0.92, snd = "Bolt", pitch = 0.7, vol = 1, kick = { V(0, -0.5, 2.5), V(-20, 0, 0) } },
		},
	}
end

-- ================= M14: mag goes to the pouch and comes back, heavy seat, pull the op-rod =================
function Defs.LONGSHOT(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -26, pitch = 14, yaw = 16, lift = V(-0.35, 0.6, 0.15), rise = 0.14, fall = 0.86 },
		keys = {
			{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
			{ t = 0.10 },
			{ t = 0.18, hand = m(0, -0.1, 0), grab = 1 },
			{ t = 0.26 },
			{ t = 0.38, hand = m(-0.3, -0.55, 0.1), mag = V(-0.3, -0.45, 0.1), rx = 10, rz = -10 },
			{ t = 0.50, hand = m(-0.95, -0.85, 0.3), mag = V(-0.95, -0.75, 0.3), rx = 0, rz = -25 },
			{ t = 0.60 },
			{ t = 0.65, rz = 0 },
			{ t = 0.74, hand = m(-0.3, -0.5, 0.1), mag = V(-0.3, -0.4, 0.1) },
			{ t = 0.81, hand = m(0, -0.15, 0), mag = V(0, -0.12, 0) },
			{ t = 0.85, hand = m(0, 0, 0), mag = V(0, 0, 0) },
			{ t = 0.89, hand = V(0.17, 0.5, -0.3) },
			{ t = 0.94, hand = V(0.17, 0.5, 0.2), cyc = 0.5 },
			{ t = 0.98, hand = V(0.17, 0.5, -0.25), cyc = 0 },
			{ t = 1, hand = FO, grab = 0 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.26, snd = "MagOut", pitch = 0.9 },
			{ at = 0.83, snd = "MagIn", pitch = 0.85, vol = 1.2, kick = { V(0, 1.8, 0.4), V(-45, 0, 30) } },
			{ at = 0.94, snd = "Bolt", pitch = 0.85, kick = { V(0, 0, 2.8), V(0, 0, 0) } },
		},
	}
end

-- ================= AWP: work the bolt, roll the rifle, push 5 loose rounds in from the left side, close the bolt =================
function Defs.HALO50(a)
	local FO = a.FO
	local pouch, side, inside = V(-0.6, -0.35, 0.1), V(-0.4, 0.3, -0.3), V(-0.1, 0.38, -0.3)
	local keys = {
		{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0, tr = 0 },
		{ t = 0.06 },
		{ t = 0.14, hand = V(0.22, 0.4, 0.1), grab = 1, tr = 15 },
		{ t = 0.22, hand = V(0.22, 0.4, 0.42), cyc = 0.47 },
		{ t = 0.26, tr = -32 },
	}
	local events = { { at = 0.02, snd = "ReloadStart" }, { at = 0.22, snd = "Bolt", pitch = 0.9 } }
	for i = 0, 4 do
		local t0 = 0.28 + i * 0.1
		table.insert(keys, { t = t0, hand = pouch, grab = 1, tr = -32 })
		table.insert(keys, { t = t0 + 0.055, hand = side, grab = 1 })
		table.insert(keys, { t = t0 + 0.075, hand = inside, grab = 0.4 })
		table.insert(events, { at = t0 + 0.075, snd = "MagIn", pitch = 1.5, vol = 0.45 })
	end
	table.insert(keys, { t = 0.80, hand = V(0.22, 0.4, 0.42), grab = 1, cyc = 0.47, tr = 15 })
	table.insert(keys, { t = 0.9, hand = V(0.22, 0.4, 0.1), cyc = 0 })
	table.insert(keys, { t = 0.95, tr = 0 })
	table.insert(keys, { t = 1, hand = FO, grab = 0 })
	table.insert(events, { at = 0.9, snd = "Bolt", kick = { V(0, 0, 3), V(-15, 0, 0) } })
	return {
		tilt = { roll = 0, pitch = 14, yaw = 14, lift = V(-0.3, 0.6, 0.15), rise = 0.12, fall = 0.9 },
		keys = keys,
		aux = function(u, c)
			local out = {}
			for i = 0, 4 do
				local t0 = 0.28 + i * 0.1
				if u >= t0 and u < t0 + 0.09 then
					local p
					if u < t0 + 0.075 then p = c.hand(u) + V(0, 0.04, 0)
					else p = inside:Lerp(inside + V(0.15, -0.05, 0), seg(u, t0 + 0.075, t0 + 0.09)) end
					out[i + 1] = CF(p) * ang(0, 90, 0)
				end
			end
			return out
		end,
		events = events,
	}
end

-- ================= Remington 870: roll the gun, push 6 shells into the port under the receiver, pump =================
function Defs.BREACHER(a)
	local FO = a.FO
	local pouch, below, port = V(-0.9, -0.6, 0.0), V(0, 0.0, -0.45), V(0, 0.13, -0.45)
	local keys = {
		{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
		{ t = 0.08 },
	}
	local events = { { at = 0.02, snd = "ReloadStart" } }
	for i = 0, 5 do
		local t0 = 0.12 + i * 0.1
		table.insert(keys, { t = t0, hand = pouch, grab = 1 })
		table.insert(keys, { t = t0 + 0.055, hand = below, grab = 1 })
		table.insert(keys, { t = t0 + 0.075, hand = port, grab = 0.5 })
		table.insert(events, { at = t0 + 0.075, snd = "MagIn", pitch = 1.3, vol = 0.5 })
	end
	table.insert(keys, { t = 0.77, hand = V(0, 0.32, -1.2), grab = 1 })
	table.insert(keys, { t = 0.85, hand = V(0, 0.32, -0.7), cyc = 0.5 })
	table.insert(keys, { t = 0.92, hand = V(0, 0.32, -1.2), cyc = 0 })
	table.insert(keys, { t = 1, hand = FO, grab = 0 })
	table.insert(events, { at = 0.84, snd = "Bolt", kick = { V(0, 0, 2.5), V(0, 0, 0) } })
	table.insert(events, { at = 0.92, snd = "Bolt", kick = { V(0, 0, -2), V(0, 0, 0) } })
	return {
		tilt = { roll = -55, pitch = 18, yaw = 10, lift = V(-0.35, 0.55, 0.15), rise = 0.1, fall = 0.9 },
		keys = keys,
		aux = function(u, c)
			local out = {}
			for i = 0, 5 do
				local t0 = 0.12 + i * 0.1
				if u >= t0 and u < t0 + 0.085 then
					local p
					if u < t0 + 0.075 then p = c.hand(u) + V(0, 0.03, 0.0)
					else p = (port + V(0, 0.03, 0)):Lerp(port + V(0, 0.18, 0), seg(u, t0 + 0.075, t0 + 0.085)) end
					out[i + 1] = CF(p) * ang(0, 0, 0)
				end
			end
			return out
		end,
		events = events,
	}
end

-- ================= Glock: drop the mag, fresh mag from the belt, slap, rack the slide =================
function Defs.V9(a)
	local MP, FO = a.MP, a.FO
	local function m(x, y, z) return MP + V(x, y, z) end
	return {
		tilt = { roll = -28, pitch = 12, yaw = 10, lift = V(-0.35, 0.5, 0.1), rise = 0.12, fall = 0.9 },
		keys = {
			{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
			{ t = 0.08 },
			{ t = 0.16, hand = m(0, -0.05, 0.05), grab = 0.8 },
			{ t = 0.22 },
			{ t = 0.30, hand = m(-0.3, -0.3, 0.1), grab = 0.3, mag = V(0, -3.2, 0.1), rx = 20, fall = true },
			{ t = 0.31, hand = m(-0.45, -0.5, 0.2), mag = V(-0.5, -3.0, 0.2), rx = 0, fall = true },
			{ t = 0.40, hand = m(-0.5, -0.6, 0.25), grab = 1, mag = V(-0.5, -0.55, 0.25), fall = false },
			{ t = 0.52, hand = m(-0.25, -0.45, 0.08), mag = V(-0.25, -0.4, 0.08) },
			{ t = 0.59, hand = m(0, -0.3, 0), mag = V(0, -0.28, 0) },
			{ t = 0.63, hand = m(0, 0, 0), mag = V(0, 0, 0) },
			{ t = 0.67 },
			{ t = 0.74, hand = V(0, 0.46, 0.1), grab = 1 },
			{ t = 0.82, hand = V(0, 0.46, 0.52), cyc = 0.42 },
			{ t = 0.87, hand = V(0, 0.46, 0.1), cyc = 0 },
			{ t = 1, hand = FO, grab = 0 },
		},
		events = {
			{ at = 0.02, snd = "ReloadStart" },
			{ at = 0.22, snd = "MagOut" },
			{ at = 0.62, snd = "MagIn", kick = { V(0, 1.2, 0), V(-30, 0, 20) } },
			{ at = 0.82, snd = "Bolt", pitch = 1.1, kick = { V(0, 0, 2), V(0, 0, 0) } },
		},
	}
end

-- ================= .44 Magnum: swing the cylinder out, eject the casings, load 6 rounds one by one, flick it shut =================
function Defs.MAGNUM(a)
	local MP, FO = a.MP, a.FO
	local OUT = V(-0.45, -0.1, 0.05)
	local function cylHand(off, dy, dz) return MP + off + V(-0.22, dy or 0, dz or 0.05) end
	local pouch = MP + V(-1.0, -0.85, 0.3)
	local keys = {
		{ t = 0, hand = FO, grab = 0, mag = V(0, 0, 0), rx = 0, ry = 0, rz = 0, cyc = 0, cov = 0 },
		{ t = 0.06 },
		{ t = 0.14, hand = cylHand(V(0, 0, 0)), grab = 1 },
		{ t = 0.24, hand = cylHand(OUT), mag = OUT, rz = 30 },
		{ t = 0.30 },
		{ t = 0.34, hand = MP + OUT + V(-0.05, -0.08, -0.4), grab = 1 },
		{ t = 0.39, hand = MP + OUT + V(-0.05, -0.08, -0.18) },
	}
	local events = {
		{ at = 0.02, snd = "ReloadStart" },
		{ at = 0.22, snd = "MagOut", pitch = 1.2 },
		{ at = 0.38, snd = "MagOut", pitch = 1.9, vol = 0.8 },
	}
	for i = 0, 5 do
		local t0 = 0.45 + i * 0.075
		local top = MP + OUT + V(0, 0.3, 0)
		table.insert(keys, { t = t0, hand = pouch, grab = 1, rz = 30 + 60 * i })
		table.insert(keys, { t = t0 + 0.045, hand = top, grab = 1 })
		table.insert(keys, { t = t0 + 0.058, hand = top + V(0, -0.1, 0), grab = 0.4 })
		table.insert(events, { at = t0 + 0.058, snd = "MagIn", pitch = 1.7, vol = 0.4 })
	end
	table.insert(keys, { t = 0.90, hand = cylHand(OUT), grab = 1, rz = 390 })
	table.insert(keys, { t = 0.95, hand = cylHand(V(0, 0, 0)), mag = V(0, 0, 0), rz = 420 })
	table.insert(keys, { t = 0.97 })
	table.insert(keys, { t = 1, hand = FO, grab = 0 })
	table.insert(events, { at = 0.95, snd = "MagIn", pitch = 1.1, vol = 0.9, kick = { V(0, 1.2, 0), V(-30, 0, 25) } })
	return {
		tilt = { roll = -22, pitch = 22, yaw = 12, lift = V(-0.3, 0.45, 0.2), rise = 0.12, fall = 0.92 },
		keys = keys,
		aux = function(u, c)
			local out = {}
			local cyl = c.MPcf * c.magRel(u)
			-- spent casings (1-6): sit in the open cylinder, then pop out and fall
			if u > 0.2 and u < 0.62 then
				for k = 0, 5 do
					local f = seg(u, 0.38 + k * 0.004, 0.58)
					local off = V((k % 2 == 0 and 1 or -1) * 0.5 * f, 0.3 * f - 3.2 * f * f, 0.25 * f)
					out[k + 1] = CF(off) * cyl * ang(0, 0, k * 60) * CF(0.14, 0, 0)
				end
			end
			-- fresh rounds (7-12): carried in the hand, then seated in the chamber at the top
			if u > 0.44 and u < 0.93 then
				for i = 0, 5 do
					local t0 = 0.45 + i * 0.075
					if u >= t0 then
						if u < t0 + 0.058 then
							out[7 + i] = CF(c.hand(u) + V(0, -0.02, 0))
						else
							out[7 + i] = cyl * ang(0, 0, 60 * i) * CF(0.14, 0, 0)
						end
					end
				end
			end
			return out
		end,
		events = events,
	}
end

-- ================= engine =================
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

function ReloadAnims.Make(modelId, P, s)
	local def = Defs[modelId] or Defs.VX9
	local MPcf = CF(P.MagPivot.Position / s) * P.MagPivot.Rotation
	local spec = def({ MP = MPcf.Position, MPcf = MPcf, FO = P.Fore.Position / s })
	prepare(spec.keys)
	local keys, tl = spec.keys, spec.tilt
	-- keep the action on screen: the mag swap is authored low (real reload height); squash anything that dips below
	-- the magwell so the hand/mag stay inside the camera frame. The intentional mag "drop" (< -1.2) stays offscreen.
	local y0, DIP = MPcf.Position.Y, 0.55
	local function sq(v, rel)
		local d = rel and v.Y or (v.Y - y0)
		if d < 0 and d > -1.2 then d *= DIP; return V(v.X, (rel and 0 or y0) + d, v.Z) end
		return v
	end
	-- the gun barely moves on screen during a reload (it used to swing toward the center and took up too much space)
	local TILT = 0.15
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
		local k0, k1, x = sample(keys, u)
		local e = smooth(seg(u, 0, tl.rise)) * (1 - smooth(seg(u, tl.fall, 1)))
		local pose = {}
		local tr = num(k0.tr or 0, k1.tr or 0, x)
		pose.tilt = CF(tl.lift * e) * ang(tl.pitch * e, tl.yaw * e, (tl.roll + tr) * e)
		pose.grab = num(k0.grab, k1.grab, x)
		pose.hand = (sq(k0.hand:Lerp(k1.hand, x), false) + V(-0.13, 0.08, 0.1) * pose.grab) * s
		local mp = sq(k0.mag:Lerp(k1.mag, x), true)
		pose.mag = CF(mp * s) * ang(num(k0.rx, k1.rx, x), num(k0.ry, k1.ry, x), num(k0.rz, k1.rz, x))
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

