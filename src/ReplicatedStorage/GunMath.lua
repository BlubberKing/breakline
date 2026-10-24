local GunMath = {}

function GunMath.Falloff(cfg, dist)
	if dist <= cfg.FalloffStart then return 1 end
	if dist >= cfg.FalloffEnd then return cfg.FalloffMin end
	local a = (dist - cfg.FalloffStart) / (cfg.FalloffEnd - cfg.FalloffStart)
	return 1 + (cfg.FalloffMin - 1) * a
end

function GunMath.IsHeadshot(part)
	if part.Name == "Head" then return true end
	local acc = part.Parent
	return acc ~= nil and acc:IsA("Accessory") and (acc.AccessoryType == Enum.AccessoryType.Hat
		or acc.AccessoryType == Enum.AccessoryType.Hair or acc.AccessoryType == Enum.AccessoryType.Face)
end

function GunMath.Damage(cfg, dist, head)
	return cfg.Damage * GunMath.Falloff(cfg, dist) * (head and cfg.HeadMultiplier or 1)
end

return GunMath
