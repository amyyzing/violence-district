-- Run with the skill-check factory in Roblox. Input is recorded, never sent to the game.
return function(factory)
	local container = Instance.new("Folder")
	local step = Instance.new("BindableEvent")
	local presses = 0
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
				if down then presses = presses + 1 end
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
		local queued = prompt("SkillCheckPromptGui-con", true)
		feature.destroy()
		task.wait()
		hit(queued)
		assert(presses == 7, "Deferred work survived destroy")
	end)
	if feature then feature.destroy() end
	container:Destroy()
	step:Destroy()
	assert(ok, err)
	return "PASS: initial visibility, prompt switching, goal rearm, replacement, recreation, mode/enable deduplication, hidden screen, disable/resume, cleanup"
end
