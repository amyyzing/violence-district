-- Uses isolated client fixtures; never throws a spear or sends a remote.
return function()
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
		object.Anchored, object.CanCollide, object.Transparency = true, true, 1
		object.Parent = parent
		return object
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { fixtures }
	local ok, err = pcall(function()
		-- Paired camera/server directions from three live throws with little camera
		-- movement. One additional capture turned quickly during replication delay.
		local throws = {
			{ 142.5, Vector3.new(0.951025, 0.140748, 0.275211), Vector3.new(0.950942, 0.141359, 0.275185) },
			{ 142.5, Vector3.new(0.602200, -0.032178, -0.797697), Vector3.new(0.602182, -0.031733, -0.797728) },
			{ 10.916162, Vector3.new(0.383826, -0.285727, 0.878087), Vector3.new(0.384176, -0.291230, 0.876124) },
		}
		for _, shot in ipairs(throws) do
			local preview = logic._projectileTrajectory(origin, shot[2].Unit, shot[1], 98.1, params, 0.02)
			local actual, velocity = origin, shot[3].Unit * shot[1]
			for _ = 1, 200 do
				velocity = velocity + Vector3.new(0, -98.1 * 0.02, 0)
				actual = actual + velocity * 0.02
			end
			expect((preview[#preview] - actual).Magnitude < 1, "Recorded launch replay diverged by over one stud")
		end
		local points, result = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 165, 98.1, params, 0.02)
		expect(result == nil, "Empty trajectory reported an impact")
		expect(points[1] == origin, "Physics origin moved")
		local simulated, velocity = origin, Vector3.new(0, 0, -165)
		for _ = 1, 200 do
			velocity = velocity + Vector3.new(0, -98.1 * 0.02, 0)
			simulated = simulated + velocity * 0.02
		end
		expect((points[#points] - simulated).Magnitude < 0.1, "Trajectory disagrees with the game's velocity-first integration")
		local slowerFrames = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 165, 98.1, params, 0.05)
		expect(slowerFrames[#slowerFrames].Y < points[#points].Y, "Frame timing was ignored")
		local low = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 50, 98.1, params)
		expect(math.abs(low[#low].Z + 200) < 0.01, "Charge speed did not affect range")
		local floor = part(fixtures, "Floor", origin - Vector3.new(0, 4, 0), Vector3.new(1000, 1, 1000))
		local falling, impact = logic._projectileTrajectory(origin, Vector3.new(0, 0, -1), 165, 98.1, params)
		expect(impact and impact.Instance == floor, "Curved path missed the floor")
		expect(falling[#falling] == impact.Position and #falling < #points, "Trajectory continued past collision")
		floor:Destroy()
		local character = Instance.new("Model")
		character.Parent = fixtures
		local root = part(character, "HumanoidRootPart", origin, Vector3.one)
		local release = logic._projectileStartPosition(character)
		expect(release == root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 1.5, 0), "Release origin disagrees with game handler")
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
		expect((visuals.Beam.CFrame.Position - visualOrigin).Magnitude < 0.001, "First drawn segment starts too far forward")
		local rayVector = (visuals.Beam.CFrame.LookVector * visuals.Beam.Length)
		expect((visuals.Beam.CFrame.Position + rayVector - points[2]).Magnitude < 0.001, "First segment does not join the physical trajectory")
		logic._setProjectileArc({ release, release + Vector3.new(0, 0, -1) }, visualOrigin, Color3.new(1, 1, 1))
		for _, object in ipairs(visuals:GetChildren()) do
			if object.Name:match("^Arc") then expect(object.Transparency == 1, "Shorter path left old segments visible") end
		end
		logic.setProjectileVisualiserEnabled(false)
		for _, object in ipairs(visuals:GetChildren()) do expect(not object:IsA("LineHandleAdornment"), "Disable leaked arc segments") end
	end)
	logic.setProjectileVisualiserEnabled(false)
	logic.setProjectileVisualiserEnabled(saved)
	fixtures:Destroy()
	camera:Destroy()
	assert(ok, err)
	return string.format("PASS: %d assertions; launch replay, gravity, charge, collision, camera origin, segment continuity and cleanup", checks)
end
