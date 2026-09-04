-- Run with the skill-check factory in Roblox. Input is recorded, never sent to the game.
return function(factory)
	local container = Instance.new("Folder")
	local step = Instance.new("BindableEvent")
	local presses = 0
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
			getEnabled = function() return true end,
			getMode = function() return "Perfect" end,
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
		local queued = prompt("SkillCheckPromptGui-con", true)
		feature.destroy()
		task.wait()
		hit(queued)
		assert(presses == 5, "Deferred work survived destroy")
	end)
	if feature then feature.destroy() end
	container:Destroy()
	step:Destroy()
	assert(ok, err)
	return "PASS: initial visibility, prompt switching, goal rearm, replacement, recreation, cleanup"
end
