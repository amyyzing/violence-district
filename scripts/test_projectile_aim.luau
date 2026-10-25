-- Uses isolated client fixtures; never throws a spear or sends a remote.
return function(capture)
	local logic = getgenv().ViolenceDistrictLogic
	local saved = logic.getState().projectileVisualiserEnabled
	local fixtures = Instance.new("Folder")
	fixtures.Name = "CateyesAimTest"
	fixtures.Parent = workspace
	local camera = Instance.new("Camera")
	local origin = Vector3.new(0, -10000, 0)
	local checks = 0
	local function expect(value, message)
		assert(value, message)
		checks = checks + 1
	end
	local function part(parent, name, position, size)
		local object = Instance.new("Part")
		object.Name, object.Position, object.Size = name, position, size
		object.Anchored, object.CanCollide, object.Transparency = true, true, 0
		object.Parent = parent
		return object
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { fixtures }
	local ok, err = pcall(function()
		for _, case in ipairs({ { 0.25, true, 54, false }, { 0.99, true, 178.2, false },
			{ 1, true, 180, false }, { 1.99, true, 180, false }, { 2, true, 180, true },
			{ 2, false, 180, false }, { 7, false, 180, false } }) do
			local speed, piercing = logic._projectileLaunchSpeed(case[1], case[2])
			expect(math.abs(speed - case[3]) < 0.001 and piercing == case[4], "Charge/cooldown disagrees with Veil's throw script")
		end
		local hudRoot = Instance.new("Folder")
		hudRoot.Parent = fixtures
		local hud = Instance.new("ScreenGui")
		hud.Name, hud.Parent = "Slasher", hudRoot
		local moves = Instance.new("Folder")
		moves.Name, moves.Parent = "Gen", hud
		local move = Instance.new("Frame")
		move.Name, move.Parent = "Move2", moves
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.Parent, icon.ImageColor3 = "Icon", move, Color3.new(1, 1, 1)
		expect(logic._projectileSpecialReady(hudRoot), "Ready ability HUD was ignored")
		icon.ImageColor3 = Color3.fromRGB(51, 51, 51)
		expect(not logic._projectileSpecialReady(hudRoot), "Cooling ability was treated as ready")
		icon.ImageColor3, hud.Enabled = Color3.new(1, 1, 1), false
		expect(not logic._projectileSpecialReady(hudRoot), "Inactive ability HUD was used")
		hudRoot:Destroy()
		local nativeMath = require(game.ReplicatedStorage.Modules.Killers.Veil.SpearMath)
		for _, direction in ipairs({Vector3.new(0,0,-1), Vector3.new(0,-1,-1).Unit, Vector3.new(1,1,0).Unit}) do
			for _, held in ipairs({0.3,0.7,1,3}) do
				local speed = logic._projectileLaunchSpeed(held, false)
				local curve = logic._projectileTrajectory(origin, direction, speed, 98.1, params)
				for index, point in ipairs(curve) do
					local time = (index-1)*4/(#curve-1)
					expect((point-nativeMath.position(origin,direction*nativeMath.power(held),time)).Magnitude<0.002,
						"Preview diverged from current native SpearMath")
				end
			end
		end
		local points, result = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 165, 98.1, params, 0.02)
		expect(result == nil, "Empty trajectory reported an impact")
		expect(points[1] == origin, "Physics origin moved")
		local scaledDirection = logic._projectileTrajectory(origin, Vector3.new(0, 0, -3), 165, 98.1, params, 0.02)
		expect((scaledDirection[#scaledDirection] - points[#points]).Magnitude < 0.001, "Direction magnitude changed the launch speed")
		local simulated, velocity = origin, Vector3.new(0, 0, -165)
		for _ = 1, 200 do
			local before = velocity
			velocity = velocity + Vector3.new(0, -98.1 * 0.02, 0)
			simulated = simulated + (before + velocity) * 0.01
		end
		expect((points[#points] - simulated).Magnitude < 0.1, "Trajectory disagrees with independent midpoint integration")
		local slowerFrames = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 165, 98.1, params, 0.05)
		expect((slowerFrames[#slowerFrames]-points[#points]).Magnitude < 0.001, "Frame timing changed analytic flight")
		local low = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 50, 98.1, params)
		expect(math.abs(low[#low].Z + 200) < 0.01, "Charge speed did not affect range")
		local floor = part(fixtures, "Floor", origin - Vector3.new(0, 4, 0), Vector3.new(1000, 1, 1000))
		local falling, impact = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 165, 98.1, params)
		expect(impact and impact.Instance == floor, "Curved path missed the floor")
		expect(falling[#falling] == impact.Position and #falling < #points, "Trajectory continued past collision")
		floor:Destroy()
		local generator = Instance.new("Model")
		generator.Name, generator.Parent = "Generator", fixtures
		local body = part(generator, "GeneratorBody", origin + Vector3.new(0, 0, -2), Vector3.one)
		body.CanCollide = false
		local generatorParams = RaycastParams.new()
		generatorParams.FilterType = Enum.RaycastFilterType.Exclude
		local generatorHit = logic._projectileSegmentRaycast(origin, Vector3.new(0, 0, -4), generatorParams)
		expect(generatorHit == nil, "Ordinary preview stopped on a non-colliding generator body")
		local fullParams = RaycastParams.new()
		fullParams.FilterType = Enum.RaycastFilterType.Exclude
		expect(logic._projectileSegmentRaycast(origin, Vector3.new(0, 0, -4), fullParams, true) == nil, "Powered spear stopped at a generator body")
		generator:Destroy()
		local layers = Instance.new("Folder")
		layers.Parent = fixtures
		for index = 1, 9 do
			local trigger = part(layers, "Trigger", origin + Vector3.new(0, 0, -index), Vector3.new(4, 4, 0.1))
			trigger.CanCollide = false
		end
		local wall = part(layers, "Wall", origin + Vector3.new(0, 0, -10), Vector3.new(4, 4, 0.1))
		local invisible = part(layers, "InvisibleWall", origin + Vector3.new(0, 0, -9.5), Vector3.new(4, 4, 0.1))
		invisible.Transparency = 1
		local layerParams = RaycastParams.new()
		layerParams.FilterType = Enum.RaycastFilterType.Exclude
		local layeredHit = logic._projectileSegmentRaycast(origin, Vector3.new(0, 0, -12), layerParams)
		expect(layeredHit and layeredHit.Instance == wall, "Invisible or non-colliding parts blocked the solid wall behind them")
		local target = Instance.new("Model")
		target.Parent = layers
		local targetHumanoid = Instance.new("Humanoid")
		targetHumanoid.Parent = target
		local targetPart = part(target, "Target", origin + Vector3.new(0, 0, -11), Vector3.one)
		local hiddenHitbox = part(target, "HiddenHitbox", origin + Vector3.new(0, 0, -9.7), Vector3.new(4, 4, 0.1))
		hiddenHitbox.Transparency = 1
		local triggerHitbox = part(target, "TriggerHitbox", origin + Vector3.new(0, 0, -9.8), Vector3.new(4, 4, 0.1))
		triggerHitbox.CanCollide = false
		local visibleParams = RaycastParams.new()
		visibleParams.FilterType = Enum.RaycastFilterType.Exclude
		local visibleHit = logic._projectileSegmentRaycast(origin, Vector3.new(0, 0, -12), visibleParams)
		expect(visibleHit and visibleHit.Instance == wall, "Excluded character hitboxes intercepted the preview")
		local piercingParams = RaycastParams.new()
		piercingParams.FilterType = Enum.RaycastFilterType.Exclude
		local piercingHit, piercingTarget = logic._projectileSegmentRaycast(origin, Vector3.new(0, 0, -12), piercingParams, true)
		expect(piercingHit and piercingHit.Instance == targetPart and piercingTarget == target, "Piercing spear stopped at a wall before the survivor")
		layers:Destroy()
		local trigger = part(fixtures, "Trigger", origin + Vector3.new(0, 0, -1), Vector3.new(4, 4, 0.01))
		trigger.CanCollide = false
		local thinWall = part(fixtures, "ThinWall", origin + Vector3.new(0, 0, -1.03), Vector3.new(4, 4, 0.01))
		local thinParams = RaycastParams.new()
		thinParams.FilterType = Enum.RaycastFilterType.Exclude
		local thinHit = logic._projectileSegmentRaycast(origin, Vector3.new(0, 0, -2), thinParams)
		expect(thinHit and thinHit.Instance == thinWall, "Skip distance jumped through a nearby thin wall")
		trigger:Destroy()
		thinWall:Destroy()
		local character = Instance.new("Model")
		character.Parent = fixtures
		local root = part(character, "HumanoidRootPart", origin, Vector3.one)
		local release = logic._projectileStartPosition(character)
		expect(release == workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector * 3, "Release origin disagrees with game handler")
		local spear = Instance.new("Model")
		spear.Name, spear.Parent = "Spear", camera
		local muzzle = part(spear, "Hitbox", origin + Vector3.new(1, 1, 2), Vector3.one)
		expect(logic._projectileVisualOrigin(camera, release) == muzzle.Position, "Drawn origin did not attach to camera spear")
		muzzle:Destroy()
		expect(logic._projectileVisualOrigin(camera, release) == release, "Missing camera spear did not fall back safely")
		local ignored = logic._projectileRaycastParams(game.Players.LocalPlayer.Character).FilterDescendantsInstances
		expect(table.find(ignored, workspace.CurrentCamera) ~= nil, "Aim ray can collide with its own viewmodel")
		logic.setProjectileVisualiserEnabled(true)
		local visualOrigin = release + Vector3.new(0, 0, 2)
		logic._setProjectileArc(points, visualOrigin, Color3.new(1, 1, 1))
		local visuals = workspace.CateyesProjectileVisualiser
		for _, object in ipairs(visuals:GetChildren()) do
			if object:IsA("HandleAdornment") then
				expect(not object.AlwaysOnTop and object.ZIndex == -1, "Arc adornment still renders through geometry")
			end
		end
		expect(visuals.Beam.Transparency == 1, "Cosmetic connector is still visible")
		expect(visuals.Beam.Length == 0, "Cosmetic connector still has length")
		expect((visuals.Arc1.CFrame.Position - points[1]).Magnitude < 0.001, "The first physical curve segment was skipped")
		expect((visuals.Arc1.CFrame.Position + visuals.Arc1.CFrame.LookVector * visuals.Arc1.Length - points[2]).Magnitude < 0.001, "First physical segment misses its sample")
		for index = 1, math.min(54, #points - 1) do
			local beam = visuals:FindFirstChild("Arc" .. index)
			expect(beam ~= nil, "Physical arc segment missing")
			expect((beam.CFrame.Position - points[index]).Magnitude < 0.001, "Drawn segment starts outside the calculated flight path")
			expect((beam.CFrame.Position + beam.CFrame.LookVector * beam.Length - points[index + 1]).Magnitude < 0.001, "Drawn segment ends outside the calculated flight path")
		end
		expect(visuals:FindFirstChild("ArcPoint1") == nil, "Dotted path markers remain")
		expect(#points == 161, "Curve no longer samples every 0.025 seconds")
		expect(visuals.Arc54.Transparency < 1 and not visuals:FindFirstChild("Arc55"), "Long tail obscures the curved preview")
		logic._setProjectileArc({ release, release + Vector3.new(0, 0, -1) }, visualOrigin, Color3.new(1, 1, 1))
		for _, object in ipairs(visuals:GetChildren()) do
			if object.Name:match("^Arc") and object.Name ~= "Arc1" then expect(object.Transparency == 1, "Shorter path left old segments visible") end
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
		logic._watchProjectileAnimations(character)
		for _, connection in ipairs(getconnections(animator.AnimationPlayed)) do
			if connection.Function then
				connection.Function({ Animation = { AnimationId = "rbxassetid://93136435416899" } })
			end
		end
		expect(visuals:FindFirstChild("Beam") ~= nil, "An old character's animation changed the current preview")
		logic._watchProjectileCharacter(character)
		character:SetAttribute("spearmode", false)
		task.wait()
		expect(visuals:FindFirstChild("Beam") ~= nil, "An old character's spear-mode change cleared the current preview")
		logic.setProjectileVisualiserEnabled(false)
		for _, object in ipairs(visuals:GetChildren()) do expect(not object:IsA("LineHandleAdornment"), "Disable leaked arc segments") end
		expect(visuals:FindFirstChild("ArcPoint1") == nil, "Disable leaked arc dots")
	end)
	logic.setProjectileVisualiserEnabled(false)
	logic.setProjectileVisualiserEnabled(saved)
	fixtures:Destroy()
	camera:Destroy()
	assert(ok, err)
	return string.format("PASS: %d assertions; launch replay, gravity, charge, collision, camera origin, segment continuity and cleanup", checks)
end
