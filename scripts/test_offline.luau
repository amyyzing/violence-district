-- Plain Lua checks for label data, legacy migration and free-flight math.
-- These lightweight doubles do not validate Roblox rendering or collisions.
local vector = {}
local vectorMeta = {
	__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
	__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
	__mul = function(a, b) return Vector3.new(a.X * b, a.Y * b, a.Z * b) end,
	__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end,
	__index = function(v, key)
		if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
		if key == "Unit" then return v / v.Magnitude end
		return vector[key]
	end,
}
Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vectorMeta) end }
Vector3.zero, Vector3.one = Vector3.new(0, 0, 0), Vector3.new(1, 1, 1)
CFrame = {
	new = function(v) return { Position = v or Vector3.zero, LookVector = Vector3.new(0, 0, -1) } end,
	lookAt = function(a, b) return { Position = a, LookVector = (b - a).Unit } end,
}
Color3 = { fromRGB = function(...) return { ... } end }
UDim2 = { fromScale = function(x, y) return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } } end }
Enum = setmetatable({}, { __index = function(t, category)
	local values = setmetatable({}, { __index = function(_, name) return category .. "." .. name end })
	rawset(t, category, values)
	return values
end })
math.clamp = function(x, lo, hi) return math.max(lo, math.min(x, hi)) end
table.clear = function(t) for k in pairs(t) do t[k] = nil end end
typeof = type
local methods = {}
local nodeMeta = {
	__index = function(n, key) return methods[key] or n.props[key] or n:FindFirstChild(key) end,
	__newindex = function(n, key, value)
		if key == "Parent" then
			local old = n.props.Parent
			if old then for i, child in ipairs(old.children) do if child == n then table.remove(old.children, i) break end end end
			if value then table.insert(value.children, n) end
		end
		n.props[key] = value
	end,
}
Instance = { new = function(class)
	local signal = { Connect = function() return { Disconnect = function() end } end }
	return setmetatable({ props = { ClassName = class, Name = class, DescendantAdded = signal, DescendantRemoving = signal }, children = {}, attributes = {} }, nodeMeta)
end }
function methods:IsA(class) return self.ClassName == class or class == "BasePart" and self.ClassName == "Part" end
function methods:FindFirstChild(name, recursive)
	for _, child in ipairs(self.children) do if child.Name == name then return child end end
	if recursive then for _, child in ipairs(self.children) do local found = child:FindFirstChild(name, true) if found then return found end end end
end
function methods:GetDescendants()
	local out = {}
	for _, child in ipairs(self.children) do table.insert(out, child) for _, nested in ipairs(child:GetDescendants()) do table.insert(out, nested) end end
	return out
end
function methods:FindFirstChildWhichIsA(class, recursive)
	for _, child in ipairs(recursive and self:GetDescendants() or self.children) do if child:IsA(class) then return child end end
end
function methods:GetAttribute(name) return self.attributes[name] end
function methods:Destroy() self.Parent = nil end
function methods:Clone()
	local clone = Instance.new(self.ClassName)
	for k, v in pairs(self.props) do if k ~= "Parent" then clone[k] = v end end
	return clone
end
local globals, migrated, destroyed = {}, false, false
getgenv = function() return globals end
local player = { WaitForChild = function() return Instance.new("PlayerGui") end }
loadstring = load
game = {
	GetService = function(_, name) if name == "Players" then return { LocalPlayer = player } end return {} end,
	HttpGet = function(_, url)
		local file = assert(io.open("features/" .. assert(url:match("([^/]+)$")), "r"))
		local source = file:read("*a")
		file:close()
		return source
	end,
}
workspace = Instance.new("Workspace")
globals.ViolenceDistrictLogic = {
	Version = 65, getState = function() return { highlightsEnabled = true, pathTreeEnabled = true } end,
	setPathTreeEnabled = function(on) migrated = not on end, destroy = function() destroyed = true end,
}
local logic = assert(loadfile("features/logic.luau"))()
print(assert(loadfile("scripts/test_spear_aim.luau"))()(logic))
print(assert(loadfile("scripts/test_feature_availability.luau"))()(logic))
print(assert(loadfile("scripts/test_auto_parry.luau"))()(assert(loadfile("features/auto_parry.luau"))()))
-- Replay irregular physics steps: the weighted correction should match integration.
local falling, fallingVelocity, flightAge = 0, 0, 0
for index = 1, 32 do
	local dt = index % 2 == 1 and 0.01 or 0.03
	logic._recordProjectileStep(dt)
	fallingVelocity = fallingVelocity - 98.1 * dt
	falling = falling + fallingVelocity * dt
	flightAge = flightAge + dt
