return function(c)
	local feature = {}
	local active = true
	local boundCheck
	local lineGUI
	local goalGUI
	local steppedConnection
	local visibleConnection
	local goalConnection
	local ancestryConnection
	local descendantAddedConnection
	local descendantRemovingConnection
	local previousRelativeRotation
	local inputFailureWarned = false
	local scanForCheck

	local SUCCESS_MIN = 103
	local SUCCESS_MAX = 113
	local PERFECT_TARGET = 108

	local function disconnect(connection)
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	local function stopWatching()
		disconnect(steppedConnection)
		steppedConnection = nil
		previousRelativeRotation = nil
	end

	local function resolveCheck(check)
		if typeof(check) ~= "Instance" or check.Name ~= "Check" then
			return nil
		end

		local prompt = check.Parent
		if not prompt or prompt.Name ~= "SkillCheckPromptGui" or prompt.Parent ~= c.playerGui then
			return nil
		end

		local line = check:FindFirstChild("Line")
		local goal = check:FindFirstChild("Goal")
		if not line or not goal then
			return nil
		end
		return line, goal
	end

	local function sendSpaceInput()
		local ok, err = pcall(function()
			c.virtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
			c.virtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
		end)
		if ok then
			inputFailureWarned = false
			return true
		end

		if not inputFailureWarned then
			inputFailureWarned = true
			warn("[Violence District] VirtualInputManager skill input failed: " .. tostring(err))
		end
		return false
	end

	local function shouldTrigger(relativeRotation)
		if relativeRotation < SUCCESS_MIN or relativeRotation > SUCCESS_MAX then
			return false
		end
		if c.getMode() ~= "Perfect" or relativeRotation >= PERFECT_TARGET then
			return true
		end

		local previous = previousRelativeRotation
		local frameStep = previous and relativeRotation - previous or 0
		return frameStep > 0 and relativeRotation + frameStep > SUCCESS_MAX
	end

	local function startWatching()
		stopWatching()
		if not active or not c.getEnabled() or not boundCheck or not boundCheck.Visible then
			return
		end
		if not lineGUI or lineGUI.Parent ~= boundCheck or not goalGUI or goalGUI.Parent ~= boundCheck then
			return
		end

		steppedConnection = c.runService.Stepped:Connect(function()
			if not active or not c.getEnabled() or not boundCheck or not boundCheck.Visible then
				stopWatching()
				return
			end
			if not lineGUI.Parent or not goalGUI.Parent then
				stopWatching()
				return
			end

			local relativeRotation = (lineGUI.Rotation - goalGUI.Rotation) % 360
			local trigger = shouldTrigger(relativeRotation)
			previousRelativeRotation = relativeRotation
			if trigger then
				stopWatching()
				if not sendSpaceInput() and boundCheck and boundCheck.Visible then
					task.defer(startWatching)
				end
			end
		end)
	end

	local function unbindCheck()
		stopWatching()
		disconnect(visibleConnection)
		disconnect(goalConnection)
		disconnect(ancestryConnection)
		visibleConnection = nil
		goalConnection = nil
		ancestryConnection = nil
		boundCheck = nil
		lineGUI = nil
		goalGUI = nil
	end

	local function bindCheck(check)
		local line, goal = resolveCheck(check)
		if not line then
			return false
		end
		if boundCheck == check and lineGUI == line and goalGUI == goal then
			return true
		end

		unbindCheck()
		boundCheck = check
		lineGUI = line
		goalGUI = goal
		visibleConnection = check:GetPropertyChangedSignal("Visible"):Connect(function()
			if check.Visible then
				startWatching()
			else
				stopWatching()
			end
		end)
		goalConnection = goal:GetPropertyChangedSignal("Rotation"):Connect(function()
			if check.Visible and c.getEnabled() then
				startWatching()
			end
		end)
		ancestryConnection = check.AncestryChanged:Connect(function(_, parent)
			if not parent then
				unbindCheck()
				task.defer(scanForCheck)
			end
		end)

		if check.Visible and c.getEnabled() then
			startWatching()
		end
		return true
	end

	scanForCheck = function()
		if not active then
			return
		end
		local prompt = c.playerGui:FindFirstChild("SkillCheckPromptGui")
		local check = prompt and prompt:FindFirstChild("Check")
		if check then
			bindCheck(check)
		end
	end

	descendantAddedConnection = c.playerGui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Check" then
			task.defer(function()
				bindCheck(descendant)
			end)
		elseif (descendant.Name == "Line" or descendant.Name == "Goal") and descendant.Parent then
			task.defer(function()
				bindCheck(descendant.Parent)
			end)
		end
	end)
	descendantRemovingConnection = c.playerGui.DescendantRemoving:Connect(function(descendant)
		if descendant == boundCheck then
			unbindCheck()
		elseif descendant == lineGUI or descendant == goalGUI then
			stopWatching()
		end
	end)

	function feature.setEnabled(on)
		local nextValue = on == true
		if c.getEnabled() == nextValue then
			return
		end

		c.setEnabled(nextValue)
		if nextValue then
			scanForCheck()
			startWatching()
		else
			stopWatching()
		end
		c.emit()
	end

	function feature.toggle()
		feature.setEnabled(not c.getEnabled())
	end

	function feature.setMode(mode)
		local nextMode = c.normalizeMode(mode, c.getMode())
		if c.getMode() == nextMode then
			return
		end

		c.setMode(nextMode)
		if boundCheck and boundCheck.Visible then
			startWatching()
		end
		c.emit()
	end

	function feature.destroy()
		if not active then
			return
		end
		active = false
		unbindCheck()
		disconnect(descendantAddedConnection)
		disconnect(descendantRemovingConnection)
	end

	scanForCheck()
	return feature
end
