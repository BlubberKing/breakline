-- TimeScale (ModuleScript in ReplicatedStorage). One number that says how fast the world should run right now.
-- 1 normally; during the SlowMo phase (the moment a round is decided) it eases down to MatchConfig.SLOWMO_SCALE.
-- Server and clients compute it from the same MatchState attributes, so everybody slows down together.
--   TimeScale.Get() -> number in (0, 1]
local RS = game:GetService("ReplicatedStorage")
local C = require(RS:WaitForChild("MatchConfig"))

local T = {}
local State

function T.Get()
	State = State or RS:FindFirstChild("MatchState")
	if not State or State:GetAttribute("Phase") ~= "SlowMo" then return 1 end
	local ends = State:GetAttribute("PhaseEnds") or 0
	local t = workspace:GetServerTimeNow() - (ends - C.SLOWMO_TIME)
	local k = math.clamp(t / C.SLOWMO_RAMP, 0, 1)
	local e = 1 - (1 - k) * (1 - k) -- ease out
	return 1 - (1 - C.SLOWMO_SCALE) * e
end

return T