end
local effectiveStep = logic._projectileFrameStep()
assert(math.abs(effectiveStep - 0.025) < 0.000001, "Irregular cadence used an unweighted average")
assert(math.abs(falling + 0.5 * 98.1 * flightAge * (flightAge + effectiveStep)) < 0.000001,
	"Cadence correction disagreed with velocity-first physics")
logic._recordProjectileStep(0)
logic._recordProjectileStep(1)
assert(math.abs(logic._projectileFrameStep() - effectiveStep) < 0.000001, "Invalid frame time polluted prediction")
for _ = 1, 32 do logic._recordProjectileStep(1 / 60) end
assert(math.abs(logic._projectileFrameStep() - 1 / 60) < 0.000001, "Cadence window did not recover after a frame-rate change")
print("PASS: irregular physics cadence, invalid timing and frame-rate recovery")
assert(migrated and destroyed, "Old path feature was not stopped during upgrade")
assert(logic.setPathTreeEnabled == nil and logic.getState().pathTreeEnabled == nil, "Removed path API remains")
assert(logic.getState().highlightsEnabled, "Upgrade lost the remaining feature state")
local model, hitbox = Instance.new("Model"), Instance.new("Part")
model.Parent, hitbox.Parent, hitbox.Name = workspace, model, "HitBox"
hitbox.Size = Vector3.new(4, 6, 4)
for _, sample in ipairs({ { 0, "0" }, { 42.39, "42.3" }, { 99.99, "99.9" }, { 100, "100" }, { -2, "0" }, { 130, "100" }, { "75.5%", "75.5" } }) do
	model.attributes.RepairProgress = sample[1]
	local label = logic._updateGeneratorProgress(model)
	assert(label.Progress.Text == sample[2] .. "/100 (" .. sample[2] .. "%)", "Wrong progress fraction")
	assert(label.Adornee == hitbox and label.StudsOffsetWorldSpace.Y == 3.75, "Incorrect generator attachment")
	assert(label.Size.X.Scale == 6 and label.Size.X.Offset == 0 and label.Progress.TextScaled, "Label does not scale proportionally")
