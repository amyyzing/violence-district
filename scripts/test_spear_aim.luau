-- Pure prediction and isolated target fixtures. Never moves the real camera or throws.
return function(logic)
	logic = logic or getgenv().ViolenceDistrictLogic
	local checks = 0
	local function expect(value, message) assert(value, message) checks = checks + 1 end
	local origin = Vector3.new(0, 3, 0)
	for _, fps in ipairs({ 30, 60, 144 }) do
		local elapsed, remaining = 0, 1
		while elapsed < 0.1 do
			local dt = math.min(1 / fps, 0.1 - elapsed)
			remaining = remaining * (1 - logic._spearAimAlpha(dt))
			elapsed = elapsed + dt
		end
		expect(math.abs(remaining - math.exp(-2.8)) < 0.000001, "Aim smoothing changed with frame rate")
	end
	expect(logic._spearAimAlpha(0) == 0, "Zero frame time advanced aim")
	local sample = {}
	expect(logic._spearMotionVelocity(sample, origin, 1, true).Magnitude == 0, "Unsampled motion invented a velocity")
	local right = origin + Vector3.new(1.6, 0, 0)
	local first = logic._spearMotionVelocity(sample, right, 1.1, true)
	expect(first.X > 0 and first.X <= 16.001, "Observed sideways motion did not build a bounded lead")
	expect((logic._spearMotionVelocity(sample, right + Vector3.new(1.6, 0, 0), 1.2, true) - Vector3.new(16, 0, 0)).Magnitude < 0.0001,
		"Steady sideways motion did not recover full velocity")
	local left = right
	expect(logic._spearMotionVelocity(sample, left, 1.3, true).X <= 0, "Direction reversal retained the old lead")
	expect(logic._spearMotionVelocity(sample, left, 1.4, true).Magnitude == 0, "Stopped target retained movement lead")
	expect(logic._spearMotionVelocity(sample, left + Vector3.new(100, 0, 0), 1.5, true).Magnitude == 0,
		"Teleport produced an extreme lead")
	expect(#sample.samples == 1, "Teleport retained stale movement history")
	expect(logic._spearMotionVelocity(sample, left, 2, true).Magnitude == 0, "Stale sample produced a velocity")
	local air = {}
	logic._spearMotionVelocity(air, origin, 1, false)
	expect(math.abs(logic._spearMotionVelocity(air, origin + Vector3.new(0, 1, 0), 1.1, false).Y - 10) < 0.0001,
		"Airborne vertical velocity was discarded")
	expect(logic._spearMotionVelocity(air, origin + Vector3.new(0, 1, 0), 1.11, true).Y == 0,
		"Grounded prediction retained vertical replication noise")
	local function trace(fps, path, inspect)
		local motion, final = {}, Vector3.zero
		for frame = 0, fps * 2 do
			local t = frame / fps
			final = logic._spearMotionVelocity(motion, path(t), t, true)
			if t > 0.5 then inspect(final, t) end
			assert(#motion.samples <= 10, "Motion history grew without a bound")
		end
		return final
	end
	for _, fps in ipairs({ 30, 60, 144 }) do
		local steady = trace(fps, function(t) return Vector3.new(16 * t, 0, -8 * t) end, function() end)
		expect((steady - Vector3.new(16, 0, -8)).Magnitude < 0.001, "Filtering biased steady diagonal movement")
		local function zigzag(t) return math.asin(math.sin(t * math.pi * 20)) * 0.8 / math.pi end
		local maxZigzag, forwardError, maxSpin, maxJitter = 0, 0, 0, 0
		trace(fps, function(t) return Vector3.new(zigzag(t), 0, -16 * t) end, function(v)
			maxZigzag, forwardError = math.max(maxZigzag, math.abs(v.X)), math.max(forwardError, math.abs(v.Z + 16))
		end)
		expect(maxZigzag < 4, "Rapid zigzags produced a large false sideways lead")
		expect(forwardError < 0.001, "Sideways zigzags suppressed steady forward movement")
		trace(fps, function(t) return Vector3.new(math.cos(16 * t), 0, math.sin(16 * t)) end, function(v)
			maxSpin = math.max(maxSpin, v.Magnitude)
		end)
		expect(maxSpin < 12, "Tight circular movement retained full tangential lead")
		trace(fps, function(t) return Vector3.new(math.sin(119 * t) * 0.005, 0, math.cos(97 * t) * 0.005) end, function(v)
			maxJitter = math.max(maxJitter, v.Magnitude)
		end)
		expect(maxJitter < 0.2, "Stationary replication jitter produced movement lead")
		local still = trace(fps, function() return Vector3.zero end, function() end)
		expect(still.Magnitude == 0, "Stationary/spinning-in-place target received a lead")
	end
	local minimumBurst, maximumBurst = math.huge, 0
	trace(144, function(t) return Vector3.new(math.floor(t * 20 + 0.000001) / 20 * 16, 0, 0) end, function(v)
		minimumBurst, maximumBurst = math.min(minimumBurst, v.X), math.max(maximumBurst, v.X)
	end)
	expect(minimumBurst > 8 and maximumBurst < 24, "Batched replication caused zero/extreme lead spikes")
	local stoppedLead = 0
	trace(144, function(t) return Vector3.new(math.min(t, 1) * 16, 0, 0) end, function(v, t)
		if t > 1.15 then stoppedLead = math.max(stoppedLead, v.Magnitude) end
	end)
	expect(stoppedLead < 0.001, "Stopped target kept lead beyond the short measurement window")
	local recovery = {}
	for i = 0, 10 do logic._spearMotionVelocity(recovery, Vector3.new(i * 1.6, 0, 0), i * 0.1, true) end
	for i = 1, 4 do
		local reversed = logic._spearMotionVelocity(recovery, Vector3.new(16 - i * 1.6, 0, 0), 1 + i * 0.1, true)
		expect(reversed.X <= 0, "Filter led into the old direction after a reversal")
	end
	expect(math.abs(recovery.velocity.X + 16) < 0.001, "Steady new direction did not recover full lead")
	for _, case in ipairs({
		{ Vector3.new(0, 3, -50), Vector3.zero, 165 },
		{ Vector3.new(0, 3, -50), Vector3.new(21, 0, 0), 165 },
		{ Vector3.new(10, 12, -80), Vector3.new(-15, 0, 4), 142.5 },
		{ Vector3.new(-20, -5, -60), Vector3.new(12, 0, -8), 142.5 },
		{ Vector3.new(0, 3, -10), Vector3.new(2, 0, 0), 50 },
		{ Vector3.new(0, 3, -2), Vector3.zero, 20 },
		{ Vector3.new(0, 10, -40), Vector3.new(8, 12, 0), 165 },
	}) do
		local target, movement, speed = case[1], case[2], case[3]
		local dt, gravity, latency = 1 / 120, 98.1, 0.025
		local direction, time, predicted = logic._spearIntercept(origin, target, movement, speed, gravity, dt, latency)
		expect(direction ~= nil and time > 0 and time <= 4, "Reachable target has no intercept")
		expect(math.abs(direction.Magnitude - 1) < 0.00001, "Aim direction is not normalized")
		local position, velocity, elapsed = origin, direction * speed, 0
		while elapsed < time do
			local step = math.min(dt, time - elapsed)
			velocity = velocity + Vector3.new(0, -gravity * step, 0)
			position = position + velocity * step
			elapsed = elapsed + step
		end
		expect((position - predicted).Magnitude < 0.02, "Simulated spear missed predicted moving target")
		expect((predicted - (target + movement * (time + latency))).Magnitude < 0.0001, "Lead omitted target movement or latency")
	end
	expect(logic._spearIntercept(origin, Vector3.new(0, 3, -1000), Vector3.zero, 165, 98.1) == nil, "Unreachable target received an aim solution")
	expect(logic._spearIntercept(origin, Vector3.new(0, 3, -30), Vector3.new(0, 0, -200), 165, 98.1) == nil, "Faster receding target received an aim solution")
	expect(logic._spearIntercept(origin, origin, Vector3.zero, 0, 98.1) == nil, "Zero speed produced an aim solution")
	local _, straightTime = logic._spearIntercept(origin, Vector3.new(0, 3, -60), Vector3.zero, 120, 0)
	expect(math.abs(straightTime - 0.5) < 0.00001, "Zero-gravity intercept is incorrect")
	local speed, gravity, dt = 165, 98.1, 1 / 60
	local peakTime = (-3 * dt + math.sqrt(dt * dt + 32 * speed * speed / (gravity * gravity))) / 4
	local range = math.sqrt(speed * speed * peakTime * peakTime - (0.5 * gravity * peakTime * (peakTime + dt)) ^ 2)
	local far = Vector3.new(0, 3, -(range - 0.0001))
	local direction, time = logic._spearIntercept(origin, far, Vector3.zero, speed, gravity, dt)
	expect(direction ~= nil, "Narrow valid intercept near maximum range was missed")
	local hit = origin + direction * speed * time - Vector3.new(0, 0.5 * gravity * time * (time + dt), 0)
	expect((hit - far).Magnitude < 0.0001, "Maximum-range solution did not meet the target")
	expect(logic._spearIntercept(origin, Vector3.new(0, 3, -(range + 0.01)), Vector3.zero, speed, gravity, dt) == nil,
		"Beyond-range target received a false intercept")
	if not Instance or not Vector2 then return string.format("PASS: %d intercept assertions", checks) end
	local models = {}
	local function player(x, team)
		local model = Instance.new("Model")
		local humanoid = Instance.new("Humanoid") humanoid.Parent = model
		local root = Instance.new("Part") root.Name, root.Position, root.Parent = "HumanoidRootPart", Vector3.new(x, 100, -30), model
		models[#models + 1] = model
		return { Team = { Name = team or "Survivors" }, Character = model }
	end
	local near, far, spectator = player(105), player(160), player(100, "Spectator")
	local outside = player(100 + logic.SpearAimFovRadius + 1)
	local camera = { WorldToViewportPoint = function(_, p) return Vector3.new(p.X, p.Y, 1), true end }
	local ok, err = pcall(function()
		expect(logic._selectSpearAimTarget(camera, Vector2.new(100, 100), { outside }) == nil, "Selected target outside the FOV circle")
		expect(logic._selectSpearAimTarget(camera, Vector2.new(100, 100), { far, spectator, near }) == near, "Did not select survivor nearest cursor")
		near.Character:SetAttribute("Knocked", true)
		expect(logic._selectSpearAimTarget(camera, Vector2.new(100, 100), { near, far }) == far, "Selected a knocked survivor")
		far.Character:FindFirstChildOfClass("Humanoid").Health = 0
		expect(logic._selectSpearAimTarget(camera, Vector2.new(100, 100), { near, far, spectator }) == nil, "Selected dead, knocked, or spectator target")
		local behind = { WorldToViewportPoint = function(_, p) return Vector3.new(p.X, p.Y, -1), false end }
		near.Character:SetAttribute("Knocked", false)
		expect(logic._selectSpearAimTarget(behind, Vector2.new(100, 100), { near }) == nil, "Selected target behind camera")
	end)
	for _, model in ipairs(models) do model:Destroy() end
	assert(ok, err)
	return string.format("PASS: %d assertions; moving-target flight simulation, reachability, cursor selection and invalid targets", checks)
end
