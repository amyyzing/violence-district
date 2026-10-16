-- Runs the actual logic against a fake camera, render scheduler, and owned models.
return function(source)
	local models, bindings = {}, {}
	local function character(position)
		local model = Instance.new("Model")
		local humanoid = Instance.new("Humanoid") humanoid.Parent = model
		local animator = Instance.new("Animator") animator.Parent = humanoid
		local root = Instance.new("Part") root.Name, root.CFrame, root.Parent = "HumanoidRootPart", CFrame.new(position), model
		models[#models + 1] = model
		return model, animator
	end
	local localCharacter, animator = character(Vector3.new(0, 3, 0))
	local target = character(Vector3.new(0, 3, -50))
	localCharacter:SetAttribute("spearmode", true)
	local playerGui = Instance.new("Folder")
	local player = { Character = localCharacter, Team = { Name = "Killer" }, WaitForChild = function() return playerGui end, GetNetworkPing = function() return 0.04 end }
	local other = { Character = target, Team = { Name = "Survivors" } }
	local camera = { CFrame = CFrame.new(0, 4, 0), WorldToViewportPoint = function() return Vector3.new(100, 100, 1), true end }
	local render = {
		BindToRenderStep = function(_, name, priority, callback) bindings[name] = { priority = priority, callback = callback } end,
		UnbindFromRenderStep = function(_, name) bindings[name] = nil end,
	}
	local services = {
		Players = { LocalPlayer = player, GetPlayers = function() return { player, other } end }, RunService = render,
		UserInputService = { GetMouseLocation = function() return Vector2.new(100, 100) end },
		GuiService = { GetGuiInset = function() return Vector2.zero end },
	}
	local globals = { ViolenceDistrictLogic = { Version = 1, getState = function() return { spearAimEnabled = true } end } }
	local fakeGame = { GetService = function(_, name) return services[name] or game:GetService(name) end }
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable({ game = fakeGame, workspace = { Gravity = 196.2, CurrentCamera = camera }, getgenv = function() return globals end }, { __index = getfenv() }))
	local logic = chunk()
	local stopped = Instance.new("BindableEvent")
	local function animation(id)
		for _, connection in ipairs(getconnections(animator.AnimationPlayed)) do
			if connection.Function then connection.Function({ Animation = { AnimationId = "rbxassetid://" .. id }, Stopped = stopped.Event }) end
		end
	end
	local checks = 0
	local function expect(value, message) assert(value, message) checks = checks + 1 end
	local ok, err = pcall(function()
		logic._watchProjectileCharacter(localCharacter)
		task.wait()
		animation("92098503722633")
		expect(bindings.CateyesSpearAim ~= nil, "Charge did not bind aim")
		task.wait(1.02)
		local previousDirection = camera.CFrame.LookVector
		bindings.CateyesSpearAim.callback(1 / 60)
		local aim = logic._spearAimDebug
		expect(aim and aim.direction and aim.speed == 142.5, "Charge did not produce medium-speed intercept")
		local remaining = (camera.CFrame.LookVector - aim.direction).Magnitude
		expect(remaining > 0.0001 and remaining < (previousDirection - aim.direction).Magnitude,
			"Camera did not ease toward the launch direction")
		expect(bindings.CateyesSpearAim.priority == Enum.RenderPriority.Camera.Value + 1, "Aim uses incorrect camera priority")
		local targetRoot = target.HumanoidRootPart
		targetRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 16)
		targetRoot.Position = targetRoot.Position + Vector3.new(-1.6, 0, 0)
		task.wait(0.1)
		bindings.CateyesSpearAim.callback(1 / 60)
		local moving = logic._spearAimDebug
		expect(moving.velocity.X < -5 and math.abs(moving.velocity.Z) < 0.001,
			"Stale assembly velocity overrode observed sideways movement")
		expect(moving.point.X < targetRoot.Position.X, "Predicted point did not lead in the observed velocity direction")
		animation("93136435416899")
		bindings.CateyesSpearAim.callback(1 / 60)
		expect(logic._spearAimDebug.speed == 142.5, "Release changed medium shot to full speed")
		expect((camera.CFrame.LookVector - logic._spearAimDebug.direction).Magnitude < 0.0001,
			"Smoothing left an aiming offset on release")
		task.wait(0.17)
		bindings.CateyesSpearAim.callback(1 / 60)
		expect(not bindings.CateyesSpearAim and not logic._spearAimDebug, "Release retained camera lock")
		animation("92098503722633")
		localCharacter:SetAttribute("spearmode", false)
		task.wait()
		expect(not bindings.CateyesSpearAim, "Weapon switch retained camera lock")
		localCharacter:SetAttribute("spearmode", true)
		animation("92098503722633")
		logic._loadFeatureModule = function(_, fallback, context) return fallback and fallback(context) or {} end
		logic.setSpearAimEnabled(false)
		expect(not bindings.CateyesSpearAim, "Disabling feature retained camera lock")
		logic.setSpearAimEnabled(true)
		expect(bindings.CateyesSpearAim ~= nil, "Re-enabling during charge did not bind aim")
		logic.destroy()
		expect(not bindings.CateyesSpearAim, "Destroy retained camera lock")
	end)
	pcall(logic.destroy)
	stopped:Destroy() playerGui:Destroy()
	for _, model in ipairs(models) do model:Destroy() end
	assert(ok, err)
	return string.format("PASS: %d fake-camera lifecycle assertions; acquisition, charge, release, weapon switch and destruction", checks)
end
