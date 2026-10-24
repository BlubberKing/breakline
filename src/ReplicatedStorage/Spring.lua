local Spring = {}
Spring.__index = Spring

function Spring.new(stiffness, damping)
	return setmetatable({
		Target = Vector3.zero, Position = Vector3.zero, Velocity = Vector3.zero,
		Stiffness = stiffness or 200, Damping = damping or 20,
	}, Spring)
end

function Spring:Impulse(v)
	self.Velocity += v
end

function Spring:Update(dt)
	local steps = math.max(1, math.ceil(dt / (1 / 240)))
	local h = dt / steps
	for _ = 1, steps do
		local force = (self.Target - self.Position) * self.Stiffness - self.Velocity * self.Damping
		self.Velocity += force * h
		self.Position += self.Velocity * h
	end
	return self.Position
end

return Spring
