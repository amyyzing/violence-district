return function(c)
	local feature = {}
	local active = true
	local boundCheck
	local lineGUI
	local goalGUI
	local steppedConnection
	local rotationConnection
	local goalConnection
	local ancestryConnection
	local descendantAddedConnection
	local descendantRemovingConnection
	local candidateConnections = {}
	local previousRelativeRotation
	local consumed = false
	local inputFailureWarned = false
	local scanForCheck

	local SUCCESS_MIN = 102
	local SUCCESS_MAX = 116
	local NORMAL_MAX = 159
	local PERFECT_TARGET = 108
	local PROMPT_NAMES = {
		SkillCheckPromptGui = true,
		["SkillCheckPromptGui-con"] = true,
	}

	local function disconnect(connection)
		if connection then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end

	local function stopWatching()
		disconnect(steppedConnection)
		disconnect(rotationConnection)
		steppedConnection = nil
		rotationConnection = nil
		previousRelativeRotation = nil
	end

	local function resolveCheck(check)
		if not active or typeof(check) ~= "Instance" or not check:IsA("GuiObject") or check.Name ~= "Check" then
			return nil
		end

		local prompt = check.Parent
		if not prompt or not PROMPT_NAMES[prompt.Name] or prompt.Parent ~= c.playerGui then
			return nil
		end

		local line = check:FindFirstChild("Line")
		local goal = check:FindFirstChild("Goal")
		if not line or not line:IsA("GuiObject") or not goal or not goal:IsA("GuiObject") then
			return nil
		end
		return line, goal
	end

	local function isVisible(check)
		local prompt = check and check.Parent
		return check and check.Visible and prompt and prompt.Parent == c.playerGui
			and (not prompt:IsA("ScreenGui") or prompt.Enabled)
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
		if relativeRotation < SUCCESS_MIN or relativeRotation > NORMAL_MAX then
			return false
		end
		-- A fast tween can skip the entire great zone between rendered frames.
		-- The game still accepts this following region as a normal hit.
		if relativeRotation > SUCCESS_MAX then
			return true
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
		if not active or consumed or not c.getEnabled() or not isVisible(boundCheck) then
			return
		end
		if not lineGUI or lineGUI.Parent ~= boundCheck or not goalGUI or goalGUI.Parent ~= boundCheck then
			return
		end

		local function checkRotation()
			if not active or consumed or not c.getEnabled() or not isVisible(boundCheck) then
				stopWatching()
				return
			end
			if not lineGUI.Parent or not goalGUI.Parent then
				stopWatching()
				return
			end

			-- Generator/healing scripts compare absolute angles, including Scourge's
			-- continuous rotations. Wrapping can turn a missed zone into a success.
			local relativeRotation = lineGUI.Rotation - goalGUI.Rotation
			local trigger = shouldTrigger(relativeRotation)
			previousRelativeRotation = relativeRotation
			if trigger then
				stopWatching()
				-- One attempt per check, even if input is unavailable. Never spam retries.
				consumed = true
				sendSpaceInput()
			end
		end
		-- Observe the actual tween update, rather than waiting for the next
		-- physics step. Keep the step check for prompts enabled mid-rotation.
		rotationConnection = lineGUI:GetPropertyChangedSignal("Rotation"):Connect(checkRotation)
		steppedConnection = c.runService.Stepped:Connect(checkRotation)
	end

	local function unbindCheck()
		stopWatching()
		disconnect(goalConnection)
		disconnect(ancestryConnection)
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
		consumed = false
		lineGUI = line
		goalGUI = goal
		goalConnection = goal:GetPropertyChangedSignal("Rotation"):Connect(function()
			consumed = false
			if isVisible(check) and c.getEnabled() then
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

	local function registerCheck(check)
		if candidateConnections[check] or not resolveCheck(check) then
			return
		end

		local visibleConnection = check:GetPropertyChangedSignal("Visible"):Connect(function()
			if check.Visible then
				bindCheck(check)
				consumed = false
				startWatching()
			elseif boundCheck == check then
				stopWatching()
			end
		end)
		local list = { visibleConnection }
		candidateConnections[check] = list
		if check.Parent:IsA("ScreenGui") then
			table.insert(list, check.Parent:GetPropertyChangedSignal("Enabled"):Connect(function()
				scanForCheck()
				startWatching()
			end))
		end
	end

	local function unregisterCheck(check)
		for _, connection in ipairs(candidateConnections[check] or {}) do disconnect(connection) end
		candidateConnections[check] = nil
	end

	scanForCheck = function()
		if not active then
			return
		end
		local fallback
		local visibleCheck
		for promptName in pairs(PROMPT_NAMES) do
			local prompt = c.playerGui:FindFirstChild(promptName)
			local check = prompt and prompt:FindFirstChild("Check")
			if check and resolveCheck(check) then
				registerCheck(check)
				if isVisible(check) then
					visibleCheck = visibleCheck or check
				end
				fallback = fallback or check
			end
		end
		if visibleCheck then
			bindCheck(visibleCheck)
		elseif fallback and not boundCheck then
			bindCheck(fallback)
		end
	end

	descendantAddedConnection = c.playerGui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "Check" or descendant.Name == "Line" or descendant.Name == "Goal" or PROMPT_NAMES[descendant.Name] then
			task.defer(scanForCheck)
		end
	end)
	descendantRemovingConnection = c.playerGui.DescendantRemoving:Connect(function(descendant)
		if descendant == boundCheck then
			unbindCheck()
			unregisterCheck(descendant)
			task.defer(scanForCheck)
		elseif candidateConnections[descendant] then
			unregisterCheck(descendant)
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
		for check in pairs(candidateConnections) do
			unregisterCheck(check)
		end
		disconnect(descendantAddedConnection)
		disconnect(descendantRemovingConnection)
	end

	scanForCheck()
	return feature
end
