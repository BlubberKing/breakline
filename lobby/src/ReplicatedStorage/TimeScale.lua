-- TimeScale (ModuleScript in ReplicatedStorage) - LOBBY place only. NEW in v4.0.
-- The lobby has no slow-motion round end, so this is a stub that always says "normal speed". It exists only so that the
-- shared Movement script (same file as Breakline's) can require it. (Breakline has the real TimeScale.)
local T = {}
function T.Get() return 1 end
return T
