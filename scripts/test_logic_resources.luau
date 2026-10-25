-- Owned signals/models: checks whole-logic start/destroy without live gameplay input.
return function(source, skillFactory, parryFactory)
	local events, models, checks = {}, {}, 0
	local function signal()
		local event = Instance.new("BindableEvent") events[#events + 1] = event return event.Event
	end
	local character = Instance.new("Model") models[#models + 1] = character
	local humanoid = Instance.new("Humanoid") humanoid.Parent = character
	local animator = Instance.new("Animator") animator.Parent = humanoid
	local dagger = Instance.new("Model") dagger.Name, dagger.Parent = "Parrying Dagger", character
	local playerGui, storage = Instance.new("Folder"), Instance.new("Folder")
	local player = { Name = "Fixture", Character = character, Team = { Name = "Survivors" },
		CharacterAdded = signal(), CharacterRemoving = signal(), WaitForChild = function() return playerGui end,
		GetAttribute = function() end, GetPropertyChangedSignal = function() return signal() end }
	local players = { LocalPlayer = player, GetPlayers = function() return { player } end,
		PlayerAdded = signal(), PlayerRemoving = signal() }
	local run = { Heartbeat = signal(), Stepped = signal(), UnbindFromRenderStep = function() end }
	local input = { InputBegan = signal(), InputEnded = signal(), WindowFocusReleased = signal() }
	local world = { ChildAdded = signal(), ChildRemoved = signal(), FindFirstChild = function() end }
	local services = { Players = players, ReplicatedStorage = storage, RunService = run, UserInputService = input }
	local proxy = { GetService = function(_, name) return services[name] or game:GetService(name) end }
	local globals = {}
	local upvalues = getupvalues or debug.getupvalues
	local logic
	local function count(event)
		local n = 0 for _, c in pairs(getconnections(event)) do if c.Connected ~= false then n = n + 1 end end return n
	end
	local function expect(value, message) assert(value, message) checks = checks + 1 end
	local ok, err = pcall(function()
		for _ = 1, 15 do
			local chunk = assert(loadstring(source))
			setfenv(chunk, setmetatable({ game = proxy, workspace = world, getgenv = function() return globals end }, { __index = getfenv() }))
			logic = chunk()
			logic._loadFeatureModule = function(name, fallback, context)
				if name == "SkillCheck" then return skillFactory(context) end
				if name == "AutoParry" then return parryFactory(context) end
				return fallback(context)
			end
			logic.start()
			logic.start()
			expect(count(run.Heartbeat) == 0, "Idle logic retained an obsolete physics listener")
			logic.setHighlightsEnabled(true) logic.setHighlightsEnabled(false)
			logic.setSkillCheckEnabled(true) logic.setSkillCheckEnabled(false)
			logic.setAutoParryEnabled(true) logic.setAutoParryEnabled(false)
			player.Team.Name, dagger.Parent = "Spectator", nil
			logic.setProjectileVisualiserEnabled(true)
			logic.setSpearAimEnabled(true)
			logic.setAutoParryEnabled(true)
			local saved = logic.getState()
			expect(saved.projectileVisualiserEnabled and saved.spearAimEnabled and saved.autoParryEnabled,
				"Unavailable feature could not retain its enabled preference")
			expect(not logic.getFeatureAvailability().autoParryEnabled and not logic.getFeatureAvailability().spearAimEnabled,
				"Enabled preference bypassed role/item requirements")
			expect(not logic.getParryDiagnostics().monitoring, "Unavailable auto parry installed a frame monitor")
			logic.setProjectileVisualiserEnabled(false)
			logic.setSpearAimEnabled(false)
			logic.setAutoParryEnabled(false)
			player.Team.Name, dagger.Parent = "Survivors", character
			expect(count(run.Heartbeat) == 0, "Disabled features retained a frame monitor")
			local resync
			for _, value in pairs(upvalues(logic.start)) do if type(value) == "thread" then resync = value end end
			expect(resync ~= nil, "Map resync worker missing")
			logic.destroy()
			task.wait()
			expect(coroutine.status(resync) == "dead", "Destroy retained the sleeping map worker")
			for _, event in ipairs(events) do expect(count(event.Event) == 0, "Destroy retained an owned service listener") end
			expect(count(animator.AnimationPlayed) == 0 and count(character:GetAttributeChangedSignal("spearmode")) == 0,
				"Destroy retained projectile character listeners")
			expect(count(playerGui.DescendantAdded) == 0 and count(playerGui.DescendantRemoving) == 0,
				"Destroy retained skill-check discovery listeners")
		end
	end)
	if logic then pcall(logic.destroy) end
	for _, event in ipairs(events) do event:Destroy() end
	for _, model in ipairs(models) do model:Destroy() end
	playerGui:Destroy() storage:Destroy()
	assert(ok, err)
	return string.format("PASS: %d logic resource assertions; 15 start/destroy cycles, feature toggles and worker/listener cleanup", checks)
end
