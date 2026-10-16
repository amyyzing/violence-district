-- Pure prediction and isolated target fixtures. Never moves the real camera or throws.
return function(logic)
	logic = logic or getgenv().ViolenceDistrictLogic
	local checks = 0
	local function expect(value, message) assert(value, message) checks = checks + 1 end
	local origin = Vector3.new(0, 3, 0)
	local sample = {}
	expect(logic._spearMotionVelocity(sample, origin, 1, true).Magnitude == 0, "Unsampled motion invented a velocity")
	local right = origin + Vector3.new(1.6, 0, 0)
	expect((logic._spearMotionVelocity(sample, right, 1.1, true) - Vector3.new(16, 0, 0)).Magnitude < 0.0001,
		"Observed sideways motion did not produce sideways velocity")
	local left = right - Vector3.new(1.6, 0, 0)
	expect((logic._spearMotionVelocity(sample, left, 1.2, true) - Vector3.new(-16, 0, 0)).Magnitude < 0.0001,
		"Direction reversal retained the old velocity")
	expect(logic._spearMotionVelocity(sample, left, 1.3, true).Magnitude == 0, "Stopped target retained movement lead")
	expect(logic._spearMotionVelocity(sample, left + Vector3.new(100, 0, 0), 1.4, true).Magnitude == 0,
		"Teleport produced an extreme lead")
	expect(logic._spearMotionVelocity(sample, left, 2, true).Magnitude == 0, "Stale sample produced a velocity")
	local air = {}
	logic._spearMotionVelocity(air, origin, 1, false)
	expect(math.abs(logic._spearMotionVelocity(air, origin + Vector3.new(0, 1, 0), 1.1, false).Y - 10) < 0.0001,
		"Airborne vertical velocity was discarded")
	expect(logic._spearMotionVelocity(air, origin + Vector3.new(0, 1, 0), 1.11, true).Y == 0,
		"Grounded prediction retained vertical replication noise")
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
	local camera = { WorldToViewportPoint = function(_, p) return Vector3.new(p.X, p.Y, 1), true end }
	local ok, err = pcall(function()
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
