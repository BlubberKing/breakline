-- Poses v1 (ModuleScript in ReplicatedStorage, named "Poses") - BOTH games (Lobby + Breakline), keep the two copies identical. NEW in v5.16 (GDD 5.10).
-- POSES = emotes. Every pose is a set of R15 joint angles (radians, the same joint space the real characters use for Motor6D.Transform and the
-- menu figures use in Skins.NewFigure), either held still (a real pose) or moving (fn = function(t, J) ... end, looping). No animation assets.
-- Rig space: +X = the character's right, +Y = up, -Z = forward.  Shoulder X+ = arm swings forward / up, Shoulder Z+ (right) / Z- (left) = arm out
-- to the side and up; Elbow X+ = bends the forearm forward; Hip X+ = thigh forward; Knee X- = bends the shin back; Neck / Waist X+ = look / lean
-- back (up), Y+ = turn left, Z = tilt. Root = { x, y, z, offsetY } (offsetY in studs of a normal-sized character, lowers / raises the whole body).
-- The angles were checked offline with a small forward-kinematics script (hand / elbow positions against the head and the floor).
--   Poses.List / Poses.ById[id] / Poses.Order       { id, name, anim (bool), price = nil (free) | { souls = n } | { essence = n }, still = t for pictures }
--   Poses.Sample(id, t) -> J                        joint table at time t (seconds since the pose started), every key filled (0 = rest)
--   Poses.Angles(j) -> CFrame                       CFrame.Angles of one joint entry
--   Poses.MOTORS                                    { key = { part, motor } } R15 motor names per joint key
--   Poses.IsFree(id), Poses.Is(id)
--   Poses.Owns(player, id) / Poses.Owned(player)    from the PosesOwnedJson attribute (+ the free poses)
--   Poses.Wheel(player) -> { 6 ids or "" }          the pose wheel (PoseWheelJson attribute; DefaultWheel when nothing is saved yet)
--   Poses.CleanWheel(t, ownsFn) -> { 6 }            a checked copy (unknown / not owned / duplicate -> "")
local HttpService = game:GetService("HttpService")

