local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Bank = require(script.Parent:WaitForChild("SoundBank"))

local Sfx = {}
local templates = {}

for name, def in Bank do
	if def.Id and def.Id ~= "" then
		local s = Instance.new("Sound")
		local id = tostring(def.Id)
		s.SoundId = string.find(id, "://") and id or ("rbxassetid://" .. id)
		s.Volume = def.Volume or 0.5
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = def.MaxDistance or 350
		s.Name = name
		templates[name] = s
	end
end

task.spawn(function()
	local list = {}
	for _, s in templates do table.insert(list, s) end
	if #list > 0 then pcall(function() ContentProvider:PreloadAsync(list) end) end
end)

-- parent = nil -> 2D (your own gun). parent = Part/Attachment -> 3D positional.
function Sfx.Play(name, parent)
	local t = templates[name]
	if not t then return nil end
	local def = Bank[name]
	local s = t:Clone()
	local lo, hi = def.PitchMin or 1, def.PitchMax or 1
	s.PlaybackSpeed = lo + math.random() * (hi - lo)
	s.Parent = parent or SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	Debris:AddItem(s, 8)
	return s
end

return Sfx
