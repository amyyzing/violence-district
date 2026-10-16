-- Run with the skill-check factory in Roblox. Input is recorded, never sent to the game.
return function(factory)
	local container = Instance.new("Folder")
	local step = Instance.new("BindableEvent")
	local presses = 0
	local pressedAngles = {}
	local observedCheck
	local enabled, mode = true, "Perfect"
	local feature
	local function prompt(name, visible)
		local screen = Instance.new("ScreenGui")
		screen.Name = name
		screen.Parent = container
		local check = Instance.new("Frame")
		check.Name = "Check"
		check.Visible = visible
		check.Parent = screen
		for _, namePart in ipairs({ "Line", "Goal" }) do
			local image = Instance.new("ImageLabel")
			image.Name = namePart
			image.Parent = check
		end
		return check
	end
	local function hit(check)
		check.Line.Rotation = check.Goal.Rotation + 108
		step:Fire()
		task.wait()
	end
	local ok, err = pcall(function()
		local desktop = prompt("SkillCheckPromptGui", true)
		local console = prompt("SkillCheckPromptGui-con", false)
		feature = factory({
			playerGui = container,
			runService = { Stepped = step.Event },
			virtualInputManager = { SendKeyEvent = function(_, down)
				if down then
					presses = presses + 1
					if observedCheck then
						pressedAngles[#pressedAngles + 1] = observedCheck.Line.Rotation - observedCheck.Goal.Rotation
					end
				end
			end },
			getEnabled = function() return enabled end,
			setEnabled = function(value) enabled = value end,
			getMode = function() return mode end,
			setMode = function(value) mode = value end,
			normalizeMode = function(value) return value end,
			emit = function() end,
		})
		hit(desktop)
		assert(presses == 1, "Initially visible prompt did not trigger")
		desktop.Visible = false
		console.Visible = true
		task.wait()
		hit(console)
		assert(presses == 2, "Second prompt was not registered during initial scan")
		console.Goal.Rotation = 200
		task.wait()
		hit(console)
		assert(presses == 3, "Goal change did not rearm")
		console.Line:Destroy()
		local replacement = Instance.new("ImageLabel")
		replacement.Name = "Line"
		replacement.Parent = console
		task.wait()
		hit(console)
		assert(presses == 4, "Replacement Line did not rebind")
		local unrelated = Instance.new("Folder")
		unrelated.Name = "Line"
		unrelated.Parent = container
		unrelated:Destroy()
		console.Parent:Destroy()
		local recreated = prompt("SkillCheckPromptGui-con", true)
		task.wait()
		hit(recreated)
		assert(presses == 5, "Recreated prompt did not rebind")
		feature.setMode("Normal")
		hit(recreated)
		assert(presses == 5, "Changing mode sent a second input for the same check")
		feature.setEnabled(false)
		feature.setEnabled(true)
		hit(recreated)
		assert(presses == 5, "Re-enabling sent a second input for the same check")
		recreated.Visible = false
		recreated.Parent.Enabled = false
		recreated.Visible = true
		task.wait()
		hit(recreated)
		assert(presses == 5, "Disabled ScreenGui received skill input")
		recreated.Parent.Enabled = true
		task.wait()
		hit(recreated)
		assert(presses == 6, "Re-enabled ScreenGui was not watched")
		recreated.Visible = false
		feature.setEnabled(false)
		recreated.Visible = true
		task.wait()
		hit(recreated)
		assert(presses == 6, "Disabled feature sent input")
		feature.setEnabled(true)
		hit(recreated)
		assert(presses == 7, "Enabled feature did not resume")
		recreated.Visible = false
		recreated.Goal.Rotation = 500
		recreated.Line.Rotation = 248
		recreated.Visible = true
		task.wait()
		step:Fire()
		task.wait()
		assert(presses == 7, "Wrapped a negative difference into a false success")
		hit(recreated)
		assert(presses == 8, "Absolute angles above 360 did not trigger")
		recreated.Goal.Rotation = 700
		task.wait()
		recreated.Line.Rotation = 1168
		step:Fire()
		task.wait()
		assert(presses == 8, "Wrapped a missed full rotation into a false success")
		hit(recreated)
		assert(presses == 9, "New continuous-rotation goal did not rearm")
		observedCheck = recreated
		local function rotationCase(angles, expected, caseMode)
			recreated.Visible = false
			task.wait()
			feature.setMode(caseMode or "Perfect")
			recreated.Line.Rotation = recreated.Goal.Rotation
			recreated.Visible = true
			task.wait()
			local before = presses
			for _, angle in ipairs(angles) do
				recreated.Line.Rotation = recreated.Goal.Rotation + angle
				task.wait()
			end
			assert(presses == before + (expected and 1 or 0), "Incorrect input count for rotation case")
			if expected == true then
				local angle = pressedAngles[#pressedAngles]
				assert(angle >= 102 and angle <= 159, "Tween input fell outside the game's accepted window")
			elseif expected then
				assert(pressedAngles[#pressedAngles] == expected, "Wrong rotation-change hit angle")
			end
			step:Fire()
			task.wait()
			assert(presses == before + (expected and 1 or 0), "Step duplicated a rotation-change input")
		end
		rotationCase({ 80, 100, 115, 140 }, 115)
		rotationCase({ 70, 100, 130, 160 }, 130)
		rotationCase({ 100, 159, 180 }, 159)
		rotationCase({ 100, 160, 468 }, nil)
		rotationCase({ 90, 102, 120 }, 102, "Normal")
		rotationCase({ 90, 116, 130 }, 116)
		for _, fps in ipairs({ 30, 60, 120 }) do
			for _, duration in ipairs({ 0.4, 0.65, 1.3 }) do
				for _, goal in ipairs({ 0, 47, 199, 700 }) do
					recreated.Visible = false
					task.wait()
					recreated.Goal.Rotation = goal
					local angles = {}
					for frame = 1, math.ceil((goal % 360 + 160) * duration * fps / 360) do
						local angle = frame * 360 / (duration * fps) - goal % 360
						angles[#angles + 1] = angle
					end
					rotationCase(angles, true)
				end
			end
		end
		for _, duration in ipairs({ 0.4, 0.65, 1.3 }) do
			for _, goal in ipairs({ 0, 47, 199, 700 }) do
				recreated.Visible = false
				task.wait()
				recreated.Goal.Rotation = goal
				recreated.Line.Rotation = goal - goal % 360
				recreated.Visible = true
				task.wait()
				local before = presses
				local tween = game:GetService("TweenService"):Create(recreated.Line,
					TweenInfo.new(duration, Enum.EasingStyle.Linear), { Rotation = goal + 180 })
				tween:Play()
				tween.Completed:Wait()
				task.wait()
				assert(presses == before + 1, "Real tween did not produce exactly one input")
				local angle = pressedAngles[#pressedAngles]
				assert(angle >= 102 and angle <= 159, "Real tween input missed the accepted window")
				tween:Destroy()
			end
		end
		local queued = prompt("SkillCheckPromptGui-con", true)
		local beforeDestroy = presses
		feature.destroy()
		task.wait()
		hit(queued)
		assert(presses == beforeDestroy, "Deferred work survived destroy")
	end)
	if feature then feature.destroy() end
	container:Destroy()
	step:Destroy()
	assert(ok, err)
	return "PASS: lifecycle, absolute rotations, skipped great zones, window boundaries, 36 sampled rotation cases, 12 real tweens, cleanup"
end