local P = {}
P.WHEEL = 6
P.MOTORS = {
	Root = { "LowerTorso", "Root" }, Waist = { "UpperTorso", "Waist" }, Neck = { "Head", "Neck" },
	RShoulder = { "RightUpperArm", "RightShoulder" }, RElbow = { "RightLowerArm", "RightElbow" }, RWrist = { "RightHand", "RightWrist" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" }, LElbow = { "LeftLowerArm", "LeftElbow" }, LWrist = { "LeftHand", "LeftWrist" },
	RHip = { "RightUpperLeg", "RightHip" }, RKnee = { "RightLowerLeg", "RightKnee" }, RAnkle = { "RightFoot", "RightAnkle" },
	LHip = { "LeftUpperLeg", "LeftHip" }, LKnee = { "LeftLowerLeg", "LeftKnee" }, LAnkle = { "LeftFoot", "LeftAnkle" },
}
local KEYS = {}
for k in P.MOTORS do table.insert(KEYS, k) end

local sin, abs, pi = math.sin, math.abs, math.pi
local ARMS_DOWN = { RShoulder = { 0, 0, 0.06 }, LShoulder = { 0, 0, -0.06 }, RElbow = { 0.1, 0, 0 }, LElbow = { 0.1, 0, 0 } }

P.List = {
	-- FREE (everybody owns these; they are on the wheel by default)
	{ id = "wave", name = "WAVE", anim = true, still = 0.35,
		joints = { RShoulder = { 0, 0, 2.55 }, RElbow = { 0.5, 0, 0 }, LShoulder = ARMS_DOWN.LShoulder, LElbow = ARMS_DOWN.LElbow, Neck = { 0.05, 0.1, -0.06 } },
		fn = function(t, J)
			J.RShoulder[3] = 2.55 + 0.24 * sin(t * 9)
			J.Waist[3] = 0.04 * sin(t * 9)
		end },
	{ id = "victory", name = "VICTORY", anim = false,
		joints = { RShoulder = { 0, 0, 2.4 }, LShoulder = { 0, 0, -2.4 }, RElbow = { 0.15, 0, 0 }, LElbow = { 0.15, 0, 0 }, Neck = { 0.25, 0, 0 }, Waist = { 0.12, 0, 0 } } },
	{ id = "crossed", name = "ARMS CROSSED", anim = false,
		joints = { RShoulder = { 1.08, 1.19, -0.54 }, RElbow = { 1.69, 0, 0 }, LShoulder = { 1.18, -1.17, 0.52 }, LElbow = { 1.67, 0, 0 },
			Neck = { 0.08, 0, 0.05 }, RHip = { 0, 0, 0.08 }, LHip = { 0, 0, -0.08 } } },
	-- SOULS
	{ id = "salute", name = "SALUTE", anim = false, price = { souls = 300 },
		joints = { RShoulder = { 1.65, 1.05, 0.83 }, RElbow = { 1.72, 0, 0 }, LShoulder = { 0, 0, -0.04 }, LElbow = { 0.05, 0, 0 }, Neck = { 0.05, 0, 0 } } },
	{ id = "shrug", name = "SHRUG", anim = true, price = { souls = 300 }, still = 0.4,
		joints = { RShoulder = { 0.35, 0, 0.45 }, RElbow = { 1.45, 0, 0 }, LShoulder = { 0.35, 0, -0.45 }, LElbow = { 1.45, 0, 0 } },
		fn = function(t, J)
			local s = sin(t * 2.4)
			J.Neck[3] = 0.2 * s
			J.Neck[1] = 0.06
			J.Root[4] = 0.05 * abs(s)
			J.RShoulder[3] = 0.45 + 0.06 * abs(s)
			J.LShoulder[3] = -0.45 - 0.06 * abs(s)
		end },
	{ id = "kneel", name = "KNEEL", anim = false, price = { souls = 400 },
		joints = { Root = { 0, 0, 0, -0.8 }, RHip = { 1.45, 0, 0 }, RKnee = { -1.5, 0, 0 }, RAnkle = { 0.05, 0, 0 }, LHip = { 0.1, 0, 0 }, LKnee = { -1.55, 0, 0 }, LAnkle = { 0.6, 0, 0 },
			Waist = { -0.12, 0, 0 }, RShoulder = { 0.75, 0, 0.1 }, RElbow = { 0.9, 0, 0 }, LShoulder = { 0.1, 0, -0.12 }, LElbow = { 0.3, 0, 0 }, Neck = { 0.15, 0, 0 } } },
	{ id = "sitback", name = "SIT BACK", anim = false, price = { souls = 500 },
		joints = { Root = { 0, 0, 0, -1.45 }, RHip = { 1.3, 0, 0.1 }, LHip = { 1.3, 0, -0.1 }, RKnee = { -1.6, 0, 0 }, LKnee = { -1.6, 0, 0 },
			Waist = { -0.15, 0, 0 }, RShoulder = { -0.35, 0, 0.25 }, LShoulder = { -0.35, 0, -0.25 }, Neck = { 0.2, 0, 0 } } },
	-- ESSENCE
	{ id = "dab", name = "DAB", anim = false, price = { essence = 120 },
		joints = { RShoulder = { 0.96, 0.77, 1.75 }, RElbow = { 0.02, 0, 0 }, LShoulder = { 2.77, -0.56, 0.72 }, LElbow = { 0.93, 0, 0 },
			Neck = { -0.45, 0.45, 0 }, Waist = { -0.1, 0.15, 0 } } },
	{ id = "flex", name = "FLEX", anim = true, price = { essence = 150 }, still = 0.6,
		joints = { RShoulder = { 1.5708, 0, 1.5708 }, RElbow = { 1.6, 0, 0 }, LShoulder = { 1.5708, 0, -1.5708 }, LElbow = { 1.6, 0, 0 }, Neck = { 0.12, 0, 0 },
			Waist = { 0.1, 0, 0 }, RHip = { 0, 0, 0.12 }, LHip = { 0, 0, -0.12 } },
		fn = function(t, J)
			local s = sin(t * 3)
			J.RElbow[1] = 1.6 + 0.25 * s
			J.LElbow[1] = 1.6 + 0.25 * s
			J.Waist[2] = 0.08 * sin(t * 1.5)
		end },
	{ id = "hype", name = "HYPE", anim = true, price = { essence = 200 }, still = 0.15,
		joints = { RShoulder = { 0, 0, 2.5 }, LShoulder = { 0, 0, -2.5 }, RElbow = { 0.3, 0, 0 }, LElbow = { 0.3, 0, 0 }, Neck = { 0.2, 0, 0 } },
		fn = function(t, J)
			local b = abs(sin(t * 5))
			J.Root[4] = 0.35 * b
			J.RShoulder[3] = 2.5 + 0.3 * sin(t * 10)
			J.LShoulder[3] = -(2.5 + 0.3 * sin(t * 10 + pi))
			J.RHip[1], J.LHip[1] = 0.25 * (1 - b), 0.25 * (1 - b)
			J.RKnee[1], J.LKnee[1] = -0.45 * (1 - b), -0.45 * (1 - b)
			J.Neck[1] = 0.2 + 0.1 * b
		end },
}
P.ById, P.Order = {}, {}
for _, p in P.List do P.ById[p.id] = p table.insert(P.Order, p.id) end
P.DefaultWheel = { "wave", "victory", "crossed", "", "", "" }

function P.Is(id) return type(id) == "string" and P.ById[id] ~= nil end
function P.IsFree(id) local p = P.ById[id] return p ~= nil and p.price == nil end

function P.Sample(id, t)
	local p = P.ById[id]
	local J = {}
	for _, k in KEYS do
		local src = p and p.joints[k]
		if k == "Root" then
			J.Root = src and { src[1] or 0, src[2] or 0, src[3] or 0, src[4] or 0 } or { 0, 0, 0, 0 }
		else
			J[k] = src and { src[1] or 0, src[2] or 0, src[3] or 0 } or { 0, 0, 0 }
		end
	end
	if p and type(p.fn) == "function" then pcall(p.fn, t or 0, J) end
	return J
end
function P.Angles(j)
	if not j then return CFrame.identity end
	return CFrame.Angles(j[1] or 0, j[2] or 0, j[3] or 0)
end

local function setFrom(player, attr)
	local raw = player and player:GetAttribute(attr)
	local ok, t = pcall(HttpService.JSONDecode, HttpService, type(raw) == "string" and raw ~= "" and raw or "[]")
	return (ok and type(t) == "table") and t or {}
end
function P.Owns(player, id)
	if not P.Is(id) then return false end
	if P.IsFree(id) then return true end
	return table.find(setFrom(player, "PosesOwnedJson"), id) ~= nil
end
function P.Owned(player)
	local list, out = setFrom(player, "PosesOwnedJson"), {}
	for _, id in P.Order do if P.IsFree(id) or table.find(list, id) then table.insert(out, id) end end
	return out
end
function P.CleanWheel(t, ownsFn)
	local out, seen = {}, {}
	for i = 1, P.WHEEL do
		local id = type(t) == "table" and t[i] or ""
		if P.Is(id) and not seen[id] and (not ownsFn or ownsFn(id)) then out[i] = id seen[id] = true else out[i] = "" end
	end
	return out
end
function P.Wheel(player)
	local raw = player and player:GetAttribute("PoseWheelJson")
	if type(raw) ~= "string" or raw == "" or raw == "[]" then return table.clone(P.DefaultWheel) end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(t) ~= "table" then return table.clone(P.DefaultWheel) end
	return P.CleanWheel(t, function(id) return P.Owns(player, id) end)
end

return P
