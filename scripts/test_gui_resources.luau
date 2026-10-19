-- Isolated GUI reloads and FOV events; no feature input or game remotes.
return function(source)
	local root, changed = Instance.new("Folder"), Instance.new("BindableEvent")
	local events = {}
	local function signal()
		local event = Instance.new("BindableEvent")
		events[#events + 1] = event
		return event.Event
	end
	local run = { Heartbeat = signal(), RenderStepped = signal() }
	local input = {
		InputBegan = signal(), InputChanged = signal(), InputEnded = signal(), WindowFocusReleased = signal(),
		GetFocusedTextBox = function() end, GetMouseLocation = function() return Vector2.zero end,
	}
	local state = { skillCheckMode = "Perfect" }
	local logic = {
		Version = 102, SpearAimFovRadius = 120, Changed = changed.Event,
		start = function() end, getState = function() return state end,
		getFeatureAvailability = function() return { spearAimEnabled = true } end,
	}
	for _, name in ipairs({ "setHighlightsEnabled", "setSkillCheckEnabled", "setProjectileVisualiserEnabled", "setSpearAimEnabled", "setAutoParryEnabled", "setSkillCheckMode" }) do logic[name] = function() end end
	local globals = { ViolenceDistrictLogic = logic }
	local proxy = {}
	function proxy:GetService(name)
		if name == "CoreGui" then return root end
		if name == "RunService" then return run end
		if name == "UserInputService" then return input end
		return game:GetService(name)
	end
	local upvalues = getupvalues or debug.getupvalues
	local function fire(signal, ...)
		for _, c in pairs(getconnections(signal)) do if c.Function then c.Function(...) end end
	end
	local function count(signal)
		local n = 0
		for _, c in pairs(getconnections(signal)) do if c.Connected ~= false then n = n + 1 end end
		return n
	end
	local controller, checks, baselineObjects
	checks = 0
	local function expect(value, message) assert(value, message) checks = checks + 1 end
	local ok, err = pcall(function()
		for _ = 1, 25 do
			local chunk = assert(loadstring(source))
			setfenv(chunk, setmetatable({ game = proxy, getgenv = function() return globals end }, { __index = getfenv() }))
			controller = chunk()
			expect(#root:GetChildren() == 1, "Reload retained duplicate GUI roots")
			baselineObjects = baselineObjects or #root:GetDescendants()
			expect(#root:GetDescendants() == baselineObjects, "Reload increased GUI object count")
			expect(count(run.Heartbeat) == 1 and count(changed.Event) == 1, "Reload accumulated availability/state listeners")
			expect(count(run.RenderStepped) == 0, "Disabled aim retained FOV frame updates")
			local mark = controller.Gui.Panel.Content.Features.HighlightsRow.Mark
			local tweenMap
			for _, c in pairs(getconnections(changed.Event)) do
				for _, value in pairs(upvalues(c.Function)) do
					if type(value) == "function" then
						for _, nested in pairs(upvalues(value)) do
							if type(nested) == "table" and nested[mark] then tweenMap = nested end
						end
					end
				end
			end
			expect(tweenMap ~= nil, "Could not inspect GUI-owned tweens")
			local initialTween = tweenMap[mark]
			for _ = 1, 100 do fire(changed.Event, state) end
			expect(tweenMap[mark] == initialTween, "Unchanged state restarted feature tweens")
			state.spearAimEnabled = true fire(changed.Event, state)
			expect(count(run.RenderStepped) == 1, "FOV did not start exactly one frame updater")
			for _ = 1, 20 do fire(changed.Event, state) end
			expect(count(run.RenderStepped) == 1, "Repeated state added FOV frame updaters")
			state.spearAimEnabled = false fire(changed.Event, state)
			expect(count(run.RenderStepped) == 0, "FOV updater survived disabling aim")
		end
		controller.destroy()
		expect(#root:GetChildren() == 0 and count(changed.Event) == 0, "Destroy retained GUI objects or state listeners")
		for _, event in ipairs(events) do expect(count(event.Event) == 0, "Destroy retained input/frame listeners") end
	end)
	if controller then controller.destroy() end
	root:Destroy() changed:Destroy()
	for _, event in ipairs(events) do event:Destroy() end
	assert(ok, err)
	return string.format("PASS: %d GUI resource assertions; 25 reloads, stable objects/listeners, idle FOV and unchanged-state tweens", checks)
end
