-- Sfx: plays sounds from the SoundBank.
--   Sfx.Play(name, parent, pitch, volume, gunId) -> Sound or nil
--       parent = nil -> 2D (only you hear it) | Part / Attachment -> 3D from it | Vector3 -> 3D from that position
--       pitch / volume = optional multipliers | gunId = "VX9" etc. -> use that gun's own version of the slot if the bank has one
--   Sfx.Loop(name, parent, gunId) -> looping Sound that starts at volume 0 (caller fades it)
--   Sfx.Has(name, gunId) -> true if the slot has a sound (own, global or fallback)
-- Lookup order: Guns[gunId][name] -> any other section's [name] -> Fallbacks[name] (another slot, pitched/quieter).
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Bank = require(script.Parent:WaitForChild("SoundBank"))

local Sfx = {}
local SECTIONS = { "Global", "Combat", "Movement", "Boxes", "Death", "Match" }
local flat = {}    -- name -> info
local perGun = {}  -- gunId -> name -> info
local preload = {}

local function idList(def)
	local list = {}
	if def.Id ~= nil and tostring(def.Id) ~= "" then table.insert(list, tostring(def.Id)) end
	if type(def.Ids) == "table" then
		for _, i in def.Ids do if tostring(i) ~= "" then table.insert(list, tostring(i)) end end
	end
	return list
end

local function toAsset(id) return string.find(id, "://") and id or ("rbxassetid://" .. id) end

local function make(name, def, base)
	local ids = idList(def)
	if #ids == 0 then return nil end
	local function pick(key, fallback)
		if def[key] ~= nil then return def[key] end
		if base and base[key] ~= nil then return base[key] end
		return fallback
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = toAsset(ids[1])
	s.Volume = pick("Volume", 0.5)
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = pick("MaxDistance", 350)
	local variants = {}
	for _, id in ids do
		table.insert(variants, toAsset(id))
		if id ~= ids[1] then
			local v = Instance.new("Sound"); v.SoundId = toAsset(id); table.insert(preload, v)
		end
	end
	table.insert(preload, s)
	return { sound = s, variants = variants, lo = pick("PitchMin", 1), hi = pick("PitchMax", 1) }
end

for _, section in SECTIONS do
	for name, def in Bank[section] or {} do
		local info = make(name, def)
		if info then flat[name] = info end
	end
end
for gunId, slots in Bank.Guns or {} do
	perGun[gunId] = {}
	for name, def in slots do
		local base
		for _, section in SECTIONS do
			if Bank[section] and Bank[section][name] then base = Bank[section][name]; break end
		end
		local info = make(name, def, base)
		if info then perGun[gunId][name] = info end
	end
end

task.spawn(function()
	if #preload > 0 then pcall(function() ContentProvider:PreloadAsync(preload) end) end
end)

local fallbacks = Bank.Fallbacks or {}
local function resolve(name, gunId, depth)
	local g = gunId and perGun[gunId]
	local info = (g and g[name]) or flat[name]
	if info then return info, 1, 1 end
	local fb = fallbacks[name]
	if fb and (depth or 0) < 3 then
		local i, p, v = resolve(fb[1], gunId, (depth or 0) + 1)
		if i then return i, p * (fb[2] or 1), v * (fb[3] or 1) end
	end
	return nil
end

function Sfx.Has(name, gunId) return resolve(name, gunId) ~= nil end

local function hostAt(pos)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Position = pos
	p.Parent = workspace
	Debris:AddItem(p, 12)
	return p
end

function Sfx.Play(name, parent, pitch, volume, gunId)
	local info, fp, fv = resolve(name, gunId)
	if not info then return nil end
	local s = info.sound:Clone()
	s.SoundId = info.variants[math.random(#info.variants)]
	s.PlaybackSpeed = (info.lo + math.random() * (info.hi - info.lo)) * (pitch or 1) * fp
	s.Volume = info.sound.Volume * (volume or 1) * fv
	local host
	if typeof(parent) == "Vector3" then host = hostAt(parent); parent = host end
	s.Parent = parent or SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy(); if host then host:Destroy() end end)
	Debris:AddItem(s, 8)
	return s
end

-- Looping 2D sound that starts at volume 0 (caller fades it). Returns nil if the slot has no sound.
function Sfx.Loop(name, parent, gunId)
	local info = resolve(name, gunId)
	if not info then return nil end
	local s = info.sound:Clone()
	s.Looped = true
	s.Volume = 0
	s.Parent = parent or SoundService
	s:Play()
	return s
end

return Sfx