end
assert(#model.children == 2, "Progress updates duplicated the label")
hitbox.Size = Vector3.new(4, 10, 4)
assert(logic._updateGeneratorProgress(model).StudsOffsetWorldSpace.Y == 5.75, "Label offset ignored generator size")
logic._projectileSegmentRaycast = function() return nil end
local origin, direction = Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)
for _, dt in ipairs({ 1 / 120, 1 / 60, 0.02, 0.05 }) do
	for _, speed in ipairs({ 1, 50, 142.5, 165 }) do
		local points = logic._projectileTrajectory(origin, direction, speed, 98.1, nil, dt)
		local actual, velocity = origin, direction * speed
		for _ = 1, math.floor(4 / dt + 0.5) do
			velocity = velocity + Vector3.new(0, -98.1 * dt, 0)
			actual = actual + velocity * dt
		end
		assert((points[#points] - actual).Magnitude < 0.00001, "Free-flight prediction disagrees with velocity-first integration")
	end
end
local capture = assert(loadfile("scripts/fixtures/veil_2026_10_15.luau"))()
local function xyz(v) return Vector3.new(v[1], v[2], v[3]) end
local worst, coarseWorst = 0, 0
for _, flight in ipairs(capture.flights) do
	local launch = capture.launches[flight.launchIndex]
	local first, last = xyz(flight.first), xyz(flight.last)
	local aim = xyz(launch.direction).Unit
	local delta = first - xyz(launch.origin)
	local age = (delta.X * aim.X + delta.Z * aim.Z) / (launch.speed * (aim.X * aim.X + aim.Z * aim.Z))
	local gravity = capture.gravity * launch.gravityMultiplier
	local velocity = aim * launch.speed + Vector3.new(0, -gravity * age, 0)
	local points = logic._projectileTrajectory(first, velocity.Unit, velocity.Magnitude, gravity, nil, flight.dtSquaredSum / flight.seconds)
	local step = 4 / (#points - 1)
	local index = math.floor(flight.seconds / step) + 1
	local fraction = flight.seconds / step - (index - 1)
	local shown = points[index] + (points[index + 1] - points[index]) * fraction
	local error = (shown - last).Magnitude
	worst = math.max(worst, error)
	assert(error < 0.05, "Drawn curve deviates from captured flying spear by over 0.05 studs")
	local stride = math.floor(0.1 / step + 0.5)
	local coarseIndex = math.floor(flight.seconds / (step * stride)) * stride + 1
	local coarseFraction = (flight.seconds - (coarseIndex - 1) * step) / (step * stride)
	local coarseShown = points[coarseIndex] + (points[coarseIndex + stride] - points[coarseIndex]) * coarseFraction
	coarseWorst = math.max(coarseWorst, (coarseShown - last).Magnitude)
end
assert(coarseWorst > 0.05, "Capture no longer reproduces the coarse-curve regression")
-- Check the retained stop endpoints as well as the cosmetic flying model.
-- Long flights make gravity measurable despite launch-origin/network error.
local stopChecks = 0
for _, launch in ipairs(capture.launches) do
	local start, finish, aim = xyz(launch.origin), xyz(launch.stop), xyz(launch.direction).Unit
	local delta = finish - start
	local age = (delta.X * aim.X + delta.Z * aim.Z) / (launch.speed * (aim.X * aim.X + aim.Z * aim.Z))
	if age > 3 and age < 4 then
		local points = logic._projectileTrajectory(start, aim, launch.speed, capture.gravity * launch.gravityMultiplier, nil, 0)
		local sample = age / (4 / (#points - 1))
		local index = math.floor(sample) + 1
		local shown = points[index] + (points[index + 1] - points[index]) * (sample % 1)
		-- No server frame times were captured. This is an approximate endpoint
		-- check, not proof of exact collision timing or current-game behavior.
		assert(math.abs(shown.Y - finish.Y) < 1.5, "Long-flight stop disagrees with predicted gravity")
		stopChecks = stopChecks + 1
	end
end
assert(stopChecks == 2, "Missing long-flight stop evidence")
local curve = logic._projectileTrajectory(origin, direction, 165, 98.1, nil, 0.02)
local scaledDirection = logic._projectileTrajectory(origin, direction * 3, 165, 98.1, nil, 0.02)
assert((scaledDirection[#scaledDirection] - curve[#curve]).Magnitude < 0.00001, "Direction magnitude incorrectly changes launch speed")
logic._setProjectileArc(curve, Vector3.new(1, 1, 1), Color3.fromRGB(255, 255, 255))
local visuals = workspace:FindFirstChild("CateyesProjectileVisualiser")
assert(not visuals.Arc1.AlwaysOnTop and visuals.Arc1.ZIndex == -1, "Arc still forces itself through walls")
assert(visuals:FindFirstChild("ArcPoint1") == nil, "Dotted markers were not removed")
assert(visuals.Beam.Transparency == 1 and visuals.Beam.Length == 0, "Cosmetic connector is still visible")
assert((visuals.Arc1.CFrame.Position - curve[1]).Magnitude < 0.00001, "First physical curve segment is missing")
for index = 1, #curve - 1 do
	local beam = assert(visuals:FindFirstChild("Arc" .. index), "Physical arc segment missing")
	assert((beam.CFrame.Position - curve[index]).Magnitude < 0.00001, "Drawn segment starts outside the calculated path")
	assert((beam.CFrame.Position + beam.CFrame.LookVector * beam.Length - curve[index + 1]).Magnitude < 0.00001, "Drawn segment ends outside the calculated path")
end
print(string.format("PASS: path migration, label data, 16 free-flight cases, %d captured flights (new %.4f vs old %.4f studs), %d long-flight stops, first curve segment", #capture.flights, worst, coarseWorst, stopChecks))
